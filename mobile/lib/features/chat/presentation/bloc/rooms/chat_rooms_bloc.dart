import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_background_service.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/features/chat/presentation/bloc/rooms/room_sync_reconciler.dart';
import 'package:jperg_app/models/chat/chat_message.dart';
import 'package:jperg_app/models/chat/chat_room.dart';
import 'package:jperg_app/core/session/session_reset.dart';
import 'package:jperg_app/services/auth_service.dart';

part 'chat_rooms_event.dart';
part 'chat_rooms_state.dart';

class ChatRoomsBloc extends Bloc<ChatRoomsEvent, ChatRoomsState> {
  final GetMyRoomsUseCase _getMyRooms;
  final GetCachedRoomsUseCase _getCachedRooms;
  final GetUnreadCountsUseCase _getUnreadCounts;
  final GetLastMessageTimesUseCase _getLastMessageTimes;
  final GetRoomMessagesUseCase _getRoomMessages;
  final AcceptRoomInviteUseCase _acceptInvite;
  final DeclineRoomInviteUseCase _declineInvite;
  final ClearRoomCacheUseCase _clearRoomCache;
  final ChatBackgroundService _bgService;
  final AuthService _authService;

  /// Decides when a room the server has stopped listing is really gone —
  /// see [RoomSyncReconciler] for why this needs a grace sync.
  final _reconciler = RoomSyncReconciler();

  StreamSubscription<ChatRoom>? _groupInviteSub;
  StreamSubscription<ChatMessage>? _bgMsgSub;
  StreamSubscription<ChatMessage>? _openRoomMsgSub;
  StreamSubscription<String>? _roomRemovedSub;
  StreamSubscription<void>? _roomsChangedSub;

  ChatRoomsBloc({
    required GetMyRoomsUseCase getMyRooms,
    required GetCachedRoomsUseCase getCachedRooms,
    required GetUnreadCountsUseCase getUnreadCounts,
    required GetLastMessageTimesUseCase getLastMessageTimes,
    required GetRoomMessagesUseCase getRoomMessages,
    required AcceptRoomInviteUseCase acceptInvite,
    required DeclineRoomInviteUseCase declineInvite,
    required ClearRoomCacheUseCase clearRoomCache,
    required ChatBackgroundService bgService,
    required AuthService authService,
  })  : _getMyRooms = getMyRooms,
        _getCachedRooms = getCachedRooms,
        _getUnreadCounts = getUnreadCounts,
        _getLastMessageTimes = getLastMessageTimes,
        _getRoomMessages = getRoomMessages,
        _acceptInvite = acceptInvite,
        _declineInvite = declineInvite,
        _clearRoomCache = clearRoomCache,
        _bgService = bgService,
        _authService = authService,
        super(const ChatRoomsState()) {
    // restartable() cancels a still-running _onLoad when a newer one is
    // requested, so a stale/slow server round-trip from an earlier load
    // (e.g. kicked off at app launch) can never emit *after* — and clobber
    // — a more recent load's correct result. Without this, _onLoad calls
    // race freely and whichever happens to finish last wins, regardless of
    // which was actually requested last.
    on<ChatRoomsLoadRequested>(_onLoad, transformer: restartable());
    // concurrent() lets refresh events run immediately alongside _onLoad
    // instead of queuing behind the network call, so the badge updates as
    // soon as a background WS message is saved to the DB.
    on<ChatRoomsRefreshUnread>(_onRefreshUnread, transformer: concurrent());
    on<ChatRoomsAcceptInvite>(_onAcceptInvite, transformer: concurrent());
    on<ChatRoomsDeclineInvite>(_onDeclineInvite, transformer: concurrent());
    on<ChatRoomsGroupInviteReceived>(_onGroupInviteReceived, transformer: concurrent());
    on<_ChatRoomsMessageArrived>(_onMessageArrived, transformer: concurrent());
    on<_ChatRoomsRoomRead>(_onRoomRead, transformer: concurrent());
    on<_ChatRoomsRoomRemoved>(_onRoomRemoved, transformer: concurrent());
    on<ChatRoomsSessionCleared>(_onSessionCleared, transformer: concurrent());

    // Torn down on sign-out. This bloc lives above the Navigator so that the
    // unread badge works everywhere, which also means replacing the navigation
    // stack does not touch it — registering is the only thing that empties it.
    SessionReset.register(this, 'ChatRoomsBloc', () {
      if (!isClosed) add(const ChatRoomsSessionCleared());
    });

    _wireBackgroundCallbacks();

    // Direct message stream: updates unreadCounts and lastMessageAt in-memory,
    // bypassing the DB.  Essential on web where SQLite is unavailable.
    _bgMsgSub = _bgService.backgroundMessages.listen((msg) {
      if (!isClosed) {
        add(_ChatRoomsMessageArrived(msg.roomId, msg.createdAt,
            senderId: msg.senderId,
            senderName: msg.senderName,
            preview: _previewOf(msg),
            countsAsUnread: !msg.isSystem));
      }
    });

    // The open room's own messages — sent and received. That room is paused, so
    // none of them reach `backgroundMessages`; without this the tile still
    // shows the previous message when the user backs out of the conversation.
    // Nothing here is unread: the user is reading it as it arrives.
    _openRoomMsgSub = _bgService.openRoomMessages.listen((msg) {
      if (!isClosed) {
        add(_ChatRoomsMessageArrived(msg.roomId, msg.createdAt,
            senderId: msg.senderId,
            senderName: msg.senderName,
            preview: _previewOf(msg),
            countsAsUnread: false));
      }
    });

    // Subscribe to the persistent relay — one subscription, no reconnect
    // management needed. All WS instances (shared + DiscoveryBloc per-event
    // sessions) funnel invites through this relay.
    _groupInviteSub = _bgService.groupInviteStream.listen((room) {
      debugPrint('[ChatRoomsBloc] groupInviteStream: roomId=${room.id} isClosed=$isClosed');
      if (!isClosed) add(ChatRoomsGroupInviteReceived(room));
    });

    // Room removed (deleted, or I was kicked) → drop it from the list live.
    _roomRemovedSub = _bgService.roomRemovedStream.listen((roomId) {
      if (!isClosed) add(_ChatRoomsRoomRemoved(roomId));
    });

    // Membership / settings changed → re-sync so names + members update live.
    _roomsChangedSub = _bgService.roomsChangedStream.listen((_) {
      if (!isClosed) add(const ChatRoomsLoadRequested());
    });
    debugPrint('[ChatRoomsBloc] created — subscribed to room lifecycle relays');
  }

  @override
  Future<void> close() {
    SessionReset.unregister(this);
    _groupInviteSub?.cancel();
    _bgMsgSub?.cancel();
    _openRoomMsgSub?.cancel();
    _roomRemovedSub?.cancel();
    _roomsChangedSub?.cancel();
    return super.close();
  }

  /// Points the background service's callbacks back at this bloc.
  ///
  /// Called from the constructor and again on every load, because it has to
  /// survive a sign-out. `ChatBackgroundService.disconnectAll` detaches these
  /// on its way out — correctly, since the bloc that set them may well be
  /// going too — but this one is built above the Navigator and is not: it is
  /// the same instance before and after, and left detached it would go on
  /// showing an inbox that never updated its badge again.
  ///
  /// Re-arming on load rather than in the teardown keeps it independent of the
  /// order handlers happen to run in. Assigning twice costs nothing.
  void _wireBackgroundCallbacks() {
    // New background message → refresh the navbar badge.
    _bgService.onUnreadUpdate = () {
      if (!isClosed) add(const ChatRoomsRefreshUnread());
    };
    // Badge-clear signal: ChatRoomBloc fires this when a room is opened.
    _bgService.onRoomRead = (roomId) {
      if (!isClosed) add(_ChatRoomsRoomRead(roomId));
    };
  }

  /// Back to the state a freshly built bloc has.
  ///
  /// A whole new [ChatRoomsState] rather than a `copyWith`: copyWith keeps
  /// every field not named, and the point here is that nothing is kept. A
  /// field added later would otherwise quietly survive sign-out, which is the
  /// exact class of bug this handler exists for.
  void _onSessionCleared(
    ChatRoomsSessionCleared event,
    Emitter<ChatRoomsState> emit,
  ) {
    emit(const ChatRoomsState());
  }

  Future<void> _onLoad(
    ChatRoomsLoadRequested event,
    Emitter<ChatRoomsState> emit,
  ) async {
    _wireBackgroundCallbacks();
    final myUserId = await _authService.getUserId();

    // Whether there is already an inbox on screen. Every re-entry to the Chats
    // tab lands here, so this is the common case, and the rule for it is: show
    // the user nothing. No spinner, no progress bar, no intermediate list —
    // the rows they are looking at stay exactly as they are until the server
    // has something better to put in their place.
    final hasRooms = state.rooms.isNotEmpty || state.pendingInvites.isNotEmpty;

    // 1. Cold start only: paint the cache so there is something to look at.
    //    Re-reading it when the list is already up would swap the rows for a
    //    staler copy of themselves and then swap them back a moment later —
    //    two visible content changes that tell the user nothing.
    if (!hasRooms) {
      try {
        final results = await Future.wait([
          _getCachedRooms(),
          _getUnreadCounts(),
          _getLastMessageTimes(),
        ]);
        final all = results[0] as List<ChatRoom>;
        final counts = results[1] as Map<String, int>;
        final lastTimes = results[2] as Map<String, DateTime>;
        final split = _splitRooms(all, myUserId);
        if (all.isNotEmpty) {
          emit(state.copyWith(
            rooms: split.$1,
            pendingInvites: split.$2,
            unreadCounts: counts,
            lastMessageAt: lastTimes,
            isSyncing: true,
            clearError: true,
            currentUserId: myUserId,
          ));
          _bgService.connectAll(split.$1);
        } else {
          emit(state.copyWith(
              isLoading: true, isSyncing: true, clearError: true));
        }
      } catch (_) {
        emit(state.copyWith(isLoading: true, isSyncing: true, clearError: true));
      }
    } else {
      // isLoading stays false — it means "nothing to show yet", and there is
      // plenty to show. Only isSyncing moves, and nothing renders it.
      emit(state.copyWith(isSyncing: true, clearError: true));
    }

    // 2. Sync from server then refresh counts.
    try {
      final fresh = await _getMyRooms();
      final results = await Future.wait([
        _getUnreadCounts(),
        _getLastMessageTimes(),
      ]);
      final counts = results[0] as Map<String, int>;
      final lastTimes = results[1] as Map<String, DateTime>;
      final split = _splitRooms(fresh, myUserId);
      // Web has no local DB, so getUnreadCounts() is empty and the badge would
      // vanish on every page refresh. Seed it from the server's per-room
      // unread_count instead, so it persists until the room is opened (which
      // sends `ack`, clearing it server-side). Native keeps the DB-derived count.
      final effectiveCounts = kIsWeb
          ? <String, int>{
              for (final r in fresh)
                if (r.unreadCount > 0) r.id: r.unreadCount,
            }
          : counts;
      // Rooms the server has now omitted often enough to be gone. Purged from
      // the cache too, or getCachedRooms() would put them straight back on the
      // next cold start.
      // Counted over both buckets at once: _splitRooms divides one server list
      // into active and pending, so a room moving between them is not a miss.
      final stale = _reconciler.onSync(
        fresh.map((r) => r.id).toSet(),
        [...state.rooms, ...state.pendingInvites].map((r) => r.id),
      );
      for (final id in stale) {
        _clearRoomCache(id).ignore();
      }

      emit(state.copyWith(
        // Merge rather than replace: a room just joined/created is written
        // to the local cache synchronously (see ChatRepositoryImpl's
        // _fetchAndCacheRoom), but the server's "list my rooms" response can
        // still be a beat behind that write. Blindly trusting `fresh` here
        // would erase a room the user only just joined — so a locally-known
        // room survives one sync without the server, and is dropped on the
        // next (see [_staleRoomIds]).
        rooms: _mergeRooms(split.$1, state.rooms, stale),
        pendingInvites: _mergeRooms(split.$2, state.pendingInvites, stale),
        unreadCounts: effectiveCounts,
        // Same reasoning as liveMessages below, for ordering rather than text.
        // On web `lastTimes` is always empty (no SQLite), so replacing outright
        // threw away every time learned from a live message and let the list
        // re-order itself on each tab switch.
        lastMessageAt: mergeTimes(lastTimes, state.lastMessageAt),
        // The fresh list carries the server's own previews, so most live ones
        // are now redundant. Dropping them wholesale used to be the rule, but
        // it blanks a tile back to an older message whenever the server's copy
        // of a room is a beat behind what this device has already seen — the
        // message you just sent, most obviously. Keep the ones that are still
        // ahead of the server; they are the only ones that matter.
        liveMessages: pruneLive(state.liveMessages, split.$1),
        isLoading: false,
        isSyncing: false,
        clearError: true,
        currentUserId: myUserId,
      ));

      // 3. Background-fetch the latest messages for active rooms.
      _syncMessagesInBackground(split.$1);

      // 4. Subscribe active rooms for WS.
      _bgService.connectAll(split.$1);
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        isSyncing: false,
        errorMessage: state.rooms.isEmpty && state.pendingInvites.isEmpty
            ? 'Could not load chats.'
            : null,
      ));
    }
  }

  /// Takes the later of the two times known for each room. [fetched] is the
  /// authority where it has an entry; [known] fills the gaps and wins where it
  /// is ahead, which is how a message seen live survives a sync that hasn't
  /// caught up with it yet.
  @visibleForTesting
  static Map<String, DateTime> mergeTimes(
    Map<String, DateTime> fetched,
    Map<String, DateTime> known,
  ) {
    if (known.isEmpty) return fetched;
    final merged = Map<String, DateTime>.from(fetched);
    known.forEach((roomId, at) {
      final existing = merged[roomId];
      if (existing == null || at.isAfter(existing)) merged[roomId] = at;
    });
    return merged;
  }

  /// Keeps only the live previews that are still newer than what [fresh]
  /// carries for the same room — the rest have been superseded by the server's
  /// own copy and would just be two records of the same message.
  ///
  /// A room missing from [fresh] keeps its live preview: the sync has no
  /// opinion about a room it didn't return.
  @visibleForTesting
  static Map<String, LastMessage> pruneLive(
    Map<String, LastMessage> live,
    List<ChatRoom> fresh,
  ) {
    if (live.isEmpty) return const {};
    final serverAt = <String, DateTime>{
      for (final r in fresh)
        if (r.lastMessage != null) r.id: r.lastMessage!.createdAt,
    };
    return {
      for (final entry in live.entries)
        if (!serverAt.containsKey(entry.key) ||
            entry.value.createdAt.isAfter(serverAt[entry.key]!))
          entry.key: entry.value,
    };
  }

  /// Unions [fresh] (just fetched from the server) with any [known] rooms
  /// that aren't in it yet, keyed by id — [fresh]'s copy of a room wins
  /// where both have it, since it's the more up-to-date one.
  List<ChatRoom> _mergeRooms(
    List<ChatRoom> fresh,
    List<ChatRoom> known,
    Set<String> stale,
  ) {
    final freshIds = fresh.map((r) => r.id).toSet();
    final onlyLocal = known
        .where((r) => !freshIds.contains(r.id) && !stale.contains(r.id));
    return [...fresh, ...onlyLocal];
  }


  /// Splits all rooms into (activeRooms, pendingInvites) for [myUserId].
  (List<ChatRoom>, List<ChatRoom>) _splitRooms(
      List<ChatRoom> all, String myUserId) {
    final active = <ChatRoom>[];
    final pending = <ChatRoom>[];
    for (final room in all) {
      if (room.hasPendingInvite(myUserId)) {
        pending.add(room);
      } else {
        active.add(room);
      }
    }
    return (active, pending);
  }

  /// Fetches the first page of messages for the most-recently-active rooms so
  /// the local DB has enough data to show accurate unread counts in the badge.
  /// Rooms are fetched sequentially to avoid flooding the server — older rooms
  /// get their messages lazily when the user opens them.
  Future<void> _syncMessagesInBackground(List<ChatRoom> rooms) async {
    const maxRooms = 5;
    final toSync = rooms.take(maxRooms).toList();
    debugPrint('[ChatRoomsBloc] _syncMessagesInBackground — syncing ${toSync.length} of ${rooms.length} rooms');
    for (final room in toSync) {
      if (isClosed) return;
      try {
        await _getRoomMessages(room.id);
      } catch (e) {
        debugPrint('[ChatRoomsBloc] _syncMessagesInBackground error room=${room.id}: $e');
      }
    }
    if (!isClosed) add(const ChatRoomsRefreshUnread());
  }

  Future<void> _onRefreshUnread(
    ChatRoomsRefreshUnread event,
    Emitter<ChatRoomsState> emit,
  ) async {
    // On web, SQLite is not available: getUnreadCounts/getLastMessageTimes always
    // return empty maps, which would wipe the in-memory state maintained by
    // _onMessageArrived. Skip the DB round-trip entirely on web.
    if (kIsWeb) return;
    try {
      final results = await Future.wait([
        _getUnreadCounts(),
        _getLastMessageTimes(),
      ]);
      emit(state.copyWith(
        unreadCounts: results[0] as Map<String, int>,
        // Merged, not replaced: getLastMessageTimes() deliberately skips
        // messages still marked local, so a message the user has sent but the
        // server has not yet echoed is invisible to it. Replacing outright
        // dropped that room back down the list for the moment in between.
        lastMessageAt: mergeTimes(
            results[1] as Map<String, DateTime>, state.lastMessageAt),
      ));
    } catch (_) {}
  }

  /// Increments the unread badge and updates sort-order for [roomId] without
  /// touching the DB.  Works on all platforms; is the sole update path on web.
  void _onMessageArrived(
    _ChatRoomsMessageArrived event,
    Emitter<ChatRoomsState> emit,
  ) {
    // System notices reorder the room and update its preview, but they are not
    // unread messages — nobody sent them to you. The server's unread query
    // excludes them too, so counting them here would put a badge on the tile
    // that the next sync silently takes away.
    final counts = Map<String, int>.from(state.unreadCounts);
    if (event.countsAsUnread) {
      counts[event.roomId] = (counts[event.roomId] ?? 0) + 1;
    }
    final times = Map<String, DateTime>.from(state.lastMessageAt);
    times[event.roomId] = event.arrivedAt;

    final live = Map<String, LastMessage>.from(state.liveMessages);
    final preview = event.preview;
    if (preview != null) {
      live[event.roomId] = preview;
    } else {
      // Nothing showable for this one. Drop any older preview rather than
      // leaving a stale line that no longer describes the latest message.
      live.remove(event.roomId);
    }

    // Backfill a nameless direct room with the sender's name so the list shows
    // the person's name instead of "Direct Message"/their role.
    var rooms = state.rooms;
    final senderName = event.senderName?.trim() ?? '';
    if (senderName.isNotEmpty &&
        event.senderId != null &&
        event.senderId != state.currentUserId) {
      rooms = rooms.map((r) {
        if (r.id != event.roomId || r.type != RoomType.direct) return r;
        if (r.name != null && r.name!.isNotEmpty) return r;
        final peer = r.participants
            .where((p) => p.userId != state.currentUserId)
            .firstOrNull;
        final hasPeerName = (peer?.userName?.trim().isNotEmpty) ?? false;
        return hasPeerName ? r : r.copyWith(name: senderName);
      }).toList();
    }

    emit(state.copyWith(
        rooms: rooms,
        unreadCounts: counts,
        lastMessageAt: times,
        liveMessages: live));
  }

  /// The arriving message as an inbox preview, or null when there is nothing to
  /// draw for it — ciphertext this device cannot read, or an empty body with no
  /// attachment.
  static LastMessage? _previewOf(ChatMessage msg) {
    if (msg.isEncrypted) return null;
    final text = msg.content.trim();
    if (text.isEmpty && msg.imageUrl == null && !msg.isSystem) return null;
    return LastMessage(
      id: msg.id,
      senderId: msg.senderId,
      senderName: msg.senderName,
      content: text.isEmpty ? null : text,
      hasImage: msg.imageUrl != null,
      systemType: msg.systemType,
      createdAt: msg.createdAt,
    );
  }

  /// Clears the unread badge for [roomId] when the user opens the room.
  void _onRoomRead(
    _ChatRoomsRoomRead event,
    Emitter<ChatRoomsState> emit,
  ) {
    if (!state.unreadCounts.containsKey(event.roomId)) return;
    final counts = Map<String, int>.from(state.unreadCounts)
      ..remove(event.roomId);
    emit(state.copyWith(unreadCounts: counts));
  }

  /// Drop a room (deleted, or I was removed) from the list + pending + counts.
  void _onRoomRemoved(
    _ChatRoomsRoomRemoved event,
    Emitter<ChatRoomsState> emit,
  ) {
    final inRooms = state.rooms.any((r) => r.id == event.roomId);
    final inPending = state.pendingInvites.any((r) => r.id == event.roomId);
    if (!inRooms && !inPending) return;
    // Purge the cache, not just the in-memory list. Without this the row
    // survives in SQLite and getCachedRooms() re-renders the room on the next
    // cold start, even though it was removed live.
    _clearRoomCache(event.roomId).ignore();
    _reconciler.forget(event.roomId);
    final counts = Map<String, int>.from(state.unreadCounts)
      ..remove(event.roomId);
    emit(state.copyWith(
      rooms: state.rooms.where((r) => r.id != event.roomId).toList(),
      pendingInvites:
          state.pendingInvites.where((r) => r.id != event.roomId).toList(),
      unreadCounts: counts,
    ));
  }

  Future<void> _onAcceptInvite(
    ChatRoomsAcceptInvite event,
    Emitter<ChatRoomsState> emit,
  ) async {
    ChatRoom? room;
    for (final r in state.pendingInvites) {
      if (r.id == event.roomId) {
        room = r;
        break;
      }
    }
    if (room == null) return;

    // Optimistically move the room from pending → active *immediately* so the
    // pending card disappears the moment the user taps Join (web + mobile),
    // without waiting on the network round-trip.
    final accepted = room;
    emit(state.copyWith(
      rooms: [...state.rooms, accepted],
      pendingInvites:
          state.pendingInvites.where((r) => r.id != event.roomId).toList(),
    ));

    try {
      // The user id goes down to the repository so the cached room row is
      // corrected too. Without it the reload below reads this room straight
      // back out of SQLite still marked `pending`, and _splitRooms undoes the
      // move above before the server has even answered.
      final myUserId = await _authService.getUserId();
      await _acceptInvite(event.roomId, userId: myUserId);
      // Subscribe immediately so WS messages start arriving right away.
      _bgService.sharedWs.subscribeRoom(event.roomId);
      // Reload to get the fresh participant list.
      add(const ChatRoomsLoadRequested());
    } catch (_) {
      // Roll back the optimistic move if the server rejected it.
      emit(state.copyWith(
        rooms: state.rooms.where((r) => r.id != event.roomId).toList(),
        pendingInvites: [...state.pendingInvites, accepted],
      ));
    }
  }

  void _onGroupInviteReceived(
    ChatRoomsGroupInviteReceived event,
    Emitter<ChatRoomsState> emit,
  ) {
    final alreadyKnown = state.pendingInvites.any((r) => r.id == event.room.id) ||
        state.rooms.any((r) => r.id == event.room.id);
    debugPrint('[ChatRoomsBloc] _onGroupInviteReceived roomId=${event.room.id} alreadyKnown=$alreadyKnown pendingCount=${state.pendingInvites.length}');
    if (alreadyKnown) return;
    emit(state.copyWith(
      pendingInvites: [...state.pendingInvites, event.room],
    ));
    debugPrint('[ChatRoomsBloc] pending invites updated — now ${state.pendingInvites.length + 1}');
  }

  Future<void> _onDeclineInvite(
    ChatRoomsDeclineInvite event,
    Emitter<ChatRoomsState> emit,
  ) async {
    ChatRoom? room;
    for (final r in state.pendingInvites) {
      if (r.id == event.roomId) {
        room = r;
        break;
      }
    }
    if (room == null) return;
    final declined = room;

    // Remove the card immediately; restore it if the server call fails.
    emit(state.copyWith(
      pendingInvites:
          state.pendingInvites.where((r) => r.id != event.roomId).toList(),
    ));
    try {
      await _declineInvite(event.roomId);
    } catch (_) {
      emit(state.copyWith(
        pendingInvites: [...state.pendingInvites, declined],
      ));
    }
  }
}

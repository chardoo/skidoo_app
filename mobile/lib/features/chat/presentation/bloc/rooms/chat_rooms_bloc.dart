import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_background_service.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';
import 'package:skidoo_app/services/auth_service.dart';

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
  final ChatBackgroundService _bgService;
  final AuthService _authService;

  StreamSubscription<ChatRoom>? _groupInviteSub;
  StreamSubscription<ChatMessage>? _bgMsgSub;

  ChatRoomsBloc({
    required GetMyRoomsUseCase getMyRooms,
    required GetCachedRoomsUseCase getCachedRooms,
    required GetUnreadCountsUseCase getUnreadCounts,
    required GetLastMessageTimesUseCase getLastMessageTimes,
    required GetRoomMessagesUseCase getRoomMessages,
    required AcceptRoomInviteUseCase acceptInvite,
    required DeclineRoomInviteUseCase declineInvite,
    required ChatBackgroundService bgService,
    required AuthService authService,
  })  : _getMyRooms = getMyRooms,
        _getCachedRooms = getCachedRooms,
        _getUnreadCounts = getUnreadCounts,
        _getLastMessageTimes = getLastMessageTimes,
        _getRoomMessages = getRoomMessages,
        _acceptInvite = acceptInvite,
        _declineInvite = declineInvite,
        _bgService = bgService,
        _authService = authService,
        super(const ChatRoomsState()) {
    on<ChatRoomsLoadRequested>(_onLoad);
    // concurrent() lets refresh events run immediately alongside _onLoad
    // instead of queuing behind the network call, so the badge updates as
    // soon as a background WS message is saved to the DB.
    on<ChatRoomsRefreshUnread>(_onRefreshUnread, transformer: concurrent());
    on<ChatRoomsAcceptInvite>(_onAcceptInvite, transformer: concurrent());
    on<ChatRoomsDeclineInvite>(_onDeclineInvite, transformer: concurrent());
    on<ChatRoomsGroupInviteReceived>(_onGroupInviteReceived, transformer: concurrent());
    on<_ChatRoomsMessageArrived>(_onMessageArrived, transformer: concurrent());
    on<_ChatRoomsRoomRead>(_onRoomRead, transformer: concurrent());

    // Wire background service → bloc so new background messages update the badge.
    _bgService.onUnreadUpdate = () {
      if (!isClosed) add(const ChatRoomsRefreshUnread());
    };

    // Direct message stream: updates unreadCounts and lastMessageAt in-memory,
    // bypassing the DB.  Essential on web where SQLite is unavailable.
    _bgMsgSub = _bgService.backgroundMessages.listen((msg) {
      if (!isClosed) add(_ChatRoomsMessageArrived(msg.roomId, msg.createdAt));
    });

    // Badge-clear signal: ChatRoomBloc fires this when a room is opened.
    _bgService.onRoomRead = (roomId) {
      if (!isClosed) add(_ChatRoomsRoomRead(roomId));
    };

    // Subscribe to the persistent relay — one subscription, no reconnect
    // management needed. All WS instances (shared + DiscoveryBloc per-event
    // sessions) funnel invites through this relay.
    _groupInviteSub = _bgService.groupInviteStream.listen((room) {
      debugPrint('[ChatRoomsBloc] groupInviteStream: roomId=${room.id} isClosed=$isClosed');
      if (!isClosed) add(ChatRoomsGroupInviteReceived(room));
    });
    debugPrint('[ChatRoomsBloc] created — subscribed to groupInviteStream');
  }

  @override
  Future<void> close() {
    _groupInviteSub?.cancel();
    _bgMsgSub?.cancel();
    return super.close();
  }

  Future<void> _onLoad(
    ChatRoomsLoadRequested event,
    Emitter<ChatRoomsState> emit,
  ) async {
    final myUserId = await _authService.getUserId();

    // 1. Load cache + unread counts + last message times instantly.
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
        emit(state.copyWith(isLoading: true, isSyncing: true, clearError: true));
      }
    } catch (_) {
      emit(state.copyWith(isLoading: true, isSyncing: true, clearError: true));
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
      emit(state.copyWith(
        rooms: split.$1,
        pendingInvites: split.$2,
        unreadCounts: counts,
        lastMessageAt: lastTimes,
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
        lastMessageAt: results[1] as Map<String, DateTime>,
      ));
    } catch (_) {}
  }

  /// Increments the unread badge and updates sort-order for [roomId] without
  /// touching the DB.  Works on all platforms; is the sole update path on web.
  void _onMessageArrived(
    _ChatRoomsMessageArrived event,
    Emitter<ChatRoomsState> emit,
  ) {
    final counts = Map<String, int>.from(state.unreadCounts);
    counts[event.roomId] = (counts[event.roomId] ?? 0) + 1;
    final times = Map<String, DateTime>.from(state.lastMessageAt);
    times[event.roomId] = event.arrivedAt;
    emit(state.copyWith(unreadCounts: counts, lastMessageAt: times));
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

  Future<void> _onAcceptInvite(
    ChatRoomsAcceptInvite event,
    Emitter<ChatRoomsState> emit,
  ) async {
    try {
      await _acceptInvite(event.roomId);
      // Move room from pending to active.
      final room = state.pendingInvites.firstWhere((r) => r.id == event.roomId,
          orElse: () => throw StateError('not found'));
      emit(state.copyWith(
        rooms: [...state.rooms, room],
        pendingInvites:
            state.pendingInvites.where((r) => r.id != event.roomId).toList(),
      ));
      // Subscribe immediately so WS messages start arriving without waiting
      // for the full reload below.
      _bgService.sharedWs.subscribeRoom(event.roomId);
      // Reload to get fresh participant list.
      add(const ChatRoomsLoadRequested());
    } catch (_) {}
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
    try {
      await _declineInvite(event.roomId);
      emit(state.copyWith(
        pendingInvites:
            state.pendingInvites.where((r) => r.id != event.roomId).toList(),
      ));
    } catch (_) {}
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:skidoo_app/features/chat/data/datasources/chat_websocket_service.dart'
    show
        ChatWebSocketService,
        WsGroupInviteEvent,
        WsUserJoinedEvent,
        WsRoomDeletedEvent,
        WsParticipantRemovedEvent,
        WsParticipantLeftEvent,
        WsRoomSettingsUpdatedEvent,
        WsMessageEditedEvent,
        WsMessageDeletedEvent;
import 'package:skidoo_app/features/chat/data/local/chat_database.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';
import 'package:skidoo_app/services/notification_prefs_service.dart';
import 'package:skidoo_app/services/notification_sound_service.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:skidoo_app/services/e2ee_service.dart';

/// Maintains a single persistent WebSocket connection to the global chat
/// endpoint and subscribes to every joined room via subscribe_room messages.
///
/// Messages received in the background are cached to the local DB and the
/// [onUnreadUpdate] callback is fired so the navbar badge can update without
/// the user having to open the chat rooms page.
class ChatBackgroundService {
  final ChatDatabase _db;
  final ChatWebSocketService _sharedWs;
  final E2eeService _e2ee;
  final AuthService _authService;
  final NotificationPrefsService _notifPrefs;
  final NotificationSoundService _sound;

  void Function()? onUnreadUpdate;

  /// Called (with the room ID) when ChatRoomBloc marks a room as fully read.
  /// ChatRoomsBloc uses this to zero the unread badge without a DB round-trip.
  void Function(String roomId)? onRoomRead;

  // Broadcasts every background-received message (after optional decrypt) so
  // subscribers can update in-memory state without touching the local DB.
  // Never closed — lives for the entire app session (service is a singleton).
  final _bgMsgController = StreamController<ChatMessage>.broadcast();

  /// Raw stream of messages received in the background (rooms not currently open).
  /// Use this instead of the DB-backed unread/lastMessage queries on platforms
  /// where SQLite is unavailable (e.g. web).
  Stream<ChatMessage> get backgroundMessages => _bgMsgController.stream;

  // Persistent relay for group invites — never closed, survives WS reconnects.
  // All WS instances (shared + DiscoveryBloc per-event) funnel invites here so
  // ChatRoomsBloc can subscribe once without any reconnect management.
  final _inviteRelay = StreamController<ChatRoom>.broadcast();
  Stream<ChatRoom> get groupInviteStream => _inviteRelay.stream;

  void reportGroupInvite(ChatRoom room) {
    debugPrint('[BgChat] reportGroupInvite: roomId=${room.id}');
    if (!_inviteRelay.isClosed) _inviteRelay.add(room);
  }

  // Persistent relays for room lifecycle — never closed, survive WS reconnects
  // (same pattern as [groupInviteStream]). ChatRoomsBloc subscribes once.

  /// Fires a roomId when the current user should remove that room from their
  /// list — the room was deleted, or the user was removed/kicked from it.
  final _roomRemovedRelay = StreamController<String>.broadcast();
  Stream<String> get roomRemovedStream => _roomRemovedRelay.stream;

  /// Fires when a room's membership / settings changed (someone joined or left,
  /// name or admin-only toggled) so the rooms list should re-sync.
  final _roomsChangedRelay = StreamController<void>.broadcast();
  Stream<void> get roomsChangedStream => _roomsChangedRelay.stream;

  StreamSubscription<ChatMessage>? _msgSub;
  StreamSubscription<WsGroupInviteEvent>? _groupInviteSub;
  StreamSubscription<WsUserJoinedEvent>? _userJoinedSub;
  StreamSubscription<WsRoomDeletedEvent>? _roomDeletedSub;
  StreamSubscription<WsParticipantRemovedEvent>? _participantRemovedSub;
  StreamSubscription<WsParticipantLeftEvent>? _participantLeftSub;
  StreamSubscription<WsRoomSettingsUpdatedEvent>? _roomSettingsSub;
  StreamSubscription<WsMessageEditedEvent>? _msgEditedSub;
  StreamSubscription<WsMessageDeletedEvent>? _msgDeletedSub;

  final Map<String, ChatRoom> _rooms = {};

  // Per-room encryption flag.  Defaults to true (mobile-only assumed).
  // Set to false when a web participant is detected — either from the initial
  // `connected` handshake or from a live `user_joined` with client_type=web.
  // Reset to true on reconnect if no web clients appear in the new handshake.
  final Map<String, bool> _roomCanEncrypt = {};

  // Rooms whose connection is temporarily handed to ChatRoomBloc.
  // Messages for paused rooms are silently dropped (the bloc handles them).
  final Set<String> _paused = {};
  bool _connected = false;
  bool _connecting = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  static const int _maxReconnectAttempts = 8;

  // Incremented each time _connect() starts a new subscription. Captured in
  // the onDone/onError closures so stale callbacks (fired by a previously
  // closed _msgController) don't cancel the current live subscription.
  int _generation = 0;
  String? _cachedMyUserId;

  // Broadcasts true when the shared WS connects, false when it drops.
  // ChatRoomBloc listens to this to know when to (re)attach its listeners
  // without owning the connection lifecycle.
  final _connectionController = StreamController<bool>.broadcast();

  ChatBackgroundService(
    this._db,
    this._sharedWs,
    this._e2ee,
    this._authService,
    this._notifPrefs, [
    this._sound = const NotificationSoundService(),
  ]) {
    // Coming back to the foreground is the clearest signal that connectivity
    // may have returned. Without this, a device that lost DNS for long enough
    // to exhaust the retry budget (8 attempts, backing off to 60s — a few
    // minutes) stayed disconnected until the process restarted, because
    // _scheduleReconnect refuses to arm another timer once the budget is gone.
    _lifecycle = AppLifecycleListener(onResume: _retryFromScratch);
  }

  AppLifecycleListener? _lifecycle;

  /// Clears the spent retry budget and tries again immediately.
  ///
  /// Only for deliberate "you should be connected now" moments — app resume, or
  /// an explicit [connectAll]. The drop handler must keep using
  /// [_scheduleReconnect] so a genuinely unreachable server is still backed off
  /// rather than hammered.
  void _retryFromScratch() {
    if (_connected || _connecting) return;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _connect();
  }

  /// Releases the lifecycle listener. The service is a singleton for the life
  /// of the app, so this is mainly for tests.
  void dispose() {
    _lifecycle?.dispose();
    _lifecycle = null;
    _reconnectTimer?.cancel();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// The shared singleton WS — ChatRoomBloc reads streams from here.
  ChatWebSocketService get sharedWs => _sharedWs;

  /// Returns true when all known participants in [roomId] are on mobile.
  /// Returns false if any web client has been detected in the room.
  /// Defaults to true when the room hasn't appeared in a handshake yet.
  bool canEncryptRoom(String roomId) => _roomCanEncrypt[roomId] ?? true;

  /// Emits true on connect, false on drop. Never closed while the service lives.
  Stream<bool> get connectionEvents => _connectionController.stream;

  /// Registers [rooms] and opens (or reuses) the single global WS connection.
  Future<void> connectAll(List<ChatRoom> rooms) async {
    for (final room in rooms) {
      _rooms[room.id] = room;
    }

    if (_connected) {
      // Already up — just subscribe any newly discovered rooms.
      for (final room in rooms) {
        if (!_paused.contains(room.id)) {
          _sharedWs.subscribeRoom(room.id);
        }
      }
      return;
    }

    // Connect even if rooms is empty — the /chat/ws/me endpoint delivers
    // user-level events (e.g. group_invite) regardless of room subscriptions.
    //
    // Reset the retry budget first: this call is an explicit request to be
    // connected (a rooms load/refresh), so it deserves a full set of attempts.
    // Otherwise, once the budget was spent, each refresh got a single doomed
    // try and chat never came back.
    if (!_connecting) _retryFromScratch();
  }

  /// Hands off [roomId] to [ChatRoomBloc]. Incoming messages for this room
  /// are silently dropped until [resume] is called.
  void pause(String roomId) {
    _paused.add(roomId);
    debugPrint('[BgChat] paused room $roomId');
  }

  /// Called when [ChatRoomBloc] is done with [roomId]. Re-subscribes so the
  /// global connection resumes delivering background messages for this room.
  void resume(String roomId) {
    _paused.remove(roomId);
    // Always re-subscribe, even for rooms not yet in _rooms (e.g. a brand-new
    // DM opened before the next connectAll call). Without this the server stops
    // delivering messages for that room after the user leaves it.
    if (_connected) {
      _sharedWs.subscribeRoom(roomId);
    }
    debugPrint('[BgChat] resumed room $roomId');
  }

  /// Disconnects the global connection (e.g. on logout).
  void disconnectAll() {
    _reconnectTimer?.cancel();
    _msgSub?.cancel();
    _groupInviteSub?.cancel();
    _userJoinedSub?.cancel();
    _sharedWs.disconnect();
    _msgSub = null;
    _groupInviteSub = null;
    _userJoinedSub = null;
    _rooms.clear();
    _paused.clear();
    _roomCanEncrypt.clear();
    onUnreadUpdate = null;
    onRoomRead = null;
    _connected = false;
    _connecting = false;
    _reconnectAttempts = 0;
    debugPrint('[BgChat] disconnected all');
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  Future<void> _connect() async {
    if (_connecting || _connected) return;
    _connecting = true;

    try {
      // connect() opens /chat/ws/me — a user-level endpoint that delivers
      // group_invite and other user events regardless of room subscriptions.
      // We connect without a specific room and then subscribe all known rooms.
      await _sharedWs.connect();

      _connected = true;
      _connecting = false;
      _reconnectAttempts = 0;

      // Subscribe ALL non-paused rooms known at this point, including any
      // rooms registered via connectAll() while the handshake was in flight.
      final allRooms = _rooms.keys.where((id) => !_paused.contains(id)).toList();
      debugPrint('[BgChat] connected — subscribing ${allRooms.length} room(s)');
      for (final roomId in allRooms) {
        _sharedWs.subscribeRoom(roomId);
      }

      // Notify ChatRoomBloc (and any other listener) that the WS is up.
      _connectionController.add(true);

      // ── Populate per-room encryption flags from the `connected` handshake ──
      // The server lists every room the user belongs to, along with participant
      // client_type.  We reset the map on every reconnect so rooms where a web
      // client later left are re-evaluated with fresh data.
      _roomCanEncrypt.clear();
      _sharedWs.connectedEvents.listen((event) {
        for (final room in event.rooms) {
          final roomId = room['room_id'] as String? ?? '';
          if (roomId.isEmpty) continue;
          final participants = (room['participants'] as List?) ?? [];
          final hasWeb = participants.any(
            (p) => (p as Map<String, dynamic>?)?['client_type'] == 'web',
          );
          _roomCanEncrypt[roomId] = !hasWeb;
          if (hasWeb) {
            debugPrint('[BgChat] room $roomId has web participant — E2EE disabled');
          }
        }
      });

      final gen = ++_generation;
      _msgSub = _sharedWs.messages.listen(
        (msg) {
          if (_paused.contains(msg.roomId)) {
            debugPrint('[BgChat] msg dropped (paused) roomId=${msg.roomId} id=${msg.id}');
          } else {
            _onMessage(msg);
          }
        },
        onDone: () {
          if (gen != _generation) return;
          _onDropped();
        },
        onError: (_) {
          if (gen != _generation) return;
          _onDropped();
        },
      );

      _groupInviteSub?.cancel();
      _groupInviteSub = _sharedWs.groupInviteEvents.listen((event) {
        debugPrint('[BgChat] group_invite via sharedWs — roomId=${event.room.id}');
        // Cache the invited room so the pending invite survives a restart /
        // shows offline (it's split out by hasPendingInvite on load).
        _db.upsertRoom(event.room).catchError((_) {});
        reportGroupInvite(event.room);
      });

      // ── Downgrade encryption when a web client joins a live room ──────────
      _userJoinedSub?.cancel();
      _userJoinedSub = _sharedWs.userJoinedEvents.listen((event) {
        if (event.clientType == 'web') {
          _roomCanEncrypt[event.roomId] = false;
          debugPrint('[BgChat] web client joined room ${event.roomId} — E2EE disabled');
        }
        // Note: a member joining is surfaced as an in-conversation system
        // message by ChatRoomBloc; we deliberately don't reload the whole
        // rooms list here to avoid churn in busy groups.
      });

      // ── Room lifecycle → rooms-list relays (live updates without refresh) ──
      // These also persist to the local DB so a kicked/deleted room doesn't
      // linger in the cache (upsert-sync never deletes rooms) and reappear on
      // restart — done here, not just in ChatRoomBloc, so it works even when
      // the conversation isn't open.
      _roomDeletedSub?.cancel();
      _roomDeletedSub = _sharedWs.roomDeletedEvents.listen((event) {
        debugPrint('[BgChat] room_deleted roomId=${event.roomId}');
        _db.deleteRoom(event.roomId).catchError((_) {});
        if (!_roomRemovedRelay.isClosed) _roomRemovedRelay.add(event.roomId);
      });

      _participantRemovedSub?.cancel();
      _participantRemovedSub =
          _sharedWs.participantRemovedEvents.listen((event) async {
        final me = _cachedMyUserId ??= await _authService.getUserId();
        if (event.userId == me) {
          // I was removed/kicked → drop the room from my list + cache.
          debugPrint('[BgChat] removed from room ${event.roomId}');
          await _db.deleteRoom(event.roomId).catchError((_) {});
          if (!_roomRemovedRelay.isClosed) _roomRemovedRelay.add(event.roomId);
        } else if (!_roomsChangedRelay.isClosed) {
          _roomsChangedRelay.add(null);
        }
      });

      _participantLeftSub?.cancel();
      _participantLeftSub = _sharedWs.participantLeftEvents.listen((_) {
        if (!_roomsChangedRelay.isClosed) _roomsChangedRelay.add(null);
      });

      _roomSettingsSub?.cancel();
      _roomSettingsSub = _sharedWs.roomSettingsEvents.listen((_) {
        if (!_roomsChangedRelay.isClosed) _roomsChangedRelay.add(null);
      });

      // ── Message edit/delete → persist to the cache even when the room isn't
      //    open (ChatRoomBloc only handles these for the active room). ───────
      _msgEditedSub?.cancel();
      _msgEditedSub = _sharedWs.messageEditedEvents.listen((event) {
        _db
            .updateMessageContent(event.id, event.content, event.updatedAt)
            .catchError((_) {});
      });

      _msgDeletedSub?.cancel();
      _msgDeletedSub = _sharedWs.messageDeletedEvents.listen((event) {
        _db.deleteMessage(event.id).catchError((_) {});
      });
    } catch (e) {
      _connected = false;
      _connecting = false;
      _sharedWs.disconnect();
      debugPrint('[BgChat] connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _onDropped() {
    _connected = false;
    _connecting = false;
    _msgSub?.cancel();
    _msgSub = null;
    _groupInviteSub?.cancel();
    _groupInviteSub = null;
    _userJoinedSub?.cancel();
    _userJoinedSub = null;
    _roomDeletedSub?.cancel();
    _roomDeletedSub = null;
    _participantRemovedSub?.cancel();
    _participantRemovedSub = null;
    _participantLeftSub?.cancel();
    _participantLeftSub = null;
    _roomSettingsSub?.cancel();
    _roomSettingsSub = null;
    _msgEditedSub?.cancel();
    _msgEditedSub = null;
    _msgDeletedSub?.cancel();
    _msgDeletedSub = null;

    if (_sharedWs.hadFatalClose) {
      debugPrint('[BgChat] fatal close — will not reconnect');
      return;
    }

    debugPrint('[BgChat] connection dropped — scheduling reconnect');
    _connectionController.add(false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[BgChat] gave up reconnecting after $_maxReconnectAttempts attempts');
      return;
    }
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: _backoff(_reconnectAttempts));
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, _connect);
  }

  int _backoff(int attempt) => (5 * (1 << attempt)).clamp(5, 60);

  Future<void> _onMessage(ChatMessage msg) async {
    if (msg.id.isEmpty || msg.roomId.isEmpty) return;
    debugPrint('[BgChat] _onMessage roomId=${msg.roomId} id=${msg.id} isEncrypted=${msg.isEncrypted} callbackNull=${onUnreadUpdate == null}');
    try {
      if (msg.isEncrypted && msg.iv != null && msg.content.isNotEmpty) {
        msg = await _tryDecrypt(msg);
      }
      await _db.upsertMessages([msg]);
      debugPrint('[BgChat] upserted msg ${msg.id} — firing backgroundMessages + onUnreadUpdate');
      if (!_bgMsgController.isClosed) _bgMsgController.add(msg);
      onUnreadUpdate?.call();
      await _maybePlayDmSound(msg);
    } catch (e) {
      debugPrint('[BgChat] _onMessage error: $e');
    }
  }

  /// Plays the notification tone for an incoming direct message. Only reached
  /// for rooms the user is NOT currently viewing — the open room is [pause]d, so
  /// its messages are handled by ChatRoomBloc and never arrive here. Skips the
  /// user's own echoed messages, non-DM rooms, and respects the in-app mute
  /// preference. Never throws — a sound must not disrupt message processing.
  Future<void> _maybePlayDmSound(ChatMessage msg) async {
    try {
      final myId = await _myUserIdCached();
      final room = _rooms[msg.roomId];
      if (shouldPlayDmSound(
        muted: _notifPrefs.isMuted,
        senderId: msg.senderId,
        myId: myId,
        roomType: room?.type,
      )) {
        _sound.playMessageTone();
      }
    } catch (_) {
      // Best-effort.
    }
  }

  /// Pure decision for whether an incoming message should play the new-message
  /// tone. Exposed for testing.
  ///
  /// Plays only for direct messages the user did not send and has not muted.
  /// [roomType] is null when the room isn't cached yet — almost always a
  /// brand-new DM (group/event/global rooms are registered up-front via
  /// [connectAll]), so an unknown room is treated as a DM rather than missing a
  /// new conversation's first message.
  @visibleForTesting
  static bool shouldPlayDmSound({
    required bool muted,
    required String senderId,
    required String myId,
    required RoomType? roomType,
  }) {
    if (muted) return false;
    if (senderId == myId) return false;
    return roomType == null || roomType == RoomType.direct;
  }

  Future<ChatMessage> _tryDecrypt(ChatMessage msg) async {
    try {
      final myId = await _myUserIdCached();
      final isOwnEcho = msg.senderId == myId;
      final isX3DH = !isOwnEcho &&
          msg.ephemeralKey != null &&
          msg.ephemeralKey!.isNotEmpty &&
          msg.senderIdentityKey != null &&
          msg.senderIdentityKey!.isNotEmpty;

      if (msg.stale == true) {
        await _e2ee.deleteSessionKey(msg.roomId);
        debugPrint('[BgChat] stale message ${msg.id} — session cleared');
        return msg.copyWith(content: '', isEncrypted: false);
      }

      if (isX3DH) {
        await _e2ee.storeIdentityKey(msg.senderId, msg.senderIdentityKey!);
        final mySpkId = await _e2ee.currentSpkId();
        final tryPrevFirst = msg.senderSpkId != null &&
            mySpkId != null &&
            msg.senderSpkId != mySpkId;
        final result = await _deriveX3DH(msg, tryPrevFirst: tryPrevFirst);
        if (result != null) {
          await _e2ee.storeSessionKey(msg.roomId, result.$1);
          debugPrint('[BgChat] X3DH session key stored for room ${msg.roomId}');
          return msg.copyWith(content: result.$2, isEncrypted: false);
        }
        debugPrint('[BgChat] X3DH failed for msgId=${msg.id} — storing ciphertext');
        return msg;
      }

      final sessionKey = await _e2ee.loadSessionKey(msg.roomId);
      if (sessionKey == null) {
        // No DM session key — try group sender key (peer or own echo).
        final groupKey = isOwnEcho
            ? await _e2ee.loadGroupSenderKey(msg.roomId)
            : await _e2ee.loadPeerGroupSenderKey(msg.roomId, msg.senderId);
        if (groupKey != null) {
          final plaintext = await _e2ee.decrypt(groupKey, msg.content, msg.iv!);
          debugPrint('[BgChat] group decrypted msgId=${msg.id}');
          return msg.copyWith(content: plaintext, isEncrypted: false);
        }
        debugPrint('[BgChat] no key for room ${msg.roomId} — storing ciphertext');
        return msg;
      }
      final plaintext = await _e2ee.decrypt(sessionKey, msg.content, msg.iv!);
      debugPrint('[BgChat] decrypted msgId=${msg.id}');
      return msg.copyWith(content: plaintext, isEncrypted: false);
    } catch (e) {
      debugPrint('[BgChat] decrypt failed for msgId=${msg.id}: $e');
      return msg;
    }
  }

  Future<(Uint8List, String)?> _deriveX3DH(
      ChatMessage msg, {required bool tryPrevFirst}) async {
    final otpkId = msg.otpkId;
    for (final tryPrev in tryPrevFirst ? [true, false] : [false, true]) {
      try {
        final key = await _e2ee.deriveReceivingKey(
          senderIdentityKey: msg.senderIdentityKey!,
          senderEphemeralKey: msg.ephemeralKey!,
          consumedOtpkId: otpkId,
          usePrevSPK: tryPrev,
          deleteConsumedOtpk: false,
        );
        final plain = await _e2ee.decrypt(key, msg.content, msg.iv!);
        if (otpkId != null) await _e2ee.deleteOtpk(otpkId);
        return (key, plain);
      } catch (_) {}
    }
    return null;
  }

  Future<String> _myUserIdCached() async {
    _cachedMyUserId ??= await _authService.getUserId();
    return _cachedMyUserId!;
  }
}

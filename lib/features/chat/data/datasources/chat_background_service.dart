import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_websocket_service.dart'
    show ChatWebSocketService, WsGroupInviteEvent;
import 'package:skidoo_app/features/chat/data/local/chat_database.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';
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

  void Function()? onUnreadUpdate;

  // Persistent relay for group invites — never closed, survives WS reconnects.
  // All WS instances (shared + DiscoveryBloc per-event) funnel invites here so
  // ChatRoomsBloc can subscribe once without any reconnect management.
  final _inviteRelay = StreamController<ChatRoom>.broadcast();
  Stream<ChatRoom> get groupInviteStream => _inviteRelay.stream;

  void reportGroupInvite(ChatRoom room) {
    debugPrint('[BgChat] reportGroupInvite: roomId=${room.id}');
    if (!_inviteRelay.isClosed) _inviteRelay.add(room);
  }

  StreamSubscription<ChatMessage>? _msgSub;
  StreamSubscription<WsGroupInviteEvent>? _groupInviteSub;

  final Map<String, ChatRoom> _rooms = {};

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

  ChatBackgroundService(this._db, this._sharedWs, this._e2ee, this._authService);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// The shared singleton WS — ChatRoomBloc reads streams from here.
  ChatWebSocketService get sharedWs => _sharedWs;

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
    if (!_connecting) _connect();
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
    _sharedWs.disconnect();
    _msgSub = null;
    _groupInviteSub = null;
    _rooms.clear();
    _paused.clear();
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
        reportGroupInvite(event.room);
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
      debugPrint('[BgChat] upserted msg ${msg.id} — firing onUnreadUpdate');
      onUnreadUpdate?.call();
    } catch (e) {
      debugPrint('[BgChat] _onMessage error: $e');
    }
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
        debugPrint('[BgChat] no session key for room ${msg.roomId} — storing ciphertext');
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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_websocket_service.dart';
import 'package:skidoo_app/features/chat/data/local/chat_database.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';
import 'package:skidoo_app/services/auth_service.dart';

/// Maintains a single persistent WebSocket connection to the global chat
/// endpoint and subscribes to every joined room via subscribe_room messages.
///
/// Messages received in the background are cached to the local DB and the
/// [onUnreadUpdate] callback is fired so the navbar badge can update without
/// the user having to open the chat rooms page.
class ChatBackgroundService {
  final AuthService _authService;
  final ChatDatabase _db;

  void Function()? onUnreadUpdate;

  ChatWebSocketService? _svc;
  StreamSubscription<ChatMessage>? _msgSub;

  final Map<String, ChatRoom> _rooms = {};

  // Rooms whose connection is temporarily handed to ChatRoomBloc.
  // Messages for paused rooms are silently dropped (the bloc handles them).
  final Set<String> _paused = {};

  bool _connected = false;
  bool _connecting = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  static const int _maxReconnectAttempts = 8;

  ChatBackgroundService(this._authService, this._db);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Registers [rooms] and opens (or reuses) the single global WS connection.
  Future<void> connectAll(List<ChatRoom> rooms) async {
    for (final room in rooms) {
      _rooms[room.id] = room;
    }

    if (_connected) {
      // Already up — just subscribe any newly discovered rooms.
      for (final room in rooms) {
        if (!_paused.contains(room.id)) {
          _svc?.subscribeRoom(room.id);
        }
      }
      return;
    }

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
    if (_rooms.containsKey(roomId) && _connected) {
      _svc?.subscribeRoom(roomId);
    }
    debugPrint('[BgChat] resumed room $roomId');
  }

  /// Disconnects the global connection (e.g. on logout).
  void disconnectAll() {
    _reconnectTimer?.cancel();
    _msgSub?.cancel();
    _svc?.disconnect();
    _svc = null;
    _msgSub = null;
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
    final activeRooms = _rooms.keys.where((id) => !_paused.contains(id)).toList();
    if (activeRooms.isEmpty) return;

    _connecting = true;
    final svc = ChatWebSocketService(_authService);
    _svc = svc;

    try {
      // connect() opens the global WS and subscribes to the first room.
      await svc.connect(activeRooms.first);

      _connected = true;
      _connecting = false;
      _reconnectAttempts = 0;
      debugPrint('[BgChat] connected (global endpoint, ${activeRooms.length} rooms)');

      // Subscribe to all remaining non-paused rooms.
      for (final roomId in activeRooms.skip(1)) {
        svc.subscribeRoom(roomId);
      }

      _msgSub = svc.messages.listen(
        (msg) {
          if (!_paused.contains(msg.roomId)) _onMessage(msg);
        },
        onDone: _onDropped,
        onError: (_) => _onDropped(),
      );
    } catch (e) {
      _connected = false;
      _connecting = false;
      _svc = null;
      svc.disconnect();
      debugPrint('[BgChat] connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _onDropped() {
    _connected = false;
    _connecting = false;
    _msgSub?.cancel();
    _msgSub = null;
    _svc = null;
    debugPrint('[BgChat] connection dropped');
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
    try {
      await _db.upsertMessages([msg]);
      onUnreadUpdate?.call();
    } catch (_) {}
  }
}

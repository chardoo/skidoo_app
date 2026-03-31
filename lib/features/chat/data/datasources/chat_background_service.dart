import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_websocket_service.dart';
import 'package:skidoo_app/features/chat/data/local/chat_database.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';
import 'package:skidoo_app/services/auth_service.dart';

/// Maintains persistent WebSocket connections to all joined rooms.
///
/// Messages received in the background are cached to the local DB and the
/// [onUnreadUpdate] callback is fired so the navbar badge can update without
/// the user having to open the chat rooms page.
class ChatBackgroundService {
  final AuthService _authService;
  final ChatDatabase _db;

  /// Called whenever a background message is received and cached.
  void Function()? onUnreadUpdate;

  // Active background services, keyed by roomId.
  final Map<String, ChatWebSocketService> _services = {};

  // All known rooms so we can reconnect after a drop.
  final Map<String, ChatRoom> _rooms = {};

  // Rooms whose connection is temporarily handed to ChatRoomBloc.
  final Set<String> _paused = {};

  ChatBackgroundService(this._authService, this._db);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Connects to every room in [rooms] that isn't already connected/paused.
  Future<void> connectAll(List<ChatRoom> rooms) async {
    for (final room in rooms) {
      _rooms[room.id] = room;
      if (!_services.containsKey(room.id) && !_paused.contains(room.id)) {
        _connectRoom(room.id); // fire-and-forget — errors are handled inside
      }
    }
  }

  /// Hands off [roomId] to [ChatRoomBloc].  The background WS is disconnected
  /// so there are no duplicate listeners while the user is actively in the room.
  void pause(String roomId) {
    _paused.add(roomId);
    final svc = _services.remove(roomId);
    svc?.disconnect();
    debugPrint('[BgChat] paused room $roomId');
  }

  /// Called when [ChatRoomBloc] is done with [roomId].  Reconnects the
  /// background listener so messages are captured going forward.
  void resume(String roomId) {
    _paused.remove(roomId);
    if (_rooms.containsKey(roomId)) {
      _connectRoom(roomId);
      debugPrint('[BgChat] resumed room $roomId');
    }
  }

  /// Disconnects all background connections (e.g. on logout).
  void disconnectAll() {
    for (final svc in _services.values) {
      svc.disconnect();
    }
    _services.clear();
    _rooms.clear();
    _paused.clear();
    debugPrint('[BgChat] disconnected all');
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  Future<void> _connectRoom(String roomId) async {
    if (_paused.contains(roomId)) return;
    if (_services.containsKey(roomId)) return; // already connecting/connected

    final svc = ChatWebSocketService(_authService);
    // Reserve the slot early to prevent duplicate connect calls.
    _services[roomId] = svc;

    try {
      await svc.connect(roomId);
      debugPrint('[BgChat] connected room $roomId');

      svc.messages.listen(
        (msg) => _onMessage(msg),
        onDone: () => _onDropped(roomId),
        onError: (_) => _onDropped(roomId),
      );
    } catch (e) {
      debugPrint('[BgChat] connect failed for room $roomId: $e');
      _services.remove(roomId);
      svc.disconnect();
      // Retry after 10 s.
      Future.delayed(const Duration(seconds: 10), () => _connectRoom(roomId));
    }
  }

  Future<void> _onMessage(ChatMessage msg) async {
    try {
      await _db.upsertMessages([msg]);
      onUnreadUpdate?.call();
    } catch (_) {}
  }

  void _onDropped(String roomId) {
    _services.remove(roomId);
    if (!_paused.contains(roomId) && _rooms.containsKey(roomId)) {
      // Reconnect after a short back-off.
      Future.delayed(const Duration(seconds: 5), () => _connectRoom(roomId));
    }
  }
}

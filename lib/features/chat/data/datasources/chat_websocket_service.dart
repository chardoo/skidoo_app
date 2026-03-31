import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/chat/like_update.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Manages the WebSocket connection to the chat service for a single room.
class ChatWebSocketService {
  final AuthService _authService;

  WebSocketChannel? _channel;
  StreamController<ChatMessage>? _msgController;
  StreamController<LikeUpdate>? _likeController;
  StreamSubscription? _sub;

  /// Emits chat messages received from the server.
  Stream<ChatMessage> get messages =>
      _msgController?.stream ?? const Stream.empty();

  /// Emits like/unlike updates for events in this room.
  Stream<LikeUpdate> get likeUpdates =>
      _likeController?.stream ?? const Stream.empty();

  bool _connected = false;
  bool get isConnected => _connected;

  ChatWebSocketService(this._authService);

  Future<void> connect(String roomId) async {
    disconnect(); // Close any previous connection first.

    final token = await _authService.getToken();
    debugPrint('[WS] token present: ${token.isNotEmpty}, length: ${token.length}');

    final wsBase = ChatConfig.wsBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$wsBase/chat/ws/$roomId?token=$token');
    debugPrint('[WS] Connecting to: $uri');

    _channel = WebSocketChannel.connect(uri);
    _msgController = StreamController<ChatMessage>.broadcast();
    _likeController = StreamController<LikeUpdate>.broadcast();

    try {
      await _channel!.ready.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('[WS] Handshake timed out after 15 s');
          throw TimeoutException('WebSocket handshake timed out');
        },
      );
    } catch (e) {
      debugPrint('[WS] ready error: $e');
      disconnect();
      rethrow;
    }

    debugPrint('[WS] Connected to room $roomId');
    _connected = true;

    _sub = _channel!.stream.listen(
      (raw) {
        try {
          final json = jsonDecode(raw as String) as Map<String, dynamic>;
          final type = json['type'] as String?;
          if (type == 'like_update') {
            _likeController?.add(LikeUpdate.fromJson(json));
          } else {
            _msgController?.add(ChatMessage.fromJson(json));
          }
        } catch (_) {
          // Ignore malformed frames.
        }
      },
      onError: (e) {
        debugPrint('[WS] Stream error: $e');
        _connected = false;
        _msgController?.close();
        _likeController?.close();
      },
      onDone: () {
        debugPrint(
          '[WS] Stream closed for room $roomId — '
          'closeCode: ${_channel?.closeCode}, '
          'closeReason: ${_channel?.closeReason}',
        );
        _connected = false;
        _msgController?.close();
        _likeController?.close();
      },
    );
  }

  /// Send a text/image message. At least one of [content] or [imageUrl] must be non-null.
  void send(String? content, {String? imageUrl, String? replyToId}) {
    final payload = <String, dynamic>{};
    if (content != null && content.isNotEmpty) payload['content'] = content;
    if (imageUrl != null) payload['image_url'] = imageUrl;
    if (replyToId != null) payload['reply_to_id'] = replyToId;
    if (payload.isEmpty) return;
    _sendRaw(payload);
  }

  /// Send a like for an event.
  void sendLike(String eventId) =>
      _sendRaw({'type': 'like', 'event_id': eventId});

  /// Remove a like for an event.
  void sendUnlike(String eventId) =>
      _sendRaw({'type': 'unlike', 'event_id': eventId});

  void _sendRaw(Map<String, dynamic> data) {
    if (!_connected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(data));
    } catch (_) {
      _connected = false;
    }
  }

  /// Gracefully close the connection.
  void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _msgController?.close();
    _likeController?.close();
    _channel = null;
    _msgController = null;
    _likeController = null;
    _connected = false;
  }
}

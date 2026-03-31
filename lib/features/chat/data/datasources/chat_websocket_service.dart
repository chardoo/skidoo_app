import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Manages the WebSocket connection to the chat service for a single room.
class ChatWebSocketService {
  final AuthService _authService;

  WebSocketChannel? _channel;
  StreamController<ChatMessage>? _controller;
  StreamSubscription? _sub;

  /// Emits messages received from the server.
  Stream<ChatMessage> get messages =>
      _controller?.stream ?? const Stream.empty();

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
    _controller = StreamController<ChatMessage>.broadcast();

    // Await the handshake with a timeout.
    // If the server never responds (or silently drops the connection),
    // this will throw after 15 s instead of hanging forever.
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
          final message = ChatMessage.fromJson(json);
          _controller!.add(message);
        } catch (_) {
          // Ignore malformed frames.
        }
      },
      onError: (e) {
        debugPrint('[WS] Stream error: $e');
        _connected = false;
        _controller?.close();
      },
      onDone: () {
        debugPrint(
          '[WS] Stream closed for room $roomId — '
          'closeCode: ${_channel?.closeCode}, '
          'closeReason: ${_channel?.closeReason}',
        );
        _connected = false;
        _controller?.close();
      },
    );
  }

  /// Send a text message to the connected room.
  void send(String content) {
    if (!_connected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode({'content': content}));
    } catch (_) {
      _connected = false;
    }
  }

  /// Gracefully close the connection.
  void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _controller?.close();
    _channel = null;
    _controller = null;
    _connected = false;
  }
}

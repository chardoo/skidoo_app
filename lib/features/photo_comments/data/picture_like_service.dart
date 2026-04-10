import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Sends picture like / unlike messages via a short-lived WebSocket connection
/// that is independent of the main [ChatWebSocketService] singleton.
///
/// Usage: call [toggleLike] and forget — it resolves as soon as the message
/// is sent or fails silently.
class PictureLikeService {
  PictureLikeService(this._getPhotoRoom, this._auth);

  final GetPhotoRoomUseCase _getPhotoRoom;
  final AuthService _auth;

  Future<void> toggleLike(String pictureId, {required bool liked}) async {
    try {
      final room = await _getPhotoRoom.call(pictureId);
      final token = await _auth.getToken();

      final wsBase = ChatConfig.wsBaseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final uri = Uri.parse('$wsBase/chat/ws/${room.id}?token=$token');

      final channel = WebSocketChannel.connect(uri);
      try {
        await channel.ready.timeout(const Duration(seconds: 10));
        channel.sink.add(jsonEncode({
          'type': liked ? 'picture_like' : 'picture_unlike',
          'picture_id': pictureId,
        }));
        // Give the server a moment to receive the frame before closing.
        await Future<void>.delayed(const Duration(milliseconds: 300));
      } finally {
        channel.sink.close();
      }
    } catch (e) {
      debugPrint('[PictureLike] toggleLike error: $e');
    }
  }
}

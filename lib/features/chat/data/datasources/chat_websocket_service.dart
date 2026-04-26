import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/chat/like_update.dart' show LikeUpdate, PictureLikeUpdate;
import 'package:skidoo_app/services/auth_service.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ── E2EE key events emitted by the WebSocket ─────────────────────────────────

/// Sent by the server when the current user joins a direct room.
/// Contains every other participant's public key material.
class WsKeyBundlesEvent {
  final List<Map<String, dynamic>> bundles;
  const WsKeyBundlesEvent(this.bundles);
}

/// Broadcast when a participant who previously had no E2EE keys publishes them.
class WsParticipantKeyAvailable {
  final String userId;
  final String identityKey;
  final Map<String, dynamic> signedPreKey;
  const WsParticipantKeyAvailable(this.userId, this.identityKey, this.signedPreKey);
}

/// Manages the WebSocket connection to the chat service for a single room.
///
/// The auth token is passed in the HTTP `Authorization` header during the
/// WebSocket upgrade handshake — NOT in the URL query string, which is visible
/// in server logs and reverse-proxy access logs.
class ChatWebSocketService {
  final AuthService _authService;

  WebSocketChannel? _channel;
  StreamController<ChatMessage>? _msgController;
  StreamController<LikeUpdate>? _likeController;
  StreamController<PictureLikeUpdate>? _picLikeController;
  StreamController<WsKeyBundlesEvent>? _keyBundlesController;
  StreamController<WsParticipantKeyAvailable>? _participantKeyController;
  StreamSubscription? _sub;

  /// Emits chat messages received from the server.
  Stream<ChatMessage> get messages =>
      _msgController?.stream ?? const Stream.empty();

  /// Emits like/unlike updates for events in this room.
  Stream<LikeUpdate> get likeUpdates =>
      _likeController?.stream ?? const Stream.empty();

  /// Emits like/unlike updates for the picture in a photo room.
  Stream<PictureLikeUpdate> get pictureLikeUpdates =>
      _picLikeController?.stream ?? const Stream.empty();

  /// Emits participant key bundles sent by the server on DM room join.
  Stream<WsKeyBundlesEvent> get keyBundleEvents =>
      _keyBundlesController?.stream ?? const Stream.empty();

  /// Emits when a participant publishes E2EE keys for the first time.
  Stream<WsParticipantKeyAvailable> get participantKeyEvents =>
      _participantKeyController?.stream ?? const Stream.empty();

  bool _connected = false;
  bool get isConnected => _connected;

  ChatWebSocketService(this._authService);

  Future<void> connect(String roomId) async {
    disconnect(); // Close any previous connection first.

    final token = await _authService.getToken();

    final wsBase = ChatConfig.wsBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    // Token goes in the Authorization header, not the URL.
    final uri = Uri.parse('$wsBase/chat/ws/$roomId');

    _msgController = StreamController<ChatMessage>.broadcast();
    _likeController = StreamController<LikeUpdate>.broadcast();
    _picLikeController = StreamController<PictureLikeUpdate>.broadcast();
    _keyBundlesController = StreamController<WsKeyBundlesEvent>.broadcast();
    _participantKeyController = StreamController<WsParticipantKeyAvailable>.broadcast();

    try {
      // IOWebSocketChannel.connect() passes headers during the HTTP upgrade
      // handshake and correctly handles wss:// URIs on iOS and Android.
      // The token never appears in the URL or server access logs.
      _channel = IOWebSocketChannel.connect(
        uri,
        headers: token.isNotEmpty
            ? {'Authorization': 'Bearer $token'}
            : const <String, Object>{},
      );
      await _channel!.ready.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('WebSocket handshake timed out'),
      );
    } catch (e) {
      debugPrint('[WS] Connection failed for room $roomId: ${e.runtimeType}');
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
          } else if (type == 'picture_like_update') {
            _picLikeController?.add(PictureLikeUpdate.fromJson(json));
          } else if (type == 'key_bundles') {
            final bundles = (json['bundles'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList();
            _keyBundlesController?.add(WsKeyBundlesEvent(bundles));
          } else if (type == 'participant_key_available') {
            final spk = json['signedPreKey'];
            if (json['userId'] is String &&
                json['identityKey'] is String &&
                spk is Map<String, dynamic>) {
              _participantKeyController?.add(WsParticipantKeyAvailable(
                json['userId'] as String,
                json['identityKey'] as String,
                spk,
              ));
            }
          } else {
            _msgController?.add(ChatMessage.fromJson(json));
          }
        } catch (_) {
          // Ignore malformed frames.
        }
      },
      onError: (e) {
        debugPrint('[WS] Stream error: ${e.runtimeType}');
        _connected = false;
        _msgController?.close();
        _likeController?.close();
        _picLikeController?.close();
        _keyBundlesController?.close();
        _participantKeyController?.close();
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
        _picLikeController?.close();
        _keyBundlesController?.close();
        _participantKeyController?.close();
      },
    );
  }

  /// Send a plain-text or image message.
  void send(String? content, {String? imageUrl, String? replyToId}) {
    final payload = <String, dynamic>{};
    if (content != null && content.isNotEmpty) payload['content'] = content;
    if (imageUrl != null) payload['image_url'] = imageUrl;
    if (replyToId != null) payload['reply_to_id'] = replyToId;
    if (payload.isEmpty) return;
    _sendRaw(payload);
  }

  /// Send an E2EE-encrypted message.
  /// [ciphertext] and [iv] are base64url-encoded (ciphertext has MAC appended).
  /// [ephemeralKey], [senderIdentityKey], [otpkId] are only present on the
  /// first message of a session (the X3DH handshake message) and omitted on
  /// all subsequent messages.
  void sendEncrypted({
    required String ciphertext,
    required String iv,
    String? ephemeralKey,
    String? senderIdentityKey,
    int? otpkId,
    String? replyToId,
  }) {
    final payload = <String, dynamic>{
      'type': 'message',
      'ciphertext': ciphertext,
      'iv': iv,
      if (ephemeralKey != null && ephemeralKey.isNotEmpty)
        'ephemeral_key': ephemeralKey,
      if (senderIdentityKey != null) 'sender_identity_key': senderIdentityKey,
      if (otpkId != null) 'otpk_id': otpkId,
      if (replyToId != null) 'reply_to_id': replyToId,
    };
    _sendRaw(payload);
  }

  /// Send a like for an event.
  void sendLike(String eventId) =>
      _sendRaw({'type': 'like', 'event_id': eventId});

  /// Remove a like for an event.
  void sendUnlike(String eventId) =>
      _sendRaw({'type': 'unlike', 'event_id': eventId});

  /// Send a dislike for an event.
  void sendDislike(String eventId) =>
      _sendRaw({'type': 'dislike', 'event_id': eventId});

  /// Remove a dislike for an event.
  void sendUndislike(String eventId) =>
      _sendRaw({'type': 'undislike', 'event_id': eventId});

  /// Send a like for a picture.
  void sendPictureLike(String pictureId) =>
      _sendRaw({'type': 'picture_like', 'picture_id': pictureId});

  /// Remove a like for a picture.
  void sendPictureUnlike(String pictureId) =>
      _sendRaw({'type': 'picture_unlike', 'picture_id': pictureId});

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
    _picLikeController?.close();
    _keyBundlesController?.close();
    _participantKeyController?.close();
    _channel = null;
    _msgController = null;
    _likeController = null;
    _picLikeController = null;
    _keyBundlesController = null;
    _participantKeyController = null;
    _connected = false;
  }
}

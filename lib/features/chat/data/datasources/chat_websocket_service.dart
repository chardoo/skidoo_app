import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/chat/like_update.dart' show LikeUpdate, PictureLikeUpdate;
import 'package:skidoo_app/services/auth_service.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ── Server-push events ────────────────────────────────────────────────────────

/// First frame the server sends after the handshake completes.
/// Lists every room the user is already a member of.
class WsConnectedEvent {
  final String userId;
  final List<Map<String, dynamic>> rooms;
  const WsConnectedEvent(this.userId, this.rooms);
}

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

/// Broadcast when any participant rotates their key bundle.
class WsKeyRotationEvent {
  final String userId;
  final int? registrationId;
  final String identityKey;
  final Map<String, dynamic> signedPreKey;
  const WsKeyRotationEvent(
      this.userId, this.identityKey, this.signedPreKey, {this.registrationId});
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Manages the WebSocket connection to the global chat endpoint.
///
/// Protocol (new global endpoint):
///   • Connect to /chat/ws — one connection for all rooms.
///   • Server immediately sends { "type": "connected", "userId": "...", "rooms": [...] }.
///   • Send { "type": "subscribe_room", "room_id": "..." } to start receiving a room's events.
///   • Every outbound event includes "room_id" (added automatically by [_sendRaw]).
///
/// The auth token is sent in the HTTP Authorization header during the upgrade
/// handshake — not in the URL, which would appear in server access logs.
class ChatWebSocketService {
  final AuthService _authService;

  WebSocketChannel? _channel;
  String? _roomId;

  StreamController<WsConnectedEvent>? _connectedController;
  StreamController<ChatMessage>? _msgController;
  StreamController<LikeUpdate>? _likeController;
  StreamController<PictureLikeUpdate>? _picLikeController;
  StreamController<WsKeyBundlesEvent>? _keyBundlesController;
  StreamController<WsParticipantKeyAvailable>? _participantKeyController;
  StreamController<WsKeyRotationEvent>? _keyRotationController;
  StreamSubscription? _sub;

  /// Emits the initial server handshake (userId + room list).
  Stream<WsConnectedEvent> get connectedEvents =>
      _connectedController?.stream ?? const Stream.empty();

  /// Emits chat messages received from the server.
  Stream<ChatMessage> get messages =>
      _msgController?.stream ?? const Stream.empty();

  /// Emits like/unlike updates for events in this room.
  Stream<LikeUpdate> get likeUpdates =>
      _likeController?.stream ?? const Stream.empty();

  /// Emits like/unlike updates for the picture in a photo room.
  Stream<PictureLikeUpdate> get pictureLikeUpdates =>
      _picLikeController?.stream ?? const Stream.empty();

  /// Emits participant key bundles sent by the server on DM room subscribe.
  Stream<WsKeyBundlesEvent> get keyBundleEvents =>
      _keyBundlesController?.stream ?? const Stream.empty();

  /// Emits when a participant publishes E2EE keys for the first time.
  Stream<WsParticipantKeyAvailable> get participantKeyEvents =>
      _participantKeyController?.stream ?? const Stream.empty();

  /// Emits when any participant rotates their key bundle.
  Stream<WsKeyRotationEvent> get keyRotationEvents =>
      _keyRotationController?.stream ?? const Stream.empty();

  bool _connected = false;
  bool get isConnected => _connected;

  ChatWebSocketService(this._authService);

  /// Connect to the global WebSocket endpoint and subscribe to [roomId].
  Future<void> connect(String roomId) async {
    disconnect(); // Close any previous connection first.

    _roomId = roomId;

    final token = await _authService.getToken();

    final wsBase = ChatConfig.wsBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    // Global endpoint — room is joined via subscribe_room, not the URL.
    final uri = Uri.parse('$wsBase/chat/ws');

    _connectedController = StreamController<WsConnectedEvent>.broadcast();
    _msgController = StreamController<ChatMessage>.broadcast();
    _likeController = StreamController<LikeUpdate>.broadcast();
    _picLikeController = StreamController<PictureLikeUpdate>.broadcast();
    _keyBundlesController = StreamController<WsKeyBundlesEvent>.broadcast();
    _participantKeyController = StreamController<WsParticipantKeyAvailable>.broadcast();
    _keyRotationController = StreamController<WsKeyRotationEvent>.broadcast();

    try {
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
      debugPrint('[WS] Connection failed: ${e.runtimeType}');
      disconnect();
      rethrow;
    }

    debugPrint('[WS] Connected (global endpoint) — subscribing to room $roomId');
    _connected = true;

    // Tell the server which room we want events for.
    _sendRaw({'type': 'subscribe_room', 'room_id': roomId});

    _sub = _channel!.stream.listen(
      (raw) {
        try {
          final json = jsonDecode(raw as String) as Map<String, dynamic>;
          final type = json['type'] as String?;
          if (type == 'connected') {
            final userId = json['userId'] as String? ?? '';
            final rooms = (json['rooms'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList();
            _connectedController?.add(WsConnectedEvent(userId, rooms));
          } else if (type == 'like_update') {
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
          } else if (type == 'key_rotation') {
            final spk = json['signedPreKey'];
            if (json['userId'] is String &&
                json['identityKey'] is String &&
                spk is Map<String, dynamic>) {
              _keyRotationController?.add(WsKeyRotationEvent(
                json['userId'] as String,
                json['identityKey'] as String,
                spk,
                registrationId: (json['registrationId'] as num?)?.toInt(),
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
        _connectedController?.close();
        _msgController?.close();
        _likeController?.close();
        _picLikeController?.close();
        _keyBundlesController?.close();
        _participantKeyController?.close();
        _keyRotationController?.close();
      },
      onDone: () {
        debugPrint(
          '[WS] Stream closed for room $_roomId — '
          'closeCode: ${_channel?.closeCode}, '
          'closeReason: ${_channel?.closeReason}',
        );
        _connected = false;
        _connectedController?.close();
        _msgController?.close();
        _likeController?.close();
        _picLikeController?.close();
        _keyBundlesController?.close();
        _participantKeyController?.close();
        _keyRotationController?.close();
      },
    );
  }

  /// Subscribe to a new room on the existing connection without reconnecting.
  /// Use this after joining a room via REST so the server starts delivering
  /// its events immediately.
  void subscribeRoom(String roomId) {
    _roomId = roomId;
    _sendRaw({'type': 'subscribe_room', 'room_id': roomId});
  }

  /// Send a plain-text or image message.
  void send(String? content, {String? imageUrl, String? replyToId}) {
    final payload = <String, dynamic>{'type': 'message'};
    if (content != null && content.isNotEmpty) payload['content'] = content;
    if (imageUrl != null) payload['image_url'] = imageUrl;
    if (replyToId != null) payload['reply_to_id'] = replyToId;
    if (payload.length == 1) return; // only 'type', nothing to send
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
    int? senderSpkId,
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
      if (senderSpkId != null) 'spk_id': senderSpkId,
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
    // Every outbound event must include room_id per the global-endpoint protocol.
    if (_roomId != null && !data.containsKey('room_id')) {
      data['room_id'] = _roomId;
    }
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
    _connectedController?.close();
    _msgController?.close();
    _likeController?.close();
    _picLikeController?.close();
    _keyBundlesController?.close();
    _participantKeyController?.close();
    _keyRotationController?.close();
    _channel = null;
    _roomId = null;
    _connectedController = null;
    _msgController = null;
    _likeController = null;
    _picLikeController = null;
    _keyBundlesController = null;
    _participantKeyController = null;
    _keyRotationController = null;
    _connected = false;
  }
}

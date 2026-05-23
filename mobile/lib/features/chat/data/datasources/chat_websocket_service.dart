import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';
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

/// Broadcast when a message is edited by its sender.
class WsMessageEditedEvent {
  final String id;
  final String roomId;
  final String content;
  final DateTime updatedAt;
  final String senderId;
  const WsMessageEditedEvent({
    required this.id,
    required this.roomId,
    required this.content,
    required this.updatedAt,
    required this.senderId,
  });
}

/// Broadcast when a message is deleted by its sender.
class WsMessageDeletedEvent {
  final String id;
  final String roomId;
  final String senderId;
  const WsMessageDeletedEvent({
    required this.id,
    required this.roomId,
    required this.senderId,
  });
}

/// Server push on the personal user channel when the current user is invited
/// to a group by another user.
class WsGroupInviteEvent {
  final ChatRoom room;
  final String invitedBy;
  final String invitedByName;
  const WsGroupInviteEvent({
    required this.room,
    required this.invitedBy,
    required this.invitedByName,
  });
}

/// Broadcast when an admin grants admin rights to another active member.
class WsAdminGrantedEvent {
  final String roomId;
  final String userId;
  final String grantedBy;
  const WsAdminGrantedEvent({
    required this.roomId,
    required this.userId,
    required this.grantedBy,
  });
}

/// Broadcast when an admin revokes another member's admin rights.
class WsAdminRevokedEvent {
  final String roomId;
  final String userId;
  final String revokedBy;
  const WsAdminRevokedEvent({
    required this.roomId,
    required this.userId,
    required this.revokedBy,
  });
}

/// Broadcast when an admin changes room-level settings (e.g. admin_only mode).
class WsRoomSettingsUpdatedEvent {
  final String roomId;
  final bool? adminOnly;
  final String? name;
  final String updatedBy;
  const WsRoomSettingsUpdatedEvent({
    required this.roomId,
    this.adminOnly,
    this.name,
    required this.updatedBy,
  });
}

/// Broadcast when an admin kicks a participant from the group.
/// The kicked user's WS is closed server-side with code 4003.
class WsParticipantRemovedEvent {
  final String roomId;
  final String userId;
  final String removedBy;
  const WsParticipantRemovedEvent({
    required this.roomId,
    required this.userId,
    required this.removedBy,
  });
}

/// Broadcast to all remaining members when a participant voluntarily leaves.
class WsParticipantLeftEvent {
  final String roomId;
  final String userId;
  const WsParticipantLeftEvent({required this.roomId, required this.userId});
}

/// Broadcast to all members when the room is permanently deleted by its sole admin.
class WsRoomDeletedEvent {
  final String roomId;
  final String deletedBy;
  const WsRoomDeletedEvent({required this.roomId, required this.deletedBy});
}

/// Pushed directly to a member when another member distributes their group
/// sender key (on join or after a re-key triggered by a member departure).
class WsSenderKeyDistributionEvent {
  final String roomId;
  final String senderId;
  final String encryptedKey; // 'message' field from server — encrypted sender key
  const WsSenderKeyDistributionEvent({
    required this.roomId,
    required this.senderId,
    required this.encryptedKey,
  });
}

/// Broadcast to all active room members when a pending invitee accepts
/// and joins the group.
class WsUserJoinedEvent {
  final String roomId;
  final String userId;
  final String userName;
  final String userRole;
  const WsUserJoinedEvent({
    required this.roomId,
    required this.userId,
    required this.userName,
    required this.userRole,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Manages the WebSocket connection to the global chat endpoint.
///
/// Protocol (new global endpoint):
///   • Connect to /chat/ws/me?token=<jwt> — one connection for all rooms.
///   • Server immediately sends { "type": "connected", "userId": "...", "rooms": [...] }.
///   • Send { "type": "subscribe_room", "room_id": "..." } to start receiving a room's events.
///   • Every outbound event includes "room_id" (added automatically by [_sendRaw]).
///
/// The auth token is passed as a query parameter so the server can authenticate
/// the upgrade request. Fatal close codes (4001/4003/4400) must not be retried.
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
  StreamController<WsMessageEditedEvent>? _msgEditedController;
  StreamController<WsMessageDeletedEvent>? _msgDeletedController;
  StreamController<WsGroupInviteEvent>? _groupInviteController;
  StreamController<WsUserJoinedEvent>? _userJoinedController;
  StreamController<WsAdminGrantedEvent>? _adminGrantedController;
  StreamController<WsAdminRevokedEvent>? _adminRevokedController;
  StreamController<WsRoomSettingsUpdatedEvent>? _roomSettingsController;
  StreamController<WsParticipantRemovedEvent>? _participantRemovedController;
  StreamController<WsParticipantLeftEvent>? _participantLeftController;
  StreamController<WsRoomDeletedEvent>? _roomDeletedController;
  StreamController<WsSenderKeyDistributionEvent>? _senderKeyDistController;
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

  /// Emits when a message is edited by its sender.
  Stream<WsMessageEditedEvent> get messageEditedEvents =>
      _msgEditedController?.stream ?? const Stream.empty();

  /// Emits when a message is deleted by its sender.
  Stream<WsMessageDeletedEvent> get messageDeletedEvents =>
      _msgDeletedController?.stream ?? const Stream.empty();

  /// Emits when the current user receives a group invite (personal channel push).
  Stream<WsGroupInviteEvent> get groupInviteEvents =>
      _groupInviteController?.stream ?? const Stream.empty();

  /// Emits when a user joins a room (broadcast to active members).
  Stream<WsUserJoinedEvent> get userJoinedEvents =>
      _userJoinedController?.stream ?? const Stream.empty();

  /// Emits when a member is granted admin rights.
  Stream<WsAdminGrantedEvent> get adminGrantedEvents =>
      _adminGrantedController?.stream ?? const Stream.empty();

  /// Emits when a member's admin rights are revoked.
  Stream<WsAdminRevokedEvent> get adminRevokedEvents =>
      _adminRevokedController?.stream ?? const Stream.empty();

  /// Emits when room settings change (e.g. admin_only toggled).
  Stream<WsRoomSettingsUpdatedEvent> get roomSettingsEvents =>
      _roomSettingsController?.stream ?? const Stream.empty();

  /// Emits when a participant is kicked from the group.
  Stream<WsParticipantRemovedEvent> get participantRemovedEvents =>
      _participantRemovedController?.stream ?? const Stream.empty();

  /// Emits when a participant voluntarily leaves the room.
  Stream<WsParticipantLeftEvent> get participantLeftEvents =>
      _participantLeftController?.stream ?? const Stream.empty();

  /// Emits when the room is permanently deleted.
  Stream<WsRoomDeletedEvent> get roomDeletedEvents =>
      _roomDeletedController?.stream ?? const Stream.empty();

  /// Emits when another member distributes their group sender key to us.
  Stream<WsSenderKeyDistributionEvent> get senderKeyDistributionEvents =>
      _senderKeyDistController?.stream ?? const Stream.empty();

  bool _connected = false;
  bool get isConnected => _connected;

  /// True when the last close was caused by a fatal server code (4001/4003/4400).
  /// Callers should not retry when this is true.
  bool _fatalClose = false;
  bool get hadFatalClose => _fatalClose;

  // Distinguishes the shared singleton from per-room event WS instances in logs.
  static int _instanceCounter = 0;
  final int _instanceId = ++_instanceCounter;

  ChatWebSocketService(this._authService);

  /// Returns true for close codes that indicate a permanent failure.
  /// The client must NOT reconnect automatically on these — re-auth or a
  /// bug fix is required.
  static bool isFatalCloseCode(int? code) {
    if (code == null) return false;
    return const {
      4001, // invalid / expired token — re-auth required
      4003, // caller is not a participant of any requested room
      4400, // wrong endpoint — client-side bug
    }.contains(code);
  }

  /// Connect to the unified WebSocket endpoint (`/chat/ws/me`).
  ///
  /// The JWT is passed as a query parameter (`?token=…`) so the server can
  /// authenticate the upgrade request without requiring a custom header
  /// (some proxies strip non-standard headers).
  /// Connect to the unified WebSocket endpoint (`/chat/ws/me`).
  ///
  /// If [roomId] is provided, sends an initial `subscribe_room` message after
  /// the handshake. Omit it (or pass null) to connect without subscribing to
  /// any room — useful when the user has no rooms yet but still needs to
  /// receive user-level push events (e.g. group_invite).
  Future<void> connect([String? roomId]) async {
    disconnect();
    _roomId = roomId;
    _fatalClose = false;

    final wsBase = ChatConfig.wsBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final token = await _authService.getToken();
    final uri = Uri.parse('$wsBase/chat/ws/me').replace(
      queryParameters: token.isNotEmpty ? {'token': token} : null,
    );

    await _doConnect(uri);
    if (roomId != null) {
      debugPrint('[WS#$_instanceId] Connected — subscribing to room $roomId');
      _sendRaw({'type': 'subscribe_room', 'room_id': roomId});
    } else {
      debugPrint('[WS#$_instanceId] Connected (no initial room subscription) — shared/user WS');
    }
  }

  /// Connect to a per-room WebSocket endpoint (`/chat/ws/{roomId}`).
  ///
  /// Used for event comment sessions. The server auto-joins the user on
  /// connection — no `subscribe_room` message is needed. Connection
  /// lifecycle is per-page: open on enter, close on leave.
  Future<void> connectToRoom(String roomId) async {
    disconnect();
    _roomId = roomId;
    _fatalClose = false;

    final wsBase = ChatConfig.wsBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final token = await _authService.getToken();
    final uri = Uri.parse('$wsBase/chat/ws/$roomId').replace(
      queryParameters: token.isNotEmpty ? {'token': token} : null,
    );

    await _doConnect(uri);
    debugPrint('[WS#$_instanceId] Per-room connected — room $roomId (event WS)');
  }

  Future<void> _doConnect(Uri uri) async {
    _connectedController = StreamController<WsConnectedEvent>.broadcast();
    _msgController = StreamController<ChatMessage>.broadcast();
    _likeController = StreamController<LikeUpdate>.broadcast();
    _picLikeController = StreamController<PictureLikeUpdate>.broadcast();
    _keyBundlesController = StreamController<WsKeyBundlesEvent>.broadcast();
    _participantKeyController = StreamController<WsParticipantKeyAvailable>.broadcast();
    _keyRotationController = StreamController<WsKeyRotationEvent>.broadcast();
    _msgEditedController = StreamController<WsMessageEditedEvent>.broadcast();
    _msgDeletedController = StreamController<WsMessageDeletedEvent>.broadcast();
    _groupInviteController = StreamController<WsGroupInviteEvent>.broadcast();
    _userJoinedController = StreamController<WsUserJoinedEvent>.broadcast();
    _adminGrantedController = StreamController<WsAdminGrantedEvent>.broadcast();
    _adminRevokedController = StreamController<WsAdminRevokedEvent>.broadcast();
    _roomSettingsController = StreamController<WsRoomSettingsUpdatedEvent>.broadcast();
    _participantRemovedController = StreamController<WsParticipantRemovedEvent>.broadcast();
    _participantLeftController = StreamController<WsParticipantLeftEvent>.broadcast();
    _roomDeletedController = StreamController<WsRoomDeletedEvent>.broadcast();
    _senderKeyDistController = StreamController<WsSenderKeyDistributionEvent>.broadcast();

    try {
      _channel = IOWebSocketChannel.connect(uri);
      await _channel!.ready.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('WebSocket handshake timed out'),
      );
    } catch (e) {
      debugPrint('[WS] Connection failed: ${e.runtimeType}');
      disconnect();
      rethrow;
    }

    _connected = true;

    _sub = _channel!.stream.listen(
      (raw) {
        try {
          final json = jsonDecode(raw as String) as Map<String, dynamic>;
          final type = json['type'] as String?;
          debugPrint('[WS#$_instanceId] frame received: type=$type roomId=${json['room_id']} id=${json['id']}');
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
          } else if (type == 'message_edited') {
            final updatedStr = json['updated_at'] as String?;
            if (json['id'] is String &&
                json['room_id'] is String &&
                json['content'] is String &&
                updatedStr != null) {
              _msgEditedController?.add(WsMessageEditedEvent(
                id: json['id'] as String,
                roomId: json['room_id'] as String,
                content: json['content'] as String,
                updatedAt: DateTime.parse(updatedStr),
                senderId: json['sender_id'] as String? ?? '',
              ));
            }
          } else if (type == 'message_deleted') {
            if (json['id'] is String && json['room_id'] is String) {
              _msgDeletedController?.add(WsMessageDeletedEvent(
                id: json['id'] as String,
                roomId: json['room_id'] as String,
                senderId: json['sender_id'] as String? ?? '',
              ));
            }
          } else if (type == 'group_invite') {
            final roomData = json['room'];
            debugPrint('[WS#$_instanceId] group_invite received — roomData is ${roomData?.runtimeType} controllerNull=${_groupInviteController == null} hasListener=${_groupInviteController?.hasListener}');
            if (roomData is Map<String, dynamic>) {
              _groupInviteController?.add(WsGroupInviteEvent(
                room: ChatRoom.fromJson(roomData),
                invitedBy: json['invited_by'] as String? ?? '',
                invitedByName: json['invited_by_name'] as String? ?? '',
              ));
              debugPrint('[WS#$_instanceId] group_invite dispatched to controller — hasListener=${_groupInviteController?.hasListener}');
            } else {
              debugPrint('[WS] group_invite DROPPED — roomData is not a Map (got ${roomData?.runtimeType})');
            }
          } else if (type == 'user_joined') {
            if (json['room_id'] is String && json['user_id'] is String) {
              _userJoinedController?.add(WsUserJoinedEvent(
                roomId: json['room_id'] as String,
                userId: json['user_id'] as String,
                userName: json['user_name'] as String? ?? '',
                userRole: json['user_role'] as String? ?? '',
              ));
            }
          } else if (type == 'admin_granted') {
            if (json['room_id'] is String && json['user_id'] is String) {
              _adminGrantedController?.add(WsAdminGrantedEvent(
                roomId: json['room_id'] as String,
                userId: json['user_id'] as String,
                grantedBy: json['granted_by'] as String? ?? '',
              ));
            }
          } else if (type == 'admin_revoked') {
            if (json['room_id'] is String && json['user_id'] is String) {
              _adminRevokedController?.add(WsAdminRevokedEvent(
                roomId: json['room_id'] as String,
                userId: json['user_id'] as String,
                revokedBy: json['revoked_by'] as String? ?? '',
              ));
            }
          } else if (type == 'room_settings_updated') {
            if (json['room_id'] is String) {
              _roomSettingsController?.add(WsRoomSettingsUpdatedEvent(
                roomId: json['room_id'] as String,
                adminOnly: json['admin_only'] as bool?,
                name: json['name'] as String?,
                updatedBy: json['updated_by'] as String? ?? '',
              ));
            }
          } else if (type == 'participant_removed') {
            if (json['room_id'] is String && json['user_id'] is String) {
              _participantRemovedController?.add(WsParticipantRemovedEvent(
                roomId: json['room_id'] as String,
                userId: json['user_id'] as String,
                removedBy: json['removed_by'] as String? ?? '',
              ));
            }
          } else if (type == 'participant_left') {
            if (json['room_id'] is String && json['user_id'] is String) {
              _participantLeftController?.add(WsParticipantLeftEvent(
                roomId: json['room_id'] as String,
                userId: json['user_id'] as String,
              ));
            }
          } else if (type == 'room_deleted') {
            if (json['room_id'] is String) {
              _roomDeletedController?.add(WsRoomDeletedEvent(
                roomId: json['room_id'] as String,
                deletedBy: json['deleted_by'] as String? ?? '',
              ));
            }
          } else if (type == 'sender_key_distribution') {
            if (json['room_id'] is String &&
                json['sender_id'] is String &&
                json['message'] is String) {
              _senderKeyDistController?.add(WsSenderKeyDistributionEvent(
                roomId: json['room_id'] as String,
                senderId: json['sender_id'] as String,
                encryptedKey: json['message'] as String,
              ));
            }
          } else {
            debugPrint('[WS] routing as ChatMessage: type=$type id=${json['id']} roomId=${json['room_id']} senderId=${json['sender_id']} isEncrypted=${json['is_encrypted']} contentLen=${json['content']?.toString().length}');
            _msgController?.add(ChatMessage.fromJson(json));
          }
        } catch (e) {
          final rawStr = raw is String ? raw : raw.toString();
          debugPrint('[WS] frame parse error: $e  raw=${rawStr.length > 200 ? rawStr.substring(0, 200) : rawStr}');
        }
      },
      onError: (e) {
        debugPrint('[WS] Stream error: ${e.runtimeType}');
        _connected = false;
        _closeControllers();
      },
      onDone: () {
        final code = _channel?.closeCode;
        final reason = _channel?.closeReason ?? '';
        debugPrint('[WS] Stream closed — code: $code, reason: $reason');
        _fatalClose = isFatalCloseCode(code);
        if (_fatalClose) {
          debugPrint('[WS] Fatal close ($code) — will not reconnect');
        }
        _connected = false;
        _closeControllers();
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

  /// Send a plain-text or image/video message.
  void send(String? content, {String? imageUrl, bool isVideo = false, String? replyToId, String? roomId}) {
    final payload = <String, dynamic>{'type': 'message'};
    if (content != null && content.isNotEmpty) payload['content'] = content;
    if (imageUrl != null) {
      payload['image_url'] = imageUrl;
      if (isVideo) payload['is_video'] = true;
    }
    if (replyToId != null) payload['reply_to_id'] = replyToId;
    if (roomId != null) payload['room_id'] = roomId;
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
    String? imageUrl,
    bool isVideo = false,
    String? ephemeralKey,
    String? senderIdentityKey,
    int? otpkId,
    int? senderSpkId,
    String? replyToId,
    String? roomId,
  }) {
    final payload = <String, dynamic>{
      'type': 'message',
      'ciphertext': ciphertext,
      'iv': iv,
      if (imageUrl != null) 'image_url': imageUrl,
      if (imageUrl != null && isVideo) 'is_video': true,
      if (ephemeralKey != null && ephemeralKey.isNotEmpty)
        'ephemeral_key': ephemeralKey,
      if (senderIdentityKey != null) 'sender_identity_key': senderIdentityKey,
      if (otpkId != null) 'otpk_id': otpkId,
      if (senderSpkId != null) 'spk_id': senderSpkId,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (roomId != null) 'room_id': roomId,
    };
    _sendRaw(payload);
  }

  /// Send a like for an event.
  void sendLike(String eventId, {String? roomId}) =>
      _sendRaw({'type': 'like', 'event_id': eventId, if (roomId != null) 'room_id': roomId});

  /// Remove a like for an event.
  void sendUnlike(String eventId, {String? roomId}) =>
      _sendRaw({'type': 'unlike', 'event_id': eventId, if (roomId != null) 'room_id': roomId});

  /// Send a dislike for an event.
  void sendDislike(String eventId, {String? roomId}) =>
      _sendRaw({'type': 'dislike', 'event_id': eventId, if (roomId != null) 'room_id': roomId});

  /// Remove a dislike for an event.
  void sendUndislike(String eventId, {String? roomId}) =>
      _sendRaw({'type': 'undislike', 'event_id': eventId, if (roomId != null) 'room_id': roomId});

  /// Send a like for a picture.
  void sendPictureLike(String pictureId, {String? roomId}) =>
      _sendRaw({'type': 'picture_like', 'picture_id': pictureId, if (roomId != null) 'room_id': roomId});

  /// Remove a like for a picture.
  void sendPictureUnlike(String pictureId, {String? roomId}) =>
      _sendRaw({'type': 'picture_unlike', 'picture_id': pictureId, if (roomId != null) 'room_id': roomId});

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

  void _closeControllers() {
    _connectedController?.close();
    _msgController?.close();
    _likeController?.close();
    _picLikeController?.close();
    _keyBundlesController?.close();
    _participantKeyController?.close();
    _keyRotationController?.close();
    _msgEditedController?.close();
    _msgDeletedController?.close();
    _groupInviteController?.close();
    _userJoinedController?.close();
    _adminGrantedController?.close();
    _adminRevokedController?.close();
    _roomSettingsController?.close();
    _participantRemovedController?.close();
    _participantLeftController?.close();
    _roomDeletedController?.close();
    _senderKeyDistController?.close();
    _connectedController = null;
    _msgController = null;
    _likeController = null;
    _picLikeController = null;
    _keyBundlesController = null;
    _participantKeyController = null;
    _keyRotationController = null;
    _msgEditedController = null;
    _msgDeletedController = null;
    _groupInviteController = null;
    _userJoinedController = null;
    _adminGrantedController = null;
    _adminRevokedController = null;
    _roomSettingsController = null;
    _participantRemovedController = null;
    _participantLeftController = null;
    _roomDeletedController = null;
    _senderKeyDistController = null;
  }

  /// Gracefully close the connection.
  void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _closeControllers();
    _channel = null;
    _roomId = null;
    _connected = false;
  }
}

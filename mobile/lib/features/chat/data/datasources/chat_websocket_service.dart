import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:jperg_app/core/config/chat_config.dart';
import 'package:jperg_app/core/utils/server_time.dart';
import 'package:jperg_app/models/chat/chat_message.dart';
import 'package:jperg_app/models/chat/chat_room.dart';
import 'package:jperg_app/models/chat/like_update.dart' show LikeUpdate, PictureLikeUpdate;
import 'package:jperg_app/services/auth_service.dart';
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

/// Broadcast when another participant reads messages in this room.
class WsReadReceiptEvent {
  final String roomId;
  final String readerId;
  /// Set for bulk acks — all messages up to and including this ID are read.
  final String? upToMessageId;
  /// Set for single-message acks.
  final String? messageId;
  const WsReadReceiptEvent({
    required this.roomId,
    required this.readerId,
    this.upToMessageId,
    this.messageId,
  });
}

/// Another participant started or stopped typing.
///
/// Nothing about this is persisted — it is broadcast and forgotten, so a frame
/// only ever describes someone who was typing a moment ago. The receiving side
/// expires the indicator on a timer rather than trusting a stop frame to
/// arrive: a client that dies mid-word never sends one.
class WsTypingEvent {
  final String roomId;
  final String userId;
  final String userName;
  final bool isTyping;
  const WsTypingEvent({
    required this.roomId,
    required this.userId,
    required this.userName,
    required this.isTyping,
  });
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
  /// 'mobile', 'web', or '' when the server didn't include the field.
  final String clientType;
  const WsUserJoinedEvent({
    required this.roomId,
    required this.userId,
    required this.userName,
    required this.userRole,
    this.clientType = '',
  });
}

/// A server error frame. Carries the bare `{"error": "..."}` validation
/// failures and the typed `{"type":"error","message":"..."}` setup error.
class WsChatErrorEvent {
  final String message;
  final String? roomId;
  const WsChatErrorEvent({required this.message, this.roomId});
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

  /// Our own user id, captured from the `connected` frame. Used to apply the
  /// server's self-filter rule: ignore fan-out events from ourselves unless
  /// they carry `echo: true`.
  String? _myUserId;

  StreamController<WsConnectedEvent>? _connectedController;
  StreamController<WsChatErrorEvent>? _errorController;
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
  StreamController<WsReadReceiptEvent>? _readReceiptController;
  StreamController<WsTypingEvent>? _typingController;
  StreamSubscription? _sub;

  /// Emits the initial server handshake (userId + room list).
  Stream<WsConnectedEvent> get connectedEvents =>
      _connectedController?.stream ?? const Stream.empty();

  /// Emits server error frames (validation failures + setup errors).
  Stream<WsChatErrorEvent> get errorEvents =>
      _errorController?.stream ?? const Stream.empty();

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

  /// Emits when another participant acknowledges reading messages in this room.
  Stream<WsTypingEvent> get typingEvents =>
      (_typingController ??= StreamController<WsTypingEvent>.broadcast())
          .stream;

  Stream<WsReadReceiptEvent> get readReceiptEvents =>
      _readReceiptController?.stream ?? const Stream.empty();

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
      4003, // caller is not a participant / pending invite
      4004, // room not found — retrying can't help
      4400, // wrong endpoint — client-side bug
      // Note: 4029 (too many concurrent connections) and 1011 (internal) are
      // intentionally NOT fatal — they should back off and retry.
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
      queryParameters: {
        if (token.isNotEmpty) 'token': token,
        'client_type': kIsWeb ? 'web' : 'mobile',
      },
    );

    await _doConnect(uri);
    if (roomId != null) {
      debugPrint('[WS#$_instanceId] Connected — subscribing to room $roomId');
      _sendRaw({'type': 'subscribe_room', 'room_id': roomId});
    } else {
      debugPrint('[WS#$_instanceId] Connected (no initial room subscription) — shared/user WS');
    }
  }

  Future<void> _doConnect(Uri uri) async {
    _connectedController = StreamController<WsConnectedEvent>.broadcast();
    _errorController = StreamController<WsChatErrorEvent>.broadcast();
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
    _readReceiptController = StreamController<WsReadReceiptEvent>.broadcast();

    try {
      _channel = WebSocketChannel.connect(uri);
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

          // Rule 1 — error frames have NO type field (bare `{"error": "..."}`),
          // plus the typed setup error `{"type":"error","message":"..."}`.
          // Check before switching on type, and never route them as messages.
          if (json.containsKey('error') || type == 'error') {
            final msg = (json['error'] ?? json['message'])?.toString() ??
                'Unknown chat error';
            // `detail` is the server's diagnostic (e.g. "<ExcType>: <msg>")
            // for the "Internal error processing message" catch-all.
            final detail = json['detail'];
            debugPrint('[WS#$_instanceId] error frame: "$msg" roomId=${json['room_id']}'
                '${detail != null ? ' detail=$detail' : ''}');
            _errorController?.add(WsChatErrorEvent(
              message: msg,
              roomId: json['room_id'] as String?,
            ));
            return;
          }

          // Rule 2 — the server suppresses self fan-out but still echoes the
          // sender a copy with `echo: true`. Ignore any event from ourselves
          // that is NOT an echo. (Frames without `sender_id` — connected,
          // subscribed, room events keyed on *_by — are unaffected.)
          final senderId = json['sender_id'];
          if (senderId != null &&
              _myUserId != null &&
              senderId == _myUserId &&
              json['echo'] != true) {
            return;
          }

          if (type == 'connected') {
            final userId = json['userId'] as String? ?? '';
            _myUserId = userId;
            final rooms = (json['rooms'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList();
            _connectedController?.add(WsConnectedEvent(userId, rooms));
          } else if (type == 'subscribed') {
            // Subscribe acknowledgement — no client state to update.
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
                updatedAt: parseServerTime(updatedStr),
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
                clientType: json['client_type'] as String? ?? '',
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
          } else if (type == 'typing') {
            if (json['room_id'] is String && json['user_id'] is String) {
              _typingController?.add(WsTypingEvent(
                roomId: json['room_id'] as String,
                userId: json['user_id'] as String,
                userName: json['user_name'] as String? ?? '',
                isTyping: json['is_typing'] as bool? ?? true,
              ));
            }
          } else if (type == 'read_receipt') {
            if (json['room_id'] is String && json['reader_id'] is String) {
              _readReceiptController?.add(WsReadReceiptEvent(
                roomId: json['room_id'] as String,
                readerId: json['reader_id'] as String,
                upToMessageId: json['up_to_message_id'] as String?,
                messageId: json['message_id'] as String?,
              ));
            }
          } else if (type == 'message' ||
              (type == null && json['id'] is String && json['created_at'] is String)) {
            // New message / comment. On web, sender_role may be absent —
            // handled by the nullable cast in ChatMessage.fromJson.
            debugPrint('[WS] routing as ChatMessage: type=$type id=${json['id']} roomId=${json['room_id']} senderId=${json['sender_id']} role=${json['sender_role']} isEncrypted=${json['is_encrypted']} contentLen=${json['content']?.toString().length}');
            _msgController?.add(ChatMessage.fromJson(json));
          } else {
            debugPrint('[WS#$_instanceId] unhandled chat frame: type=$type');
          }
        } catch (e, st) {
          final rawStr = raw is String ? raw : raw.toString();
          debugPrint('[WS] frame parse error: $e\n$st\n  raw=${rawStr.length > 300 ? rawStr.substring(0, 300) : rawStr}');
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

  /// The room currently on screen, or null for "looking at nothing".
  ///
  /// This is what decides whether a message raises a push notification. It has
  /// to be separate from [subscribeRoom]: the app subscribes every joined room
  /// for the whole session, so a subscription says the socket is alive, not
  /// that anyone is reading. Without this the server treated every running app
  /// as present in every conversation and sent no notifications at all.
  ///
  /// Send null when leaving a room AND when the app goes to the background —
  /// a backgrounded app still holds the socket open.
  ///
  /// Sent with `room_id` explicitly present (possibly null), so _sendRaw's
  /// "fill in the current room" convenience cannot turn a clear into a claim.
  void sendFocus(String? roomId) {
    _focusedRoomId = roomId;
    _sendRaw({'type': 'focus', 'room_id': roomId});
  }

  /// The room the user is looking at, remembered across backgrounding and
  /// reconnects. Focus is per-socket on the server, so a new socket knows
  /// nothing until we say it again.
  String? _focusedRoomId;

  /// State this socket's focus, even when it is "nothing".
  ///
  /// Must be sent once on every connect. The server cannot tell a client that
  /// supports focus and is looking at nothing from an old client that will
  /// never mention it — and it has to assume the latter is still reading, or
  /// old builds would be notified about the chat on their screen. Saying
  /// `null` out loud is what distinguishes the two. Skipping it would leave
  /// an app that is running but has no room open silent, which is the common
  /// case and the whole bug.
  void announceFocus() {
    _sendRaw({'type': 'focus', 'room_id': _focusedRoomId});
  }

  /// App backgrounded — stop suppressing notifications, without forgetting
  /// which room to reclaim on return.
  void releaseFocus() {
    _sendRaw({'type': 'focus', 'room_id': null});
  }

  /// App foregrounded, or the socket reconnected — re-assert the open room.
  void restoreFocus() => announceFocus();

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

  /// Acknowledge reading all messages up to [upToMessageId] in [roomId].
  /// The server broadcasts a `read_receipt` event to all other room members.
  /// Tell the room the user has started or stopped typing.
  ///
  /// Fire-and-forget: [_sendRaw] drops the frame when the socket is down, which
  /// is the right outcome — a typing indicator is worthless by the time a
  /// reconnect would deliver it.
  void sendTyping(String roomId, {required bool isTyping}) {
    _sendRaw({
      'type': 'typing',
      'room_id': roomId,
      'is_typing': isTyping,
    });
  }

  void sendAck(String roomId, String upToMessageId) {
    _sendRaw({
      'type': 'ack',
      'room_id': roomId,
      'up_to_message_id': upToMessageId,
    });
  }

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
    _errorController?.close();
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
    _readReceiptController?.close();
    _typingController?.close();
    _connectedController = null;
    _errorController = null;
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
    _readReceiptController = null;
    _typingController = null;
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

import 'package:jperg_app/core/utils/cloudinary_transform.dart';

class ReplyPreview {
  final String id;
  final String senderName;
  final String? content;
  final String? imageUrl;
  final bool isVideo;

  const ReplyPreview({
    required this.id,
    required this.senderName,
    this.content,
    this.imageUrl,
    this.isVideo = false,
  });

  factory ReplyPreview.fromJson(Map<String, dynamic> json) {
    return ReplyPreview(
      id: json['id'] as String,
      senderName: json['sender_name'] as String,
      content: json['content'] as String?,
      imageUrl: json['image_url'] as String?,
      isVideo: (json['is_video'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_name': senderName,
        'content': content,
        'image_url': imageUrl,
        'is_video': isVideo,
      };
}

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String content;
  final String? imageUrl;
  final bool isVideo;

  /// Server-side pixel dimensions of the attached image/video. Null when no
  /// attachment or when the backend hasn't supplied dimensions yet.
  final int? mediaWidth;
  final int? mediaHeight;

  double? get mediaAspectRatio =>
      (mediaWidth != null && mediaHeight != null && mediaHeight! > 0)
          ? mediaWidth! / mediaHeight!
          : null;

  final String? replyToId;
  final ReplyPreview? replyPreview;
  final DateTime createdAt;
  final bool isRead;

  /// IDs of participants (other than the sender) who have read this message.
  /// Populated from REST `read_by` array and updated live via `read_receipt` WS events.
  final List<String> readBy;

  /// True for messages added optimistically before server confirms.
  final bool isLocal;

  // ── E2EE fields (present when server forwards an encrypted message) ─────────
  /// True when the server stored ciphertext in [content] instead of plaintext.
  final bool isEncrypted;

  /// Base64url 12-byte AES-GCM nonce.
  final String? iv;

  /// Base64url X25519 ephemeral public key used in the X3DH key exchange.
  final String? ephemeralKey;

  /// Base64url X25519 identity public key of the sender (present on the first
  /// encrypted message in a session so the receiver can complete X3DH).
  final String? senderIdentityKey;

  /// keyId of the one-time prekey consumed during X3DH (null if none used).
  /// The receiver needs this to compute DH4 and derive the same session key.
  final int? otpkId;

  /// keyId of the recipient's signed prekey the sender fetched from the bundle
  /// when running X3DH. Only present on the first message of a session.
  /// If this differs from the receiver's current SPK ID, the sender used an
  /// older SPK (rotation window) — the receiver should try the previous SPK.
  final int? senderSpkId;

  /// Server-set staleness flag — only present when [ephemeralKey] is non-null.
  ///   true  → sender's identity key doesn't match their current bundle
  ///   false → match, credentials are current
  ///   null  → ongoing session (no sender_identity_key in this message)
  final bool? stale;

  /// Set when the message has been edited. Null on original send.
  final DateTime? updatedAt;

  /// Non-null when this row is a system notice rather than something a person
  /// typed — "group_created", "invite_accepted", "invite_declined". Drawn as a
  /// centred italic line instead of a bubble.
  ///
  /// The wording is built in the app from this plus [senderName], not sent by
  /// the server, so it stays translatable. An unrecognised value renders as
  /// nothing — see [isSystem].
  final String? systemType;

  static const _knownSystemTypes = {
    'group_created',
    'invite_accepted',
    'invite_declined',
  };

  /// True when this should be drawn as a system notice. False for a
  /// system_type this build doesn't know, so a newer server adding one cannot
  /// put a blank line in an older app's conversation.
  bool get isSystem =>
      systemType != null && _knownSystemTypes.contains(systemType);

  bool get isEdited => updatedAt != null;

  bool get isAdminMessage =>
      senderRole == 'admin' || senderRole == 'superAdmin';

  String get displayName =>
      isAdminMessage ? 'Jperg Admin' : senderName;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    this.senderName = '',
    required this.senderRole,
    this.content = '',
    this.imageUrl,
    this.isVideo = false,
    this.mediaWidth,
    this.mediaHeight,
    this.replyToId,
    this.replyPreview,
    required this.createdAt,
    this.isRead = false,
    this.readBy = const [],
    this.isLocal = false,
    this.isEncrypted = false,
    this.iv,
    this.ephemeralKey,
    this.senderIdentityKey,
    this.otpkId,
    this.senderSpkId,
    this.stale,
    this.updatedAt,
    this.systemType,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    ReplyPreview? preview;
    final previewRaw = json['reply_preview'];
    if (previewRaw is Map<String, dynamic>) {
      preview = ReplyPreview.fromJson(previewRaw);
    }

    final imageUrl = json['image_url'] as String?;
    // is_video may be a bool (JSON) or int 0/1 (SQLite cache) — handle both.
    // The sender's own flag wins; the URL is only a fallback for rows written
    // before the server stored one. A video mistaken for an image goes to the
    // image loader, which can only fail — the reader gets "Photo unavailable"
    // on a video.
    final rawIsVideo = json['is_video'];
    final isVideoFlag = rawIsVideo == true || rawIsVideo == 1;
    final isVideoByExt = imageUrl != null && _isVideoUrl(imageUrl);

    return ChatMessage(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String? ?? '',
      // sender_role can be absent/null in some server frames (e.g. web clients
      // whose role isn't tracked); default to '' rather than throwing a
      // TypeError that silently drops the WS message.
      senderRole: json['sender_role'] as String? ?? '',
      content: json['content'] as String? ?? '',
      imageUrl: imageUrl,
      isVideo: isVideoFlag || isVideoByExt,
      mediaWidth: (json['media_width'] as num?)?.toInt(),
      mediaHeight: (json['media_height'] as num?)?.toInt(),
      replyToId: json['reply_to_id'] as String?,
      replyPreview: preview,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: (json['is_read'] as bool?) ?? false,
      readBy: (json['read_by'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      isEncrypted: (json['is_encrypted'] as bool?) ?? false,
      iv: json['iv'] as String?,
      ephemeralKey: json['ephemeral_key'] as String?,
      senderIdentityKey: json['sender_identity_key'] as String?,
      otpkId: (json['otpk_id'] as num?)?.toInt(),
      senderSpkId: ((json['sender_spk_id'] ?? json['spk_id']) as num?)?.toInt(),
      stale: json['stale'] as bool?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      systemType: json['system_type'] as String?,
    );
  }

  static bool _isVideoUrl(String url) => CloudinaryTransform.isVideoUrl(url);

  Map<String, dynamic> toJson() => {
        'id': id,
        'room_id': roomId,
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_role': senderRole,
        'content': content,
        'image_url': imageUrl,
        'is_video': isVideo,
        if (mediaWidth != null) 'media_width': mediaWidth,
        if (mediaHeight != null) 'media_height': mediaHeight,
        'reply_to_id': replyToId,
        'reply_preview': replyPreview?.toJson(),
        'created_at': createdAt.toIso8601String(),
        'is_read': isRead ? 1 : 0,
        'is_local': isLocal ? 1 : 0,
        'is_encrypted': isEncrypted ? 1 : 0,
        'iv': iv,
        'ephemeral_key': ephemeralKey,
        'sender_identity_key': senderIdentityKey,
        'otpk_id': otpkId,
        'spk_id': senderSpkId,
        'stale': stale,
        'updated_at': updatedAt?.toIso8601String(),
        'system_type': systemType,
      };

  ChatMessage copyWith({
    String? id,
    String? senderName,
    bool? isRead,
    List<String>? readBy,
    bool? isLocal,
    String? imageUrl,
    bool? isVideo,
    String? content,
    bool? isEncrypted,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      roomId: roomId,
      senderId: senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      isVideo: isVideo ?? this.isVideo,
      mediaWidth: mediaWidth,
      mediaHeight: mediaHeight,
      replyToId: replyToId,
      replyPreview: replyPreview,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      readBy: readBy ?? this.readBy,
      isLocal: isLocal ?? this.isLocal,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      iv: iv,
      ephemeralKey: ephemeralKey,
      senderIdentityKey: senderIdentityKey,
      otpkId: otpkId,
      senderSpkId: senderSpkId,
      stale: stale,
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
      systemType: systemType,
    );
  }
}

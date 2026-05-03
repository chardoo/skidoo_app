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
  final String? replyToId;
  final ReplyPreview? replyPreview;
  final DateTime createdAt;
  final bool isRead;

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

  bool get isEdited => updatedAt != null;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    this.senderName = '',
    required this.senderRole,
    this.content = '',
    this.imageUrl,
    this.isVideo = false,
    this.replyToId,
    this.replyPreview,
    required this.createdAt,
    this.isRead = false,
    this.isLocal = false,
    this.isEncrypted = false,
    this.iv,
    this.ephemeralKey,
    this.senderIdentityKey,
    this.otpkId,
    this.senderSpkId,
    this.stale,
    this.updatedAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    ReplyPreview? preview;
    final previewRaw = json['reply_preview'];
    if (previewRaw is Map<String, dynamic>) {
      preview = ReplyPreview.fromJson(previewRaw);
    }

    final imageUrl = json['image_url'] as String?;
    // is_video may be a bool (JSON) or int 0/1 (SQLite cache) — handle both.
    final rawIsVideo = json['is_video'];
    final isVideoFlag = rawIsVideo == true || rawIsVideo == 1;
    final isVideoByExt = imageUrl != null && _isVideoUrl(imageUrl);

    return ChatMessage(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String? ?? '',
      senderRole: json['sender_role'] as String,
      content: json['content'] as String? ?? '',
      imageUrl: imageUrl,
      isVideo: isVideoFlag || isVideoByExt,
      replyToId: json['reply_to_id'] as String?,
      replyPreview: preview,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: (json['is_read'] as bool?) ?? false,
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
    );
  }

  static bool _isVideoUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    // Cloudinary video URLs always contain /video/upload/ in the path.
    if (lower.contains('/video/upload/')) return true;
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'room_id': roomId,
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_role': senderRole,
        'content': content,
        'image_url': imageUrl,
        'is_video': isVideo,
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
      };

  ChatMessage copyWith({
    String? id,
    String? senderName,
    bool? isRead,
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
      replyToId: replyToId,
      replyPreview: replyPreview,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      isLocal: isLocal ?? this.isLocal,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      iv: iv,
      ephemeralKey: ephemeralKey,
      senderIdentityKey: senderIdentityKey,
      otpkId: otpkId,
      senderSpkId: senderSpkId,
      stale: stale,
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    );
  }
}

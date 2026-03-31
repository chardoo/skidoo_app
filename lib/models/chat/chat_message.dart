class ReplyPreview {
  final String id;
  final String senderName;
  final String? content;
  final String? imageUrl;

  const ReplyPreview({
    required this.id,
    required this.senderName,
    this.content,
    this.imageUrl,
  });

  factory ReplyPreview.fromJson(Map<String, dynamic> json) {
    return ReplyPreview(
      id: json['id'] as String,
      senderName: json['sender_name'] as String,
      content: json['content'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_name': senderName,
        'content': content,
        'image_url': imageUrl,
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
  final String? replyToId;
  final ReplyPreview? replyPreview;
  final DateTime createdAt;
  final bool isRead;

  /// True for messages added optimistically before server confirms.
  final bool isLocal;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    this.senderName = '',
    required this.senderRole,
    this.content = '',
    this.imageUrl,
    this.replyToId,
    this.replyPreview,
    required this.createdAt,
    this.isRead = false,
    this.isLocal = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    ReplyPreview? preview;
    final previewRaw = json['reply_preview'];
    if (previewRaw is Map<String, dynamic>) {
      preview = ReplyPreview.fromJson(previewRaw);
    }

    return ChatMessage(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String? ?? '',
      senderRole: json['sender_role'] as String,
      content: json['content'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      replyToId: json['reply_to_id'] as String?,
      replyPreview: preview,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: (json['is_read'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'room_id': roomId,
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_role': senderRole,
        'content': content,
        'image_url': imageUrl,
        'reply_to_id': replyToId,
        'reply_preview': replyPreview?.toJson(),
        'created_at': createdAt.toIso8601String(),
        'is_read': isRead ? 1 : 0,
        'is_local': isLocal ? 1 : 0,
      };

  ChatMessage copyWith({
    String? id,
    String? senderName,
    bool? isRead,
    bool? isLocal,
    String? imageUrl,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      roomId: roomId,
      senderId: senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole,
      content: content,
      imageUrl: imageUrl ?? this.imageUrl,
      replyToId: replyToId,
      replyPreview: replyPreview,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      isLocal: isLocal ?? this.isLocal,
    );
  }
}

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderRole;
  final String content;
  final DateTime createdAt;
  final bool isRead;

  /// True for messages added optimistically before server confirms.
  final bool isLocal;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderRole,
    required this.content,
    required this.createdAt,
    this.isRead = false,
    this.isLocal = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      senderId: json['sender_id'] as String,
      senderRole: json['sender_role'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: (json['is_read'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'room_id': roomId,
        'sender_id': senderId,
        'sender_role': senderRole,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'is_read': isRead ? 1 : 0,
        'is_local': isLocal ? 1 : 0,
      };

  ChatMessage copyWith({
    String? id,
    bool? isRead,
    bool? isLocal,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      roomId: roomId,
      senderId: senderId,
      senderRole: senderRole,
      content: content,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      isLocal: isLocal ?? this.isLocal,
    );
  }
}

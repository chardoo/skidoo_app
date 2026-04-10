import 'dart:convert';

enum RoomType {
  global,
  direct,
  event,
  eventPrivate,
  photo,
  sample,
  unknown;

  static RoomType fromString(String? value) {
    switch (value) {
      case 'global':
        return RoomType.global;
      case 'direct':
        return RoomType.direct;
      case 'event':
        return RoomType.event;
      case 'event_private':
        return RoomType.eventPrivate;
      case 'photo':
        return RoomType.photo;
      case 'sample':
        return RoomType.sample;
      default:
        return RoomType.unknown;
    }
  }

  String toApiString() {
    switch (this) {
      case RoomType.global:
        return 'global';
      case RoomType.direct:
        return 'direct';
      case RoomType.event:
        return 'event';
      case RoomType.eventPrivate:
        return 'event_private';
      case RoomType.photo:
        return 'photo';
      case RoomType.sample:
        return 'sample';
      case RoomType.unknown:
        return 'unknown';
    }
  }

  /// True for rooms that represent personal conversations shown in the inbox.
  bool get isConversation =>
      this == RoomType.direct || this == RoomType.eventPrivate;
}

class ChatParticipant {
  final String userId;
  final String userRole;
  final DateTime joinedAt;

  const ChatParticipant({
    required this.userId,
    required this.userRole,
    required this.joinedAt,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      userId: json['user_id'] as String,
      userRole: json['user_role'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'user_role': userRole,
        'joined_at': joinedAt.toIso8601String(),
      };
}

class ChatRoom {
  final String id;
  final RoomType type;
  final String? eventId;
  final String? name;
  final DateTime createdAt;
  final List<ChatParticipant> participants;

  const ChatRoom({
    required this.id,
    required this.type,
    this.eventId,
    this.name,
    required this.createdAt,
    this.participants = const [],
  });

  /// Human-readable display name.
  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    switch (type) {
      case RoomType.global:
        return 'Global Chat';
      case RoomType.direct:
        return 'Direct Message';
      case RoomType.event:
        return 'Event Chat';
      case RoomType.eventPrivate:
        return 'Private Chat';
      case RoomType.photo:
        return 'Photo Comments';
      case RoomType.sample:
        return 'Sample Chat';
      case RoomType.unknown:
        return 'Chat';
    }
  }

  ChatRoom copyWith({
    String? id,
    RoomType? type,
    String? eventId,
    String? name,
    DateTime? createdAt,
    List<ChatParticipant>? participants,
  }) =>
      ChatRoom(
        id: id ?? this.id,
        type: type ?? this.type,
        eventId: eventId ?? this.eventId,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
        participants: participants ?? this.participants,
      );

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    final participantsList = (json['participants'] as List<dynamic>? ?? [])
        .map((p) => ChatParticipant.fromJson(p as Map<String, dynamic>))
        .toList();

    return ChatRoom(
      id: json['id'] as String,
      type: RoomType.fromString(json['type'] as String?),
      eventId: json['event_id'] as String?,
      name: json['name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      participants: participantsList,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toApiString(),
        'event_id': eventId,
        'name': name,
        'created_at': createdAt.toIso8601String(),
        'participants': jsonEncode(participants.map((p) => p.toJson()).toList()),
      };
}

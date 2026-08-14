import 'dart:convert';

enum RoomType {
  global,
  direct,
  event,
  eventPrivate,
  photo,
  sample,
  group,
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
      case 'group':
        return RoomType.group;
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
      case RoomType.group:
        return 'group';
      case RoomType.unknown:
        return 'unknown';
    }
  }

  /// True for rooms shown in the Messages inbox.
  bool get isConversation =>
      this == RoomType.global ||
      this == RoomType.direct ||
      this == RoomType.eventPrivate ||
      this == RoomType.group;
}

class ChatParticipant {
  final String userId;
  final String userRole;
  final DateTime joinedAt;

  /// 'active' for joined members, 'pending' for users who have been invited
  /// but haven't yet accepted.
  final String status;

  /// Display name, if provided by the server.
  final String? userName;

  /// True when this participant has admin privileges in a group room.
  final bool isAdmin;

  const ChatParticipant({
    required this.userId,
    required this.userRole,
    required this.joinedAt,
    this.status = 'active',
    this.userName,
    this.isAdmin = false,
  });

  bool get isPending => status == 'pending';

  /// Best-effort display label: userName → role → userId.
  String get displayName {
    if (userName != null && userName!.isNotEmpty) return userName!;
    if (userRole.isNotEmpty) {
      return userRole[0].toUpperCase() + userRole.substring(1);
    }
    return userId;
  }

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      userId: json['user_id'] as String,
      userRole: json['user_role'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      status: (json['status'] as String?) ?? 'active',
      userName: json['user_name'] as String?,
      isAdmin: (json['is_admin'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'user_role': userRole,
        'joined_at': joinedAt.toIso8601String(),
        'status': status,
        if (userName != null) 'user_name': userName,
        'is_admin': isAdmin,
      };

  ChatParticipant copyWith({
    String? userId,
    String? userRole,
    DateTime? joinedAt,
    String? status,
    String? userName,
    bool? isAdmin,
  }) =>
      ChatParticipant(
        userId: userId ?? this.userId,
        userRole: userRole ?? this.userRole,
        joinedAt: joinedAt ?? this.joinedAt,
        status: status ?? this.status,
        userName: userName ?? this.userName,
        isAdmin: isAdmin ?? this.isAdmin,
      );
}

class ChatRoom {
  final String id;
  final RoomType type;
  final String? eventId;
  final String? name;
  final DateTime createdAt;
  final List<ChatParticipant> participants;
  /// Per-user E2EE bundle availability, keyed by userId.
  /// Populated by POST /chat/rooms/direct and GET /chat/rooms/{id}.
  final Map<String, bool> e2eStatus;

  /// When true, only admins can send messages. Group rooms only.
  final bool adminOnly;

  /// Server-provided count of messages this user hasn't read yet. The backend
  /// derives it from the user's last-read marker (updated by `ack`). Used to
  /// seed the unread badge on platforms with no local DB (web), so the count
  /// survives a page refresh. Defaults to 0 when the server omits it.
  final int unreadCount;

  const ChatRoom({
    required this.id,
    required this.type,
    this.eventId,
    this.name,
    required this.createdAt,
    this.participants = const [],
    this.e2eStatus = const {},
    this.adminOnly = false,
    this.unreadCount = 0,
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
      case RoomType.group:
        return 'Group';
      case RoomType.unknown:
        return 'Chat';
    }
  }

  /// For direct rooms: returns the other participant's name — the actual
  /// person's name, never their role ("Photographer") or "Direct Message".
  /// Falls back to [displayName] for non-direct rooms or when no name is known.
  String displayNameFor(String myId) {
    // An explicit room name (e.g. set when opening a DM from a profile) wins.
    if (name != null && name!.isNotEmpty) return name!;
    if (type != RoomType.direct || myId.isEmpty) return displayName;
    final peer = participants.where((p) => p.userId != myId).firstOrNull;
    // Use the peer's *name* only — not their role — so we never show
    // "Photographer"/"User" in place of a person's name.
    final peerName = peer?.userName;
    if (peerName != null && peerName.trim().isNotEmpty) return peerName.trim();
    return displayName;
  }

  /// True when any participant is an admin or superAdmin — used to badge
  /// the room tile in the listing so users know this is an official room.
  bool get hasAdminParticipant => participants.any(
        (p) => p.userRole == 'admin' || p.userRole == 'superAdmin',
      );

  /// For direct rooms: returns the other participant's display name as subtitle.
  /// Returns null for non-direct rooms so the caller can use its own label.
  String? peerName(String myId) {
    if (type != RoomType.direct || myId.isEmpty) return null;
    if (name != null && name!.isNotEmpty) return name!;
    final peer = participants.where((p) => p.userId != myId).firstOrNull;
    return peer?.displayName;
  }

  /// True if [userId] has a pending invite to this room.
  bool hasPendingInvite(String userId) =>
      participants.any((p) => p.userId == userId && p.isPending);

  /// This room with [userId]'s pending invite turned into membership, or null
  /// when there was no pending invite to turn.
  ///
  /// Accepting an invite used to change only the server. The rooms list reads
  /// the local cache before it syncs, and the cached copy still said `pending`
  /// — so [hasPendingInvite] answered true and the room went straight back into
  /// the pending bucket, undoing the join on screen until the round-trip
  /// landed. Null rather than an unchanged copy so the caller can skip the
  /// write when there is nothing to correct.
  ChatRoom? withInviteAccepted(String userId) {
    if (!hasPendingInvite(userId)) return null;
    return copyWith(
      participants: [
        for (final p in participants)
          if (p.userId == userId && p.isPending)
            p.copyWith(status: 'active')
          else
            p,
      ],
    );
  }

  ChatRoom copyWith({
    String? id,
    RoomType? type,
    String? eventId,
    String? name,
    DateTime? createdAt,
    List<ChatParticipant>? participants,
    Map<String, bool>? e2eStatus,
    bool? adminOnly,
    int? unreadCount,
  }) =>
      ChatRoom(
        id: id ?? this.id,
        type: type ?? this.type,
        eventId: eventId ?? this.eventId,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
        participants: participants ?? this.participants,
        e2eStatus: e2eStatus ?? this.e2eStatus,
        adminOnly: adminOnly ?? this.adminOnly,
        unreadCount: unreadCount ?? this.unreadCount,
      );

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    final participantsList = (json['participants'] as List<dynamic>? ?? [])
        .map((p) => ChatParticipant.fromJson(p as Map<String, dynamic>))
        .toList();

    final rawStatus = json['e2e_status'] as Map<String, dynamic>?;
    final e2eStatus = rawStatus != null
        ? rawStatus.map((k, v) => MapEntry(k, (v as bool?) ?? false))
        : const <String, bool>{};

    return ChatRoom(
      id: json['id'] as String,
      type: RoomType.fromString(json['type'] as String?),
      eventId: json['event_id'] as String?,
      name: json['name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      participants: participantsList,
      e2eStatus: e2eStatus,
      adminOnly: (json['admin_only'] as bool?) ?? false,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toApiString(),
        'event_id': eventId,
        'name': name,
        'created_at': createdAt.toIso8601String(),
        'admin_only': adminOnly,
        'participants': jsonEncode(participants.map((p) => p.toJson()).toList()),
      };
}

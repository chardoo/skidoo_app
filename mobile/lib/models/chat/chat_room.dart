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

  /// Avatar URL, resolved server-side from the user record. Null when the
  /// account has no photo — callers fall back to the name's initial.
  final String? userImage;

  /// True when this participant has admin privileges in a group room.
  final bool isAdmin;

  /// True when *this* participant has muted the room. Only ever meaningful for
  /// the signed-in user's own row; everyone else's is nobody's business.
  final bool muted;

  /// Who sent the invite, for pending rows. Null for anyone who joined without
  /// one — creators, and members of public rooms.
  final String? invitedBy;
  final String? invitedByName;

  const ChatParticipant({
    required this.userId,
    required this.userRole,
    required this.joinedAt,
    this.status = 'active',
    this.userName,
    this.userImage,
    this.isAdmin = false,
    this.muted = false,
    this.invitedBy,
    this.invitedByName,
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
      userImage: json['user_image'] as String?,
      isAdmin: (json['is_admin'] as bool?) ?? false,
      muted: (json['muted'] as bool?) ?? false,
      invitedBy: json['invited_by'] as String?,
      invitedByName: json['invited_by_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'user_role': userRole,
        'joined_at': joinedAt.toIso8601String(),
        'status': status,
        if (userName != null) 'user_name': userName,
        if (userImage != null) 'user_image': userImage,
        'is_admin': isAdmin,
        'muted': muted,
        if (invitedBy != null) 'invited_by': invitedBy,
        if (invitedByName != null) 'invited_by_name': invitedByName,
      };

  ChatParticipant copyWith({
    String? userId,
    String? userRole,
    DateTime? joinedAt,
    String? status,
    String? userName,
    String? userImage,
    bool? isAdmin,
    bool? muted,
    String? invitedBy,
    String? invitedByName,
  }) =>
      ChatParticipant(
        userId: userId ?? this.userId,
        userRole: userRole ?? this.userRole,
        joinedAt: joinedAt ?? this.joinedAt,
        status: status ?? this.status,
        userName: userName ?? this.userName,
        userImage: userImage ?? this.userImage,
        isAdmin: isAdmin ?? this.isAdmin,
        muted: muted ?? this.muted,
        invitedBy: invitedBy ?? this.invitedBy,
        invitedByName: invitedByName ?? this.invitedByName,
      );
}

/// The preview line under a room name in the inbox.
///
/// Comes from the server with the room list, so the tile can be drawn before
/// any of the room's messages have been fetched or cached locally.
class LastMessage {
  final String id;
  final String senderId;
  final String senderName;

  /// Null for image-only messages, system notices, and ciphertext — see
  /// [hasImage], [systemType] and [isEncrypted] for what to show instead.
  final String? content;
  final bool hasImage;
  final bool isEncrypted;

  /// Non-null when this is a system notice rather than something someone typed.
  /// See [ChatMessage.systemType].
  final String? systemType;
  final DateTime createdAt;

  const LastMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.content,
    this.hasImage = false,
    this.isEncrypted = false,
    this.systemType,
    required this.createdAt,
  });

  factory LastMessage.fromJson(Map<String, dynamic> json) => LastMessage(
        id: json['id'] as String,
        senderId: (json['sender_id'] as String?) ?? '',
        senderName: (json['sender_name'] as String?) ?? '',
        content: json['content'] as String?,
        hasImage: (json['has_image'] as bool?) ?? false,
        isEncrypted: (json['is_encrypted'] as bool?) ?? false,
        systemType: json['system_type'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_id': senderId,
        'sender_name': senderName,
        'content': content,
        'has_image': hasImage,
        'is_encrypted': isEncrypted,
        'system_type': systemType,
        'created_at': createdAt.toIso8601String(),
      };
}

class ChatRoom {
  final String id;
  final RoomType type;
  final String? eventId;
  final String? name;

  /// Group photo. Null for DMs, which show the other person's avatar instead.
  final String? imageUrl;
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

  /// The preview line for the inbox tile. Null for a room nobody has written
  /// in, and on responses other than the room list — the per-room endpoints
  /// don't pay for it, since no screen that uses them draws a preview.
  final LastMessage? lastMessage;

  const ChatRoom({
    required this.id,
    required this.type,
    this.eventId,
    this.name,
    this.imageUrl,
    required this.createdAt,
    this.participants = const [],
    this.e2eStatus = const {},
    this.adminOnly = false,
    this.unreadCount = 0,
    this.lastMessage,
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

  /// The avatar for this room: the group photo, or in a DM the other person's.
  /// Null when there is none to show and the caller should fall back to an
  /// initial or a type icon.
  String? avatarFor(String myId) {
    if (type == RoomType.group) return imageUrl;
    if (type != RoomType.direct || myId.isEmpty) return imageUrl;
    return participants
        .where((p) => p.userId != myId)
        .map((p) => p.userImage)
        .firstWhere((image) => image != null && image.isNotEmpty,
            orElse: () => null);
  }

  /// The signed-in user's own participant row, or null if they aren't in the
  /// room (a public room they're only reading).
  ChatParticipant? participantFor(String myId) =>
      participants.where((p) => p.userId == myId).firstOrNull;

  /// Whether the signed-in user has muted this room.
  bool isMutedFor(String myId) => participantFor(myId)?.muted ?? false;

  /// Who invited [myId], for the pending-invite card. Null when they weren't
  /// invited, or when the invite predates the server recording it.
  String? inviterNameFor(String myId) {
    final me = participantFor(myId);
    if (me == null || !me.isPending) return null;
    final name = me.invitedByName;
    return (name != null && name.trim().isNotEmpty) ? name.trim() : null;
  }

  /// Members other than [myId], active ones first — the order the group header
  /// and the member list both want.
  List<ChatParticipant> othersFor(String myId) => [
        for (final p in participants)
          if (p.userId != myId) p,
      ]..sort((a, b) {
          if (a.isPending != b.isPending) return a.isPending ? 1 : -1;
          if (a.isAdmin != b.isAdmin) return a.isAdmin ? -1 : 1;
          return a.displayName.compareTo(b.displayName);
        });

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
    String? imageUrl,
    DateTime? createdAt,
    List<ChatParticipant>? participants,
    Map<String, bool>? e2eStatus,
    bool? adminOnly,
    int? unreadCount,
    LastMessage? lastMessage,
  }) =>
      ChatRoom(
        id: id ?? this.id,
        type: type ?? this.type,
        eventId: eventId ?? this.eventId,
        name: name ?? this.name,
        imageUrl: imageUrl ?? this.imageUrl,
        createdAt: createdAt ?? this.createdAt,
        participants: participants ?? this.participants,
        e2eStatus: e2eStatus ?? this.e2eStatus,
        adminOnly: adminOnly ?? this.adminOnly,
        unreadCount: unreadCount ?? this.unreadCount,
        lastMessage: lastMessage ?? this.lastMessage,
      );

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    final participantsList = (json['participants'] as List<dynamic>? ?? [])
        .map((p) => ChatParticipant.fromJson(p as Map<String, dynamic>))
        .toList();

    final rawStatus = json['e2e_status'] as Map<String, dynamic>?;
    final e2eStatus = rawStatus != null
        ? rawStatus.map((k, v) => MapEntry(k, (v as bool?) ?? false))
        : const <String, bool>{};

    final rawLast = json['last_message'] as Map<String, dynamic>?;

    return ChatRoom(
      id: json['id'] as String,
      type: RoomType.fromString(json['type'] as String?),
      eventId: json['event_id'] as String?,
      name: json['name'] as String?,
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      participants: participantsList,
      e2eStatus: e2eStatus,
      adminOnly: (json['admin_only'] as bool?) ?? false,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      lastMessage: rawLast != null ? LastMessage.fromJson(rawLast) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toApiString(),
        'event_id': eventId,
        'name': name,
        'image_url': imageUrl,
        'created_at': createdAt.toIso8601String(),
        'admin_only': adminOnly,
        'participants': jsonEncode(participants.map((p) => p.toJson()).toList()),
      };
}

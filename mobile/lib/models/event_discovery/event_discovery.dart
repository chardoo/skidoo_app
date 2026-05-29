enum MediaType { photo, video }

class EventPicture {
  final String id;
  final String url;
  final String imageId;
  final int price;
  final MediaType mediaType;
  final bool owner;
  final int likeCount;
  final int commentCount;
  final bool isLikedByUser;
  final bool commentsEnabled;

  const EventPicture({
    required this.id,
    required this.url,
    required this.imageId,
    required this.price,
    this.mediaType = MediaType.photo,
    this.owner = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLikedByUser = false,
    this.commentsEnabled = true,
  });

  bool get isVideo => mediaType == MediaType.video;

  Map<String, dynamic> toMap() => {
        'id': id,
        'url': url,
        'imageId': imageId,
        'price': price,
        'mediaType': isVideo ? 'video' : 'photo',
        'owner': owner,
        'like_count': likeCount,
        'comment_count': commentCount,
        'isLikedByUser': isLikedByUser,
        'comments_enabled': commentsEnabled,
      };

  factory EventPicture.fromMap(Map<String, dynamic> json) {
    final typeRaw = json['mediaType']?.toString().toLowerCase() ?? 'photo';
    // Support both camelCase and snake_case keys the server may return.
    int parseInt(String a, String b) =>
        (json[a] as num?)?.toInt() ?? (json[b] as num?)?.toInt() ?? 0;
    return EventPicture(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      imageId: json['imageId']?.toString() ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      mediaType: typeRaw == 'video' ? MediaType.video : MediaType.photo,
      owner: json['owner'] == true,
      likeCount: parseInt('likeCount', 'like_count'),
      commentCount: parseInt('commentCount', 'comment_count'),
      isLikedByUser: json['isLikedByUser'] == true || json['is_liked_by_user'] == true,
      commentsEnabled: json['comments_enabled'] as bool? ?? true,
    );
  }
}

class EventDiscovery {
  final String id;
  final String eventName;
  final String photographerName;
  final String photographerId;
  final List<EventPicture> pictures;
  final int likes;
  final int dislikes;
  final int commentCount;
  final bool commentsEnabled;

  /// The authenticated user's current reaction: 'like', 'dislike', or null.
  final String? userReaction;

  /// True when the current user already follows this photographer.
  /// Sourced directly from event.user.is_followed in the feed response.
  final bool isFollowed;

  /// Backend-supplied content tags (e.g. ["wedding", "photography", "ghana"]).
  /// Shown as hashtags beneath the event name in the caption area.
  final List<String> contentTags;

  const EventDiscovery({
    required this.id,
    required this.eventName,
    required this.photographerName,
    required this.photographerId,
    required this.pictures,
    this.likes = 0,
    this.dislikes = 0,
    this.commentCount = 0,
    this.commentsEnabled = true,
    this.userReaction,
    this.isFollowed = false,
    this.contentTags = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'eventName': eventName,
        'user': {
          'id': photographerId,
          'name': photographerName,
          'is_followed': isFollowed,
        },
        'pictures': pictures.map((p) => p.toMap()).toList(),
        'likes': likes,
        'dislikes': dislikes,
        'comment_count': commentCount,
        'comments_enabled': commentsEnabled,
      };

  EventDiscovery copyWith({
    int? likes,
    int? dislikes,
    int? commentCount,
    bool? commentsEnabled,
    String? userReaction,
    bool clearReaction = false,
    bool? isFollowed,
    List<String>? contentTags,
  }) {
    return EventDiscovery(
      id: id,
      eventName: eventName,
      photographerName: photographerName,
      photographerId: photographerId,
      pictures: pictures,
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      commentCount: commentCount ?? this.commentCount,
      commentsEnabled: commentsEnabled ?? this.commentsEnabled,
      userReaction:
          clearReaction ? null : (userReaction ?? this.userReaction),
      isFollowed: isFollowed ?? this.isFollowed,
      contentTags: contentTags ?? this.contentTags,
    );
  }

  factory EventDiscovery.fromMap(Map<String, dynamic> json) {
    // Support both wrapped { "event": {...} } and flat item shapes.
    final Map<String, dynamic> event =
        json['event'] is Map<String, dynamic>
            ? json['event'] as Map<String, dynamic>
            : json;
    // User/photographer can be nested under 'user' or 'photographer'.
    final user = (event['user'] as Map<String, dynamic>?) ??
        (event['photographer'] as Map<String, dynamic>?) ??
        {};
    // Pictures can be under 'pictures' or 'images'.
    final rawPics = (event['pictures'] as List<dynamic>?) ??
        (event['images'] as List<dynamic>?) ??
        [];
    final pics = rawPics
        .map((p) => EventPicture.fromMap(p as Map<String, dynamic>))
        .toList();
    final isFollowed = user['is_followed'] == true;
    final rawTags = event['content_tags'] ?? event['contentTags'];
    final contentTags = rawTags is List
        ? rawTags.map((t) => t.toString()).where((t) => t.isNotEmpty).toList()
        : <String>[];
    return EventDiscovery(
      id: event['id']?.toString() ?? '',
      // Event name can be 'eventName' or 'name'.
      eventName: event['eventName']?.toString() ??
          event['name']?.toString() ?? '',
      photographerName: user['name']?.toString() ?? '',
      photographerId: user['id']?.toString() ?? '',
      pictures: pics,
      likes: (event['likes'] as num?)?.toInt() ?? 0,
      dislikes: (event['dislikes'] as num?)?.toInt() ?? 0,
      commentCount: (event['commentCount'] as num?)?.toInt() ??
          (event['comment_count'] as num?)?.toInt() ?? 0,
      commentsEnabled: event['comments_enabled'] as bool? ?? true,
      isFollowed: isFollowed,
      contentTags: contentTags,
    );
  }
}

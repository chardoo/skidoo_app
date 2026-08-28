import 'package:jperg_app/core/utils/cloudinary_transform.dart';
import 'package:jperg_app/features/music/domain/entities/music_track.dart';

enum MediaType { photo, video }

class EventPicture {
  final String id;
  final String url;
  final String imageId;
  /// In whole currency units, with the pesewas kept.
  ///
  /// Was an `int`, and this is a money path: it becomes `Photo.price`, which
  /// decides whether a photo is bought or saved for nothing. Truncating turned
  /// a photo priced 0.50 into 0 — free, given away — and undercharged 6.27 by
  /// the 27 pesewas.
  final double price;
  final MediaType mediaType;
  final bool owner;
  final int likeCount;
  final int commentCount;
  final bool isLikedByUser;
  final bool commentsEnabled;

  /// Already bought by whoever is looking. The feed's grid shows no price, but
  /// the viewer it opens into does — so this has to travel with the picture or
  /// the viewer offers to sell something already owned.
  final bool isPurchased;

  /// Server-side pixel dimensions. Null for legacy records that pre-date
  /// backend dimension extraction. The card falls back to a 4:5 default
  /// when these are absent.
  final int? width;
  final int? height;

  /// Duration in seconds for video assets. Null for photos.
  final double? durationSeconds;

  const EventPicture({
    required this.id,
    required this.url,
    required this.imageId,
    required this.price,
    this.isPurchased = false,
    this.mediaType = MediaType.photo,
    this.owner = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLikedByUser = false,
    this.commentsEnabled = true,
    this.width,
    this.height,
    this.durationSeconds,
  });

  /// Same fallback as `Photo.isVideo`: the url settles it when the record
  /// carries no `media_type`.
  bool get isVideo =>
      mediaType == MediaType.video || CloudinaryTransform.isVideoUrl(url);

  /// Aspect ratio (width ÷ height). Returns null when dimensions are unknown.
  double? get aspectRatio =>
      (width != null && height != null && height! > 0) ? width! / height! : null;

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
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (durationSeconds != null) 'duration_seconds': durationSeconds,
      };

  factory EventPicture.fromMap(Map<String, dynamic> json) {
    final typeRaw = json['mediaType']?.toString().toLowerCase() ?? 'photo';
    int parseInt(String a, String b) =>
        (json[a] as num?)?.toInt() ?? (json[b] as num?)?.toInt() ?? 0;
    return EventPicture(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      imageId: json['imageId']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      mediaType: typeRaw == 'video' ? MediaType.video : MediaType.photo,
      owner: json['owner'] == true,
      isPurchased:
          json['isPurchased'] == true || json['is_purchased'] == true,
      likeCount: parseInt('likeCount', 'like_count'),
      commentCount: parseInt('commentCount', 'comment_count'),
      isLikedByUser: json['isLikedByUser'] == true || json['is_liked_by_user'] == true,
      commentsEnabled: json['comments_enabled'] as bool? ?? true,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      durationSeconds:
          ((json['durationSeconds'] ?? json['duration_seconds']) as num?)
              ?.toDouble(),
    );
  }
}

class EventDiscovery {
  final String id;
  final String eventName;
  final String photographerName;
  final String photographerId;

  /// The photographer's personal avatar — canonical field is `profile_url`
  /// on the nested user/photographer object (same field used everywhere
  /// else a creator's photo appears: listing, search, suggested). Null
  /// when the photographer has no avatar set.
  final String? photographerProfileUrl;

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
  /// Shown as hashtags beneath the event name in the caption area. Always
  /// present (at least `[]`) per `docs/FRONTEND_EVENT_DESCRIPTION_TAGS.md`.
  final List<String> contentTags;

  /// Backend-supplied caption text, max 2000 chars. Always present (at
  /// least `''`) per `docs/FRONTEND_EVENT_DESCRIPTION_TAGS.md` — shown as
  /// the caption body beneath the event name, above the content tags.
  final String description;

  /// The soundtrack the photographer scored this event with, in the order
  /// they chose — the feed plays it in that order.
  ///
  /// Whole track objects rather than ids, which is the backend's deliberate
  /// design (see the note on `Event.music`): the feed can start playing
  /// without resolving anything, and an event scored under one music provider
  /// keeps playing after a move to another.
  ///
  /// Empty for every event nobody scored, which is most of them — an empty
  /// soundtrack is the normal case, not a missing one.
  final List<MusicTrack> music;

  const EventDiscovery({
    required this.id,
    required this.eventName,
    required this.photographerName,
    required this.photographerId,
    this.photographerProfileUrl,
    required this.pictures,
    this.likes = 0,
    this.dislikes = 0,
    this.commentCount = 0,
    this.commentsEnabled = true,
    this.userReaction,
    this.isFollowed = false,
    this.contentTags = const [],
    this.description = '',
    this.music = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'eventName': eventName,
        'user': {
          'id': photographerId,
          'name': photographerName,
          'is_followed': isFollowed,
          if (photographerProfileUrl != null) 'profile_url': photographerProfileUrl,
        },
        'pictures': pictures.map((p) => p.toMap()).toList(),
        'likes': likes,
        'dislikes': dislikes,
        'comment_count': commentCount,
        'comments_enabled': commentsEnabled,
        'content_tags': contentTags,
        'description': description,
        'music': music.map((t) => t.toMap()).toList(),
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
    String? description,
    List<MusicTrack>? music,
  }) {
    return EventDiscovery(
      id: id,
      eventName: eventName,
      photographerName: photographerName,
      photographerId: photographerId,
      photographerProfileUrl: photographerProfileUrl,
      pictures: pictures,
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      commentCount: commentCount ?? this.commentCount,
      commentsEnabled: commentsEnabled ?? this.commentsEnabled,
      userReaction:
          clearReaction ? null : (userReaction ?? this.userReaction),
      isFollowed: isFollowed ?? this.isFollowed,
      contentTags: contentTags ?? this.contentTags,
      description: description ?? this.description,
      music: music ?? this.music,
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
      photographerProfileUrl: (user['profile_url'] as String?)?.isNotEmpty == true
          ? user['profile_url'] as String
          : null,
      pictures: pics,
      likes: (event['likes'] as num?)?.toInt() ?? 0,
      dislikes: (event['dislikes'] as num?)?.toInt() ?? 0,
      commentCount: (event['commentCount'] as num?)?.toInt() ??
          (event['comment_count'] as num?)?.toInt() ?? 0,
      commentsEnabled: event['comments_enabled'] as bool? ?? true,
      isFollowed: isFollowed,
      contentTags: contentTags,
      description: event['description']?.toString() ?? '',
      // Absent on any endpoint that has not been taught to send it, and on
      // every cached feed written before it existed — both parse to empty,
      // which is the same as an unscored event and needs no special case.
      music: MusicTrack.listFrom(event['music']),
    );
  }
}

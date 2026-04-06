enum MediaType { photo, video }

class EventPicture {
  final String id;
  final String url;
  final String imageId;
  final int price;
  final MediaType mediaType;

  /// True when this picture belongs to (features) the currently logged-in user.
  final bool owner;

  const EventPicture({
    required this.id,
    required this.url,
    required this.imageId,
    required this.price,
    this.mediaType = MediaType.photo,
    this.owner = false,
  });

  bool get isVideo => mediaType == MediaType.video;

  factory EventPicture.fromMap(Map<String, dynamic> json) {
    final typeRaw = json['mediaType']?.toString().toLowerCase() ?? 'photo';
    return EventPicture(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      imageId: json['imageId']?.toString() ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      mediaType: typeRaw == 'video' ? MediaType.video : MediaType.photo,
      owner: json['owner'] == true,
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

  /// The authenticated user's current reaction: 'like', 'dislike', or null.
  final String? userReaction;

  const EventDiscovery({
    required this.id,
    required this.eventName,
    required this.photographerName,
    required this.photographerId,
    required this.pictures,
    this.likes = 0,
    this.dislikes = 0,
    this.userReaction,
  });

  EventDiscovery copyWith({
    int? likes,
    int? dislikes,
    String? userReaction,
    bool clearReaction = false,
  }) {
    return EventDiscovery(
      id: id,
      eventName: eventName,
      photographerName: photographerName,
      photographerId: photographerId,
      pictures: pictures,
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      userReaction:
          clearReaction ? null : (userReaction ?? this.userReaction),
    );
  }

  factory EventDiscovery.fromMap(Map<String, dynamic> json) {
    // Support both wrapped { "event": {...} } and flat item shapes.
    final Map<String, dynamic> event =
        json['event'] is Map<String, dynamic>
            ? json['event'] as Map<String, dynamic>
            : json;
    final user = (event['user'] as Map<String, dynamic>?) ?? {};
    final pics = (event['pictures'] as List<dynamic>? ?? [])
        .map((p) => EventPicture.fromMap(p as Map<String, dynamic>))
        .toList();
    return EventDiscovery(
      id: event['id']?.toString() ?? '',
      eventName: event['eventName']?.toString() ?? '',
      photographerName: user['name']?.toString() ?? '',
      photographerId: user['id']?.toString() ?? '',
      pictures: pics,
      likes: (event['likes'] as num?)?.toInt() ?? 0,
      dislikes: (event['dislikes'] as num?)?.toInt() ?? 0,
    );
  }
}

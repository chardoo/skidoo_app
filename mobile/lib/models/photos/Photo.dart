/*
{
  id: "",
  eventName: "",
  imageId: "",
  url: "",
  price: "",
  eventDate: "",
  identification: "",
}
*/

import 'package:skidoo_app/core/utils/cloudinary_transform.dart';

class Photo {
  final String id;
  final String eventId;
  final String eventName;
  final String imageId;
  final String url;
  final String userId;
  final double price;
  final String eventDate;
  late String? identification;
  final bool isPublic;

  /// Denormalized counts from the server response (zero extra queries).
  final int likeCount;
  final int commentCount;

  /// Whether the currently logged-in user has liked this photo.
  final bool isLikedByUser;

  /// The owner's engagement switch for this picture. False silences comments
  /// *and* reactions on it — see CardInteractionBar.reactionsEnabled.
  ///
  /// Defaults true: a payload that omits the field predates the setting, and
  /// the server's own default is enabled.
  final bool commentsEnabled;

  /// 'image' or 'video' — matches the server's media_type field.
  final String mediaType;

  /// Server-side pixel dimensions. Null for legacy records.
  final int? width;
  final int? height;

  /// Duration in seconds (video only). Null for photos.
  final double? durationSeconds;

  /// Display name of the photographer who shot the event. Empty when the
  /// endpoint that produced this record doesn't embed the event's owner.
  final String photographerName;

  /// Photographer's avatar. See the `profile_url` contract — `profile_url`
  /// is canonical, the legacy `profile` array is only a fallback.
  final String photographerAvatarUrl;

  /// Where the event took place, e.g. "Accra". Empty when unknown.
  final String location;

  /// Whether the user has already bought this photo. Sent by
  /// `GET /client/my-photos`; false for endpoints that don't report it.
  final bool isPurchased;

  /// When the face-match that surfaced this photo was recorded. Null outside
  /// the recognition endpoints.
  final DateTime? identifiedAt;

  double? get aspectRatio => (width != null && height != null && height! > 0)
      ? width! / height!
      : null;

  /// True for a clip. `media_type` is the server's answer, but not every
  /// endpoint sends it — where it's missing the url still gives it away, and
  /// without this such a record loses its play badge and opens in the photo
  /// viewer instead of the player.
  bool get isVideo =>
      mediaType == 'video' || CloudinaryTransform.isVideoUrl(url);

  /// [eventDate] parsed for date filtering/sorting. Null when the server
  /// sent an empty or non-ISO value.
  DateTime? get eventDateTime => DateTime.tryParse(eventDate);

  /// Best available "when" for a found photo: when the event happened, or
  /// failing that when the match was made. Used by the Found tab's date
  /// filter, which must still work for events with no date on record.
  DateTime? get foundDate => eventDateTime ?? identifiedAt;

  Photo(this.id, this.eventName, this.imageId, this.url, this.userId,
      this.price, this.eventDate, this.identification, this.isPublic,
      {this.eventId = '',
      this.likeCount = 0,
      this.commentCount = 0,
      this.isLikedByUser = false,
      this.commentsEnabled = true,
      this.mediaType = 'image',
      this.width,
      this.height,
      this.durationSeconds,
      this.photographerName = '',
      this.photographerAvatarUrl = '',
      this.location = '',
      this.isPurchased = false,
      this.identifiedAt});

  /// Narrows [value] to a string map, or null when it's absent/another type.
  static Map<String, dynamic>? _map(dynamic value) =>
      value is Map<String, dynamic> ? value : null;

  /// First non-empty string found under [keys] across [sources], in order.
  static String _pick(List<Map<String, dynamic>> sources, List<String> keys) {
    for (final source in sources) {
      for (final key in keys) {
        final v = source[key];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
    }
    return '';
  }

  /// Photographer avatar, honouring the `profile_url`-over-`profile[]`
  /// contract used across the main API.
  static String _avatarOf(Map<String, dynamic> user) {
    final url = _pick([user], ['profile_url', 'profileUrl', 'avatar', 'image']);
    if (url.isNotEmpty) return url;
    final legacy = user['profile'];
    if (legacy is List && legacy.isNotEmpty) return legacy.first.toString();
    return '';
  }

  /// Deserializes one picture record from the client endpoints —
  /// `GET /client/my-photos` (face recognitions) and
  /// `POST /client/dashboard` (purchased photos).
  ///
  /// The two differ in shape: dashboard nests the picture under a `picture`
  /// key, my-photos returns the picture's fields at the top level with the
  /// `event` / photographer alongside. Both are handled by treating the item
  /// itself as the picture when there's no `picture` wrapper. Every lookup is
  /// defensive — a partial payload yields empty strings and zero counts
  /// rather than throwing.
  factory Photo.fromMap(Map<String, dynamic> json) {
    final picture = _map(json['picture']) ?? json;
    final event = _map(json['event']) ??
        _map(picture['event']) ??
        const <String, dynamic>{};
    // my-photos nests the photographer inside the event; older shapes put it
    // at the top level or under `user`.
    final user = _map(event['photographer']) ??
        _map(json['photographer']) ??
        _map(json['user']) ??
        _map(event['user']) ??
        const <String, dynamic>{};

    final mediaType = _pick([picture], ['media_type', 'mediaType']);
    final identified =
        _pick([json, picture], ['identifiedAt', 'identified_at']);

    return Photo(
      _pick([picture, json], ['id', 'pictureId']),
      _pick([event, picture, json], ['eventName', 'name']),
      _pick([picture, json], ['imageId']),
      _pick([picture, json], ['url']),
      // Never fall back to `event.id` here — that's the event, not its owner.
      _pick([event], ['userId']).isNotEmpty
          ? _pick([event], ['userId'])
          : _pick([user], ['id']),
      (picture['price'] as num?)?.toDouble() ?? 0.0,
      // `photoDate` is the photo's own shoot date and is what the server's
      // dateRange filter matches on — prefer it over the event's date.
      _pick([picture, json, event], ['photoDate', 'eventDate', 'createdAt']),
      picture['identification']?.toString(),
      (picture['public'] ?? json['public'] ?? false) as bool,
      // Same trap in reverse: `picture.id` is the photo, so only read a bare
      // `id` off the event object.
      eventId: _pick([event], ['id']).isNotEmpty
          ? _pick([event], ['id'])
          : _pick([picture, json], ['eventId']),
      likeCount: (picture['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (picture['commentCount'] as num?)?.toInt() ?? 0,
      isLikedByUser: (picture['isLikedByUser'] ?? false) as bool,
      commentsEnabled: (picture['comments_enabled'] ??
          picture['commentsEnabled'] ??
          true) as bool,
      mediaType: mediaType.isEmpty ? 'image' : mediaType,
      width: (picture['width'] as num?)?.toInt(),
      height: (picture['height'] as num?)?.toInt(),
      durationSeconds:
          ((picture['durationSeconds'] ?? picture['duration_seconds']) as num?)
              ?.toDouble(),
      photographerName:
          _pick([user, event], ['name', 'userName', 'photographerName']),
      photographerAvatarUrl: _avatarOf(user),
      location: _pick([event], ['location', 'city', 'venue']),
      isPurchased:
          (json['isPurchased'] ?? json['is_purchased'] ?? false) as bool,
      identifiedAt: identified.isEmpty ? null : DateTime.tryParse(identified),
    );
  }

  factory Photo.fromMap2(Map<String, dynamic> json) {
    final event = _map(json['event']) ?? const <String, dynamic>{};
    final user = _map(event['user']) ?? const <String, dynamic>{};
    return Photo(
      json["id"],
      json["event"]["eventName"],
      json["imageId"],
      json["url"],
      json['event']["userId"] ?? '',
      (json["price"] as num?)?.toDouble() ?? 0.0,
      json["event"]["eventDate"] ?? '',
      json["identification"],
      json['public'] ?? false,
      eventId: json["event"]["id"]?.toString() ?? '',
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      isLikedByUser: json['isLikedByUser'] as bool? ?? false,
      commentsEnabled:
          (json['comments_enabled'] ?? json['commentsEnabled'] ?? true) as bool,
      mediaType:
          (json['media_type'] ?? json['mediaType'] as String?) ?? 'image',
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      durationSeconds:
          ((json['durationSeconds'] ?? json['duration_seconds']) as num?)
              ?.toDouble(),
      photographerName:
          _pick([user, event], ['name', 'userName', 'photographerName']),
      photographerAvatarUrl: _avatarOf(user),
      location: _pick([event], ['location', 'city', 'venue']),
    );
  }
  Map<String, dynamic> toJson() => {
        "id": id,
        "eventName": eventName,
        "imageId": imageId,
        "url": url,
        "userId": userId,
        "price": price,
        "eventDate": eventDate,
        "identification": identification,
      };

  //serialization
  @override
  String toString() {
    return "{ id: $id, eventName: $eventName, imageId: $imageId, url: $url,userId: $userId"
        "price: $price, eventDate: $eventDate, identification: $identification}";
  }
}

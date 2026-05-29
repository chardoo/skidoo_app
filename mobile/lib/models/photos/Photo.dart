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

  /// 'image' or 'video' — matches the server's media_type field.
  final String mediaType;

  /// Server-side pixel dimensions. Null for legacy records.
  final int? width;
  final int? height;

  /// Duration in seconds (video only). Null for photos.
  final double? durationSeconds;

  double? get aspectRatio =>
      (width != null && height != null && height! > 0) ? width! / height! : null;

  bool get isVideo => mediaType == 'video';

  Photo(this.id, this.eventName, this.imageId, this.url, this.userId,
      this.price, this.eventDate, this.identification, this.isPublic,
      {this.eventId = '',
      this.likeCount = 0,
      this.commentCount = 0,
      this.isLikedByUser = false,
      this.mediaType = 'image',
      this.width,
      this.height,
      this.durationSeconds});

  //deserialization
  factory Photo.fromMap(Map<String, dynamic> json) {
    return Photo(
      json["picture"]["id"],
     '',
      json["picture"]["imageId"],
      json["picture"]["url"],
      "   ",
      0,
      json["picture"]["eventDate"],
      json["picture"]["identification"],
      false,

    );
  }

  factory Photo.fromMap2(Map<String, dynamic> json) {
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
      mediaType: (json['media_type'] ?? json['mediaType'] as String?) ?? 'image',
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble(),
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

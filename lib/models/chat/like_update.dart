/// Broadcast received when a user likes/unlikes a picture in a photo room.
class PictureLikeUpdate {
  final String pictureId;
  final int likes;
  final bool liked;
  final bool echo;

  const PictureLikeUpdate({
    required this.pictureId,
    required this.likes,
    required this.liked,
    this.echo = false,
  });

  factory PictureLikeUpdate.fromJson(Map<String, dynamic> json) =>
      PictureLikeUpdate(
        pictureId: json['picture_id']?.toString() ?? '',
        likes: (json['likes'] as num?)?.toInt() ?? 0,
        liked: json['liked'] == true,
        echo: json['echo'] == true,
      );
}

class LikeUpdate {
  final String eventId;
  final int likes;
  final int dislikes;
  final bool liked;
  final bool disliked;
  final String senderId;
  final bool echo;

  const LikeUpdate({
    required this.eventId,
    required this.likes,
    required this.dislikes,
    required this.liked,
    required this.disliked,
    required this.senderId,
    this.echo = false,
  });

  factory LikeUpdate.fromJson(Map<String, dynamic> json) {
    return LikeUpdate(
      eventId: (json['event_id'] as String?) ?? '',
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      dislikes: (json['dislikes'] as num?)?.toInt() ?? 0,
      liked: (json['liked'] as bool?) ?? false,
      disliked: (json['disliked'] as bool?) ?? false,
      senderId: (json['sender_id'] as String?) ?? '',
      echo: (json['echo'] as bool?) ?? false,
    );
  }
}

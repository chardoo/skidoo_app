class LikeUpdate {
  final String eventId;
  final int likes;
  final bool liked;
  final String senderId;
  final bool echo;

  const LikeUpdate({
    required this.eventId,
    required this.likes,
    required this.liked,
    required this.senderId,
    this.echo = false,
  });

  factory LikeUpdate.fromJson(Map<String, dynamic> json) {
    return LikeUpdate(
      eventId: json['event_id'] as String,
      likes: json['likes'] as int,
      liked: json['liked'] as bool,
      senderId: json['sender_id'] as String,
      echo: (json['echo'] as bool?) ?? false,
    );
  }
}

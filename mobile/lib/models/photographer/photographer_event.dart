class PhotographerEvent {
  final String id;
  final String eventName;
  final String eventDate;

  /// The event's cover image.
  final String url;

  /// [url]'s pixel dimensions, sent alongside it. Null for covers uploaded
  /// before the server recorded them.
  final int? coverWidth;
  final int? coverHeight;

  const PhotographerEvent({
    required this.id,
    required this.eventName,
    required this.eventDate,
    required this.url,
    this.coverWidth,
    this.coverHeight,
  });

  /// The cover's shape, so its tile can be laid out at the right size before
  /// the image arrives. Null when the dimensions are unknown.
  double? get coverAspectRatio =>
      (coverWidth != null && coverHeight != null && coverHeight! > 0)
          ? coverWidth! / coverHeight!
          : null;

  static int? _intOrNull(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  factory PhotographerEvent.fromJson(Map<String, dynamic> json) {
    return PhotographerEvent(
      id: json['id']?.toString() ?? '',
      eventName: json['eventName']?.toString() ?? '',
      eventDate: json['eventDate']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      coverWidth:
          _intOrNull(json['coverWidth'] ?? json['cover_width'] ?? json['width']),
      coverHeight: _intOrNull(
          json['coverHeight'] ?? json['cover_height'] ?? json['height']),
    );
  }
}

class PhotographerEventsResult {
  final List<PhotographerEvent> events;
  final bool hasNext;

  const PhotographerEventsResult({required this.events, required this.hasNext});
}

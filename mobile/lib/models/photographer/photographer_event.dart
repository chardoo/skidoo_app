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

  /// Whether a moderator took this album down, and the reason they gave.
  ///
  /// This list is the one place a blocked album still appears: it is the
  /// creator's own library, and the server sends them the row precisely so
  /// they can be told. Everyone else is not sent it at all, so this is false
  /// for them by construction rather than by a check here.
  ///
  /// A takedown nobody can see is a takedown that becomes a support ticket —
  /// the album is missing, nothing says why, and the only reading left is that
  /// the platform lost it.
  final bool isBlocked;
  final String? blockedReason;

  const PhotographerEvent({
    required this.id,
    required this.eventName,
    required this.eventDate,
    required this.url,
    this.coverWidth,
    this.coverHeight,
    this.isBlocked = false,
    this.blockedReason,
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
      isBlocked: json['isBlocked'] == true,
      blockedReason: json['blockedReason']?.toString(),
    );
  }
}

class PhotographerEventsResult {
  final List<PhotographerEvent> events;
  final bool hasNext;

  const PhotographerEventsResult({required this.events, required this.hasNext});
}

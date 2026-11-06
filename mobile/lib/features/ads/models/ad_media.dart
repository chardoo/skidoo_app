class AdMedia {
  const AdMedia({
    required this.id,
    required this.url,
    required this.mediaType,
    this.position = 0,
    this.width,
    this.height,
    this.durationSeconds,
    this.isDefault = false,
  });

  final String id;
  final String url;

  /// "image" | "video"
  final String mediaType;
  final int position;

  /// Server-side pixel dimensions. Null for legacy records.
  final int? width;
  final int? height;

  /// Duration in seconds (video only). Null for images.
  final double? durationSeconds;

  /// True when this is the platform's stand-in image rather than one the
  /// requester attached — a request may be posted without a photo, and the
  /// server fills the gap so every card has something to show.
  ///
  /// It is not a row in anybody's media list: `id` is empty and there is
  /// nothing to delete. Screens that edit photos must leave it out; screens
  /// that only display them can treat it like any other image.
  final bool isDefault;

  bool get isVideo => mediaType == 'video';

  double? get aspectRatio => (width != null && height != null && height! > 0)
      ? width! / height!
      : null;

  factory AdMedia.fromJson(Map<String, dynamic> j) => AdMedia(
        id: j['id'] as String? ?? '',
        url: j['url'] as String? ??
            j['media_url'] as String? ??
            j['asset_url'] as String? ??
            '',
        mediaType:
            j['media_type'] as String? ?? j['type'] as String? ?? 'image',
        position:
            (j['sort_order'] as num? ?? j['position'] as num?)?.toInt() ?? 0,
        width: (j['width'] as num?)?.toInt(),
        height: (j['height'] as num?)?.toInt(),
        isDefault: j['is_default'] as bool? ?? false,
        durationSeconds: (j['duration_seconds'] as num?)?.toDouble(),
      );
}

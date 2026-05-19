class AdMedia {
  const AdMedia({
    required this.id,
    required this.url,
    required this.mediaType,
    this.position = 0,
  });

  final String id;
  final String url;

  /// "image" | "video"
  final String mediaType;
  final int position;

  bool get isVideo => mediaType == 'video';

  factory AdMedia.fromJson(Map<String, dynamic> j) => AdMedia(
        id: j['id'] as String? ?? '',
        url: j['url'] as String? ?? j['media_url'] as String? ?? j['asset_url'] as String? ?? '',
        mediaType:
            j['media_type'] as String? ?? j['type'] as String? ?? 'image',
        position: (j['position'] as num?)?.toInt() ?? 0,
      );
}

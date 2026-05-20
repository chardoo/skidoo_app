class Ad {
  final String id;
  final String adsetId;
  final String headline;
  final String? body;
  final String? mediaUrl;
  final AdMediaType mediaType;
  final String ctaText;
  final String ctaUrl;
  final int impressions;
  final int clicks;
  final int conversions;
  final String status;
  final DateTime createdAt;
  final bool commentsEnabled;

  double get ctr => impressions > 0 ? clicks / impressions : 0.0;

  const Ad({
    required this.id,
    required this.adsetId,
    required this.headline,
    this.body,
    this.mediaUrl,
    required this.mediaType,
    required this.ctaText,
    required this.ctaUrl,
    required this.impressions,
    required this.clicks,
    required this.conversions,
    required this.status,
    required this.createdAt,
    this.commentsEnabled = true,
  });

  factory Ad.fromJson(Map<String, dynamic> j) => Ad(
        id: j['id'] as String,
        adsetId: j['adset_id'] as String? ?? '',
        headline: j['headline'] as String,
        body: j['body'] as String?,
        mediaUrl: j['media_url'] as String?,
        mediaType: AdMediaType.fromString(j['media_type'] as String? ?? ''),
        ctaText: j['cta_text'] as String? ?? 'Learn More',
        ctaUrl: j['cta_url'] as String? ?? '',
        impressions: j['impressions'] as int? ?? 0,
        clicks: j['clicks'] as int? ?? 0,
        conversions: j['conversions'] as int? ?? 0,
        status: j['status'] as String? ?? 'active',
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'] as String)
            : j['created_at'] != null
                ? DateTime.parse(j['created_at'] as String)
                : DateTime.now(),
        commentsEnabled: j['comments_enabled'] as bool? ?? true,
      );
}

enum AdMediaType {
  text,
  image,
  video;

  static AdMediaType fromString(String s) => switch (s) {
        'image' => image,
        'video' => video,
        _ => text,
      };

  String get value => name;
}

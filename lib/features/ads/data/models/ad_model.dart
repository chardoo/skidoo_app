class AdModel {
  const AdModel({
    required this.adId,
    required this.adsetId,
    required this.campaignId,
    required this.headline,
    required this.body,
    required this.ctaText,
    required this.ctaUrl,
    required this.advertiserId,
    required this.advertiserName,
    required this.placement,
    required this.impressionToken,
    this.mediaUrl,
    this.mediaType = 'text',
    this.advertiserPhoto,
    this.advertiserType,
  });

  final String adId;
  final String adsetId;
  final String campaignId;
  final String headline;
  final String body;
  final String ctaText;
  final String ctaUrl;
  /// "image" | "video" | "text"
  final String mediaType;
  final String? mediaUrl;
  final String advertiserId;
  final String advertiserName;
  final String? advertiserPhoto;
  /// "photographer" | "client"
  final String? advertiserType;
  final String placement;
  final String impressionToken;

  bool get isVideo => mediaType == 'video';

  factory AdModel.fromJson(Map<String, dynamic> json) => AdModel(
        adId: json['ad_id'] as String? ?? '',
        adsetId: json['adset_id'] as String? ?? '',
        campaignId: json['campaign_id'] as String? ?? '',
        headline: json['headline'] as String? ?? '',
        body: json['body'] as String? ?? '',
        ctaText: json['cta_text'] as String? ?? 'Learn More',
        ctaUrl: json['cta_url'] as String? ?? '',
        mediaUrl: json['media_url'] as String?,
        mediaType: json['media_type'] as String? ?? 'text',
        advertiserId: json['advertiser_id'] as String? ?? '',
        advertiserName: json['advertiser_name'] as String? ?? '',
        advertiserPhoto: json['advertiser_photo'] as String?,
        advertiserType: json['advertiser_type'] as String?,
        placement: json['placement'] as String? ?? '',
        impressionToken: json['impression_token'] as String? ?? '',
      );
}

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
    this.commentsEnabled = true,
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
  final bool commentsEnabled;
  final String placement;
  final String impressionToken;

  bool get isVideo => mediaType == 'video';

  factory AdModel.fromJson(Map<String, dynamic> json) => AdModel(
        // Server may return 'id' or 'ad_id'
        adId: json['ad_id'] as String? ?? json['id'] as String? ?? '',
        adsetId: json['adset_id'] as String? ?? json['ad_set_id'] as String? ?? '',
        campaignId: json['campaign_id'] as String? ?? '',
        headline: json['headline'] as String? ?? json['title'] as String? ?? '',
        body: json['body'] as String? ?? json['description'] as String? ?? '',
        ctaText: json['cta_text'] as String? ?? json['cta_label'] as String? ?? 'Learn More',
        ctaUrl: json['cta_url'] as String? ?? json['cta_link'] as String? ?? '',
        mediaUrl: json['media_url'] as String? ?? json['asset_url'] as String?,
        mediaType: json['media_type'] as String? ?? json['asset_type'] as String? ?? 'text',
        advertiserId: json['advertiser_id'] as String? ?? json['advertiser_user_id'] as String? ?? '',
        advertiserName: json['advertiser_name'] as String? ?? json['advertiser_username'] as String? ?? '',
        advertiserPhoto: json['advertiser_photo'] as String? ?? json['advertiser_avatar'] as String?,
        advertiserType: json['advertiser_type'] as String?,
        commentsEnabled: json['comments_enabled'] as bool? ?? true,
        placement: json['placement'] as String? ?? '',
        impressionToken: json['impression_token'] as String? ?? '',
      );
}

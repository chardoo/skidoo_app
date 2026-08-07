import 'package:jperg_app/features/ads/models/ad_media.dart';

class AdRequest {
  final String id;
  final String requesterId;
  final String requesterType;
  final String? requesterName;
  final String? requesterPhoto;
  final String title;
  final String? description;
  final String? eventType;
  final String? location;
  final double? budgetAmount;
  final String currency;
  final String visibleTo;
  final AdRequestStatus status;
  final String? assetUrl;
  final String? assetType;
  final String? promotedCampaignId;
  final bool commentsEnabled;
  final int commentCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AdMedia> media;

  const AdRequest({
    required this.id,
    required this.requesterId,
    required this.requesterType,
    this.requesterName,
    this.requesterPhoto,
    required this.title,
    this.description,
    this.eventType,
    this.location,
    this.budgetAmount,
    required this.currency,
    required this.visibleTo,
    required this.status,
    this.assetUrl,
    this.assetType,
    this.promotedCampaignId,
    this.commentsEnabled = true,
    this.commentCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.media = const [],
  });

  factory AdRequest.fromJson(Map<String, dynamic> j) {
    final rawMedia = (j['media'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AdMedia.fromJson)
        .toList();
    final legacyUrl = j['asset_url'] as String?;
    final legacyType = j['asset_type'] as String? ?? 'image';
    final media = rawMedia.isNotEmpty
        ? rawMedia
        : (legacyUrl != null && legacyUrl.isNotEmpty
            ? [AdMedia(id: '', url: legacyUrl, mediaType: legacyType)]
            : <AdMedia>[]);

    return AdRequest(
      id: j['id'] as String,
      requesterId: j['requester_id'] as String,
      requesterType: j['requester_type'] as String,
      requesterName: j['requester_name'] as String?,
      requesterPhoto: j['requester_photo'] as String?,
      title: j['title'] as String,
      description: j['description'] as String?,
      eventType: j['event_type'] as String?,
      location: j['location'] as String?,
      budgetAmount: (j['budget_amount'] as num?)?.toDouble(),
      currency: j['currency'] as String? ?? 'GHS',
      visibleTo: j['visible_to'] as String? ?? 'all',
      status: AdRequestStatus.fromString(j['status'] as String? ?? ''),
      assetUrl: j['asset_url'] as String?,
      assetType: j['asset_type'] as String?,
      promotedCampaignId: j['promoted_campaign_id'] as String?,
      commentsEnabled: j['comments_enabled'] as bool? ?? true,
      commentCount: (j['comment_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(j['createdAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
      media: media,
    );
  }
}

enum AdRequestStatus {
  pendingReview,
  open,
  filled,
  closed,
  rejected,
  promoted;

  static AdRequestStatus fromString(String s) => switch (s) {
        'open' => open,
        'filled' => filled,
        'closed' => closed,
        'rejected' => rejected,
        'promoted' => promoted,
        _ => pendingReview,
      };

  String get label => switch (this) {
        pendingReview => 'Pending Review',
        open => 'Open',
        filled => 'Filled',
        closed => 'Closed',
        rejected => 'Rejected',
        promoted => 'Promoted',
      };

  bool get isEditable => this == open;
  bool get canPromote => this == open;
  bool get canClose => this == open;
}

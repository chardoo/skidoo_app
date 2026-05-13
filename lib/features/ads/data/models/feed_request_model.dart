class FeedRequestModel {
  const FeedRequestModel({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.requesterType,
    required this.title,
    required this.description,
    required this.eventType,
    required this.location,
    required this.currency,
    required this.status,
    this.budgetAmount,
    this.requesterPhoto,
    this.visibleTo,
    this.promotedCampaignId,
    this.assetUrl,
    this.assetType,
    this.createdAt,
    this.commentsEnabled = true,
  });

  final String id;
  final String requesterId;
  final String requesterName;
  /// "client" | "photographer"
  final String requesterType;
  final String title;
  final String description;
  final String eventType;
  final String location;
  final double? budgetAmount;
  final String currency;
  final String? requesterPhoto;
  /// Who can see this request: "photographers" | "clients"
  final String? visibleTo;
  final String? promotedCampaignId;
  /// "pending_review" | "open" | "promoted" | "filled" | "closed" | "rejected"
  final String status;
  /// Cloudinary URL for the attached media asset
  final String? assetUrl;
  /// "image" | "video"
  final String? assetType;
  final DateTime? createdAt;
  final bool commentsEnabled;

  factory FeedRequestModel.fromJson(Map<String, dynamic> json) =>
      FeedRequestModel(
        id: json['id'] as String? ?? '',
        requesterId: json['requester_id'] as String? ?? '',
        requesterName: json['requester_name'] as String? ??
            json['requester_username'] as String? ??
            '',
        requesterType: json['requester_type'] as String? ?? 'client',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        eventType: json['event_type'] as String? ?? '',
        location: json['location'] as String? ?? '',
        budgetAmount: (json['budget_amount'] as num?)?.toDouble(),
        currency: json['currency'] as String? ?? 'USD',
        requesterPhoto: json['requester_photo'] as String?,
        visibleTo: json['visible_to'] as String?,
        promotedCampaignId: json['promoted_campaign_id'] as String?,
        status: json['status'] as String? ?? 'open',
        assetUrl: (json['asset_url'] ?? json['media_url']) as String?,
        assetType: (json['asset_type'] ?? json['media_type']) as String?,
        commentsEnabled: json['comments_enabled'] as bool? ?? true,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}

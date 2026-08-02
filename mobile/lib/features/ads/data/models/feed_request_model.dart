import 'package:skidoo_app/features/ads/models/ad_media.dart';

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
    this.commentCount = 0,
    this.media = const [],
    this.interestedCount = 0,
    this.interested = const [],
    this.viewerInterested = false,
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

  /// Cloudinary URL for the attached media asset (legacy)
  final String? assetUrl;

  /// "image" | "video" (legacy)
  final String? assetType;
  final DateTime? createdAt;
  final bool commentsEnabled;
  final int commentCount;
  final List<AdMedia> media;

  /// Photographers who answered this request — the card's "4 interested".
  final int interestedCount;

  /// The first few of them, for the stacked avatars. Never longer than the
  /// count; when there are more, the row shows a "+N" after these.
  final List<RequestInterest> interested;

  /// Whether the signed-in viewer is one of them, so the button on the board
  /// reads "Interested" rather than offering it again.
  final bool viewerInterested;

  factory FeedRequestModel.fromJson(Map<String, dynamic> json) {
    final rawMedia = (json['media'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AdMedia.fromJson)
        .toList();
    final legacyUrl = (json['asset_url'] ?? json['media_url']) as String?;
    final legacyType =
        (json['asset_type'] ?? json['media_type']) as String? ?? 'image';
    final media = rawMedia.isNotEmpty
        ? rawMedia
        : (legacyUrl != null && legacyUrl.isNotEmpty
            ? [AdMedia(id: '', url: legacyUrl, mediaType: legacyType)]
            : <AdMedia>[]);

    return FeedRequestModel(
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
      assetUrl: legacyUrl,
      assetType: legacyType,
      commentsEnabled: json['comments_enabled'] as bool? ?? true,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      media: media,
      interestedCount: (json['interested_count'] as num?)?.toInt() ?? 0,
      interested: (json['interested'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(RequestInterest.fromJson)
          .toList(),
      viewerInterested: json['viewer_interested'] as bool? ?? false,
    );
  }

  FeedRequestModel copyWith({
    String? status,
    int? interestedCount,
    bool? viewerInterested,
  }) {
    return FeedRequestModel(
      id: id,
      requesterId: requesterId,
      requesterName: requesterName,
      requesterType: requesterType,
      title: title,
      description: description,
      eventType: eventType,
      location: location,
      currency: currency,
      status: status ?? this.status,
      budgetAmount: budgetAmount,
      requesterPhoto: requesterPhoto,
      visibleTo: visibleTo,
      promotedCampaignId: promotedCampaignId,
      assetUrl: assetUrl,
      assetType: assetType,
      createdAt: createdAt,
      commentsEnabled: commentsEnabled,
      commentCount: commentCount,
      media: media,
      interestedCount: interestedCount ?? this.interestedCount,
      interested: interested,
      viewerInterested: viewerInterested ?? this.viewerInterested,
    );
  }
}

/// Someone who answered a request. `message` is only ever filled in on the
/// requester's own list — the card and the board carry the face and name.
class RequestInterest {
  const RequestInterest({
    required this.id,
    this.name,
    this.profileUrl,
    this.message,
    this.createdAt,
  });

  final String id;
  final String? name;
  final String? profileUrl;
  final String? message;
  final DateTime? createdAt;

  factory RequestInterest.fromJson(Map<String, dynamic> json) {
    return RequestInterest(
      id: json['id'] as String? ?? '',
      name: json['name'] as String?,
      profileUrl: json['profile_url'] as String?,
      message: json['message'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}

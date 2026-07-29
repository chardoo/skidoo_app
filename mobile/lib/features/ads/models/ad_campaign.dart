import 'package:flutter/foundation.dart';
import 'package:skidoo_app/features/ads/models/ad_media.dart';
import 'package:skidoo_app/features/ads/models/ad_set.dart';

class AdCampaign {
  final String id;
  final String advertiserId;
  final String advertiserType;
  final String? advertiserName;
  final String? advertiserPhoto;
  final String name;
  final CampaignObjective objective;
  final double budgetAmount;
  final double spent;
  final String currency;
  final CampaignStatus status;
  final String? rejectionReason;
  final String? sourceRequestId;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? paystackReference;
  final bool commentsEnabled;
  final int commentCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AdSet> adSets;
  final List<AdMedia> media;

  double get spentPercent =>
      budgetAmount > 0 ? (spent / budgetAmount).clamp(0.0, 1.0) : 0.0;

  double get remaining => (budgetAmount - spent).clamp(0.0, budgetAmount);

  const AdCampaign({
    required this.id,
    required this.advertiserId,
    required this.advertiserType,
    this.advertiserName,
    this.advertiserPhoto,
    required this.name,
    required this.objective,
    required this.budgetAmount,
    required this.spent,
    required this.currency,
    required this.status,
    this.rejectionReason,
    this.sourceRequestId,
    this.startAt,
    this.endAt,
    this.paystackReference,
    this.commentsEnabled = true,
    this.commentCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.adSets = const [],
    this.media = const [],
  });

  factory AdCampaign.fromJson(Map<String, dynamic> j) => AdCampaign(
        id: j['id'] as String,
        advertiserId: j['advertiser_id'] as String? ?? '',
        advertiserType: j['advertiser_type'] as String? ?? '',
        advertiserName: j['advertiser_name'] as String?,
        advertiserPhoto: j['advertiser_photo'] as String?,
        name: j['name'] as String,
        objective:
            CampaignObjective.fromString(j['objective'] as String? ?? ''),
        budgetAmount: (j['budget_amount'] as num).toDouble(),
        spent:
            (j['spent'] as num? ?? j['amount_spent'] as num? ?? 0).toDouble(),
        currency: j['currency'] as String? ?? 'GHS',
        status: CampaignStatus.fromString(j['status'] as String? ?? ''),
        rejectionReason: j['rejection_reason'] as String?,
        sourceRequestId: j['source_request_id'] as String?,
        startAt: j['start_at'] != null
            ? DateTime.parse(j['start_at'] as String)
            : null,
        endAt:
            j['end_at'] != null ? DateTime.parse(j['end_at'] as String) : null,
        paystackReference: j['paystack_reference'] as String?,
        commentsEnabled: j['comments_enabled'] as bool? ?? true,
        commentCount: (j['comment_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(
            j['createdAt'] as String? ?? j['created_at'] as String),
        updatedAt: DateTime.parse(
            j['updatedAt'] as String? ?? j['updated_at'] as String),
        adSets: (j['ad_sets'] as List<dynamic>? ?? [])
            .map((e) => AdSet.fromJson(e as Map<String, dynamic>))
            .toList(),
        media: () {
          // Try every key the server might use for campaign-level media.
          for (final key in const [
            'media',
            'images',
            'assets',
            'campaign_media'
          ]) {
            final raw = j[key];
            if (raw is List && raw.isNotEmpty) {
              return raw
                  .whereType<Map<String, dynamic>>()
                  .map(AdMedia.fromJson)
                  .toList();
            }
          }
          // Fall back to a single cover/thumbnail URL if present.
          final singleUrl = j['thumbnail_url'] as String? ??
              j['cover_url'] as String? ??
              j['cover_image'] as String? ??
              j['image_url'] as String?;
          if (singleUrl != null && singleUrl.isNotEmpty) {
            debugPrint(
                '[AdCampaign] using single cover URL for id=${j['id']}: $singleUrl');
            return [AdMedia(id: '', url: singleUrl, mediaType: 'image')];
          }
          return <AdMedia>[];
        }(),
      );
}

enum CampaignStatus {
  draft,
  pendingPayment,
  pendingReview,
  active,
  paused,
  completed,
  rejected;

  static CampaignStatus fromString(String s) => switch (s) {
        'draft' => draft,
        'pending_payment' => pendingPayment,
        'pending_review' => pendingReview,
        'active' => active,
        'paused' => paused,
        'completed' => completed,
        'rejected' => rejected,
        _ => draft,
      };

  String get label => switch (this) {
        draft => 'Draft',
        pendingPayment => 'Awaiting Payment',
        pendingReview => 'Under Review',
        active => 'Active',
        paused => 'Paused',
        completed => 'Completed',
        rejected => 'Rejected',
      };

  bool get isEditable => this != completed;
  bool get canPay => this == draft || this == pendingPayment;
  bool get canTopup => this == paused;
  bool get canPause => this == active;
  bool get canResume => this == paused;
  bool get canDelete => this == draft;
}

enum CampaignObjective {
  awareness,
  traffic,
  conversion;

  static CampaignObjective fromString(String s) => switch (s) {
        'traffic' => traffic,
        'conversion' || 'conversions' => conversion,
        _ => awareness,
      };

  String get value => switch (this) {
        awareness => 'awareness',
        traffic => 'traffic',
        conversion => 'conversion',
      };

  String get label => switch (this) {
        awareness => 'Brand Awareness',
        traffic => 'Drive Traffic',
        conversion => 'Conversions',
      };
}

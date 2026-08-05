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
  final CampaignFormat format;

  /// The total for the whole run, whichever way it was entered.
  final double budgetAmount;

  /// Which field the advertiser actually typed, so re-opening the wizard shows
  /// them that one rather than the derived other.
  final BudgetMode budgetMode;
  final double? dailyBudget;
  final int? durationDays;

  // The creative. On the campaign now, not two tables down on the ad.
  final String? headline;
  final String? body;
  final String? ctaText;
  final String? ctaUrl;

  final DateTime? submittedAt;

  /// When the 48-hour payment window closes.
  final DateTime? paymentDueAt;

  /// Seconds left on that window **by the server's clock**, so a device with a
  /// wrong time does not render a countdown that is hours out or already done.
  final int? paymentSecondsLeft;

  /// Summed across every ad set — a campaign runs in more than one placement,
  /// and one ad's numbers would under-report it.
  final int impressions;
  final int clicks;
  final int reach;
  final List<String> placements;

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
    this.format = CampaignFormat.image,
    required this.budgetAmount,
    this.budgetMode = BudgetMode.daily,
    this.dailyBudget,
    this.durationDays,
    this.headline,
    this.body,
    this.ctaText,
    this.ctaUrl,
    this.submittedAt,
    this.paymentDueAt,
    this.paymentSecondsLeft,
    this.impressions = 0,
    this.clicks = 0,
    this.reach = 0,
    this.placements = const [],
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
        format: CampaignFormat.fromString(j['format'] as String? ?? ''),
        budgetAmount: (j['budget_amount'] as num).toDouble(),
        budgetMode: BudgetMode.fromString(j['budget_mode'] as String? ?? ''),
        dailyBudget: (j['daily_budget'] as num?)?.toDouble(),
        durationDays: (j['duration_days'] as num?)?.toInt(),
        headline: j['headline'] as String?,
        body: j['body'] as String?,
        ctaText: j['cta_text'] as String?,
        ctaUrl: j['cta_url'] as String?,
        submittedAt: j['submitted_at'] != null
            ? DateTime.tryParse(j['submitted_at'] as String)
            : null,
        paymentDueAt: j['payment_due_at'] != null
            ? DateTime.tryParse(j['payment_due_at'] as String)
            : null,
        paymentSecondsLeft: (j['payment_seconds_left'] as num?)?.toInt(),
        impressions: (j['impressions'] as num?)?.toInt() ?? 0,
        clicks: (j['clicks'] as num?)?.toInt() ?? 0,
        reach: (j['reach'] as num?)?.toInt() ?? 0,
        placements: (j['placements'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList(),
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

  /// Approved, waiting on payment, with a 48-hour window running.
  approvedUnpaid,

  /// That window closed unpaid. Not rejected — nobody turned it down, and it
  /// can be submitted again.
  paymentExpired,
  active,
  paused,
  completed,
  rejected;

  static CampaignStatus fromString(String s) => switch (s) {
        'draft' => draft,
        'pending_payment' => pendingPayment,
        'pending_review' => pendingReview,
        'approved_unpaid' => approvedUnpaid,
        'payment_expired' => paymentExpired,
        'active' => active,
        'paused' => paused,
        'completed' => completed,
        'rejected' => rejected,
        _ => draft,
      };

  /// The pill on the list row and the details header.
  String get label => switch (this) {
        draft => 'Draft',
        pendingPayment => 'Unpaid',
        pendingReview => 'In Review',
        approvedUnpaid => 'Unpaid',
        paymentExpired => 'Expired',
        active => 'Active',
        paused => 'Paused',
        completed => 'Closed',
        rejected => 'Rejected',
      };

  bool get isEditable => this != completed;
  bool get canPay =>
      this == draft || this == pendingPayment || this == approvedUnpaid;
  bool get canTopup => this == paused;
  bool get canPause => this == active;
  bool get canResume => this == paused;
  bool get canDelete => this == draft;

  /// Whether the campaign can go into the review queue from here.
  bool get canSubmit =>
      this == draft || this == rejected || this == paymentExpired;

  /// "Cancel Campaign Submission" — only while it is actually queued.
  bool get canWithdraw => this == pendingReview;
}

/// Image is one picture, Carousel two or three, Video one clip.
enum CampaignFormat {
  image,
  carousel,
  video;

  static CampaignFormat fromString(String s) => switch (s) {
        'carousel' => carousel,
        'video' => video,
        _ => image,
      };

  String get value => name;

  String get label => switch (this) {
        image => 'Image',
        carousel => 'Carousel',
        video => 'Video',
      };

  /// How many files this format takes — the wizard gates Next on it, and the
  /// server refuses a submission that disagrees.
  (int, int) get mediaRange => switch (this) {
        image => (1, 1),
        carousel => (2, 3),
        video => (1, 1),
      };
}

enum BudgetMode {
  daily,
  total;

  static BudgetMode fromString(String s) => s == 'total' ? total : daily;

  String get value => name;
  String get label => switch (this) {
        daily => 'Daily budget',
        total => 'Total budget',
      };
}

enum CampaignObjective {
  awareness,
  traffic,
  leads,
  services;

  /// "conversion" is the old name for leads and is still on live rows, so it
  /// has to resolve rather than silently fall back to awareness.
  static CampaignObjective fromString(String s) => switch (s) {
        'traffic' => traffic,
        'leads' || 'conversion' || 'conversions' => leads,
        'services' => services,
        _ => awareness,
      };

  String get value => name;

  String get label => switch (this) {
        awareness => 'Brand Awareness',
        traffic => 'Drive Traffic',
        leads => 'Get Leads',
        services => 'Promote Services',
      };

  String get blurb => switch (this) {
        awareness => 'Get your brand seen by more people',
        traffic => 'Send people to your website or portfolio',
        leads => 'Collect inquiries from potential clients',
        services => 'Highlight your photography packages',
      };
}

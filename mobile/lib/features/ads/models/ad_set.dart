import 'package:jperg_app/features/ads/models/ad.dart';

class AdSet {
  final String id;
  final String campaignId;
  final String name;
  final AdPlacement placement;
  final AdSetTargeting targeting;
  final double dailyBudget;
  final BidType bidType;
  final double bidAmount;
  final String status;
  final List<Ad> ads;

  const AdSet({
    required this.id,
    required this.campaignId,
    required this.name,
    required this.placement,
    required this.targeting,
    required this.dailyBudget,
    this.bidType = BidType.cpm,
    this.bidAmount = 0,
    required this.status,
    this.ads = const [],
  });

  factory AdSet.fromJson(Map<String, dynamic> j) => AdSet(
        id: j['id'] as String,
        campaignId: j['campaign_id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        placement: AdPlacement.fromString(j['placement'] as String? ?? ''),
        targeting: AdSetTargeting.fromJson(
            j['targeting'] as Map<String, dynamic>? ?? {}),
        dailyBudget: (j['daily_budget'] as num?)?.toDouble() ?? 0,
        bidType: BidType.fromString(j['bid_type'] as String? ?? ''),
        bidAmount: (j['bid_amount'] as num?)?.toDouble() ?? 0,
        status: j['status'] as String? ?? 'active',
        ads: (j['ads'] as List<dynamic>? ?? [])
            .map((e) => Ad.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AdSetTargeting {
  final List<String> eventTypes;
  final List<String> locations;
  final String? audience;
  final double? radiusKm;

  const AdSetTargeting({
    this.eventTypes = const [],
    this.locations = const [],
    this.audience,
    this.radiusKm,
  });

  factory AdSetTargeting.fromJson(Map<String, dynamic> j) => AdSetTargeting(
        eventTypes: List<String>.from(j['event_types'] as List? ?? []),
        locations: List<String>.from(j['locations'] as List? ?? []),
        audience: j['audience'] as String?,
        radiusKm: (j['radius_km'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        if (eventTypes.isNotEmpty) 'event_types': eventTypes,
        if (locations.isNotEmpty) 'locations': locations,
        if (audience != null) 'audience': audience,
        if (radiusKm != null) 'radius_km': radiusKm,
      };
}

enum AdPlacement {
  eventFeed,
  searchResults,
  postRecognition,
  profilePage,
  requestBoard;

  static AdPlacement fromString(String s) => switch (s) {
        'search_results' => searchResults,
        'post_recognition' => postRecognition,
        'profile_page' => profilePage,
        'request_board' => requestBoard,
        _ => eventFeed,
      };

  String get value => switch (this) {
        eventFeed => 'event_feed',
        searchResults => 'search_results',
        postRecognition => 'post_recognition',
        profilePage => 'profile_page',
        requestBoard => 'request_board',
      };

  String get label => switch (this) {
        eventFeed => 'Event Feed',
        searchResults => 'Search Results',
        postRecognition => 'After Photo Recognition',
        profilePage => 'Profile Page',
        requestBoard => 'Request Board',
      };
}

enum BidType {
  cpm,
  cpc,
  cpa;

  static BidType fromString(String s) => switch (s) {
        'cpc' => cpc,
        'cpa' => cpa,
        _ => cpm,
      };

  String get value => name;

  String get label => switch (this) {
        cpm => 'CPM (per 1,000 impressions)',
        cpc => 'CPC (per click)',
        cpa => 'CPA (per conversion)',
      };
}

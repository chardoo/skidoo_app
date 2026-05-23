/// App-wide configuration controlled by the super admin.
class AppConfig {
  const AppConfig({
    this.adsEnabled = true,
    this.requestsEnabled = true,
    this.adsEveryNEvents = 10,
    this.requestsEveryNEvents = 20,
    this.commentsEnabled = true,
    this.minCampaignBudgetGhs = 30.0,
  });

  /// Whether ad slots appear in the home feed.
  final bool adsEnabled;

  /// Whether request slots appear in the home feed.
  final bool requestsEnabled;

  /// Insert an ad after every N events (e.g. 10 → ad at position 10, 20, …).
  final int adsEveryNEvents;

  /// Insert a request after every N events (e.g. 20 → request at position 20, 40, …).
  final int requestsEveryNEvents;

  /// Global kill switch — hides comment input on all cards when false.
  final bool commentsEnabled;

  /// Minimum total campaign budget in GHS.
  final double minCampaignBudgetGhs;

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return AppConfig(
      adsEnabled: data['ads_enabled'] as bool? ?? true,
      requestsEnabled: data['requests_enabled'] as bool? ?? true,
      adsEveryNEvents: (data['ads_every_n_events'] as num?)?.toInt() ?? 10,
      requestsEveryNEvents:
          (data['requests_every_n_events'] as num?)?.toInt() ?? 20,
      commentsEnabled: data['comments_enabled'] as bool? ?? true,
      minCampaignBudgetGhs:
          (data['min_campaign_budget_ghs'] as num?)?.toDouble() ?? 30.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'ads_enabled': adsEnabled,
        'requests_enabled': requestsEnabled,
        'ads_every_n_events': adsEveryNEvents,
        'requests_every_n_events': requestsEveryNEvents,
        'comments_enabled': commentsEnabled,
        'min_campaign_budget_ghs': minCampaignBudgetGhs,
      };

  AppConfig copyWith({
    bool? adsEnabled,
    bool? requestsEnabled,
    int? adsEveryNEvents,
    int? requestsEveryNEvents,
    bool? commentsEnabled,
    double? minCampaignBudgetGhs,
  }) {
    return AppConfig(
      adsEnabled: adsEnabled ?? this.adsEnabled,
      requestsEnabled: requestsEnabled ?? this.requestsEnabled,
      adsEveryNEvents: adsEveryNEvents ?? this.adsEveryNEvents,
      requestsEveryNEvents: requestsEveryNEvents ?? this.requestsEveryNEvents,
      commentsEnabled: commentsEnabled ?? this.commentsEnabled,
      minCampaignBudgetGhs: minCampaignBudgetGhs ?? this.minCampaignBudgetGhs,
    );
  }
}

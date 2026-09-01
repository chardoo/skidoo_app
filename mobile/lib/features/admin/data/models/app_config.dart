/// The tag vocabulary shipped with the build.
///
/// A first-launch and offline fallback only — /config is the source of truth,
/// because it is also what the web portal reads when a photographer tags an
/// album, and the two matching is the entire point. Keep in step with
/// `picco-v2/src/services/contentTags.ts` and the seed in main's
/// `f1a2b3c4d5e6_content_tag_vocabulary` migration.
const List<String> kContentTagFallback = [
  // Occasions — what an album usually is
  'Wedding', 'Birthday', 'Funeral', 'Graduation', 'Naming Ceremony',
  'Anniversary', 'Engagement', 'Baby Shower', 'Bridal Shower',
  'Festival', 'Concert', 'Party', 'Conference', 'Corporate', 'Church',
  'Sports', 'Fashion Show', 'Award Show', 'Culture', 'Traditional',
  // Genres — what somebody photographs, or wants to look at
  'Portrait', 'Landscape', 'Nature', 'Wildlife', 'Street', 'Travel',
  'Architecture', 'Food', 'Documentary', 'Lifestyle', 'Fashion',
  'Macro', 'Aerial', 'Night', 'Fine Art', 'Photojournalism', 'Abstract',
  'Animals', 'Aviation', 'Technology',
];

/// App-wide configuration controlled by the super admin.
class AppConfig {
  const AppConfig({
    this.adsEnabled = true,
    this.requestsEnabled = true,
    this.adsEveryNEvents = 10,
    this.requestsEveryNEvents = 20,
    this.feedSlideIntervalSeconds = 3,
    this.commentsEnabled = true,
    this.minCampaignBudgetGhs = 30.0,
    this.contentTags = kContentTagFallback,
  });

  /// Whether ad slots appear in the home feed.
  final bool adsEnabled;

  /// Whether request slots appear in the home feed.
  final bool requestsEnabled;

  /// Insert an ad after every N events (e.g. 10 → ad at position 10, 20, …).
  final int adsEveryNEvents;

  /// Insert a request after every N events (e.g. 20 → request at position 20, 40, …).
  final int requestsEveryNEvents;

  /// How long a feed card holds on one photo before sliding to the next by
  /// itself. The slide stops at the third photo, where "Explore event photos"
  /// takes over, so this paces an introduction to an album rather than running
  /// a slideshow.
  ///
  /// Zero switches it off and leaves every card swipe-only.
  final int feedSlideIntervalSeconds;

  /// Global kill switch — hides comment input on all cards when false.
  final bool commentsEnabled;

  /// Minimum total campaign budget in GHS.
  final double minCampaignBudgetGhs;

  /// The one tag vocabulary — the words this screen offers as interests, and
  /// the words a photographer picks from when tagging an album.
  ///
  /// They have to be the same words. They were not: interests came from a
  /// hardcoded list of photography genres here, while album tags were a
  /// free-text box in the web portal, so photographers typed what the event
  /// was — "Ga state", "Ghana weddings", "Homowo". Two vocabularies describing
  /// different things, and the content half of the feed matched almost nothing
  /// as a result.
  ///
  /// Served from /config so it cannot drift again. This app alone had shipped
  /// two lists that disagreed with each other, one saying "Portraits" and the
  /// other "Portrait".
  final List<String> contentTags;

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
      feedSlideIntervalSeconds:
          (data['feed_slide_interval_seconds'] as num?)?.toInt() ?? 3,
      commentsEnabled: data['comments_enabled'] as bool? ?? true,
      minCampaignBudgetGhs:
          (data['min_campaign_budget_ghs'] as num?)?.toDouble() ?? 30.0,
      contentTags: () {
        final raw = data['content_tags'];
        if (raw is List && raw.isNotEmpty) {
          return raw.map((t) => t.toString()).toList(growable: false);
        }
        return kContentTagFallback;
      }(),
    );
  }

  Map<String, dynamic> toJson() => {
        'ads_enabled': adsEnabled,
        'requests_enabled': requestsEnabled,
        'ads_every_n_events': adsEveryNEvents,
        'requests_every_n_events': requestsEveryNEvents,
        'feed_slide_interval_seconds': feedSlideIntervalSeconds,
        'comments_enabled': commentsEnabled,
        'min_campaign_budget_ghs': minCampaignBudgetGhs,
        'content_tags': contentTags,
      };

  AppConfig copyWith({
    bool? adsEnabled,
    bool? requestsEnabled,
    int? adsEveryNEvents,
    int? requestsEveryNEvents,
    int? feedSlideIntervalSeconds,
    bool? commentsEnabled,
    double? minCampaignBudgetGhs,
    List<String>? contentTags,
  }) {
    return AppConfig(
      adsEnabled: adsEnabled ?? this.adsEnabled,
      requestsEnabled: requestsEnabled ?? this.requestsEnabled,
      adsEveryNEvents: adsEveryNEvents ?? this.adsEveryNEvents,
      requestsEveryNEvents: requestsEveryNEvents ?? this.requestsEveryNEvents,
      feedSlideIntervalSeconds:
          feedSlideIntervalSeconds ?? this.feedSlideIntervalSeconds,
      commentsEnabled: commentsEnabled ?? this.commentsEnabled,
      minCampaignBudgetGhs: minCampaignBudgetGhs ?? this.minCampaignBudgetGhs,
      contentTags: contentTags ?? this.contentTags,
    );
  }
}

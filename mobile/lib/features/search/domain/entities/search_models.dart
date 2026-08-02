import 'package:equatable/equatable.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

/// The three result lists a query fans out into. The wire value is the `type`
/// query parameter of `GET /client/search/results`; `all` is not a member
/// because it is never a *selected* chip — it is the shape of the first
/// request, which fills all three sections at once.
enum SearchResultType {
  events,
  photographers,
  tags;

  /// `type=` value on the wire.
  String get wire => name;

  /// Chip label, matching the design.
  String get label => switch (this) {
        SearchResultType.events => 'Events',
        SearchResultType.photographers => 'Photographers',
        SearchResultType.tags => 'Tags',
      };
}

// ── Shared parsing helpers ────────────────────────────────────────────────────

/// Every field below is read defensively: a partial payload yields empty
/// strings and zero counts rather than throwing, the same contract the rest of
/// the app's models keep.
class SearchJson {
  const SearchJson._();

  static Map<String, dynamic>? map(dynamic v) =>
      v is Map<String, dynamic> ? v : null;

  static String str(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final v = json[key];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '';
  }

  static int intOf(dynamic v, [int fallback = 0]) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static int? intOrNull(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static bool boolOf(dynamic v, [bool fallback = false]) =>
      v is bool ? v : fallback;

  static List<String> strings(dynamic v) {
    if (v is! List) return const [];
    return v
        .map((e) => e?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  /// The creator's category line — "Events & Nature".
  ///
  /// `category` is the server-built line and wins outright: it is the first
  /// two specialties already joined, which is exactly what the row wants.
  /// The rest is for deploys that predate it, and the **array** comes before
  /// the singular `specialty`, because `specialty` is only ever the first one
  /// — reading it earlier would settle for "Events" while "Events & Nature"
  /// sat in the same payload.
  ///
  /// Two is the cap, matching the server: a third pushes the follower count
  /// off the row. Empty string, never null, since every caller here renders a
  /// possibly-absent line by checking `isNotEmpty`.
  static String category(Map<String, dynamic> json) {
    final built = str(json, ['category']);
    if (built.isNotEmpty) return built;

    final list = strings(json['specialties']);
    if (list.isNotEmpty) return list.take(2).join(' & ');

    return str(json, ['specialty']);
  }

  /// The photographer avatar contract used across the main API: `profile_url`
  /// is canonical, the legacy `profile` array is only a fallback for accounts
  /// created before the field existed.
  static String avatar(Map<String, dynamic> json) {
    final url = str(json, ['profile_url', 'profileUrl', 'avatar', 'image']);
    if (url.isNotEmpty) return url;
    final legacy = json['profile'];
    if (legacy is List && legacy.isNotEmpty) return legacy.first.toString();
    return '';
  }
}

// ── Pagination ────────────────────────────────────────────────────────────────

/// The `pagination` block the paged search endpoints carry.
class SearchPagination extends Equatable {
  const SearchPagination({
    this.page = 1,
    this.limit = 25,
    this.total = 0,
    this.totalPages = 0,
    this.hasNext = false,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNext;

  factory SearchPagination.fromJson(Map<String, dynamic> json) {
    final page = SearchJson.intOf(json['page'], 1);
    final totalPages = SearchJson.intOf(json['totalPages']);
    return SearchPagination(
      page: page,
      limit: SearchJson.intOf(json['limit'], 25),
      total: SearchJson.intOf(json['total']),
      totalPages: totalPages,
      // Older/partial envelopes: derive it rather than stalling paging.
      hasNext: json['hasNext'] as bool? ?? page < totalPages,
    );
  }

  @override
  List<Object?> get props => [page, limit, total, totalPages, hasNext];
}

/// One page of a single section — rows plus the pagination that produced them.
class SearchSectionPage<T> extends Equatable {
  const SearchSectionPage({required this.items, required this.pagination});

  final List<T> items;
  final SearchPagination pagination;

  @override
  List<Object?> get props => [items, pagination];
}

// ── Photographer ──────────────────────────────────────────────────────────────

/// The photographer block embedded in an event row. A subset of
/// [SearchPhotographerRow] — the server sends only what a subtitle needs.
class SearchPhotographerBrief extends Equatable {
  const SearchPhotographerBrief({
    required this.id,
    required this.name,
    required this.profileUrl,
    required this.specialty,
    required this.followerCount,
    required this.isVerified,
  });

  final String id;
  final String name;
  final String profileUrl;
  final String specialty;
  final int followerCount;
  final bool isVerified;

  factory SearchPhotographerBrief.fromJson(Map<String, dynamic> json) {
    return SearchPhotographerBrief(
      id: SearchJson.str(json, ['id']),
      name: SearchJson.str(json, ['name', 'userName', 'username']),
      profileUrl: SearchJson.avatar(json),
      specialty: SearchJson.category(json),
      followerCount: SearchJson.intOf(json['followerCount']),
      isVerified: SearchJson.boolOf(
          json['verified_by_admin'] ?? json['verifiedByAdmin']),
    );
  }

  bool get isEmpty => id.isEmpty && name.isEmpty;

  @override
  List<Object?> get props =>
      [id, name, profileUrl, specialty, followerCount, isVerified];
}

/// A row in the Photographers section.
class SearchPhotographerRow extends Equatable {
  const SearchPhotographerRow({
    required this.id,
    required this.name,
    required this.username,
    required this.profileUrl,
    required this.bio,
    required this.specialty,
    required this.specialties,
    required this.studioName,
    required this.studioImageUrl,
    required this.isVerified,
    required this.followerCount,
    required this.eventCount,
    required this.isFollowedByMe,
  });

  final String id;
  final String name;
  final String username;
  final String profileUrl;
  final String bio;

  /// The category line — the first half of the design's subtitle, and the
  /// server's `category` where it sends one. See [SearchJson.category]: it is
  /// up to two specialties joined, not just the first.
  final String specialty;

  /// The full list, uncapped — for anywhere that wants more than the line.
  final List<String> specialties;
  final String studioName;
  final String studioImageUrl;
  final bool isVerified;
  final int followerCount;
  final int eventCount;

  /// Always false for a signed-out viewer.
  final bool isFollowedByMe;

  factory SearchPhotographerRow.fromJson(Map<String, dynamic> json) {
    final specialties = SearchJson.strings(json['specialties']);
    return SearchPhotographerRow(
      id: SearchJson.str(json, ['id']),
      name: SearchJson.str(json, ['name', 'userName']),
      username: SearchJson.str(json, ['username']),
      profileUrl: SearchJson.avatar(json),
      bio: SearchJson.str(json, ['bio']),
      specialty: SearchJson.category(json),
      specialties: specialties,
      studioName: SearchJson.str(json, ['studio_name', 'studioName']),
      studioImageUrl:
          SearchJson.str(json, ['studio_image_url', 'studioImageUrl']),
      isVerified: SearchJson.boolOf(
          json['verified_by_admin'] ?? json['verifiedByAdmin']),
      followerCount: SearchJson.intOf(json['followerCount']),
      eventCount: SearchJson.intOf(json['eventCount']),
      isFollowedByMe: SearchJson.boolOf(json['isFollowedByMe']),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        username,
        profileUrl,
        bio,
        specialty,
        specialties,
        studioName,
        studioImageUrl,
        isVerified,
        followerCount,
        eventCount,
        isFollowedByMe,
      ];
}

// ── Event ─────────────────────────────────────────────────────────────────────

/// A row in the Events section, and the header of the event-photos screen.
class SearchEventRow extends Equatable {
  const SearchEventRow({
    required this.id,
    required this.eventName,
    required this.description,
    required this.coverUrl,
    required this.eventDate,
    required this.accessCode,
    required this.contentTags,
    required this.photoCount,
    required this.commentsEnabled,
    required this.photographer,
    required this.isOwner,
    this.coverWidth,
    this.coverHeight,
  });

  final String id;
  final String eventName;
  final String description;

  /// Thumbnail for the row and the cover of the event-photos screen.
  final String coverUrl;

  /// Pixel dimensions of [coverUrl], sent alongside it. Null for events whose
  /// cover predates the server recording them.
  final int? coverWidth;
  final int? coverHeight;

  /// [coverUrl]'s shape, for reserving its slot before it loads. Null when the
  /// dimensions are unknown.
  double? get coverAspectRatio =>
      (coverWidth != null && coverHeight != null && coverHeight! > 0)
          ? coverWidth! / coverHeight!
          : null;

  final String eventDate;

  /// Typing or scanning this puts the event first in the results.
  final String accessCode;
  final List<String> contentTags;

  /// Public photos only — the design's "108 photos" subtitle.
  final int photoCount;
  final bool commentsEnabled;
  final SearchPhotographerBrief? photographer;

  /// True when the signed-in viewer owns the event (sees every photo).
  final bool isOwner;

  factory SearchEventRow.fromJson(Map<String, dynamic> json) {
    final photographer = SearchJson.map(json['photographer']);
    return SearchEventRow(
      id: SearchJson.str(json, ['id']),
      eventName: SearchJson.str(json, ['eventName', 'name']),
      description: SearchJson.str(json, ['description']),
      coverUrl: SearchJson.str(json, ['coverUrl', 'cover_url', 'url']),
      coverWidth: SearchJson.intOrNull(
          json['coverWidth'] ?? json['cover_width'] ?? json['width']),
      coverHeight: SearchJson.intOrNull(
          json['coverHeight'] ?? json['cover_height'] ?? json['height']),
      eventDate: SearchJson.str(json, ['eventDate', 'event_date']),
      accessCode: SearchJson.str(json, ['accessCode', 'access_code']),
      contentTags:
          SearchJson.strings(json['content_tags'] ?? json['contentTags']),
      photoCount: SearchJson.intOf(json['photoCount']),
      commentsEnabled: SearchJson.boolOf(
          json['comments_enabled'] ?? json['commentsEnabled'], true),
      photographer: photographer == null
          ? null
          : SearchPhotographerBrief.fromJson(photographer),
      isOwner: SearchJson.boolOf(json['owner']),
    );
  }

  static const empty = SearchEventRow(
    id: '',
    eventName: '',
    description: '',
    coverUrl: '',
    eventDate: '',
    accessCode: '',
    contentTags: [],
    photoCount: 0,
    commentsEnabled: true,
    photographer: null,
    isOwner: false,
  );

  @override
  List<Object?> get props => [
        id,
        eventName,
        description,
        coverUrl,
        eventDate,
        accessCode,
        contentTags,
        photoCount,
        commentsEnabled,
        photographer,
        isOwner,
        coverWidth,
        coverHeight,
      ];
}

// ── Tag ───────────────────────────────────────────────────────────────────────

/// A row in the Tags section. [tag] is the drill-down key, [label] is what the
/// row shows — `#RELOADED`, `#reloaded` and `reloaded` collapse into one row
/// server-side, so the label is authoritative.
class SearchTagRow extends Equatable {
  const SearchTagRow({
    required this.tag,
    required this.label,
    required this.postCount,
    required this.eventCount,
  });

  final String tag;
  final String label;

  /// Public photos across every event carrying the tag. Formatted client-side.
  final int postCount;
  final int eventCount;

  factory SearchTagRow.fromJson(Map<String, dynamic> json) {
    final tag = SearchJson.str(json, ['tag']);
    final label = SearchJson.str(json, ['label']);
    return SearchTagRow(
      // The key is always bare — it goes into the drill-down URL, which the
      // server takes with or without the `#`, and into row keys.
      tag: tag.startsWith('#') ? tag.substring(1) : tag,
      label: _hashed(label.isNotEmpty ? label : tag),
      postCount: SearchJson.intOf(json['postCount']),
      eventCount: SearchJson.intOf(json['eventCount']),
    );
  }

  /// A tag always reads with its `#`. Normalised rather than trusted because
  /// the row is drawn next to a `#` mark — a label that arrived bare would put
  /// "reloaded" beside a hash and read as a different thing to the row above
  /// it. Idempotent, so an already-hashed label is left alone.
  static String _hashed(String value) {
    if (value.isEmpty) return '';
    return value.startsWith('#') ? value : '#$value';
  }

  @override
  List<Object?> get props => [tag, label, postCount, eventCount];
}

// ── Responses ─────────────────────────────────────────────────────────────────

/// The `counts` block — one number per chip.
class SearchCounts extends Equatable {
  const SearchCounts({this.events = 0, this.photographers = 0, this.tags = 0});

  final int events;
  final int photographers;
  final int tags;

  factory SearchCounts.fromJson(Map<String, dynamic> json) => SearchCounts(
        events: SearchJson.intOf(json['events']),
        photographers: SearchJson.intOf(json['photographers']),
        tags: SearchJson.intOf(json['tags']),
      );

  int of(SearchResultType type) => switch (type) {
        SearchResultType.events => events,
        SearchResultType.photographers => photographers,
        SearchResultType.tags => tags,
      };

  static const zero = SearchCounts();

  @override
  List<Object?> get props => [events, photographers, tags];
}

/// `type=all` — every section at once, each capped at a screenful.
class SearchAllResults extends Equatable {
  const SearchAllResults({
    required this.query,
    required this.counts,
    required this.total,
    required this.events,
    required this.photographers,
    required this.tags,
  });

  final String query;
  final SearchCounts counts;

  /// Zero is the `No results for '…'` state — the chips hide with it.
  final int total;
  final List<SearchEventRow> events;
  final List<SearchPhotographerRow> photographers;
  final List<SearchTagRow> tags;

  factory SearchAllResults.fromJson(Map<String, dynamic> json) {
    final counts = SearchJson.map(json['counts']);
    final events = _rows(json['events'], SearchEventRow.fromJson);
    final photographers =
        _rows(json['photographers'], SearchPhotographerRow.fromJson);
    final tags = _rows(json['tags'], SearchTagRow.fromJson);
    return SearchAllResults(
      query: SearchJson.str(json, ['query']),
      counts: counts == null ? SearchCounts.zero : SearchCounts.fromJson(counts),
      // Falls back to the rows actually delivered, so a missing `total` shows
      // results rather than the empty state.
      total: SearchJson.intOrNull(json['total']) ??
          (events.length + photographers.length + tags.length),
      events: events,
      photographers: photographers,
      tags: tags,
    );
  }

  /// The chip that opens first: the leftmost section that has anything in it.
  SearchResultType? get firstNonEmptyType {
    for (final type in SearchResultType.values) {
      if (counts.of(type) > 0 || _rowsOf(type).isNotEmpty) return type;
    }
    return null;
  }

  List<Object> _rowsOf(SearchResultType type) => switch (type) {
        SearchResultType.events => events,
        SearchResultType.photographers => photographers,
        SearchResultType.tags => tags,
      };

  static List<T> _rows<T>(dynamic raw, T Function(Map<String, dynamic>) parse) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(parse)
        .toList(growable: false);
  }

  static const empty = SearchAllResults(
    query: '',
    counts: SearchCounts.zero,
    total: 0,
    events: [],
    photographers: [],
    tags: [],
  );

  @override
  List<Object?> get props =>
      [query, counts, total, events, photographers, tags];
}

/// `GET /client/search/tags/{tag}` — the events behind one tag row.
class TagEventsPage extends Equatable {
  const TagEventsPage({
    required this.tag,
    required this.label,
    required this.postCount,
    required this.eventCount,
    required this.events,
    required this.pagination,
  });

  final String tag;
  final String label;
  final int postCount;
  final int eventCount;
  final List<SearchEventRow> events;
  final SearchPagination pagination;

  @override
  List<Object?> get props =>
      [tag, label, postCount, eventCount, events, pagination];
}

/// `GET /client/search/you-may-like` — one slice of the shuffled snapshot.
class YouMayLikePage extends Equatable {
  const YouMayLikePage({required this.photos, required this.nextCursor});

  final List<Photo> photos;

  /// Null at the end of the set — not an error, just the end. Refreshing
  /// builds a new snapshot and starts over.
  final int? nextCursor;

  @override
  List<Object?> get props => [photos, nextCursor];
}

/// `GET /client/events/{eventId}/photos` — the grid behind an event row.
class EventPhotosPage extends Equatable {
  const EventPhotosPage({
    required this.event,
    required this.photos,
    required this.pagination,
  });

  final SearchEventRow event;
  final List<Photo> photos;
  final SearchPagination pagination;

  @override
  List<Object?> get props => [event, photos, pagination];
}

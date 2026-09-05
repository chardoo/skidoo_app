part of 'search_bloc.dart';

enum SearchStatus {
  /// No query typed — the screen shows recents + "You may like".
  idle,

  /// A query is in flight (including its debounce window).
  loading,
  success,
  failure,
}

/// One chip's worth of results: the rows on screen and where paging is up to.
///
/// [page] is 0 while the list holds only the preview `type=all` returned. The
/// first real page therefore *replaces* those rows rather than appending to
/// them — page 1 of the paged endpoint is a superset of the preview, so
/// appending would show every row twice.
class SearchSection<T> extends Equatable {
  const SearchSection({
    this.items = const [],
    this.count = 0,
    this.page = 0,
    this.hasNext = false,
    this.isLoadingMore = false,
  });

  final List<T> items;

  /// `counts.<type>` — the section's true size, which can exceed [items].
  final int count;
  final int page;
  final bool hasNext;
  final bool isLoadingMore;

  /// True while the preview is all we have and the server says there is more.
  bool get needsFirstPage => page == 0 && count > items.length;

  bool get canLoadMore => !isLoadingMore && (hasNext || needsFirstPage);

  SearchSection<T> copyWith({
    List<T>? items,
    int? count,
    int? page,
    bool? hasNext,
    bool? isLoadingMore,
  }) {
    return SearchSection<T>(
      items: items ?? this.items,
      count: count ?? this.count,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [items, count, page, hasNext, isLoadingMore];
}

class SearchState extends Equatable {
  const SearchState({
    this.query = '',
    this.status = SearchStatus.idle,
    this.activeType = SearchResultType.events,
    this.events = const SearchSection<SearchEventRow>(),
    this.photographers = const SearchSection<SearchPhotographerRow>(),
    this.tags = const SearchSection<SearchTagRow>(),
    this.total = 0,
    this.errorMessage,
    this.recents = const [],
    this.youMayLike = const [],
    this.youMayLikeCursor,
    this.isLoadingYouMayLike = false,
    this.isLoadingMoreYouMayLike = false,
    this.youMayLikeError,
  });

  /// What the user has typed, trimmed. Empty means the idle screen.
  final String query;
  final SearchStatus status;

  /// The chip that owns the list. Only meaningful when [hasResults].
  final SearchResultType activeType;

  final SearchSection<SearchEventRow> events;
  final SearchSection<SearchPhotographerRow> photographers;
  final SearchSection<SearchTagRow> tags;

  /// `counts.events + photographers + tags`. Zero is the `No results` state.
  final int total;
  final String? errorMessage;

  // ── Idle screen ────────────────────────────────────────────────────────────

  final List<String> recents;

  /// Suggested *events*, not photographs — see [YouMayLikePage.events].
  final List<SearchEventRow> youMayLike;

  /// Null once the snapshot is exhausted — that is the end, not an error.
  final int? youMayLikeCursor;
  final bool isLoadingYouMayLike;
  final bool isLoadingMoreYouMayLike;
  final String? youMayLikeError;

  // ── Derived ────────────────────────────────────────────────────────────────

  bool get isIdle => query.isEmpty;
  bool get hasResults => total > 0;

  /// True for the `No results for '…'` state — chips hide with it.
  bool get isEmptyResult =>
      status == SearchStatus.success && query.isNotEmpty && total == 0;

  bool get canLoadMoreYouMayLike =>
      youMayLikeCursor != null &&
      !isLoadingYouMayLike &&
      !isLoadingMoreYouMayLike;

  /// The chips to render, in fixed order, skipping sections the query matched
  /// nothing in — a chip that opens an empty list is a dead end.
  List<SearchResultType> get visibleTypes => SearchResultType.values
      .where((type) => sectionCount(type) > 0)
      .toList(growable: false);

  int sectionCount(SearchResultType type) => switch (type) {
        SearchResultType.events => events.count,
        SearchResultType.photographers => photographers.count,
        SearchResultType.tags => tags.count,
      };

  SearchSection<Object> section(SearchResultType type) => switch (type) {
        SearchResultType.events => events,
        SearchResultType.photographers => photographers,
        SearchResultType.tags => tags,
      };

  SearchSection<Object> get activeSection => section(activeType);

  SearchState copyWith({
    String? query,
    SearchStatus? status,
    SearchResultType? activeType,
    SearchSection<SearchEventRow>? events,
    SearchSection<SearchPhotographerRow>? photographers,
    SearchSection<SearchTagRow>? tags,
    int? total,
    String? errorMessage,
    bool clearError = false,
    List<String>? recents,
    List<SearchEventRow>? youMayLike,
    int? youMayLikeCursor,
    bool clearYouMayLikeCursor = false,
    bool? isLoadingYouMayLike,
    bool? isLoadingMoreYouMayLike,
    String? youMayLikeError,
    bool clearYouMayLikeError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      status: status ?? this.status,
      activeType: activeType ?? this.activeType,
      events: events ?? this.events,
      photographers: photographers ?? this.photographers,
      tags: tags ?? this.tags,
      total: total ?? this.total,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      recents: recents ?? this.recents,
      youMayLike: youMayLike ?? this.youMayLike,
      youMayLikeCursor: clearYouMayLikeCursor
          ? null
          : (youMayLikeCursor ?? this.youMayLikeCursor),
      isLoadingYouMayLike: isLoadingYouMayLike ?? this.isLoadingYouMayLike,
      isLoadingMoreYouMayLike:
          isLoadingMoreYouMayLike ?? this.isLoadingMoreYouMayLike,
      youMayLikeError: clearYouMayLikeError
          ? null
          : (youMayLikeError ?? this.youMayLikeError),
    );
  }

  /// Back to the idle screen, keeping everything the idle screen renders.
  SearchState cleared() => SearchState(
        recents: recents,
        youMayLike: youMayLike,
        youMayLikeCursor: youMayLikeCursor,
      );

  @override
  List<Object?> get props => [
        query,
        status,
        activeType,
        events,
        photographers,
        tags,
        total,
        errorMessage,
        recents,
        youMayLike,
        youMayLikeCursor,
        isLoadingYouMayLike,
        isLoadingMoreYouMayLike,
        youMayLikeError,
      ];
}

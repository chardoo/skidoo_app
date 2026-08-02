import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/search/data/services/recent_searches_store.dart';
import 'package:skidoo_app/features/search/domain/entities/search_models.dart';
import 'package:skidoo_app/features/search/domain/usecases/search_usecase.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

part 'search_event.dart';
part 'search_state.dart';

/// Drives the whole Search screen: the query, the three chips and their
/// paging, the recent searches, and the "You may like" grid behind them.
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc({
    required SearchUseCase searchUseCase,
    RecentSearchesStore recents = const RecentSearchesStore(),
  })  : _search = searchUseCase,
        _recents = recents,
        super(const SearchState()) {
    // restartable: a keystroke cancels the previous (debounced) request before
    // it reaches the network, so only the query the user paused on is fetched
    // and results can't arrive out of order.
    on<SearchRequested>(_onRequested, transformer: restartable());
    // droppable, and a separate event — see [SearchSectionMoreRequested].
    on<SearchSectionMoreRequested>(_onSectionMore, transformer: droppable());
    on<SearchCleared>(_onCleared);

    // Independent of the query — the idle screen. Writes disjoint state
    // fields, so it is free to run alongside a search.
    on<SearchYouMayLikeRequested>(_onYouMayLike, transformer: restartable());
    on<SearchYouMayLikeMoreRequested>(_onYouMayLikeMore,
        transformer: droppable());

    on<SearchRecentsRequested>(_onRecentsRequested, transformer: sequential());
    on<SearchRecentSaved>(_onRecentSaved, transformer: sequential());
    on<SearchRecentRemoved>(_onRecentRemoved, transformer: sequential());
  }

  final SearchUseCase _search;
  final RecentSearchesStore _recents;

  /// Long enough that a typist doesn't fire a request per letter, short enough
  /// that pausing feels like the results were already there.
  static const _debounce = Duration(milliseconds: 320);

  static const _sectionLimit = 25;
  static const _youMayLikeLimit = 30;

  // ── Results ────────────────────────────────────────────────────────────────

  Future<void> _onRequested(
      SearchRequested event, Emitter<SearchState> emit) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      emit(state.cleared());
      return;
    }

    if (event.type != null) {
      // Chip tap. The rows are already on screen from the `type=all` response;
      // switch first so the list changes under the user's finger, then top it
      // up if the preview was short of the section's real count.
      emit(state.copyWith(activeType: event.type, clearError: true));
      if (state.section(event.type!).needsFirstPage) {
        await _loadSection(event.type!, query, emit);
      }
      return;
    }

    // New query.
    final isNewQuery = query != state.query;
    emit(state.copyWith(
      query: query,
      status: SearchStatus.loading,
      clearError: true,
      // Stale rows under a fresh spinner read as results for the new query.
      events: isNewQuery ? const SearchSection<SearchEventRow>() : null,
      photographers:
          isNewQuery ? const SearchSection<SearchPhotographerRow>() : null,
      tags: isNewQuery ? const SearchSection<SearchTagRow>() : null,
      total: isNewQuery ? 0 : null,
    ));

    // Because this handler is restartable, a keystroke arriving inside this
    // window cancels it here — before the network call — so only the query the
    // user paused on is ever fetched.
    await Future<void>.delayed(_debounce);
    if (emit.isDone) return;

    try {
      final results = await _search.all(query);
      if (emit.isDone) return;
      emit(state.copyWith(
        status: SearchStatus.success,
        total: results.total,
        // Fall back to the current chip when nothing matched, so the chip row
        // has a defined selection the moment results reappear.
        activeType: results.firstNonEmptyType ?? state.activeType,
        events: SearchSection<SearchEventRow>(
          items: results.events,
          count: _atLeast(results.counts.events, results.events.length),
        ),
        photographers: SearchSection<SearchPhotographerRow>(
          items: results.photographers,
          count: _atLeast(
              results.counts.photographers, results.photographers.length),
        ),
        tags: SearchSection<SearchTagRow>(
          items: results.tags,
          count: _atLeast(results.counts.tags, results.tags.length),
        ),
      ));
    } catch (error) {
      if (emit.isDone) return;
      emit(state.copyWith(
        status: SearchStatus.failure,
        errorMessage: _messageFor(error, 'Search failed. Please try again.'),
      ));
    }
  }

  Future<void> _onSectionMore(
      SearchSectionMoreRequested event, Emitter<SearchState> emit) async {
    // A page belonging to a query the user has already moved on from is not
    // worth fetching, and its rows would be wrong if it were.
    if (event.query != state.query || event.type != state.activeType) return;
    await _loadSection(event.type, event.query, emit);
  }

  /// Fetches the next page of [type] and folds it into that section.
  ///
  /// Page 1 *replaces* the preview rows rather than appending: the paged
  /// endpoint's first page is a superset of the ten the `type=all` response
  /// carried, so appending would show each of them twice.
  Future<void> _loadSection(
    SearchResultType type,
    String query,
    Emitter<SearchState> emit,
  ) async {
    final section = state.section(type);
    if (section.isLoadingMore) return;
    if (!section.hasNext && !section.needsFirstPage) return;

    final page = section.page + 1;
    emit(_withSection(type, isLoadingMore: true));

    try {
      final result =
          await _search.section(type, query, page: page, limit: _sectionLimit);
      if (emit.isDone) return;
      // The query can have moved on while this was in flight — a restartable
      // `SearchRequested` cancels itself, but not a droppable page fetch that
      // was already running. Dropping it here is what keeps a stale page from
      // appending itself to a different query's results.
      if (query != state.query) return;
      emit(_withSection(
        type,
        rows: result.items,
        replace: page == 1,
        page: page,
        hasNext: result.pagination.hasNext,
        count: _atLeast(result.pagination.total, section.count),
        isLoadingMore: false,
      ));
    } catch (error) {
      if (emit.isDone) return;
      emit(_withSection(type, isLoadingMore: false).copyWith(
        errorMessage:
            _messageFor(error, 'Could not load more results.'),
      ));
    }
  }

  /// Rebuilds [state] with one section changed. Typed row lists are the reason
  /// this can't be a single generic helper on [SearchState].
  SearchState _withSection(
    SearchResultType type, {
    List<Object>? rows,
    bool replace = false,
    int? page,
    bool? hasNext,
    int? count,
    bool? isLoadingMore,
  }) {
    List<T> merge<T>(SearchSection<T> section) => rows == null
        ? section.items
        : (replace
            ? rows.cast<T>()
            : [...section.items, ...rows.cast<T>()]);

    return switch (type) {
      SearchResultType.events => state.copyWith(
          events: state.events.copyWith(
            items: merge(state.events),
            page: page,
            hasNext: hasNext,
            count: count,
            isLoadingMore: isLoadingMore,
          ),
        ),
      SearchResultType.photographers => state.copyWith(
          photographers: state.photographers.copyWith(
            items: merge(state.photographers),
            page: page,
            hasNext: hasNext,
            count: count,
            isLoadingMore: isLoadingMore,
          ),
        ),
      SearchResultType.tags => state.copyWith(
          tags: state.tags.copyWith(
            items: merge(state.tags),
            page: page,
            hasNext: hasNext,
            count: count,
            isLoadingMore: isLoadingMore,
          ),
        ),
    };
  }

  void _onCleared(SearchCleared event, Emitter<SearchState> emit) {
    emit(state.cleared());
  }

  // ── You may like ───────────────────────────────────────────────────────────

  Future<void> _onYouMayLike(
      SearchYouMayLikeRequested event, Emitter<SearchState> emit) async {
    // Already have a grid and this isn't the ↻ button — nothing to do. Without
    // this the grid would reshuffle every time the screen is revisited.
    if (!event.refresh && state.youMayLike.isNotEmpty) return;

    emit(state.copyWith(
      isLoadingYouMayLike: true,
      clearYouMayLikeError: true,
    ));
    try {
      final page = await _search.youMayLike(
        limit: _youMayLikeLimit,
        refresh: event.refresh,
      );
      if (emit.isDone) return;
      emit(state.copyWith(
        isLoadingYouMayLike: false,
        youMayLike: page.photos,
        youMayLikeCursor: page.nextCursor,
        clearYouMayLikeCursor: page.nextCursor == null,
      ));
    } catch (error) {
      if (emit.isDone) return;
      emit(state.copyWith(
        isLoadingYouMayLike: false,
        youMayLikeError:
            _messageFor(error, 'Could not load suggestions.'),
      ));
    }
  }

  Future<void> _onYouMayLikeMore(
      SearchYouMayLikeMoreRequested event, Emitter<SearchState> emit) async {
    final cursor = state.youMayLikeCursor;
    // Null cursor is the end of the snapshot, not a failure — the ↻ button is
    // what starts a new one.
    if (cursor == null || state.isLoadingMoreYouMayLike) return;

    emit(state.copyWith(isLoadingMoreYouMayLike: true));
    try {
      final page = await _search.youMayLike(
        limit: _youMayLikeLimit,
        cursor: cursor,
      );
      if (emit.isDone) return;
      // A ↻ that landed while this was in flight built a new snapshot; these
      // photos belong to the old one and would duplicate or interleave.
      if (state.youMayLikeCursor != cursor) {
        emit(state.copyWith(isLoadingMoreYouMayLike: false));
        return;
      }
      emit(state.copyWith(
        isLoadingMoreYouMayLike: false,
        youMayLike: [...state.youMayLike, ...page.photos],
        youMayLikeCursor: page.nextCursor,
        clearYouMayLikeCursor: page.nextCursor == null,
      ));
    } catch (_) {
      if (emit.isDone) return;
      // Silent: the grid already has content and the user did not ask for
      // this page explicitly — they scrolled. Retried on the next scroll.
      emit(state.copyWith(isLoadingMoreYouMayLike: false));
    }
  }

  // ── Recent searches (device-local) ─────────────────────────────────────────

  Future<void> _onRecentsRequested(
      SearchRecentsRequested event, Emitter<SearchState> emit) async {
    emit(state.copyWith(recents: await _recents.load()));
  }

  Future<void> _onRecentSaved(
      SearchRecentSaved event, Emitter<SearchState> emit) async {
    emit(state.copyWith(recents: await _recents.add(event.query)));
  }

  Future<void> _onRecentRemoved(
      SearchRecentRemoved event, Emitter<SearchState> emit) async {
    emit(state.copyWith(recents: await _recents.remove(event.query)));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Guards against a server count smaller than the rows it just sent, which
  /// would leave [SearchSection.needsFirstPage] permanently false — or worse,
  /// hide a chip whose list is not empty.
  static int _atLeast(int count, int rows) => count > rows ? count : rows;

  static String _messageFor(Object error, String fallback) => switch (error) {
        NetworkException e => e.message,
        ServerException e => e.message,
        BadRequestException e => e.message,
        NotFoundException e => e.message,
        UnauthorizedException e => e.message,
        _ => fallback,
      };
}

part of 'search_bloc.dart';

sealed class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

/// A new query or a chip tap — the two things that decide *what* the list is
/// showing. Folded into one event so they share one `restartable` handler: a
/// keystroke has to cancel the previous query's request, and a chip tap has to
/// cancel a query whose results would land under the wrong chip.
class SearchRequested extends SearchEvent {
  /// A new query as it is being typed. Debounced, resets the chips.
  const SearchRequested.query(this.query)
      : type = null,
        immediate = false;

  /// A query the person has finished choosing — a recent search tapped, the
  /// keyboard's search key, a code handed over from the unlock sheet.
  ///
  /// The debounce exists to wait out the *next keystroke*, and there isn't
  /// going to be one: they picked a whole query in a single gesture. Waiting
  /// anyway put a third of a second of nothing between the tap and the screen
  /// doing something, which reads as the tap having missed.
  const SearchRequested.now(this.query)
      : type = null,
        immediate = true;

  /// A chip tap. Immediate; fetches the first real page only if the preview
  /// the `type=all` response carried is short of the section's count.
  const SearchRequested.type(this.query, SearchResultType this.type)
      : immediate = true;

  final String query;
  final SearchResultType? type;

  /// Whether to skip the typing debounce. See [SearchRequested.now].
  final bool immediate;

  @override
  List<Object?> get props => [query, type, immediate];
}

/// The active chip's next page.
///
/// Deliberately *not* part of [SearchRequested]: paging fires on every scroll
/// frame near the bottom, and under `restartable` each of those would cancel
/// the fetch the one before it started, so no page would ever arrive. It is
/// `droppable` instead — the first request wins and the rest are ignored while
/// it is in flight — and carries the query and chip it belongs to so a result
/// that outlives a newer search can be recognised and discarded.
class SearchSectionMoreRequested extends SearchEvent {
  const SearchSectionMoreRequested(this.query, this.type);

  final String query;
  final SearchResultType type;

  @override
  List<Object?> get props => [query, type];
}

/// Back to the idle screen — the ✕ in the field, or an empty query.
class SearchCleared extends SearchEvent {
  const SearchCleared();
}

// ── Idle screen ───────────────────────────────────────────────────────────────

/// Loads the "You may like" grid. [refresh] is the ↻ button: it asks the
/// server for a brand-new shuffled snapshot rather than the held one.
class SearchYouMayLikeRequested extends SearchEvent {
  const SearchYouMayLikeRequested({this.refresh = false});

  final bool refresh;

  @override
  List<Object?> get props => [refresh];
}

/// The next slice of the current snapshot, by cursor.
class SearchYouMayLikeMoreRequested extends SearchEvent {
  const SearchYouMayLikeMoreRequested();
}

/// Reads the device's stored recent searches.
class SearchRecentsRequested extends SearchEvent {
  const SearchRecentsRequested();
}

/// Records a query the user actually acted on — submitted, or opened a result
/// from. Typing alone does not earn a row.
class SearchRecentSaved extends SearchEvent {
  const SearchRecentSaved(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// The ✕ on a recent row.
class SearchRecentRemoved extends SearchEvent {
  const SearchRecentRemoved(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

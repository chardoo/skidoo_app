part of 'found_bloc.dart';

abstract class FoundEvent extends Equatable {
  const FoundEvent();
  @override
  List<Object?> get props => [];
}

/// Fetches found albums.
///
/// * default — reload from page 1 (initial load, pull-to-refresh)
/// * [loadMore] — append the next page
/// * [filters] — apply a new selection and reload from page 1
///
/// One event covers all three on purpose — see the note on [FoundBloc].
class FoundPhotosRequested extends FoundEvent {
  const FoundPhotosRequested({this.loadMore = false, this.filters});

  final bool loadMore;

  /// Null means "keep whatever is applied"; non-null replaces the selection.
  final FoundFilters? filters;

  @override
  List<Object?> get props => [loadMore, filters];
}

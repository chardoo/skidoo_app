part of 'found_bloc.dart';

class FoundState extends Equatable {
  const FoundState({
    this.albums = const [],
    this.filters = FoundFilters.none,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.page = 0,
    this.totalPhotos,
    this.totalEvents = 0,
    this.hasMore = true,
  });

  final List<FoundAlbum> albums;

  /// The selection [albums] was fetched with.
  final FoundFilters filters;

  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  /// Last page of events successfully fetched. 0 before the first load.
  final int page;

  /// `totals.photos` — the "N found" headline. Unlike the album count this
  /// covers every page, so it doesn't creep upward as the user scrolls.
  ///
  /// It reflects [filters]: the server counts it over the same predicate it
  /// selects rows with, so narrowing the selection narrows the headline and it
  /// always agrees with the grid beneath it. Null means the server sent no
  /// usable `totals` and the headline is suppressed rather than guessed.
  final int? totalPhotos;

  final int totalEvents;
  final bool hasMore;

  FoundState copyWith({
    List<FoundAlbum>? albums,
    FoundFilters? filters,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
    int? page,
    int? totalPhotos,
    bool clearTotalPhotos = false,
    int? totalEvents,
    bool? hasMore,
  }) {
    return FoundState(
      albums: albums ?? this.albums,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      page: page ?? this.page,
      totalPhotos: clearTotalPhotos ? null : (totalPhotos ?? this.totalPhotos),
      totalEvents: totalEvents ?? this.totalEvents,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  @override
  List<Object?> get props => [
        albums,
        filters,
        isLoading,
        isLoadingMore,
        errorMessage,
        page,
        totalPhotos,
        totalEvents,
        hasMore,
      ];
}

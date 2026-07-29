part of 'found_album_bloc.dart';

class FoundAlbumState extends Equatable {
  const FoundAlbumState({
    this.photos = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.page = 0,
    this.total = 0,
    this.hasMore = true,
  });

  final List<Photo> photos;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final int page;

  /// Photos in this event, across every page.
  final int total;

  final bool hasMore;

  FoundAlbumState copyWith({
    List<Photo>? photos,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
    int? page,
    int? total,
    bool? hasMore,
  }) {
    return FoundAlbumState(
      photos: photos ?? this.photos,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      page: page ?? this.page,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  @override
  List<Object?> get props =>
      [photos, isLoading, isLoadingMore, errorMessage, page, total, hasMore];
}

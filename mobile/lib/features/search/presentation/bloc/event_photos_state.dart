part of 'event_photos_bloc.dart';

class EventPhotosState extends Equatable {
  const EventPhotosState({
    this.event = SearchEventRow.empty,
    this.photos = const [],
    this.page = 0,
    this.hasNext = false,
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  /// The event block the envelope carries — the page's title and header.
  final SearchEventRow event;
  final List<Photo> photos;
  final int page;
  final bool hasNext;

  /// Photos across every page, for the header count.
  final int total;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  bool get isEmpty => !isLoading && photos.isEmpty && errorMessage == null;

  EventPhotosState copyWith({
    SearchEventRow? event,
    List<Photo>? photos,
    int? page,
    bool? hasNext,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return EventPhotosState(
      event: event ?? this.event,
      photos: photos ?? this.photos,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        event,
        photos,
        page,
        hasNext,
        total,
        isLoading,
        isLoadingMore,
        errorMessage,
      ];
}

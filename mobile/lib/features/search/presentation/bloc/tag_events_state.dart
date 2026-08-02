part of 'tag_events_bloc.dart';

class TagEventsState extends Equatable {
  const TagEventsState({
    this.label = '',
    this.postCount = 0,
    this.eventCount = 0,
    this.events = const [],
    this.page = 0,
    this.hasNext = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  /// What the header shows — `#reloaded`. Empty until the first response, so
  /// the page falls back to the label the row it was opened from carried.
  final String label;
  final int postCount;
  final int eventCount;
  final List<SearchEventRow> events;
  final int page;
  final bool hasNext;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  bool get isEmpty => !isLoading && events.isEmpty && errorMessage == null;

  TagEventsState copyWith({
    String? label,
    int? postCount,
    int? eventCount,
    List<SearchEventRow>? events,
    int? page,
    bool? hasNext,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TagEventsState(
      label: label ?? this.label,
      postCount: postCount ?? this.postCount,
      eventCount: eventCount ?? this.eventCount,
      events: events ?? this.events,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        label,
        postCount,
        eventCount,
        events,
        page,
        hasNext,
        isLoading,
        isLoadingMore,
        errorMessage,
      ];
}

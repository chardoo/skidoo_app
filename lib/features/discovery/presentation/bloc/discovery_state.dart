part of 'discovery_bloc.dart';

class DiscoveryState extends Equatable {
  final List<EventDiscovery> events;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final String? currentUserId;
  final Set<String> hiddenEventIds;
  /// ID of the event currently pending hide (card collapsed, undo available).
  final String? pendingHideEventId;

  const DiscoveryState({
    this.events = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.currentUserId,
    this.hiddenEventIds = const {},
    this.pendingHideEventId,
  });

  DiscoveryState copyWith({
    List<EventDiscovery>? events,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
    String? currentUserId,
    Set<String>? hiddenEventIds,
    String? pendingHideEventId,
    bool clearPendingHide = false,
  }) {
    return DiscoveryState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentUserId: currentUserId ?? this.currentUserId,
      hiddenEventIds: hiddenEventIds ?? this.hiddenEventIds,
      pendingHideEventId:
          clearPendingHide ? null : (pendingHideEventId ?? this.pendingHideEventId),
    );
  }

  @override
  List<Object?> get props => [
        events,
        isLoading,
        isLoadingMore,
        errorMessage,
        currentUserId,
        hiddenEventIds,
        pendingHideEventId,
      ];
}

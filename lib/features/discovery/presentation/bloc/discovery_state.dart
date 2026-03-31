part of 'discovery_bloc.dart';

class DiscoveryState extends Equatable {
  final List<EventDiscovery> events;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  const DiscoveryState({
    this.events = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  DiscoveryState copyWith({
    List<EventDiscovery>? events,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DiscoveryState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [events, isLoading, isLoadingMore, errorMessage];
}

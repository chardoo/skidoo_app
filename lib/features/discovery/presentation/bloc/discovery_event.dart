part of 'discovery_bloc.dart';

abstract class DiscoveryEvent extends Equatable {
  const DiscoveryEvent();
  @override
  List<Object?> get props => [];
}

/// Initial load (clears existing list).
class DiscoveryLoadRequested extends DiscoveryEvent {
  const DiscoveryLoadRequested();
}

/// Load the next page and append to the existing list.
class DiscoveryLoadMoreRequested extends DiscoveryEvent {
  const DiscoveryLoadMoreRequested();
}

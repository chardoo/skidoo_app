part of 'home_bloc.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object?> get props => [];
}

class HomeInitialized extends HomeEvent {
  const HomeInitialized();
}

class HomeEventSearched extends HomeEvent {
  final String query;
  const HomeEventSearched(this.query);
  @override
  List<Object?> get props => [query];
}

class HomeImagesSearched extends HomeEvent {
  final String eventId;
  final String eventName;
  const HomeImagesSearched({required this.eventId, required this.eventName});
  @override
  List<Object?> get props => [eventId, eventName];
}

class HomeSearchClosed extends HomeEvent {
  const HomeSearchClosed();
}

/// Save a list of search-result photos to the user's gallery for free.
class HomeFreeImagesSaved extends HomeEvent {
  final List<Photo> photos;
  const HomeFreeImagesSaved(this.photos);
  @override
  List<Object?> get props => [photos];
}

part of 'event_photos_bloc.dart';

sealed class EventPhotosEvent extends Equatable {
  const EventPhotosEvent();

  @override
  List<Object?> get props => [];
}

/// The first page, or a pull-to-refresh. Restartable — a refresh replaces
/// whatever was in flight.
class EventPhotosRequested extends EventPhotosEvent {
  const EventPhotosRequested();
}

/// The next page.
///
/// Separate from [EventPhotosRequested] and `droppable`, not restartable:
/// paging fires on every scroll frame near the bottom, and restarting on each
/// of those would cancel the fetch before it could ever finish.
class EventPhotosMoreRequested extends EventPhotosEvent {
  const EventPhotosMoreRequested();
}

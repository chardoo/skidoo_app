part of 'tag_events_bloc.dart';

sealed class TagEventsEvent extends Equatable {
  const TagEventsEvent();

  @override
  List<Object?> get props => [];
}

/// The first page, or a refresh.
class TagEventsRequested extends TagEventsEvent {
  const TagEventsRequested();
}

/// The next page — see [EventPhotosMoreRequested] for why this is its own
/// `droppable` event rather than a flag on the one above.
class TagEventsMoreRequested extends TagEventsEvent {
  const TagEventsMoreRequested();
}

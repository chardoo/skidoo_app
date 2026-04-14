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

/// Toggle like or dislike for an event card in the feed.
class DiscoveryReactionToggled extends DiscoveryEvent {
  final String eventId;

  /// true = like/unlike action, false = dislike/undislike action.
  final bool isLike;

  const DiscoveryReactionToggled(this.eventId, {required this.isLike});

  @override
  List<Object?> get props => [eventId, isLike];
}

/// Dispatched by the card widget when it enters the viewport.
class DiscoveryEventVisible extends DiscoveryEvent {
  final String eventId;
  const DiscoveryEventVisible(this.eventId);
  @override
  List<Object?> get props => [eventId];
}

/// Dispatched by the card widget when it leaves the viewport.
class DiscoveryEventHidden extends DiscoveryEvent {
  final String eventId;
  const DiscoveryEventHidden(this.eventId);
  @override
  List<Object?> get props => [eventId];
}

/// User chose to hide an event — collapses the card and shows an undo window.
class DiscoveryEventHideRequested extends DiscoveryEvent {
  final String eventId;
  const DiscoveryEventHideRequested(this.eventId);
  @override
  List<Object?> get props => [eventId];
}

/// Commits a pending hide: removes from list and persists to local storage.
/// Fired when the undo window closes without the user tapping Undo.
class DiscoveryEventHideCommitted extends DiscoveryEvent {
  final String eventId;
  const DiscoveryEventHideCommitted(this.eventId);
  @override
  List<Object?> get props => [eventId];
}

/// Cancels a pending hide and restores the card.
class DiscoveryEventHideUndone extends DiscoveryEvent {
  const DiscoveryEventHideUndone();
}

/// Internal — fired when a like_update arrives on a persistent WS session.
class _DiscoveryLikeUpdateReceived extends DiscoveryEvent {
  final LikeUpdate update;
  const _DiscoveryLikeUpdateReceived(this.update);
  @override
  List<Object?> get props => [update];
}

/// Internal — fired when background reaction enrichment finishes.
/// Patches counts/userReaction onto already-visible events without a reload.
class _DiscoveryReactionsPatchReceived extends DiscoveryEvent {
  final List<EventDiscovery> enriched;
  const _DiscoveryReactionsPatchReceived(this.enriched);
  @override
  List<Object?> get props => [enriched];
}

/// Internal — restores persisted hidden IDs from SharedPreferences on startup.
class _DiscoveryHiddenIdsLoaded extends DiscoveryEvent {
  final Set<String> ids;
  const _DiscoveryHiddenIdsLoaded(this.ids);
  @override
  List<Object?> get props => [ids];
}

/// User tapped the bookmark button on an event card.
class DiscoveryEventSaveToggled extends DiscoveryEvent {
  final String eventId;
  const DiscoveryEventSaveToggled(this.eventId);
  @override
  List<Object?> get props => [eventId];
}

/// Internal — fires when the initial saved-items list is loaded from the server.
class _DiscoverySavedItemsLoaded extends DiscoveryEvent {
  /// Map of eventId → savedItemRecordId, for all currently saved events.
  final Map<String, String> recordIds;
  const _DiscoverySavedItemsLoaded(this.recordIds);
  @override
  List<Object?> get props => [recordIds];
}

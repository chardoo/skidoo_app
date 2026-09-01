part of 'discovery_bloc.dart';

/// Where an event's reaction stands, independently of which list it was drawn
/// from.
///
/// The counts on [DiscoveryState.events] only ever described the Feed tab's
/// own list, and every reaction handler here began by looking the event up in
/// it. Following fetches its posts from a different endpoint into a list of its
/// own, so its cards were never in that list — liking one found nothing to
/// update and returned, and the heart did not so much as flicker. The Feed tab
/// worked, which is what made it look like a Following bug rather than a
/// missing idea.
///
/// This is the missing idea: what the viewer has done to an event, and what the
/// server has said about it since, keyed by event and belonging to no list.
class EventReactionState extends Equatable {
  const EventReactionState({
    required this.likes,
    required this.dislikes,
    this.userReaction,
  });

  final int likes;
  final int dislikes;

  /// 'like', 'dislike', or null for neither.
  final String? userReaction;

  bool get liked => userReaction == 'like';
  bool get disliked => userReaction == 'dislike';

  @override
  List<Object?> get props => [likes, dislikes, userReaction];
}

/// What a tap on the heart came to: the state to emit, the word the server
/// expects, and what to put back if the send never happens.
class ReactionToggle {
  const ReactionToggle({
    required this.state,
    required this.action,
    required this.previous,
  });

  final DiscoveryState state;

  /// 'like' | 'unlike' | 'dislike' | 'undislike'.
  final String action;

  /// Where the event stood before, for the revert path.
  final EventReactionState previous;
}

class DiscoveryState extends Equatable {
  final List<EventDiscovery> events;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final String? currentUserId;
  final Set<String> hiddenEventIds;

  /// ID of the event currently pending hide (card collapsed, undo available).
  final String? pendingHideEventId;

  /// IDs of events the current user has bookmarked.
  final Set<String> savedEventIds;

  /// Maps eventId → saved-item record ID (for DELETE by record ID).
  final Map<String, String> savedItemRecordIds;

  /// False once the API returns fewer items than the page size — no more pages.
  final bool hasMore;

  /// Reactions by event id, for every event this session has touched or heard
  /// about — whichever feed it came from. See [EventReactionState].
  final Map<String, EventReactionState> reactions;

  const DiscoveryState({
    this.events = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.currentUserId,
    this.hiddenEventIds = const {},
    this.pendingHideEventId,
    this.savedEventIds = const {},
    this.savedItemRecordIds = const {},
    this.hasMore = true,
    this.reactions = const {},
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
    Set<String>? savedEventIds,
    Map<String, String>? savedItemRecordIds,
    bool? hasMore,
    Map<String, EventReactionState>? reactions,
  }) {
    return DiscoveryState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentUserId: currentUserId ?? this.currentUserId,
      hiddenEventIds: hiddenEventIds ?? this.hiddenEventIds,
      pendingHideEventId: clearPendingHide
          ? null
          : (pendingHideEventId ?? this.pendingHideEventId),
      savedEventIds: savedEventIds ?? this.savedEventIds,
      savedItemRecordIds: savedItemRecordIds ?? this.savedItemRecordIds,
      hasMore: hasMore ?? this.hasMore,
      reactions: reactions ?? this.reactions,
    );
  }

  /// Where an event stands right now, from the best source available: this
  /// state's own record, then the Feed tab's list, then whatever a card
  /// supplied. The last is what makes a reaction possible on a post from
  /// another feed entirely — see [EventReactionState].
  EventReactionState? reactionFor(String eventId,
      [EventReactionState? fallback]) {
    final known = reactions[eventId];
    if (known != null) return known;

    final idx = events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return fallback;

    final e = events[idx];
    return EventReactionState(
      likes: e.likes,
      dislikes: e.dislikes,
      userReaction: e.userReaction,
    );
  }

  /// Writes a reaction everywhere it is held: the shared record, and the Feed
  /// tab's list when the event happens to be in it.
  DiscoveryState withReaction(String eventId, EventReactionState reaction) {
    final next = Map<String, EventReactionState>.from(reactions)
      ..[eventId] = reaction;

    final idx = events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return copyWith(reactions: next);

    final patched = List<EventDiscovery>.from(events);
    patched[idx] = patched[idx].copyWith(
      likes: reaction.likes,
      dislikes: reaction.dislikes,
      userReaction: reaction.userReaction,
      clearReaction: reaction.userReaction == null,
    );
    return copyWith(events: patched, reactions: next);
  }

  /// The optimistic half of a tap on the heart (or the thumb).
  ///
  /// Null when nothing is known about the event and the card offered nothing
  /// either — there is no count to move and no state to guess at.
  ReactionToggle? toggleReaction(
    String eventId, {
    required bool isLike,
    EventReactionState? snapshot,
  }) {
    final current = reactionFor(eventId, snapshot);
    if (current == null) return null;

    final String action;
    if (isLike) {
      action = current.liked ? 'unlike' : 'like';
    } else {
      action = current.disliked ? 'undislike' : 'dislike';
    }

    var likes = current.likes;
    var dislikes = current.dislikes;
    String? reaction;

    switch (action) {
      case 'like':
        likes++;
        if (current.disliked) dislikes--;
        reaction = 'like';
      case 'unlike':
        likes = (likes - 1).clamp(0, 999999999);
        reaction = null;
      case 'dislike':
        dislikes++;
        if (current.liked) likes--;
        reaction = 'dislike';
      case 'undislike':
        dislikes = (dislikes - 1).clamp(0, 999999999);
        reaction = null;
    }

    return ReactionToggle(
      state: withReaction(
        eventId,
        EventReactionState(
          likes: likes,
          dislikes: dislikes,
          userReaction: reaction,
        ),
      ),
      action: action,
      previous: current,
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
        savedEventIds,
        savedItemRecordIds,
        hasMore,
        reactions,
      ];
}

import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// Liking a post in Following did nothing at all.
///
/// Every reaction handler in this bloc began by looking the event up in
/// `state.events` — the Feed tab's list — and returning when it was not there.
/// Following fetches its own posts from its own endpoint into its own list, so
/// its cards were never in that list: the heart did not fill, the count did not
/// move, and nothing was sent. The Feed tab worked perfectly, which is what
/// made it read as a Following bug rather than a missing idea.
///
/// The missing idea is [EventReactionState]: what the viewer has done to an
/// event, held by event id and belonging to no list. Exercised through
/// [DiscoveryState.toggleReaction], which is the decision the bloc makes before
/// it sends anything — the rest of that handler is a websocket, and the bloc
/// itself needs the chat service, shared preferences and a token to construct.
EventDiscovery event({
  String id = 'e1',
  int likes = 10,
  int dislikes = 0,
  String? userReaction,
}) =>
    EventDiscovery(
      id: id,
      eventName: 'Graduation',
      photographerName: 'Kwame',
      photographerId: 'p1',
      likes: likes,
      dislikes: dislikes,
      userReaction: userReaction,
      pictures: const [],
    );

void main() {
  group('a post this bloc never fetched', () {
    test('can be liked, and the count moves', () {
      // What a card in Following hands down: its own copy of the post.
      final toggle = const DiscoveryState().toggleReaction(
        'following-post',
        isLike: true,
        snapshot: const EventReactionState(likes: 10, dislikes: 0),
      );

      expect(toggle, isNotNull, reason: 'this used to return, doing nothing');
      expect(toggle!.action, 'like');
      expect(toggle.state.reactions['following-post']?.liked, isTrue);
      expect(toggle.state.reactions['following-post']?.likes, 11);
    });

    test('and unliked again, back to where it started', () {
      const snapshot = EventReactionState(likes: 10, dislikes: 0);

      final liked = const DiscoveryState()
          .toggleReaction('p', isLike: true, snapshot: snapshot)!;
      final unliked =
          liked.state.toggleReaction('p', isLike: true, snapshot: snapshot)!;

      expect(unliked.action, 'unlike');
      expect(unliked.state.reactions['p']?.liked, isFalse);
      // 10, not 9: the second toggle reads the record the first one wrote,
      // rather than the stale snapshot the card is still carrying.
      expect(unliked.state.reactions['p']?.likes, 10);
    });

    test('is left alone when nobody can say where it stands', () {
      // No record, not in the list, and no snapshot — there is no count to
      // move and guessing at one would put a wrong number on the card.
      expect(const DiscoveryState().toggleReaction('p', isLike: true), isNull);
    });
  });

  group('a post from the Feed tab', () {
    test('is updated in the list as well as in the record', () {
      final state = DiscoveryState(events: [event(likes: 10)]);

      final toggle = state.toggleReaction('e1', isLike: true)!;

      // The list, because the Feed tab's cards are built from it...
      expect(toggle.state.events.first.likes, 11);
      expect(toggle.state.events.first.userReaction, 'like');
      // ...and the record, because that is what the rail reads.
      expect(toggle.state.reactions['e1']?.likes, 11);
    });

    test('prefers what the bloc knows to what a card supplies', () {
      // A card built before an echo landed carries a stale count. The bloc has
      // seen the echo, and must not be talked backwards by the card.
      final state = DiscoveryState(
        events: [event(likes: 10)],
        reactions: const {'e1': EventReactionState(likes: 50, dislikes: 0)},
      );

      final toggle = state.toggleReaction(
        'e1',
        isLike: true,
        snapshot: const EventReactionState(likes: 10, dislikes: 0),
      )!;

      expect(toggle.state.reactions['e1']?.likes, 51);
    });
  });

  group('the two reactions against each other', () {
    test('liking something disliked moves both counts', () {
      final state = DiscoveryState(
        events: [event(likes: 10, dislikes: 4, userReaction: 'dislike')],
      );

      final toggle = state.toggleReaction('e1', isLike: true)!;

      expect(toggle.state.reactions['e1']?.likes, 11);
      expect(toggle.state.reactions['e1']?.dislikes, 3);
      expect(toggle.state.reactions['e1']?.userReaction, 'like');
    });

    test('a count never goes below zero', () {
      // Server counts and local ones drift; an unlike against a zero must not
      // print "-1 likes" on somebody's photograph.
      final state = DiscoveryState(events: [event(likes: 0, userReaction: 'like')]);

      final toggle = state.toggleReaction('e1', isLike: true)!;

      expect(toggle.action, 'unlike');
      expect(toggle.state.reactions['e1']?.likes, 0);
    });
  });

  test('the previous state comes back for the revert path', () {
    // The bloc puts this back when there is no room to route the send through.
    final state = DiscoveryState(events: [event(likes: 10)]);

    final toggle = state.toggleReaction('e1', isLike: true)!;
    final reverted = toggle.state.withReaction('e1', toggle.previous);

    expect(reverted.reactions['e1']?.likes, 10);
    expect(reverted.reactions['e1']?.liked, isFalse);
    expect(reverted.events.first.likes, 10);
  });
}

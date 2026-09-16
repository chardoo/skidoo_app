import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/follow/data/follow_repository.dart';
import 'package:jperg_app/features/follow/presentation/widgets/following_feed.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

List<EventDiscovery> events(int count) => [
      for (var i = 0; i < count; i++)
        EventDiscovery(
          id: 'e$i',
          eventName: 'Event $i',
          photographerName: 'Creator',
          photographerId: 'u1',
          pictures: const [],
        ),
    ];

List<SuggestedPhotographer> creators(int count) => [
      for (var i = 0; i < count; i++)
        SuggestedPhotographer(
          id: 'c$i',
          name: 'Creator $i',
          contact: '',
          email: '',
          followerCount: i,
        ),
    ];

/// Reads the page list as a shape — 'e' for a post, 'S' for a suggestions
/// card — so the ordering is legible at a glance.
String shapeOf(List<FeedSlot> slots) =>
    slots.map((s) => s.isSuggestions ? 'S' : 'e').join();

/// The ids on the suggestion cards, in the order they are dealt.
List<List<String>> slicesOf(List<FeedSlot> slots) => [
      for (final slot in slots)
        if (slot.isSuggestions)
          slot.suggestions!.map((s) => s.id).toList(),
    ];


/// How many creators each suggestions card was dealt, in order.
List<int> cardSizes(List<FeedSlot> slots) => [
      for (final s in slots)
        if (s.isSuggestions) s.suggestions!.length,
    ];

void main() {
  test('a card lands after every five posts', () {
    final slots = buildFollowingSlots(
      events: events(15),
      suggestions: creators(20),
    );
    expect(shapeOf(slots), 'eeeeeSeeeeeSeeeeeS');
  });

  test('each card carries the next five creators, never a repeat', () {
    final slots = buildFollowingSlots(
      events: events(15),
      suggestions: creators(20),
    );
    expect(slicesOf(slots), [
      ['c0', 'c1', 'c2', 'c3', 'c4'],
      ['c5', 'c6', 'c7', 'c8', 'c9'],
      ['c10', 'c11', 'c12', 'c13', 'c14'],
    ]);
  });

  test('no card before the first five posts are through', () {
    final slots = buildFollowingSlots(
      events: events(4),
      suggestions: creators(20),
    );
    expect(shapeOf(slots), 'eeee');
  });

  test('cards stop when the creators run out, and the posts keep going', () {
    final slots = buildFollowingSlots(
      events: events(20),
      suggestions: creators(7),
    );
    // Seven creators is one full card, and the two left over are dropped
    // rather than given a page of their own.
    //
    // This used to deal the short card as well. It was reported as a bug from
    // the other end of the same behaviour: with six creators the remainder is
    // *one*, and a full-screen page introducing a single creator reads as a
    // mistake rather than as a suggestion. A page is worth
    // [FollowingFeed.minSuggestionsPerCard] creators or it is not worth a
    // page — see the group at the end of this file.
    expect(shapeOf(slots), 'eeeeeSeeeeeeeeeeeeeee');
    expect(slots.where((s) => !s.isSuggestions).length, 20);
    expect(slicesOf(slots), [
      ['c0', 'c1', 'c2', 'c3', 'c4'],
    ]);
  });

  test('no creators at all is just the feed', () {
    final slots = buildFollowingSlots(
      events: events(12),
      suggestions: const [],
    );
    expect(shapeOf(slots), 'eeeeeeeeeeee');
  });

  test('appending a page of posts never reshuffles the pages before it', () {
    final first = buildFollowingSlots(
      events: events(6),
      suggestions: creators(20),
    );
    final grown = buildFollowingSlots(
      events: events(12),
      suggestions: creators(20),
    );

    // The user is somewhere in this list while more loads underneath; the
    // prefix has to stay put or the page they are on changes under them.
    expect(shapeOf(grown).startsWith(shapeOf(first)), isTrue);
    expect(slicesOf(grown).first, slicesOf(first).first);
  });

  test('growing the creator pool leaves already-dealt cards alone', () {
    final before = buildFollowingSlots(
      events: events(15),
      suggestions: creators(10),
    );
    final after = buildFollowingSlots(
      events: events(15),
      suggestions: creators(20),
    );

    expect(slicesOf(after).take(2), slicesOf(before));
    // …and the boundary that had nothing to show now has the next five.
    expect(slicesOf(after).last, ['c10', 'c11', 'c12', 'c13', 'c14']);
  });

  group('a suggestions card is never a page for one creator', () {
    // The slices are disjoint, so the last one is whatever is left over: six
    // suggestions dealt a card of five and then a card of **one**, and a
    // full-screen page introducing a single creator reads as a mistake.

    test('a leftover of one is not given a page', () {
      final slots = buildFollowingSlots(
        events: events(20),
        suggestions: creators(6),
      );

      expect(cardSizes(slots), [5]);
    });

    test('nor a leftover of two', () {
      final slots = buildFollowingSlots(
        events: events(20),
        suggestions: creators(7),
      );

      expect(cardSizes(slots), [5]);
    });

    test('a remainder worth showing still gets one', () {
      final slots = buildFollowingSlots(
        events: events(20),
        suggestions: creators(8),
      );

      expect(cardSizes(slots), [5, 3]);
    });

    test('full slices are unaffected', () {
      final slots = buildFollowingSlots(
        events: events(20),
        suggestions: creators(10),
      );

      expect(cardSizes(slots), [5, 5]);
    });

    test('the stub after two full cards goes too', () {
      final slots = buildFollowingSlots(
        events: events(30),
        suggestions: creators(11),
      );

      expect(cardSizes(slots), [5, 5]);
    });

    test('the first card shows a short list rather than nothing', () {
      // On a platform with two creators on it, this is the only card there
      // will ever be — dropping it would mean the tab never suggests anybody.
      final slots = buildFollowingSlots(
        events: events(20),
        suggestions: creators(2),
      );

      expect(cardSizes(slots), [2]);
    });

    test('no suggestions at all deals no cards', () {
      final slots = buildFollowingSlots(
        events: events(20),
        suggestions: creators(0),
      );

      expect(cardSizes(slots), isEmpty);
    });
  });
}

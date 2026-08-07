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
    // Seven creators is one full card and a short one; the remaining
    // boundaries pass without a card rather than dealing an empty one.
    expect(shapeOf(slots), 'eeeeeSeeeeeSeeeeeeeeee');
    expect(slots.where((s) => !s.isSuggestions).length, 20);
    expect(slicesOf(slots), [
      ['c0', 'c1', 'c2', 'c3', 'c4'],
      ['c5', 'c6'],
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
}

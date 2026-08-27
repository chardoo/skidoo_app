import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/cache/comment_counts.dart';
import 'package:jperg_app/core/cache/session_cache.dart';

/// The badge that would not move.
///
/// A card's comment count arrives inside immutable feed data and nothing
/// rewrote it, so posting a comment left the number showing whatever the list
/// was fetched with. [CommentCounts] holds the correction.
///
/// The rule under nearly every test here: a null count means *leave the
/// displayed number alone*. It is not zero, and it is not an invitation to
/// guess. The server sends null for a reply — replies do not count towards the
/// badge — and whenever it could not read the count back, and in both cases a
/// stale number beats an invented one.
void main() {
  setUp(CommentCounts.instance.clear);

  group('reporting a count', () {
    test('a reported count replaces what the card was built with', () {
      CommentCounts.instance.report('ad1', 4);

      expect(CommentCounts.instance.countFor('ad1'), 4);
    });

    test('an untouched target reports null, not zero', () {
      expect(CommentCounts.instance.countFor('never-commented'), isNull);
    });

    test('null is ignored so a reply cannot blank a good number', () {
      CommentCounts.instance.report('ad1', 4);

      CommentCounts.instance.report('ad1', null);

      expect(CommentCounts.instance.countFor('ad1'), 4);
    });

    test('a negative count is refused', () {
      CommentCounts.instance.report('ad1', 4);

      CommentCounts.instance.report('ad1', -1);

      expect(CommentCounts.instance.countFor('ad1'), 4);
    });

    test('an empty or null target id is ignored', () {
      CommentCounts.instance.report('', 4);
      CommentCounts.instance.report(null, 4);

      expect(CommentCounts.instance.countFor(''), isNull);
    });

    test('targets do not bleed into each other', () {
      CommentCounts.instance.report('ad1', 4);
      CommentCounts.instance.report('ad2', 9);

      expect(CommentCounts.instance.countFor('ad1'), 4);
      expect(CommentCounts.instance.countFor('ad2'), 9);
    });
  });

  group('notifying', () {
    test('a change notifies listeners', () {
      var notified = 0;
      void listener() => notified++;
      CommentCounts.instance.addListener(listener);
      addTearDown(() => CommentCounts.instance.removeListener(listener));

      CommentCounts.instance.report('ad1', 4);

      expect(notified, 1);
    });

    test('reporting the same number again notifies nobody', () {
      CommentCounts.instance.report('ad1', 4);
      var notified = 0;
      void listener() => notified++;
      CommentCounts.instance.addListener(listener);
      addTearDown(() => CommentCounts.instance.removeListener(listener));

      CommentCounts.instance.report('ad1', 4);

      // Every card on screen rebuilds on a notification; one that changes
      // nothing is pure work.
      expect(notified, 0);
    });
  });

  group('adjusting without a server figure', () {
    test('a delta applies on top of the count the card knows', () {
      // Deletion answers 204 with no body, so there is nothing to read back.
      CommentCounts.instance.adjust('ad1', -1, base: 5);

      expect(CommentCounts.instance.countFor('ad1'), 4);
    });

    test('a delta applies on top of an already-corrected count', () {
      CommentCounts.instance.report('ad1', 10);

      CommentCounts.instance.adjust('ad1', 1, base: 5);

      expect(CommentCounts.instance.countFor('ad1'), 11);
    });

    test('it never lands below zero', () {
      CommentCounts.instance.adjust('ad1', -1, base: 0);

      expect(CommentCounts.instance.countFor('ad1'), 0);
    });

    test('an authoritative count overrides a guess', () {
      CommentCounts.instance.adjust('ad1', 1, base: 5);

      CommentCounts.instance.report('ad1', 2);

      expect(CommentCounts.instance.countFor('ad1'), 2);
    });
  });

  group('signing out', () {
    test('clearAll empties it, so the next account sees nothing', () {
      CommentCounts.instance.report('ad1', 4);

      SessionCache.clearAll();

      expect(CommentCounts.instance.countFor('ad1'), isNull);
    });
  });

  group('LiveCommentCount', () {
    Widget harness(String? targetId, int fallback) => Directionality(
          textDirection: TextDirection.ltr,
          child: LiveCommentCount(
            targetId: targetId,
            fallback: fallback,
            builder: (_, count) => Text('$count'),
          ),
        );

    testWidgets('shows the fallback until something reports otherwise',
        (tester) async {
      await tester.pumpWidget(harness('ad1', 7));

      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('rebuilds when the count is reported', (tester) async {
      await tester.pumpWidget(harness('ad1', 7));

      CommentCounts.instance.report('ad1', 8);
      await tester.pump();

      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('ignores a report about a different target', (tester) async {
      await tester.pumpWidget(harness('ad1', 7));

      CommentCounts.instance.report('ad2', 99);
      await tester.pump();

      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('a card with no target id just renders its fallback',
        (tester) async {
      await tester.pumpWidget(harness(null, 7));

      expect(find.text('7'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/top_comment_line.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// The comment that borrows a card's caption line for five seconds.
///
/// The whole feature is about *not* doing it most of the time — the server only
/// sends one when a comment clears a floor and a margin over the runner-up, so
/// the client's half of the contract is that null is ordinary and must never
/// draw anything.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: child),
      ),
    );

Map<String, dynamic> eventJson({Object? topComment = _absent}) => {
      'id': 'e1',
      'eventName': 'Wedding',
      'user': {'id': 'p1', 'name': 'Ama'},
      'pictures': const [],
      if (!identical(topComment, _absent)) 'topComment': topComment,
    };

const _absent = Object();

void main() {
  group('parsing', () {
    test('a card with no standout comment carries null', () {
      // The ordinary case, and the one the card is built around.
      expect(EventDiscovery.fromMap(eventJson()).topComment, isNull);
    });

    test('an explicit null is null, not a crash', () {
      expect(EventDiscovery.fromMap(eventJson(topComment: null)).topComment,
          isNull);
    });

    test('a standout comment is read off the event', () {
      final event = EventDiscovery.fromMap(eventJson(topComment: {
        'id': 'c1',
        'authorName': 'Kofi',
        'content': 'the light in the third one is unreal',
        'likeCount': 312,
        'replyCount': 9,
      }));

      expect(event.topComment!.id, 'c1');
      expect(event.topComment!.authorName, 'Kofi');
      expect(event.topComment!.likeCount, 312);
      expect(event.topComment!.replyCount, 9);
    });

    test('snake_case is accepted too', () {
      // The feed sends camelCase; a cached page or another endpoint may not.
      final event = EventDiscovery.fromMap(eventJson(topComment: {
        'id': 'c1',
        'author_name': 'Kofi',
        'content': 'lovely',
        'like_count': 7,
        'reply_count': 2,
      }));

      expect(event.topComment!.authorName, 'Kofi');
      expect(event.topComment!.likeCount, 7);
      expect(event.topComment!.replyCount, 2);
    });

    test('a comment with no id is dropped', () {
      // It could be drawn but not opened, and a line that does nothing when
      // tapped is worse than no line.
      expect(
        EventDiscovery.fromMap(
            eventJson(topComment: {'content': 'orphan'})).topComment,
        isNull,
      );
    });

    test('a comment with no text is dropped', () {
      expect(
        EventDiscovery.fromMap(
            eventJson(topComment: {'id': 'c1', 'content': '   '})).topComment,
        isNull,
      );
    });

    test('it survives a round trip through the cache', () {
      // Feed pages are written to disk and repainted from there on a cold
      // start; a comment that did not survive that would flash on first load
      // and never again.
      final original = EventDiscovery.fromMap(eventJson(topComment: {
        'id': 'c1',
        'authorName': 'Kofi',
        'content': 'lovely',
        'likeCount': 4,
        'replyCount': 1,
      }));

      final restored = EventDiscovery.fromMap(original.toMap());

      expect(restored.topComment!.id, 'c1');
      expect(restored.topComment!.likeCount, 4);
      expect(restored.topComment!.replyCount, 1);
    });

    test('copyWith does not drop it', () {
      final event = EventDiscovery.fromMap(eventJson(topComment: {
        'id': 'c1',
        'content': 'lovely',
      })).copyWith(likes: 5);

      expect(event.topComment, isNotNull);
    });
  });

  group('the line itself', () {
    const comment = TopComment(
      id: 'c1',
      authorName: 'Kofi',
      content: 'the light in the third one is unreal',
      likeCount: 312,
      replyCount: 9,
    );

    testWidgets('shows the count, the author and the comment', (t) async {
      await t.pumpWidget(
          host(TopCommentLine(comment: comment, onTap: () {})));

      expect(find.text('312'), findsOneWidget);
      expect(find.textContaining('Kofi'), findsOneWidget);
      expect(find.textContaining('the light in the third one'), findsOneWidget);
    });

    testWidgets('the reply count is hidden when there are none', (t) async {
      await t.pumpWidget(host(TopCommentLine(
        comment: const TopComment(
            id: 'c1', authorName: 'Kofi', content: 'nice', likeCount: 8),
        onTap: () {},
      )));

      expect(find.byIcon(Icons.mode_comment_outlined), findsNothing);
    });

    testWidgets('it is clamped to two lines so the block cannot jump',
        (t) async {
      // The caption it replaces is clamped to two. A taller comment would
      // grow the block for five seconds and shrink it back.
      await t.pumpWidget(host(TopCommentLine(
        comment: TopComment(
          id: 'c1',
          authorName: 'Kofi',
          content: 'a very long comment ' * 40,
          likeCount: 8,
        ),
        onTap: () {},
      )));

      final text = t.widget<Text>(find.byType(Text).last);
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('tapping it reports', (t) async {
      var tapped = false;
      await t.pumpWidget(
          host(TopCommentLine(comment: comment, onTap: () => tapped = true)));

      await t.tap(find.byType(TopCommentLine));

      expect(tapped, isTrue);
    });
  });
}

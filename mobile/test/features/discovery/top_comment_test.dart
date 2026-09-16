import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/top_comment_line.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// The standout comment, drawn above the post's own text.
///
/// It used to borrow the caption's line for five seconds and then give it back,
/// which meant the description and the hashtags were gone while the comment was
/// up and the comment was gone the rest of the time. The reference (Shorts)
/// stacks them instead — comment, then name, then caption — so nothing is ever
/// hidden to make room for anything else.
///
/// The whole feature is still about *not* drawing one most of the time: the
/// server only sends a comment that clears a floor and a margin over the
/// runner-up, so the client's half of the contract is that null is ordinary and
/// must never draw anything.
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

    test('the author avatar is read, under either spelling', () {
      // The capsule draws the commenter's picture, which the feed only started
      // sending when this moved above the caption.
      final camel = EventDiscovery.fromMap(eventJson(topComment: {
        'id': 'c1',
        'content': 'lovely',
        'authorAvatarUrl': 'https://cdn.example.com/kofi.jpg',
      }));
      final snake = EventDiscovery.fromMap(eventJson(topComment: {
        'id': 'c1',
        'content': 'lovely',
        'author_avatar_url': 'https://cdn.example.com/kofi.jpg',
      }));

      expect(camel.topComment!.authorAvatarUrl,
          'https://cdn.example.com/kofi.jpg');
      expect(snake.topComment!.authorAvatarUrl,
          'https://cdn.example.com/kofi.jpg');
    });

    test('a blank avatar is no avatar', () {
      // An empty string is a value, and it would send the image loader after
      // nothing. The capsule wants null so it can draw the initial instead.
      final event = EventDiscovery.fromMap(eventJson(topComment: {
        'id': 'c1',
        'content': 'lovely',
        'authorAvatarUrl': '   ',
      }));

      expect(event.topComment!.authorAvatarUrl, isNull);
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

    test('the avatar survives the cache too', () {
      // toMap has to carry it or a cold start draws initials on every capsule
      // until the feed is refetched.
      final original = EventDiscovery.fromMap(eventJson(topComment: {
        'id': 'c1',
        'content': 'lovely',
        'authorAvatarUrl': 'https://cdn.example.com/kofi.jpg',
      }));

      expect(EventDiscovery.fromMap(original.toMap()).topComment!.authorAvatarUrl,
          'https://cdn.example.com/kofi.jpg');
    });

    test('copyWith does not drop it', () {
      final event = EventDiscovery.fromMap(eventJson(topComment: {
        'id': 'c1',
        'content': 'lovely',
      })).copyWith(likes: 5);

      expect(event.topComment, isNotNull);
    });
  });

  group('the capsule', () {
    const comment = TopComment(
      id: 'c1',
      authorName: 'Kofi',
      content: 'the light in the third one is unreal',
      likeCount: 312,
      replyCount: 9,
    );

    BoxDecoration capsuleOf(WidgetTester t) => t
        .widgetList<Container>(find.descendant(
          of: find.byType(TopCommentLine),
          matching: find.byType(Container),
        ))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.shape != BoxShape.circle);

    testWidgets('carries the comment and nothing else', (t) async {
      await t.pumpWidget(host(TopCommentLine(comment: comment, onTap: () {})));

      expect(find.textContaining('the light in the third one'), findsOneWidget);

      // The reference capsule holds a picture and a sentence. The counts and
      // the author's name were the old inline treatment's way of earning its
      // place on the caption's line; above the caption it does not have to
      // argue for the space, and the numbers belong in the sheet this opens.
      expect(find.text('312'), findsNothing);
      expect(find.text('Kofi'), findsNothing);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(find.byIcon(Icons.mode_comment_outlined), findsNothing);
    });

    testWidgets('sits on a dark translucent capsule', (t) async {
      await t.pumpWidget(host(TopCommentLine(comment: comment, onTap: () {})));
      final decoration = capsuleOf(t);

      // Over an arbitrary photograph, and white text on it: opaque would read
      // as a panel cut out of the image, clear would be unreadable.
      expect(decoration.color!.a, greaterThan(0.0));
      expect(decoration.color!.a, lessThan(1.0));
      expect(decoration.borderRadius, isNotNull);
    });

    testWidgets('an author with no picture gets their initial', (t) async {
      await t.pumpWidget(host(TopCommentLine(
        comment: const TopComment(
            id: 'c1', authorName: 'kofi', content: 'nice'),
        onTap: () {},
      )));

      // A letter rather than a generic silhouette: every avatar in a feed of
      // these would otherwise be the same shape.
      expect(find.text('K'), findsOneWidget);
    });

    testWidgets('an author with no name at all still draws', (t) async {
      await t.pumpWidget(host(TopCommentLine(
        comment: const TopComment(id: 'c1', authorName: '', content: 'nice'),
        onTap: () {},
      )));

      expect(t.takeException(), isNull);
      expect(find.text('nice'), findsOneWidget);
    });

    testWidgets('it is clamped to two lines', (t) async {
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

    testWidgets('a short comment does not stretch across the photo',
        (t) async {
      await t.pumpWidget(host(TopCommentLine(
        comment: const TopComment(id: 'c1', authorName: 'Kofi', content: 'ha'),
        onTap: () {},
      )));

      // Sized to its content. A two-letter comment on a bar the width of the
      // screen reads as a banner rather than as something somebody said.
      //
      // The capsule, not the widget: the widget is an Align filling whatever
      // the card gives it, and the thing being drawn is what sits inside.
      final capsule = find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape != BoxShape.circle);

      expect(t.getSize(capsule).width, lessThan(390 * 0.9));
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

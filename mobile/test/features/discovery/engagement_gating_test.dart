import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/media/media_reaction_rail.dart';
import 'package:jperg_app/core/theme/app_icons.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/card_interaction_bar.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// `comments_enabled` closes the thread, and closes nothing else.
///
/// It was read for a while as "no feedback of any kind", which took the heart
/// off a post whose owner had merely declined a conversation: somebody who
/// liked it yesterday had no way to like it today, and nothing on the card
/// explained why. Reactions and comments are different things — one is a
/// number, the other is somebody talking — and only the second is the owner's
/// to switch off.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: child),
      ),
    );

CardInteractionBar bar({required bool commentsEnabled}) => CardInteractionBar(
      liked: false,
      disliked: false,
      saved: false,
      likeCount: 12,
      dislikeCount: 3,
      commentCount: 7,
      commentsEnabled: commentsEnabled,
      ext: AppThemeExtension.dark,
      onLike: () {},
      onDislike: () {},
      onComment: () {},
      onShare: () {},
      onSave: () {},
    );

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('CardInteractionBar', () {
    testWidgets('comments on: like, dislike and comment all present',
        (tester) async {
      await tester.pumpWidget(host(bar(commentsEnabled: true)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.thumb_down_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget);
    });

    testWidgets('comments off: the thread closes and the heart stays',
        (tester) async {
      await tester.pumpWidget(host(bar(commentsEnabled: false)));
      await tester.pumpAndSettle();

      // The regression this file now exists for.
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.thumb_down_outlined), findsOneWidget);

      // The comment glyph stays, drawn unavailable — the *same* glyph, dimmed.
      // A bar with no comment button at all reads as one that never had
      // comments, and the owner's decision is worth stating; a different icon
      // in its place said it by being a different drawing, which made the one
      // unavailable action on the bar the only one that did not look like
      // itself.
      expect(find.byIcon(Icons.comments_disabled_rounded), findsNothing);
      expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget);
      // Matched loosely: the count rides in the same label, so the
      // announcement is "Comments disabled" *and* the number.
      expect(
          find.bySemanticsLabel(RegExp('Comments disabled')), findsOneWidget);
    });

    testWidgets('and the closed one is dimmed, not drawn live', (tester) async {
      // Dimming is now the whole visual signal, so it has to actually be there
      // — and it has to reach the count, since a bright "7" over a greyed glyph
      // reads as a live button.
      await tester.pumpWidget(host(bar(commentsEnabled: true)));
      await tester.pumpAndSettle();
      final live =
          tester.widget<Icon>(find.byIcon(Icons.mode_comment_outlined)).color;

      await tester.pumpWidget(host(bar(commentsEnabled: false)));
      await tester.pumpAndSettle();
      final closed =
          tester.widget<Icon>(find.byIcon(Icons.mode_comment_outlined));
      final count = tester.widget<Text>(find.text('7'));

      expect(closed.color, isNot(live));
      expect(count.style?.color, closed.color);
    });

    testWidgets('share and save survive: they distribute, not react',
        (tester) async {
      await tester.pumpWidget(host(bar(commentsEnabled: false)));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Send'), findsOneWidget);
    });

    testWidgets(
        'the admin kill-switch silences comments without killing reactions',
        (tester) async {
      // Same rule one level up: the global toggle is about the comment feature,
      // and an admin disabling it app-wide has said nothing about likes.
      await tester.pumpWidget(host(bar(commentsEnabled: false)));
      await tester.pumpAndSettle();

      expect(
          find.bySemanticsLabel(RegExp('Comments disabled')), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.thumb_down_outlined), findsOneWidget);
    });
  });

  group('MediaReactionRail', () {
    // The rail over media is the other half of the same rule, and it used to
    // get it wrong: it dropped the comment button outright, so a closed thread
    // looked identical to a rail that never had comments.
    Widget rail({required bool commentsEnabled}) => host(
          MediaReactionRail(
            actions: [
              if (commentsEnabled)
                MediaReaction.comment(count: 7, onTap: () {})
              else
                MediaReaction.commentsDisabled(count: 7),
              MediaReaction.share(onTap: () {}),
            ],
          ),
        );

    // The bubble, whichever state it is in: the rail draws design's artwork
    // for the comment action, and a closed thread draws the same file.
    final bubble = find.byWidgetPredicate(
        (w) => w is AppSvgIcon && w.asset == AppIcons.comment);

    testWidgets('draws the comment action as unavailable, not absent',
        (tester) async {
      await tester.pumpWidget(rail(commentsEnabled: false));
      await tester.pumpAndSettle();

      // The same glyph the live action uses, and nothing from the icon font
      // standing in for it.
      expect(bubble, findsOneWidget);
      expect(find.byIcon(Icons.comments_disabled_rounded), findsNothing);
      // Matched loosely: the count merges into the same semantics node, so the
      // announcement is "Comments disabled" *and* the number.
      expect(
          find.bySemanticsLabel(RegExp('Comments disabled')), findsOneWidget);
    });

    testWidgets('the closed thread draws the same glyph as the open one',
        (tester) async {
      // What the fix is: an unavailable action is the action, drawn
      // unavailable. It used to be a crossed bubble out of the icon font — a
      // different shape *and* a different icon family from the live one beside
      // it.
      await tester.pumpWidget(rail(commentsEnabled: true));
      await tester.pumpAndSettle();
      expect(bubble, findsOneWidget);

      await tester.pumpWidget(rail(commentsEnabled: false));
      await tester.pumpAndSettle();
      expect(bubble, findsOneWidget);
    });

    testWidgets('dims the count along with the glyph', (tester) async {
      // A bright "7" over a greyed-out icon reads as a live button.
      await tester.pumpWidget(rail(commentsEnabled: false));
      await tester.pumpAndSettle();

      final glyph = tester.widget<AppSvgIcon>(bubble);
      final count = tester.widget<Text>(find.text('7'));

      expect(glyph.color, isNot(Colors.white));
      expect(count.style?.color, glyph.color);
    });

    testWidgets('the disabled action does nothing when tapped', (tester) async {
      await tester.pumpWidget(rail(commentsEnabled: false));
      await tester.pumpAndSettle();

      // No sheet, no navigation, no exception — the dimming and the label have
      // already said everything there is to say.
      await tester.tap(bubble);
      await tester.pumpAndSettle();

      expect(bubble, findsOneWidget);
    });

    testWidgets('the count survives the thread closing', (tester) async {
      // Comments left before the owner turned them off are still there and
      // still readable elsewhere; the number is not made untrue by the switch.
      await tester.pumpWidget(rail(commentsEnabled: false));
      await tester.pumpAndSettle();

      expect(find.text('7'), findsOneWidget);
    });
  });

  group('Photo.commentsEnabled', () {
    test('reads comments_enabled from the picture payload', () {
      final off = Photo.fromMap({
        'id': 'p1',
        'url': 'u',
        'comments_enabled': false,
      });
      expect(off.commentsEnabled, isFalse);

      final on = Photo.fromMap({
        'id': 'p2',
        'url': 'u',
        'comments_enabled': true,
      });
      expect(on.commentsEnabled, isTrue);
    });

    test('defaults to enabled when the field is absent', () {
      // Older payloads predate the setting, and the server default is enabled —
      // defaulting to false would silently strip reactions everywhere.
      final photo = Photo.fromMap({'id': 'p3', 'url': 'u'});
      expect(photo.commentsEnabled, isTrue);
    });
  });
}

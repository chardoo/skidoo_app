import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/media/media_reaction_rail.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/card_interaction_bar.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// `comments_enabled` is the owner's "no feedback on this" switch. It used to
/// hide only the comment button, leaving like and dislike live — so an event,
/// ad or campaign with engagement switched off still collected reactions.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: child),
      ),
    );

CardInteractionBar bar({
  required bool commentsEnabled,
  required bool reactionsEnabled,
}) =>
    CardInteractionBar(
      liked: false,
      disliked: false,
      saved: false,
      likeCount: 12,
      dislikeCount: 3,
      commentCount: 7,
      commentsEnabled: commentsEnabled,
      reactionsEnabled: reactionsEnabled,
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
    testWidgets('engagement on: like, dislike and comment all present',
        (tester) async {
      await tester.pumpWidget(
          host(bar(commentsEnabled: true, reactionsEnabled: true)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.thumb_down_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget);
    });

    testWidgets('engagement off: no like, no dislike, no comment',
        (tester) async {
      await tester.pumpWidget(
          host(bar(commentsEnabled: false, reactionsEnabled: false)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
      expect(find.byIcon(Icons.thumb_down_outlined), findsNothing);
      expect(find.byIcon(Icons.mode_comment_outlined), findsNothing);
      // The bar shows a struck-through comment icon in place of the button.
      expect(find.byIcon(Icons.comments_disabled_rounded), findsOneWidget);
    });

    testWidgets('share and save survive: they distribute, not react',
        (tester) async {
      await tester.pumpWidget(
          host(bar(commentsEnabled: false, reactionsEnabled: false)));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Send'), findsOneWidget);
    });

    testWidgets(
        'admin comments kill-switch silences comments without killing reactions',
        (tester) async {
      // The global toggle is about written comments. An admin disabling those
      // app-wide must not also remove every like.
      await tester.pumpWidget(
          host(bar(commentsEnabled: false, reactionsEnabled: true)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mode_comment_outlined), findsNothing);
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

    testWidgets('draws the comment action as unavailable, not absent',
        (tester) async {
      await tester.pumpWidget(rail(commentsEnabled: false));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mode_comment_outlined), findsNothing);
      expect(find.byIcon(Icons.comments_disabled_rounded), findsOneWidget);
      // Matched loosely: the count merges into the same semantics node, so the
      // announcement is "Comments disabled" *and* the number.
      expect(find.bySemanticsLabel(RegExp('Comments disabled')),
          findsOneWidget);
    });

    testWidgets('dims the count along with the glyph', (tester) async {
      // A bright "7" over a greyed-out icon reads as a live button.
      await tester.pumpWidget(rail(commentsEnabled: false));
      await tester.pumpAndSettle();

      final glyph = tester.widget<Icon>(
          find.byIcon(Icons.comments_disabled_rounded));
      final count = tester.widget<Text>(find.text('7'));

      expect(glyph.color, isNot(Colors.white));
      expect(count.style?.color, glyph.color);
    });

    testWidgets('the disabled action does nothing when tapped', (tester) async {
      await tester.pumpWidget(rail(commentsEnabled: false));
      await tester.pumpAndSettle();

      // No sheet, no navigation, no exception — the glyph has already said
      // everything there is to say.
      await tester.tap(find.byIcon(Icons.comments_disabled_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.comments_disabled_rounded), findsOneWidget);
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

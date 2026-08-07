import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
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

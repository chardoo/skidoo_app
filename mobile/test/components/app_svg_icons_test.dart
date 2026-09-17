import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:jperg_app/core/theme/app_icons.dart';
import 'package:jperg_app/components/media/media_rail_action.dart';
import 'package:jperg_app/components/media/media_reaction_rail.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The engagement rail draws design's own artwork.
///
/// Supplied as 24x24 SVGs — an outlined heart, bubble, bookmark and paper
/// plane, drawn from the same set the rest of the app's chrome comes from.
/// They are **rest states only**: there is no filled heart or bookmark
/// in the set, so an active reaction still comes from the icon font. That is
/// not a stopgap dressed as a decision — the rail says "you liked this" by
/// changing the glyph's shape and not only its colour, which
/// reaction_buttons_transparent_test enforces, and colour alone says nothing
/// to a reader who cannot separate red from white.
Widget _host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(body: Center(child: child)),
      ),
    );

Iterable<String> _assetsIn(WidgetTester t) => t
    .widgetList<SvgPicture>(find.byType(SvgPicture))
    .map((p) => (p.bytesLoader as SvgAssetLoader).assetName);

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  group('a resting reaction uses the supplied artwork', () {
    testWidgets('the heart', (t) async {
      await t.pumpWidget(_host(MediaReactionRail(actions: [
        MediaReaction.like(liked: false, count: 3, onTap: () {}),
      ])));

      expect(_assetsIn(t), contains(AppIcons.like));
    });

    testWidgets('the bubble, the bookmark and the plane', (t) async {
      await t.pumpWidget(_host(MediaReactionRail(actions: [
        MediaReaction.comment(count: 2, onTap: () {}),
        MediaReaction.bookmark(saved: false, onTap: () {}),
        MediaReaction.share(onTap: () {}),
      ])));

      expect(
        _assetsIn(t),
        containsAll([
          AppIcons.comment,
          AppIcons.save,
          AppIcons.share,
        ]),
      );
    });
  });

  group('an active reaction', () {
    testWidgets('falls back to the filled font glyph', (t) async {
      await t.pumpWidget(_host(MediaReactionRail(actions: [
        MediaReaction.like(liked: true, count: 3, onTap: () {}),
      ])));

      // The shape has to change, not just the tint — there is no filled heart
      // in the supplied set to change it with.
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(_assetsIn(t), isEmpty);
    });

    testWidgets('and a saved bookmark does the same', (t) async {
      await t.pumpWidget(_host(MediaReactionRail(actions: [
        MediaReaction.bookmark(saved: true, onTap: () {}),
      ])));

      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      expect(_assetsIn(t), isEmpty);
    });
  });

  group('the artwork is drawn like a font glyph', () {
    testWidgets('it takes the tint it is given', (t) async {
      await t.pumpWidget(_host(const AppSvgIcon(
        AppIcons.like,
        size: 24,
        color: Colors.red,
      )));

      // The artwork ships with the exporter's grey baked in; a source-in
      // filter is what makes one file serve every tint the app needs.
      final picture =
          t.widgetList<SvgPicture>(find.byType(SvgPicture)).first;
      expect(picture.colorFilter,
          const ColorFilter.mode(Colors.red, BlendMode.srcIn));
    });

    testWidgets('and carries the rail shadow, which SvgPicture cannot',
        (t) async {
      // Every glyph over a photograph is separated from it by a tight drop
      // shadow. Icon takes that as a parameter; ImageIcon has nowhere to put
      // it, so it is drawn as an offset copy beneath.
      await t.pumpWidget(_host(const AppSvgIcon(
        AppIcons.like,
        size: 24,
        shadows: [Shadow(color: Colors.black, offset: Offset(0, 1))],
      )));

      expect(find.byType(SvgPicture), findsNWidgets(2));
      expect(find.byType(Transform), findsWidgets);
    });

    testWidgets('no shadow asked for is one glyph, not two', (t) async {
      await t.pumpWidget(_host(
        const AppSvgIcon(AppIcons.like, size: 24),
      ));

      expect(find.byType(SvgPicture), findsOneWidget);
    });
  });

  testWidgets('a reaction with no supplied artwork still draws', (t) async {
    // Download and the disabled-comments glyph have no counterpart in the set.
    await t.pumpWidget(_host(MediaReactionRail(actions: [
      MediaReaction.download(onTap: () {}),
    ])));

    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    expect(_assetsIn(t), isEmpty);
  });

  testWidgets('MediaRailAction prefers the asset when given both', (t) async {
    await t.pumpWidget(_host(MediaRailAction(
      icon: Icons.favorite_border_rounded,
      assetIcon: AppIcons.like,
      onTap: () {},
    )));

    expect(find.byType(SvgPicture), findsWidgets);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
  });
}

/// The three empty-state marks, which are PNGs among a set of SVGs.
///
/// The designs call for glyphs that say what is *missing* rather than what the
/// thing is — a bookmark with a tick in it, a heart with a line through it, one
/// speech bubble. None of those are in the supplied vector set, so they arrived
/// separately as bitmaps and [AppEmptyState] picks by file extension.
///
/// That branch is the reason this file exists. A path typo in an SVG constant
/// fails loudly in any test that renders it; a path typo in a PNG constant
/// throws only when the screen is actually opened, which for an empty state is
/// the one path nobody exercises by hand. So each is loaded here for real.
///
/// The tint is asserted for a less obvious reason. The empty state picks
/// between two accent shades depending on the ground it is drawn on, because
/// the lighter one measures under the 3:1 WCAG 1.4.11 asks of a graphic on the
/// light page. These bitmaps ship with the brand green already baked in, so
/// they would look perfectly fine while quietly ignoring that choice — and the
/// failure is invisible unless something checks the colour is being applied.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/app_empty_state.dart';
import 'package:jperg_app/core/theme/app_icons.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

Widget host(String icon, AppThemeExtension ext) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: [ext]),
        home: Scaffold(
          body: AppEmptyState(icon: icon, message: 'Nothing here'),
        ),
      ),
    );

/// The three that are raster, and the screen each one belongs to.
const rasterMarks = <String, String>{
  'saved': AppIcons.emptySaved,
  'likes': AppIcons.emptyLikes,
  'chat': AppIcons.emptyChat,
};

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  group('the raster marks', () {
    rasterMarks.forEach((name, asset) {
      testWidgets('$name is a real bundled file', (tester) async {
        // `Image.asset` resolves against the manifest, so a path that is not
        // declared in pubspec.yaml — or simply misspelt — fails here rather
        // than on somebody's phone.
        await tester.pumpWidget(host(asset, AppThemeExtension.dark));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: '$asset did not load');
        expect(find.byType(Image), findsOneWidget);
      });

      testWidgets('$name is tinted, not drawn in its own ink', (tester) async {
        await tester.pumpWidget(host(asset, AppThemeExtension.dark));
        await tester.pumpAndSettle();

        final image = tester.widget<Image>(find.byType(Image));
        expect(image.color, AppThemeExtension.dark.accentGold);
      });
    });
  });

  testWidgets('on a light ground they take the darker accent', (tester) async {
    // The contrast rule, reaching the bitmaps as well as the vectors. The
    // lighter accent on the light page measures 2.8:1 for a graphic, under the
    // 3:1 WCAG 1.4.11 requires, and a baked-in green would sit at exactly that
    // failing value forever.
    await tester.pumpWidget(host(AppIcons.emptyLikes, AppThemeExtension.light));
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.color, AppThemeExtension.light.accentGoldDark);
    expect(image.color, isNot(AppThemeExtension.light.accentGold));
  });

  testWidgets('a vector mark still draws as a vector', (tester) async {
    // The other half of the branch. If the extension check were dropped, every
    // SVG would go down the Image path and fail to decode.
    await tester.pumpWidget(host(AppIcons.camera, AppThemeExtension.dark));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsNothing);
  });
}

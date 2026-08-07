import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/customThemeData.dart';
import 'package:jperg_app/core/theme/dark_media_surface.dart';

/// The media feeds are dark whatever theme the app is in, so the photograph is
/// the brightest thing on screen. A light surround competes with the image and
/// undercuts the white-on-shadow overlays that sit on the media.
///
/// The mechanism matters as much as the colour: the feed doesn't reach for dark
/// values itself, it changes what "the theme" resolves to for everything inside
/// it. A card several layers down asking for `homeBackground` gets the dark one
/// without knowing this widget exists.
/// [Styles] resolves `.sp`, so the theme has to be built inside
/// [ScreenUtilInit] rather than handed in ready-made.
Widget host({required bool light, required Widget child}) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: light ? Styles.light : Styles.dark,
        home: Scaffold(body: DarkMediaSurface(child: child)),
      ),
    );

void main() {
  testWidgets('a descendant of a light app still resolves the dark palette',
      (t) async {
    AppThemeExtension? seen;
    Brightness? brightness;

    await t.pumpWidget(host(
      light: true,
      child: Builder(builder: (context) {
        seen = Theme.of(context).extension<AppThemeExtension>();
        brightness = Theme.of(context).brightness;
        return const SizedBox.shrink();
      }),
    ));

    expect(seen, AppThemeExtension.dark);
    expect(brightness, Brightness.dark,
        reason: 'widgets that branch on brightness must see dark too');
  });

  testWidgets('it paints the dark background itself', (t) async {
    // The Scaffold behind it is light; without painting its own ground the
    // letterbox around a photo would still come out pale.
    await t.pumpWidget(host(light: true, child: const SizedBox.expand()));

    final painted = t
        .widgetList<ColoredBox>(find.descendant(
          of: find.byType(DarkMediaSurface),
          matching: find.byType(ColoredBox),
        ))
        .map((b) => b.color);

    expect(painted, contains(AppThemeExtension.dark.homeBackground));
  });

  testWidgets('the status bar switches to light glyphs', (t) async {
    // The feed runs under the status bar. In a light app the platform default
    // is dark glyphs, which disappear on this surface.
    await t.pumpWidget(host(light: true, child: const SizedBox.expand()));

    final region = t.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>));
    expect(region.value.statusBarIconBrightness, Brightness.light);
  });

  testWidgets('a dark app is unaffected — same palette either way', (t) async {
    AppThemeExtension? seen;

    await t.pumpWidget(host(
      light: false,
      child: Builder(builder: (context) {
        seen = Theme.of(context).extension<AppThemeExtension>();
        return const SizedBox.shrink();
      }),
    ));

    expect(seen, AppThemeExtension.dark);
  });

  test('the theme tokens themselves still follow the app', () {
    // Deliberately not "darken mediaLetterbox in both palettes": media is
    // letterboxed in themed contexts too — a grid tile, a sheet preview — and
    // those should stay light in a light app. Only the feed opts out.
    expect(AppThemeExtension.light.mediaLetterbox,
        isNot(AppThemeExtension.dark.mediaLetterbox));
  });
}

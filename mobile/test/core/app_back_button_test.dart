import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

Widget host(Widget child, {GlobalKey<NavigatorState>? navigator}) =>
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        navigatorKey: navigator,
        theme:
            ThemeData.dark().copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: child),
      ),
    );

/// Going back used to look like a different control on nearly every screen:
/// four different glyphs at five different sizes, plus Flutter's [BackButton],
/// which renders a *different* icon per platform. One control now — but not one
/// glyph, which is the correction this file carries.
///
/// The app drew iOS's chevron on both platforms. On Android back is an arrow
/// everywhere in the system, so every screen's back control disagreed with the
/// keyboard, the share sheet and every other app on the device. Per-platform is
/// the point of a back button: it should be the mark the reader already knows.
void main() {
  /// Draws [AppBackButton] as [platform] would see it.
  ///
  /// The override is cleared inside the test body, not in a tear-down: the
  /// binding asserts every foundation debug variable is back to null the moment
  /// the body returns, which is before any tear-down runs.
  Future<IconData> glyphOn(WidgetTester t, TargetPlatform platform) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await t.pumpWidget(host(const AppBackButton()));
      await t.pumpAndSettle();
      return t.widget<Icon>(find.byType(Icon)).icon!;
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('draws iOS the chevron', (t) async {
    expect(
      await glyphOn(t, TargetPlatform.iOS),
      Icons.arrow_back_ios_new_rounded,
    );
  });

  testWidgets('draws Android the full arrow', (t) async {
    expect(await glyphOn(t, TargetPlatform.android), Icons.arrow_back_rounded);
  });

  test('and sizes each glyph for what it is', () {
    // The chevron is tall and narrow, so 20 draws a mark about the size of a
    // 24 dp arrow. One number for both would leave the arrow visibly small
    // against every other icon in an app bar.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      expect(AppBackButton.defaultSize, 20);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(AppBackButton.defaultSize, 24);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('pops the route it is on', (t) async {
    final navigator = GlobalKey<NavigatorState>();
    await t.pumpWidget(host(const Text('first'), navigator: navigator));
    await t.pumpAndSettle();

    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: AppBackButton()),
    ));
    await t.pumpAndSettle();

    await t.tap(find.byType(AppBackButton));
    await t.pumpAndSettle();

    expect(find.text('first'), findsOneWidget);
  });

  test('no screen rolls its own back icon', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('app_back_button.dart')) continue;

      final source = entity.readAsStringSync();
      // `BackButton(` is Flutter's own, whose glyph follows the platform.
      // Any `Icons.arrow_back*` named outside the widget is a screen picking
      // its own glyph again — including the chevron, which has to stay behind
      // [AppBackButton.icon] so a screen cannot draw iOS's mark on Android.
      if (source.contains('Icons.arrow_back') ||
          RegExp(r'\bBackButton\(').hasMatch(source)) {
        offenders.add(entity.path);
      }
    }

    expect(offenders, isEmpty,
        reason: 'use AppBackButton (or AppBackButton.icon) instead');
  });
}

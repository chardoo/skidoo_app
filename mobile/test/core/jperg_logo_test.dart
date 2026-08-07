import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/jperg_logo.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

Widget host(AppThemeExtension ext, {Widget? child}) => MaterialApp(
      theme: ThemeData(
        brightness: ext == AppThemeExtension.light
            ? Brightness.light
            : Brightness.dark,
        extensions: [ext],
      ),
      home: Scaffold(body: child ?? const JpergLogo()),
    );

Image imageOf(WidgetTester t) => t.widget<Image>(find.byType(Image));

/// The app used to draw its own lockup: a rounded square holding the letter
/// "S" — from a previous name — next to the word "JPERG". Three screens each
/// built their own, so the brand was three different shapes and none of them
/// was the actual logo.
void main() {
  testWidgets('renders the wordmark asset', (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark));

    final provider = imageOf(t).image as AssetImage;
    expect(provider.assetName, 'assets/logo/jperg_wordmark_alpha.png');
  });

  testWidgets('takes its colour from the theme, in both modes', (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark));
    expect(imageOf(t).color, AppThemeExtension.dark.accentGold);

    await t.pumpWidget(host(AppThemeExtension.light));
    expect(imageOf(t).color, AppThemeExtension.light.accentGold);
  });

  testWidgets('is painted through the artwork, not over it', (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark));
    // The asset is alpha-only. Any blend mode but srcIn would paint a solid
    // rectangle of the tint instead of the logo's shape.
    expect(imageOf(t).colorBlendMode, BlendMode.srcIn);
  });

  testWidgets('a caller sets height; the width follows the artwork',
      (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark,
        child: const Center(child: JpergLogo(height: 30))));

    final size = t.getSize(find.byType(JpergLogo));
    expect(size.height, 30);
    expect(size.width, closeTo(30 * JpergLogo.aspectRatio, 0.5));
  });

  testWidgets('an explicit colour wins over the theme', (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark,
        child: const JpergLogo(color: Color(0xFFFFFFFF))));
    expect(imageOf(t).color, const Color(0xFFFFFFFF));
  });

  test('the asset it needs is on disk and declared', () {
    expect(File('assets/logo/jperg_wordmark_alpha.png').existsSync(), isTrue);
    expect(File('pubspec.yaml').readAsStringSync(), contains('assets/logo/'));
  });

  test('no screen still draws the old "S" lockup', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      // The badge's letter, and the wordmark that used to sit beside it.
      if (RegExp("'S',").hasMatch(source) || source.contains("'JPERG'")) {
        offenders.add(entity.path);
      }
    }

    expect(offenders, isEmpty, reason: 'use JpergLogo instead');
  });
}

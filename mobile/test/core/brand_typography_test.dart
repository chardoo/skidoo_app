import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/theme/customThemeData.dart';

/// The brand pairs two typefaces and gives each a job: Syne for headers, DM
/// Sans for body (brand guidelines, Typography). Both halves are easy to break
/// silently — a header written as a hand-typed `TextStyle` quietly takes body
/// type, and a font asset dropped from pubspec falls back to Roboto/SF with no
/// error anywhere. This pins the split and the bundle.
void main() {
  // Every tier sizes itself with `.sp`, so the scale does not exist until
  // screenutil has a screen to scale against.
  setUpAll(() => ScreenUtil.configure(
        data: const MediaQueryData(size: Size(390, 844)),
        designSize: const Size(390, 844),
        minTextAdapt: false,
        splitScreenMode: false,
      ));

  group('the split', () {
    test('headers are Syne', () {
      for (final tier in {
        'title': AppTypography.title,
        'headline': AppTypography.headline,
        'display': AppTypography.display,
      }.entries) {
        expect(tier.value.fontFamily, 'Syne', reason: '${tier.key} is a header');
      }
    });

    test('body tiers name no family, so they inherit DM Sans', () {
      // Deliberately unset rather than spelled out: `ThemeData.fontFamily` is
      // the one place the body face is chosen, and a tier that repeats it is a
      // second place to have to change.
      for (final tier in {
        'micro': AppTypography.micro,
        'label': AppTypography.label,
        'caption': AppTypography.caption,
        'captionBold': AppTypography.captionBold,
        'body': AppTypography.body,
        'bodyBold': AppTypography.bodyBold,
        'bodyLarge': AppTypography.bodyLarge,
        'bodyLargeBold': AppTypography.bodyLargeBold,
        'subtitle': AppTypography.subtitle,
      }.entries) {
        expect(tier.value.fontFamily, isNull, reason: '${tier.key} is body');
      }
    });

    test('the theme sets DM Sans as the app-wide default', () {
      for (final theme in [Styles.light, Styles.dark]) {
        expect(theme.textTheme.bodyMedium?.fontFamily, 'DM Sans');
      }
    });

    test('an AppBar title is a header', () {
      for (final theme in [Styles.light, Styles.dark]) {
        expect(theme.appBarTheme.titleTextStyle?.fontFamily, 'Syne');
      }
    });
  });

  group('the bundle', () {
    // Read out of the manifest the build generates, not out of pubspec: this
    // is what actually ships, and it is the thing that goes quiet — a family
    // that never made it into the bundle renders in Roboto/SF instead of
    // throwing.
    // Icon fonts (MaterialIcons, cupertino_icons) ride in the same manifest
    // and are not typography.
    late Map<String, List<dynamic>> ours;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      ours = {
        for (final family in manifest)
          if (!(family['family'] as String).contains('Icons'))
            family['family'] as String: family['fonts'] as List,
      };
    });

    test('bundles the two brand families and nothing else', () {
      expect(ours.keys, ['Syne', 'DM Sans']);
    });

    test('every declared asset exists', () {
      for (final family in ours.entries) {
        for (final font in family.value) {
          expect(File(font['asset']).existsSync(), isTrue,
              reason: '${family.key}: ${font['asset']}');
        }
      }
    });

    test('covers every weight the app asks for', () {
      // Audited from the `FontWeight.wNNN` call sites. Syne's `wght` axis stops
      // at 800 and has no Black, which is fine as long as nothing set in Syne
      // asks for w900 — the header tiers above top out at w800.
      final weights = {
        for (final family in ours.entries)
          family.key: {for (final font in family.value) font['weight']}
      };
      expect(weights['DM Sans'], {400, 500, 600, 700, 800, 900});
      expect(weights['Syne'], {400, 500, 600, 700, 800});
    });
  });
}

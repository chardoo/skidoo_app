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
      // Syne's `wght` axis stops at 800 and has no Black. That is fine only as
      // long as nothing set in Syne asks for w900 — which the call-site group
      // below is what actually holds to.
      final weights = {
        for (final family in ours.entries)
          family.key: {for (final font in family.value) font['weight']}
      };
      expect(weights['DM Sans'], {400, 500, 600, 700, 800, 900});
      expect(weights['Syne'], {400, 500, 600, 700, 800});
    });
  });

  group('the call sites', () {
    // Read off the source, because these are properties of ~130 hand-typed
    // `TextStyle`s scattered across the app rather than of the scale — there
    // is no object to assert against. Both rules below were broken by exactly
    // one thing: styles carried over from Poppins with their old numbers
    // still on them.
    final syneStyles = <({String where, String source})>[];

    setUpAll(() {
      final block = RegExp(r'TextStyle\((?:[^()]|\([^()]*\))*\)', dotAll: true);
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        for (final match in block.allMatches(source)) {
          final style = match.group(0)!;
          if (!style.contains('displayFontFamily') && !style.contains("'Syne'")) {
            continue;
          }
          final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
          syneStyles.add((where: '${file.path}:$line', source: style));
        }
      }
    });

    test('there are Syne styles to check', () {
      // A scan that silently matches nothing would pass both tests below.
      expect(syneStyles.length, greaterThan(100));
    });

    test('none asks for a weight Syne does not have', () {
      final offenders = [
        for (final style in syneStyles)
          if (style.source.contains('FontWeight.w900')) style.where,
      ];
      expect(offenders, isEmpty,
          reason: 'Syne stops at w800; asking for Black gets the nearest face, '
              'synthetically emboldened on iOS');
    });

    test('none tightens the tracking Syne ships with', () {
      final offenders = [
        for (final style in syneStyles)
          if (RegExp(r'letterSpacing:\s*-').hasMatch(style.source)) style.where,
      ];
      expect(offenders, isEmpty,
          reason: 'negative tracking is a Poppins habit — Syne is already '
              'narrow, and tightening it closes the counters');
    });
  });

  group('the scale', () {
    // The design file names seven sizes and four weights. The app had drifted
    // to 22 sizes and a vocabulary of its own — w600 and w800 exist nowhere in
    // the file — which is most of why the type read as nearly-right. These two
    // scan every `fontSize:` and `FontWeight.` in lib/, not just the tiers,
    // because the tiers are 32 of ~900 call sites.
    final sizes = <double>{12, 14, 15, 16, 18, 22, 24};
    const weights = {'w300', 'w400', 'w500', 'w700', 'normal', 'bold'};

    /// Sizes the scale deliberately does not cover, each with a reason it is
    /// not text: unread-count bubbles and micro tags below it (see
    /// [AppTypography.badge] / [AppTypography.tag]), and above it a countdown,
    /// an emoji glyph and the letters in an avatar.
    final outside = <double>{8, 9, 10, 10.5, 11, 11.5, 27, 28, 36, 40, 56};

    late String allSource;

    setUpAll(() {
      allSource = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.readAsStringSync())
          .join('\n');
    });

    test('every size is a step on the scale, or deliberately off it', () {
      final used = RegExp(r'fontSize:\s*([0-9.]+)\.sp')
          .allMatches(allSource)
          .map((m) => double.parse(m.group(1)!))
          .toSet();
      expect(used.difference(sizes).difference(outside), isEmpty,
          reason: 'a size between two steps is a design decision, not a '
              'rounding one — put it in the file first');
    });

    test('every weight is one of the four the file names', () {
      final used = RegExp(r'FontWeight\.(\w+)')
          .allMatches(allSource)
          .map((m) => m.group(1)!)
          .toSet();
      expect(used.difference(weights), isEmpty,
          reason: 'the file has light/regular/medium/bold and no semibold');
    });

    test('the tiers are built from the scale', () {
      for (final tier in {
        'caption': AppTypography.caption,
        'body': AppTypography.body,
        'bodyLarge': AppTypography.bodyLarge,
        'subtitle': AppTypography.subtitle,
        'title': AppTypography.title,
        'headline': AppTypography.headline,
        'display': AppTypography.display,
      }.entries) {
        expect(sizes, contains(tier.value.fontSize), reason: tier.key);
        expect(weights, contains(_nameOf(tier.value.fontWeight!)),
            reason: tier.key);
      }
    });
  });
}

/// `FontWeight.w500` prints as `FontWeight.w500`; this is the tail of it.
String _nameOf(FontWeight w) => w.toString().split('.').last;

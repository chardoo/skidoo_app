/// `hintColor` has to be readable on the ground it sits on.
///
/// It was the ground: near-black `#1F1F1D` for dark, pure white for light —
/// each one roughly the surface behind it, so anything drawn in it was
/// invisible in whichever theme was on. The light half is what hid
/// "How we handle your data:" on Manage Face Data and "Read them first:" on
/// the verify-terms screen, where the prefix of `LegalLinksRow` falls back to
/// it. Sign-up escaped only by passing a colour of its own, which is the kind
/// of local workaround that hides a broken default rather than fixing it.
///
/// Contrast is computed rather than eyeballed because the failure is a
/// *ratio*, and a colour can look fine in a screenshot while failing anybody
/// who needs the contrast.
///
/// Built through `ScreenUtilInit` because the theme sizes its text in `.sp`,
/// so `Styles.light` cannot be evaluated until ScreenUtil exists — which is
/// why these are widget tests over a plain unit test.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/customThemeData.dart';

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// The theme as a screen actually receives it.
Future<ThemeData> resolve(WidgetTester t, {required bool dark}) async {
  late ThemeData captured;
  await t.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      // Evaluated inside the builder, after ScreenUtil is initialised.
      builder: (_, __) => MaterialApp(
        theme: dark ? Styles.dark : Styles.light,
        home: Builder(
          builder: (context) {
            captured = Theme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await t.pump();
  return captured;
}

void main() {
  /// 4.5:1 is AA for body text. These labels are small and grey by intention,
  /// so they are exactly the case the threshold exists for.
  const aa = 4.5;

  group('hintColor', () {
    testWidgets('is readable on the light ground', (t) async {
      final theme = await resolve(t, dark: false);
      final ext = theme.extension<AppThemeExtension>()!;
      final ratio = contrast(theme.hintColor, ext.cardSurface);

      expect(
        ratio,
        greaterThanOrEqualTo(aa),
        reason: 'hintColor on the light card is '
            '${ratio.toStringAsFixed(2)}:1 — it was pure white here, which is '
            'the card itself',
      );
    });

    testWidgets('is readable on the dark ground', (t) async {
      final theme = await resolve(t, dark: true);
      final ext = theme.extension<AppThemeExtension>()!;
      final ratio = contrast(theme.hintColor, ext.cardSurface);

      expect(ratio, greaterThanOrEqualTo(aa),
          reason: 'hintColor on the dark card is '
              '${ratio.toStringAsFixed(2)}:1');
    });

    /// The exact shape of the old bug: the hint *was* the surface, so the
    /// ratio was 1:1 and the text simply was not there.
    testWidgets('is never the surface it is drawn on', (t) async {
      for (final dark in [false, true]) {
        final theme = await resolve(t, dark: dark);
        final ext = theme.extension<AppThemeExtension>()!;
        expect(theme.hintColor, isNot(ext.cardSurface), reason: 'dark=$dark');
        expect(theme.hintColor, isNot(ext.homeBackground),
            reason: 'dark=$dark');
      }
    });
  });
}

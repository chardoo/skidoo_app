import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/customThemeData.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';

/// A snackbar has to be readable in both themes, and an error one most of all
/// — it is the app's only account of what just went wrong, it covers the
/// bottom of the screen for three seconds, and then it is gone.
///
/// In dark mode it was not. The bars set a background and left the text to the
/// theme; Material resolves snackbar content to `colorScheme.onInverseSurface`,
/// which falls back to `colorScheme.surface` when a scheme does not name it —
/// #1F1F1D here. So a failure was reported as near-black text on dark red, at
/// about 1.3:1.
///
/// These measure the contrast rather than naming a colour, because the colour
/// is not the promise. The threshold is WCAG AA for body text.
void main() {
  setUpAll(() => ScreenUtil.configure(
        data: const MediaQueryData(size: Size(390, 844)),
        designSize: const Size(390, 844),
        minTextAdapt: false,
        splitScreenMode: false,
      ));

  /// WCAG relative luminance.
  double luminanceOf(Color c) {
    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  double contrast(Color a, Color b) {
    final la = luminanceOf(a), lb = luminanceOf(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// Raises a snackbar and reports what was actually drawn: the fill behind it
  /// and the colour the message came out in.
  Future<({Color background, Color text})> show(
    WidgetTester t, {
    required ThemeData theme,
    required void Function(BuildContext) raise,
  }) async {
    const message = 'Something went wrong';
    await t.pumpWidget(MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => raise(context),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('go'));
    // Let the bar animate in, so what is measured is what is on screen.
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));

    final text = find.text(message);
    expect(text, findsOneWidget, reason: 'the snackbar never appeared');

    final style = t.widget<Text>(text).style;
    final material = t.widget<Material>(find.ancestor(
      of: text,
      matching: find.byType(Material),
    ).first);

    return (
      background: material.color ??
          Theme.of(t.element(text)).snackBarTheme.backgroundColor!,
      text: style?.color ??
          DefaultTextStyle.of(t.element(text)).style.color!,
    );
  }

  // Resolved inside the tests, not in the loop header: the themes size their
  // type with `.sp`, so building one before setUpAll has configured screenutil
  // throws while the file is still loading.
  ThemeData themeNamed(String name) =>
      name == 'light' ? Styles.light : Styles.dark;

  for (final themeName in ['light', 'dark']) {
    group('in $themeName mode', () {
      for (final (kind, raise) in <(String, void Function(BuildContext))>[
        ('error', _raiseError),
        ('success', _raiseSuccess),
        ('info', _raiseInfo),
      ]) {
        testWidgets('a $kind snackbar is legible', (t) async {
          final drawn =
              await show(t, theme: themeNamed(themeName), raise: raise);

          expect(
            contrast(drawn.text, drawn.background),
            greaterThanOrEqualTo(4.5),
            reason: '$kind in $themeName: ${drawn.text} on ${drawn.background}',
          );
        });
      }

      testWidgets('a bare SnackBar is legible too', (t) async {
        // Three call sites raise one directly rather than through
        // [AppSnackBar] — the music sheet and the notifications list. They
        // take their colours from the theme, so the theme has to have them.
        final drawn = await show(
          t,
          theme: themeNamed(themeName),
          raise: (context) => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Something went wrong')),
          ),
        );

        expect(
          contrast(drawn.text, drawn.background),
          greaterThanOrEqualTo(4.5),
          reason: 'bare in $themeName: ${drawn.text} on ${drawn.background}',
        );
      });
    });
  }

  // There is deliberately no test here on `colorScheme.inverseSurface` /
  // `onInverseSurface`, which the theme now names explicitly. Every property
  // worth asserting about that pair — that they oppose each other, that one is
  // legible on the other — is *also* true of the fallbacks they replace, so
  // such a test passes with the fix reverted and guards nothing. What the
  // fallback actually breaks is text on a caller's own background, and that is
  // what the bars above measure.
}

void _raiseError(BuildContext context) =>
    AppSnackBar.error(context, 'Something went wrong');

void _raiseSuccess(BuildContext context) =>
    AppSnackBar.success(context, 'Something went wrong');

void _raiseInfo(BuildContext context) =>
    AppSnackBar.info(context, 'Something went wrong');

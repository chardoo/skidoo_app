import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/verified_badge.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The verified tick is one widget in one colour.
///
/// It used to be drawn at six call sites in three colours — `infoBlue` on the
/// creator profile, the public profile and the chat room tile, `accentGold` in
/// search, the portfolio editor and the verification form — so the same claim
/// about the same account changed colour depending on which screen you reached
/// it from.
///
/// Two things are pinned here: that the colour is the brand green resolved
/// against the ground it sits on, and — in the last group — that no screen has
/// quietly gone back to drawing its own tick.
Widget host(Widget child, {required AppThemeExtension ext}) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: [ext]),
        home: Scaffold(backgroundColor: ext.homeBackground, body: child),
      ),
    );

Color _iconColour(WidgetTester t) =>
    t.widget<Icon>(find.byIcon(Icons.verified_rounded)).color!;

void main() {
  testWidgets('it is green on the dark ground', (t) async {
    await t.pumpWidget(host(const VerifiedBadge(), ext: AppThemeExtension.dark));
    await t.pump();

    expect(_iconColour(t), AppThemeExtension.dark.accentGold);
    expect(_iconColour(t), const Color(0xFF1D9E75));
  });

  testWidgets('it takes the darker green on the light ground', (t) async {
    // #1D9E75 is only 3.15:1 on the light background — under the 4.5:1 a glyph
    // needs — so the accent's declared partner is used there instead. Not a
    // fourth colour: the palette as intended.
    await t.pumpWidget(host(const VerifiedBadge(), ext: AppThemeExtension.light));
    await t.pump();

    expect(_iconColour(t), AppThemeExtension.light.accentGoldDark);
    expect(_iconColour(t), const Color(0xFF16795B));
  });

  testWidgets('it is never blue', (t) async {
    // The specific regression: blue is the tick other platforms use for
    // something they verify differently from us, and three screens had it.
    for (final ext in [AppThemeExtension.dark, AppThemeExtension.light]) {
      await t.pumpWidget(host(const VerifiedBadge(), ext: ext));
      await t.pump();
      expect(_iconColour(t), isNot(ext.infoBlue));
    }
  });

  testWidgets('it draws nothing when the account is not verified', (t) async {
    await t.pumpWidget(host(
      const VerifiedBadge(isVerified: false),
      ext: AppThemeExtension.dark,
    ));
    await t.pump();

    expect(find.byIcon(Icons.verified_rounded), findsNothing);
  });

  testWidgets('a screen reader is told what it means', (t) async {
    await t.pumpWidget(host(
      const VerifiedBadge(semanticLabel: 'Official account'),
      ext: AppThemeExtension.dark,
    ));
    await t.pump();

    expect(find.bySemanticsLabel('Official account'), findsOneWidget);
  });

  group('no screen draws its own tick', () {
    /// Every `Icons.verified_rounded` outside the shared widget, with the
    /// colour it was given.
    ///
    /// A source scan rather than a widget test because the point is coverage:
    /// a new screen adding its own blue tick is exactly the regression, and no
    /// amount of pumping the badge itself would catch it.
    List<String> offendingLines() {
      final offenders = <String>[];
      final allowed = {
        // Its own "Verified" status card, which is a page heading rather than
        // a badge beside a name — it uses `accentOnGround` directly.
        'lib/features/verification/presentation/verification_form.dart',
        // The hero glyph on the premium invite, same resolution.
        'lib/features/photographers/presentation/widgets/premium_invite_prompt.dart',
        // The notifications list colours each row by the notification's
        // *category*, not by what its glyph depicts. Making this one green
        // would break that consistency instead of adding to this one.
        'lib/features/notifications/presentation/pages/notifications_page.dart',
        // The widget itself.
        'lib/core/common/widgets/verified_badge.dart',
      };

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (allowed.contains(entity.path)) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('Icons.verified_rounded')) {
            offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
      return offenders;
    }

    test('every tick comes from VerifiedBadge', () {
      expect(
        offendingLines(),
        isEmpty,
        reason: 'Use VerifiedBadge instead of drawing Icons.verified_rounded '
            'directly — that is how the badge ended up in three colours.',
      );
    });
  });
}

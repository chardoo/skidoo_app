import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jperg_app/core/common/widgets/app_empty_state.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/theme/customThemeData.dart';
import 'package:jperg_app/features/user_profile/presentation/widgets/profile_photo_grid.dart';

/// Every list that can be empty says so the same way.
///
/// There were three answers to "we have nothing to show you" and the
/// differences were nobody's decision: the inbox drew a tinted disc with a Syne
/// title, the profile tabs drew a half-faded grey glyph with the title in body
/// type, and the shared widget drew a third icon size again. Three screens,
/// three designs.
///
/// These hold the single answer in place. The size and colour tests matter
/// most: they are the thing that drifted, and they drift silently — nothing
/// fails when a caller passes its own 40px grey icon, it just stops matching
/// the screen next to it.
void main() {
  Widget host(Widget child, {bool dark = true}) => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: dark ? Styles.dark : Styles.light,
          home: Scaffold(body: child),
        ),
      );

  AppThemeExtension ext(bool dark) =>
      dark ? AppThemeExtension.dark : AppThemeExtension.light;

  group('the one drawing', () {
    testWidgets('the glyph sits in a tinted disc, in the accent', (t) async {
      await t.pumpWidget(host(const AppEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        message: 'No messages yet',
      )));
      await t.pump();

      final icon = t.widget<Icon>(find.byType(Icon));
      expect(icon.color, ext(true).accentGold);

      // The disc, not a bare glyph. It is what makes the state look designed
      // rather than like a missing image.
      final disc = t.widget<Container>(find.ancestor(
        of: find.byType(Icon),
        matching: find.byType(Container),
      ));
      final decoration = disc.decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('the title is Syne, not body type', (t) async {
      // The reported bug: the profile tabs set no family, so the title came
      // out in DM Sans while every other empty state used Syne.
      await t.pumpWidget(host(const AppEmptyState(
        icon: Icons.favorite_rounded,
        message: 'Nothing liked yet',
      )));
      await t.pump();

      final title = t.widget<Text>(find.text('Nothing liked yet'));
      expect(title.style?.fontFamily, 'Syne');
      expect(title.style?.fontWeight, AppTypography.bold);
    });

    testWidgets('and the hint is body type, a step down', (t) async {
      await t.pumpWidget(host(const AppEmptyState(
        icon: Icons.favorite_rounded,
        message: 'Nothing liked yet',
        hint: 'Photos you like show up here.',
      )));
      await t.pump();

      final hint = t.widget<Text>(find.text('Photos you like show up here.'));
      expect(hint.style?.fontFamily, isNull, reason: 'a hint is body text');
      expect(hint.style?.fontSize, lessThan(
        t.widget<Text>(find.text('Nothing liked yet')).style!.fontSize!,
      ));
    });

    testWidgets('it reads in light mode too', (t) async {
      // Both themes, because the disc is an alpha wash over the page and a
      // colour chosen against one background can vanish on the other.
      await t.pumpWidget(host(
        const AppEmptyState(icon: Icons.inbox_outlined, message: 'No requests yet'),
        dark: false,
      ));
      await t.pump();

      expect(t.widget<Icon>(find.byType(Icon)).color, ext(false).accentGoldDark);
      expect(
        t.widget<Text>(find.text('No requests yet')).style?.color,
        ext(false).greetingColor,
      );
    });

    test('the glyph is legible against its own disc, in both themes', () {
      // The bug this is here for: one accent was serving two grounds. The disc
      // is the accent at 12% over the page, which on near-black stays dark and
      // on cream turns pale mint — so the accent that read cleanly in dark mode
      // measured 2.8:1 in light and the glyph looked half-erased.
      //
      // Asserted as a ratio rather than as a colour, because the colour is the
      // answer and the ratio is the requirement. Swapping the palette should
      // fail this when the new shades do not carry, and pass when they do.
      for (final dark in [true, false]) {
        final e = ext(dark);
        final disc = Color.alphaBlend(
          e.accentGold.withValues(alpha: 0.12),
          e.homeBackground,
        );
        final glyph = dark ? e.accentGold : e.accentGoldDark;

        expect(
          _contrast(glyph, disc),
          greaterThanOrEqualTo(3.0),
          reason: '${dark ? 'dark' : 'light'}: WCAG 1.4.11 wants 3:1 for a '
              'graphic, and under it the mark reads as a rendering fault',
        );
        // The link is body-sized text on the page itself, which is the
        // stricter bar of the two.
        expect(
          _contrast(glyph, e.homeBackground),
          greaterThanOrEqualTo(4.5),
          reason: '${dark ? 'dark' : 'light'}: the action link is text',
        );
      }
    });
  });

  group('in a box too small for it', () {
    testWidgets('the disc goes rather than the message', (t) async {
      // A step inside a bottom sheet. The full treatment does not fit, and
      // drawing it anyway gets overflow bars across the words — which is not a
      // more consistent design, only a broken one.
      await t.pumpWidget(host(Column(children: [
        SizedBox(
          height: 160,
          child: Row(children: const [
            Expanded(
              child: AppEmptyState(
                icon: Icons.public_off_rounded,
                message: 'No countries match that',
                hint: 'Check the spelling, or clear the search.',
              ),
            ),
          ]),
        ),
      ])));
      await t.pump();

      // An overflow is reported as a thrown FlutterError rather than a
      // failure, so the pump passes and the bars only show in a screenshot.
      expect(t.takeException(), isNull, reason: 'it overflowed its box');
      expect(find.text('No countries match that'), findsOneWidget);
      expect(find.text('Check the spelling, or clear the search.'),
          findsOneWidget);
    });

    testWidgets('and comes back when there is room', (t) async {
      await t.pumpWidget(host(const AppEmptyState(
        icon: Icons.public_off_rounded,
        message: 'No countries match that',
      )));
      await t.pump();

      final disc = t.widget<Container>(find.ancestor(
        of: find.byType(Icon),
        matching: find.byType(Container),
      ));
      expect((disc.decoration! as BoxDecoration).shape, BoxShape.circle);
    });
  });

  group('the second line', () {
    testWidgets('a hint alone is not tappable', (t) async {
      // Purchased photos have no action — you do not buy one from the tab that
      // lists them — and a link that goes nowhere is worse than no link.
      await t.pumpWidget(host(const AppEmptyState(
        icon: Icons.shopping_bag_rounded,
        message: 'No purchased photos yet',
        hint: 'All your purchased photos live here.',
      )));
      await t.pump();

      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('an action is a link inside the sentence', (t) async {
      var taps = 0;
      await t.pumpWidget(host(AppEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        message: 'No messages yet',
        actionLabel: 'Start a chat',
        hint: 'to see your conversations here',
        onAction: () => taps++,
      )));
      await t.pump();

      await t.tap(find.text('Start a chat'));
      expect(taps, 1);
    });

    testWidgets('only the link is tappable, not the whole line', (t) async {
      var taps = 0;
      await t.pumpWidget(host(AppEmptyState(
        icon: Icons.rocket_launch_outlined,
        message: 'No campaigns yet',
        actionLabel: 'Create a campaign',
        hint: 'to get started.',
        onAction: () => taps++,
      )));
      await t.pump();

      final link = t.widget<Text>(find.text('Create a campaign'));
      expect(link.style?.decoration, TextDecoration.underline);
      expect(link.style?.color, ext(true).accentGold);
      expect(taps, 0, reason: 'nothing was tapped yet');
    });
  });

  group('the screens that had their own', () {
    testWidgets('a profile tab draws the shared one', (t) async {
      // This is the font fix. The grid used to draw its own column, and
      // nothing but this notices if somebody puts it back.
      await t.pumpWidget(host(ProfilePhotoGrid(
        photos: const [],
        loading: false,
        ext: ext(true),
        emptyTitle: 'Nothing liked yet',
        emptyHint: 'Photos you like show up here.',
        emptyIcon: Icons.favorite_rounded,
        onOpen: (_) {},
      )));
      await t.pump();

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(
        t.widget<Text>(find.text('Nothing liked yet')).style?.fontFamily,
        'Syne',
      );
    });

    testWidgets('and can still be pulled down on', (t) async {
      // An empty tab inside a RefreshIndicator with nothing scrollable in it
      // cannot be pulled, so the only way to retry is to leave and come back.
      await t.pumpWidget(host(ProfilePhotoGrid(
        photos: const [],
        loading: false,
        ext: ext(true),
        emptyTitle: 'Nothing liked yet',
        emptyHint: 'Photos you like show up here.',
        onOpen: (_) {},
      )));
      await t.pump();

      final scroll = t.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scroll.physics, isA<AlwaysScrollableScrollPhysics>());
    });

    test('and the last two hand-rolled ones are gone', () {
      // The followers list and the saved tab each drew their own: a 56px grey
      // glyph, a 16px title, a 13px hint — the same anatomy as the shared
      // widget at three different sizes, which is the drift this file exists
      // to stop.
      //
      // Read off the source rather than pumped, because both live in private
      // widgets inside pages that want a repository and a registered locator
      // to build. The question here is only which widget they draw, and the
      // import answers it.
      for (final page in [
        'lib/features/follow/presentation/pages/follow_list_page.dart',
        'lib/features/discovery/presentation/pages/saved_items_page.dart',
      ]) {
        final source = File(page).readAsStringSync();

        expect(source.contains('AppEmptyState'), isTrue,
            reason: '$page should draw the shared empty state');
        expect(
          RegExp(r'size: 56').hasMatch(source),
          isFalse,
          reason: '$page is back to drawing its own 56px glyph',
        );
      }
    });
  });

  group('the look is not a parameter', () {
    test('no caller can pass a size, a colour or a style', () {
      // How it drifted in the first place: a widget whose appearance is
      // arguable will be argued with. Read off the constructor, because the
      // guarantee is the absence of a parameter and there is no object to
      // interrogate for a parameter that is not there.
      final source =
          File('lib/core/common/widgets/app_empty_state.dart').readAsStringSync();
      final start = source.indexOf('const AppEmptyState({');
      // Ends at the closing `})`, not at `});` — this constructor carries an
      // assert, so the first `});` in the file is somewhere in `build`, and
      // slicing to it swallows the whole widget (which of course mentions
      // colours and sizes, that being its job).
      final constructor = source.substring(start, source.indexOf('  })', start));

      for (final forbidden in [
        'iconSize', 'iconColor', 'size', 'color', 'style', 'textStyle',
        'titleStyle', 'fontSize', 'padding',
      ]) {
        expect(constructor.contains(forbidden), isFalse,
            reason: '`$forbidden` is how three empty states became three '
                'different designs — it belongs in the widget, not the call');
      }
    });

    test('and the two numbers are written down once each', () {
      final source =
          File('lib/core/common/widgets/app_empty_state.dart').readAsStringSync();

      expect(RegExp(r'_discSize = \d').hasMatch(source), isTrue);
      expect(RegExp(r'_iconSize = \d').hasMatch(source), isTrue);
    });
  });

  group('the rule under a tab bar', () {
    test('Material does not draw its own', () {
      // M3 puts its divider below the indicator and a pixel shorter, so the
      // active tab sits on a visible step. Off in the theme rather than on
      // each of the four TabBars, which is how it came to differ per screen.
      for (final theme in [Styles.light, Styles.dark]) {
        expect(theme.tabBarTheme.dividerHeight, 0);
      }
    });
  });
}

/// WCAG relative luminance, and the ratio between two opaque colours.
///
/// Written out rather than taken from `Color.computeLuminance` alone because
/// the ratio needs the +0.05 on both terms, and getting that wrong gives
/// plausible-looking numbers that pass when they should not.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/app_filter_chips.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The app's one filter chip.
///
/// It was five: the notifications filters, the Found sheet, the request board,
/// the reviews tabs and the payments screen had each written the pill out
/// again, and they had drifted to four heights, three radii and three different
/// ways of saying "selected". The payments screen had drifted furthest — square
/// filled blocks whose selected state was a 14%-opacity wash that, on the
/// near-black settings ground, reads as *disabled*.
///
/// What these pin is the part that was actually wrong: selection has to be
/// unmistakable, and two stacked rows have to read as a heading and its
/// refinement rather than as one bank of identical buttons.
void main() {
  Widget host(Widget child) => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark()
              .copyWith(extensions: const [AppThemeExtension.dark]),
          home: Scaffold(
            backgroundColor: AppThemeExtension.dark.homeBackground,
            body: child,
          ),
        ),
      );

  Container boxOf(WidgetTester t, String label) => t.widget<Container>(
        find
            .ancestor(
              of: find.text(label),
              matching: find.byType(Container),
            )
            .first,
      );

  Color? fillOf(WidgetTester t, String label) =>
      (boxOf(t, label).decoration as BoxDecoration?)?.color;

  TextStyle styleOf(WidgetTester t, String label) =>
      t.widget<Text>(find.text(label)).style!;

  group('a primary row', () {
    testWidgets('fills the selected chip with the accent, not a wash',
        (t) async {
      // The whole complaint in one assertion. A tint at 14% over a near-black
      // page is not visible as a choice, and the app had already settled on a
      // solid fill everywhere else.
      await t.pumpWidget(host(AppFilterRow(
        labels: const ['All', 'Purchases', 'Boosts'],
        selected: 0,
        onSelect: (_) {},
      )));
      await t.pumpAndSettle();

      expect(fillOf(t, 'All'), AppThemeExtension.dark.accentGold);
      expect(styleOf(t, 'All').color, Colors.white);
      // And the rest are outlines, so the row is not a wall of blocks.
      expect(fillOf(t, 'Boosts'), Colors.transparent);
    });

    testWidgets('says which is selected in weight as well as colour',
        (t) async {
      // Colour alone says nothing to a reader who cannot separate the green
      // from the grey.
      await t.pumpWidget(host(AppFilterRow(
        labels: const ['All', 'Purchases'],
        selected: 0,
        onSelect: (_) {},
      )));
      await t.pumpAndSettle();

      expect(styleOf(t, 'All').fontWeight, FontWeight.w700);
      expect(styleOf(t, 'Purchases').fontWeight, FontWeight.w500);
    });

    testWidgets('reports the tap', (t) async {
      var picked = -1;
      await t.pumpWidget(host(AppFilterRow(
        labels: const ['All', 'Purchases', 'Boosts'],
        selected: 0,
        onSelect: (i) => picked = i,
      )));
      await t.pumpAndSettle();

      await t.tap(find.text('Boosts'));
      expect(picked, 2);
    });
  });

  group('a secondary row', () {
    testWidgets('is visibly lighter than the row it qualifies', (t) async {
      // Two rows of the same chip is eight buttons of equal weight, which is
      // what made this screen unreadable: nothing said "Failed" was a
      // qualifier on "Campaigns" rather than a seventh kind.
      await t.pumpWidget(host(Column(children: [
        AppFilterRow(
          labels: const ['All', 'Campaigns'],
          selected: 1,
          onSelect: (_) {},
        ),
        AppFilterRow(
          labels: const ['Paid', 'Failed'],
          selected: 1,
          onSelect: (_) {},
          style: AppFilterRowStyle.secondary,
        ),
      ])));
      await t.pumpAndSettle();

      expect(
        AppFilterChip.heightFor(AppFilterRowStyle.secondary),
        lessThan(AppFilterChip.heightFor(AppFilterRowStyle.primary)),
      );
      expect(styleOf(t, 'Failed').fontSize, lessThan(styleOf(t, 'Campaigns').fontSize!));

      // Selected, but with a tint rather than the solid fill above it — the
      // difference is what makes the pair read as two levels.
      expect(fillOf(t, 'Failed'), isNot(AppThemeExtension.dark.accentGold));
      expect(styleOf(t, 'Failed').color, AppThemeExtension.dark.accentGold);
      expect(fillOf(t, 'Campaigns'), AppThemeExtension.dark.accentGold);
    });

    testWidgets('leaves its resting chips unboxed', (t) async {
      await t.pumpWidget(host(AppFilterRow(
        labels: const ['All', 'Paid'],
        selected: 0,
        onSelect: (_) {},
        style: AppFilterRowStyle.secondary,
      )));
      await t.pumpAndSettle();

      final border = (boxOf(t, 'Paid').decoration as BoxDecoration?)?.border;
      expect(border?.top.color, Colors.transparent);
    });
  });

  testWidgets('a row that fits shows no fade', (t) async {
    // The fade means "there is more this way". On a row with nothing beyond the
    // edge it would just be a dimmed last chip.
    await t.pumpWidget(host(AppFilterRow(
      labels: const ['All', 'Paid'],
      selected: 0,
      onSelect: (_) {},
    )));
    await t.pumpAndSettle();

    expect(find.byType(ShaderMask), findsNothing);
  });

  testWidgets('a row that overflows fades at the edge with more behind it',
      (t) async {
    // What the screenshot showed: a chip sliced off square at the screen edge,
    // which reads as a layout fault rather than as something you can push.
    await t.pumpWidget(host(AppFilterRow(
      labels: const [
        'All',
        'Purchases',
        'Boosts',
        'Campaigns',
        'Bookings',
        'Payouts',
      ],
      selected: 0,
      onSelect: (_) {},
    )));
    await t.pumpAndSettle();

    expect(find.byType(ShaderMask), findsOneWidget);
  });
}

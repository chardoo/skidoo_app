import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/customThemeData.dart';
import 'package:jperg_app/features/home/presentation/widgets/feed_top_bar.dart';

Widget host(AppThemeExtension ext, Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [ext]),
        home: Scaffold(body: child),
      ),
    );

/// The bar full-width at the top of the screen, the way the feed page mounts it
/// — the geometry assertions below are about where things land in that strip.
Widget topHost(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(
          fontFamily: Styles.fontFamily,
          extensions: const [AppThemeExtension.dark],
        ),
        home: Scaffold(
          body: Stack(children: [
            Positioned(top: 0, left: 0, right: 0, child: child),
          ]),
        ),
      ),
    );

/// Loads the real Poppins metrics.
///
/// The default test font gives every glyph the same square advance, so a bold
/// label and a medium one measure identically — which is exactly the difference
/// the layout-shift test needs to see. Without the real font that test passes
/// no matter what the widget does.
Future<void> loadPoppins() async {
  final loader = FontLoader(Styles.fontFamily);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(Future.value(ByteData.sublistView(
        File('assets/fonts/Poppins-$weight.ttf').readAsBytesSync())));
  }
  await loader.load();
}

FeedTopBar bar({
  List<String> tabs = const ['Found', 'Feed', 'Following'],
  int selected = 1,
  bool solid = false,
  VoidCallback? onSearch,
  VoidCallback? onUnlock,
}) =>
    FeedTopBar(
      tabs: tabs,
      selectedTab: selected,
      overSolidBackground: solid,
      onTabChanged: (_) {},
      onSearchOpen: onSearch ?? () {},
      onUnlockPressed: onUnlock,
    );

Color labelColour(WidgetTester t, String label) =>
    t.widget<Text>(find.text(label)).style!.color!;

void main() {
  // Real metrics for every test in the file: the bar's layout is driven by how
  // wide the labels actually are, and the test font's square glyphs make them
  // roughly twice Poppins' width — wide enough to change what fits.
  setUpAll(loadPoppins);

  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  testWidgets('guests get Found | Explore, and no Following', (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark,
        bar(tabs: const ['Found', 'Explore'], selected: 1)));
    expect(find.text('Found'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Feed'), findsNothing);
    expect(find.text('Following'), findsNothing);
  });

  testWidgets('signed in keeps the three-tab set', (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark, bar()));
    for (final l in ['Found', 'Feed', 'Following']) {
      expect(find.text(l), findsOneWidget);
    }
    expect(find.text('Explore'), findsNothing);
  });

  testWidgets('the leading action is the QR mark, not a plus', (t) async {
    var taps = 0;
    await t.pumpWidget(
        host(AppThemeExtension.dark, bar(onUnlock: () => taps++)));

    // The design's leading icon is a QR glyph; "+" (create) is not on this bar.
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    final unlock = find.bySemanticsLabel('Unlock private photos');
    expect(unlock, findsOneWidget);

    await t.tap(unlock);
    expect(taps, 1);
  });

  testWidgets('the leading action is hidden when no handler is given',
      (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark, bar()));
    expect(find.bySemanticsLabel('Unlock private photos'), findsNothing);
  });

  testWidgets('the QR glyph takes the accent while its sheet is open',
      (t) async {
    const ext = AppThemeExtension.dark;

    // The glyph is a CustomPaint and its painter type is private to the widget
    // library, so the colour is read off it dynamically rather than by casting
    // to a type this file cannot name.
    Color glyphColour(WidgetTester t) {
      final painted = t
          .widgetList<CustomPaint>(find.descendant(
            of: find.bySemanticsLabel('Unlock private photos'),
            matching: find.byType(CustomPaint),
          ))
          .firstWhere((p) => p.painter != null);
      return (painted.painter as dynamic).color as Color;
    }

    await t.pumpWidget(host(
        ext,
        FeedTopBar(
          selectedTab: 1,
          onTabChanged: (_) {},
          onSearchOpen: () {},
          onUnlockPressed: () {},
        )));
    expect(glyphColour(t), Colors.white, reason: 'idle over media');

    await t.pumpWidget(host(
        ext,
        FeedTopBar(
          selectedTab: 1,
          onTabChanged: (_) {},
          onSearchOpen: () {},
          onUnlockPressed: () {},
          unlockActive: true,
        )));
    // Tinted over the tween's duration, not instantly.
    await t.pumpAndSettle();
    expect(glyphColour(t), ext.accentGold);
  });

  testWidgets('the search icon hands off to the Search screen', (t) async {
    // The bar itself no longer holds a query field — search is a route of its
    // own, so all this button owes anyone is the callback.
    var taps = 0;
    await t.pumpWidget(
        host(AppThemeExtension.dark, bar(onSearch: () => taps++)));

    expect(find.byType(TextField), findsNothing);
    await t.tap(find.bySemanticsLabel('Open search'));
    expect(taps, 1);
  });

  // One theme per test: pumping two themes into the same widget tree reuses
  // the element and the second theme doesn't take, which silently passes the
  // assertion for the wrong reason.
  for (final (name, ext) in [
    ('dark', AppThemeExtension.dark),
    ('light', AppThemeExtension.light),
  ]) {
    testWidgets('over media the labels stay white — $name', (t) async {
      await t.pumpWidget(host(ext, bar(selected: 1, solid: false)));
      expect(labelColour(t, 'Feed'), Colors.white);
      // A drop shadow is what keeps it legible over an arbitrary photo.
      expect(t.widget<Text>(find.text('Feed')).style!.shadows, isNotNull);
    });

    testWidgets('on the Found tab the labels follow the theme — $name',
        (t) async {
      // The regression this guards: white-on-white in light mode, because the
      // Found tab renders on the page background rather than over media.
      await t.pumpWidget(host(
          ext, bar(tabs: const ['Found', 'Explore'], selected: 0, solid: true)));
      expect(labelColour(t, 'Found'), ext.greetingColor);
      expect(labelColour(t, 'Explore'), ext.searchHintColor);
      expect(t.widget<Text>(find.text('Found')).style!.shadows, isNull);
    });
  }

  // ── Layout and hit testing ──────────────────────────────────────────────────

  /// Every tab's tap box, in order.
  Finder tabBoxes() => find.descendant(
        of: find.byType(Row).first,
        matching: find.byType(GestureDetector),
      );

  testWidgets('labels sit on the same optical line as the icons', (t) async {
    // They used to sit 3 dp higher: the label and its underline were centred as
    // one block, so the underline's share pushed the text up off the line the
    // leading and trailing glyphs are on.
    await t.pumpWidget(topHost(bar(onUnlock: () {})));

    final iconCentre =
        t.getRect(find.bySemanticsLabel('Unlock private photos')).center.dy;
    expect(t.getRect(find.bySemanticsLabel('Open search')).center.dy,
        moreOrLessEquals(iconCentre, epsilon: 0.5));

    for (final l in ['Found', 'Feed', 'Following']) {
      expect(t.getRect(find.text(l)).center.dy,
          moreOrLessEquals(iconCentre, epsilon: 0.5),
          reason: '$l is off the icons\' line');
    }
  });

  testWidgets('every control clears the 48 dp minimum tap target', (t) async {
    // The bug this guards: a 27 dp tall tab whose top edge was flush with the
    // top of the glyphs, so a tap aimed at the label but landing a couple of
    // pixels high missed it entirely and nothing happened.
    await t.pumpWidget(topHost(bar(onUnlock: () {})));

    for (var i = 0; i < tabBoxes().evaluate().length; i++) {
      final r = t.getRect(tabBoxes().at(i));
      expect(r.height, greaterThanOrEqualTo(48), reason: 'tab $i is too short');
      expect(r.width, greaterThanOrEqualTo(48), reason: 'tab $i is too narrow');
    }
    for (final label in ['Unlock private photos', 'Open search']) {
      expect(t.getRect(find.bySemanticsLabel(label)).height,
          greaterThanOrEqualTo(48),
          reason: '$label is too short');
    }
  });

  testWidgets('a tap just above the label still selects the tab', (t) async {
    // The reported symptom, precisely: tapping the word did nothing and you had
    // to aim below it.
    var picked = -1;
    await t.pumpWidget(topHost(FeedTopBar(
      tabs: const ['Found', 'Feed', 'Following'],
      selectedTab: 0,
      onTabChanged: (i) => picked = i,
      onSearchOpen: () {},
    )));

    final word = t.getRect(find.text('Following'));
    for (final dy in [word.top - 4, word.center.dy, word.bottom + 3]) {
      picked = -1;
      await t.tapAt(Offset(word.center.dx, dy));
      await t.pump();
      expect(picked, 2, reason: 'missed at y=$dy');
    }
  });

  testWidgets('the gap between labels belongs to a tab, not to nothing',
      (t) async {
    await t.pumpWidget(topHost(bar()));

    for (var i = 1; i < tabBoxes().evaluate().length; i++) {
      final gap = t.getRect(tabBoxes().at(i)).left -
          t.getRect(tabBoxes().at(i - 1)).right;
      expect(gap, moreOrLessEquals(0, epsilon: 0.01),
          reason: 'dead strip between tabs ${i - 1} and $i');
    }
  });

  testWidgets('changing the selection does not slide the labels sideways',
      (t) async {
    // The active label is bolder, so it is wider. The row is sized to its
    // contents and centred, so without reserving the bold width the whole group
    // shifted a couple of pixels on every tab change.
    final lefts = <int, List<double>>{};
    for (final selected in [0, 1, 2]) {
      await t.pumpWidget(topHost(bar(selected: selected)));
      lefts[selected] = [
        for (final l in ['Found', 'Feed', 'Following'])
          t.getRect(find.text(l)).left,
      ];
    }

    for (final selected in [1, 2]) {
      for (var i = 0; i < 3; i++) {
        expect(lefts[selected]![i], moreOrLessEquals(lefts[0]![i], epsilon: 0.01),
            reason: 'label $i moved when tab $selected became active');
      }
    }
  });
}

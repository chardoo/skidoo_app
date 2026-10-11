import 'package:flutter/material.dart';
import 'package:jperg_app/core/theme/app_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/common/navbar.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/home/presentation/pages/home_navigation_page.dart';

/// The floating pill was drawn in hardcoded black whatever the theme, with
/// white icons on it — a black slab on a #F7F7F2 page, and the one piece of
/// chrome that never followed the light palette.
Widget host(AppThemeExtension ext, {int selected = 3}) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(
          brightness: ext == AppThemeExtension.light
              ? Brightness.light
              : Brightness.dark,
          extensions: [ext],
        ),
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: AppNavbar(
            selectedIndex: selected,
            onchange: (_) {},
          ),
        ),
      ),
    );

/// The pill itself — the first decorated box inside the bar.
BoxDecoration pill(WidgetTester t) => t
    .widgetList<Container>(find.descendant(
      of: find.byType(AppNavbar),
      matching: find.byType(Container),
    ))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .firstWhere((d) => d.borderRadius != null && d.color != null);

Color labelColour(WidgetTester t, String label) =>
    t.widget<Text>(find.text(label)).style!.color!;

/// Every tab's glyph, whichever widget draws it.
///
/// The tabs draw the supplied artwork now rather than the icon font, so a
/// sweep for [Icon] sees nothing. What the assertions are about — size, and
/// the colour that says which tab you are on — is the same either way.
List<({double? size, Color? color})> tabGlyphs(WidgetTester t) => [
      ...t
          .widgetList<AppSvgIcon>(find.descendant(
            of: find.byType(AppNavbar),
            matching: find.byType(AppSvgIcon),
          ))
          .map((w) => (size: w.size, color: w.color)),
      ...t
          .widgetList<Icon>(find.descendant(
            of: find.byType(AppNavbar),
            matching: find.byType(Icon),
          ))
          .map((w) => (size: w.size, color: w.color)),
    ];

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('light mode: a white pill that earns its edge from a shadow',
      (t) async {
    await t.pumpWidget(host(AppThemeExtension.light));

    final decoration = pill(t);
    expect(decoration.color, AppThemeExtension.light.cardSurface);
    expect(decoration.boxShadow, isNotNull,
        reason: 'white on a light page needs a shadow to read as in front');
  });

  testWidgets('dark mode lifts the pill off the page rather than sinking it',
      (t) async {
    // It used to be pure black on a #111110 page — *darker* than the surface
    // it floats over, which reads as a hole punched in the page rather than
    // something in front of it. A raised surface is lighter than its ground;
    // that is what tonal elevation means and what Material 3 does.
    await t.pumpWidget(host(AppThemeExtension.dark));

    final decoration = pill(t);
    final page = AppThemeExtension.dark.homeBackground;
    expect(decoration.color, isNot(Colors.black));
    expect(
      decoration.color!.computeLuminance(),
      greaterThan(page.computeLuminance()),
      reason: 'the pill must sit above the page, not below it',
    );
  });

  testWidgets('light mode draws the active label in the accent, not out of it',
      (t) async {
    await t.pumpWidget(host(AppThemeExtension.light));
    expect(labelColour(t, 'Profile'), AppThemeExtension.light.accentGold);
  });

  testWidgets('dark mode draws it in the accent too', (t) async {
    // It used to be knocked out in black on a solid accent chip. Per the
    // design the chip recedes on both grounds and the accent is what marks
    // the tab — a filled green slab put the bar's whole weight on one tab and
    // read as a button sitting on the nav rather than as where you are.
    await t.pumpWidget(host(AppThemeExtension.dark));
    expect(labelColour(t, 'Profile'), AppThemeExtension.dark.accentGold);
  });

  testWidgets('the active chip is a lift off the ground, not a slab of accent',
      (t) async {
    // Dark: a little white over the black pill. Light: a tint of the accent.
    // Either way the fill stays quieter than the glyph on top of it.
    for (final (ext, selected) in [
      (AppThemeExtension.dark, 3),
      (AppThemeExtension.light, 3),
    ]) {
      await t.pumpWidget(host(ext, selected: selected));

      final chip = t
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.color != null && d.color!.a > 0);

      expect(chip.color, isNot(ext.accentGold),
          reason: 'the chip is not the accent itself');
      expect(chip.color!.a, lessThan(0.2),
          reason: 'and it is barely there — the label carries the state');
    }
  });

  testWidgets('inactive icons follow the theme, not a fixed white', (t) async {
    // white70 on a white pill is all but invisible.
    await t.pumpWidget(host(AppThemeExtension.light));

    final icons = tabGlyphs(t);
    final inactive =
        icons.where((i) => i.color != AppThemeExtension.light.accentGold);

    expect(inactive, isNotEmpty);
    for (final icon in inactive) {
      expect(icon.color, AppThemeExtension.light.searchHintColor);
    }
  });

  // ── Over the feed ────────────────────────────────────────────────────────
  //
  // The feed wraps itself in DarkMediaSurface, which forces the dark palette
  // whatever the app theme is. The bar lives in the Scaffold's
  // bottomNavigationBar — outside that wrapper — so it read the app theme and,
  // with extendBody:true, put a white pill and grey icons on top of full-bleed
  // dark media. It has to join the island it floats over.

  testWidgets('the feed tab takes the dark pill even in light mode', (t) async {
    await t.pumpWidget(host(AppThemeExtension.light, selected: 0));

    final decoration = pill(t);
    // Dark, whatever the app theme says — the feed is an island. Not pure
    // black: see the dark-mode test above.
    expect(
      decoration.color!.computeLuminance(),
      lessThan(0.2),
      reason: 'the bar has to join the dark island it floats over',
    );
  });

  testWidgets('over the feed the inactive icons go light, not grey',
      (t) async {
    await t.pumpWidget(host(AppThemeExtension.light, selected: 0));

    // The selected tab is the accent on either ground — this is about the three
    // it leaves behind. It has to be filtered out by hand now that every tab
    // draws an [Icon]: Home used to be an `Image.asset`, so with Home selected
    // the sweep below happened to see only inactive tabs.
    final icons = tabGlyphs(t);
    final inactive =
        icons.where((i) => i.color != AppThemeExtension.light.accentGold);

    expect(icons, hasLength(4));
    expect(inactive, hasLength(3));
    for (final icon in inactive) {
      expect(icon.color, Colors.white70,
          reason: 'grey-on-dark-media is the case this fixes');
    }
  });

  testWidgets('over the feed the active label is the accent', (t) async {
    await t.pumpWidget(host(AppThemeExtension.light, selected: 0));
    expect(labelColour(t, 'Home'), AppThemeExtension.light.accentGold);
  });

  testWidgets('every tab draws one size of glyph', (t) async {
    // The bar was reported for uneven icons, and Home was why: it drew a 50 px
    // PNG whose artwork ran to the edge of its own box, so the shared 20 dp
    // came out a ~19 dp mark with a ~1.9 dp stroke against the Material
    // glyphs' 16.7 dp mark and 1.7 dp stroke. Same number in the code either
    // way — what makes the row even is every tab taking its glyph from one
    // family, which is drawn to one grid at one outline weight.
    for (final selected in [0, 1, 2, 3]) {
      await t.pumpWidget(host(AppThemeExtension.dark, selected: selected));

      final icons = tabGlyphs(t);

      expect(icons, hasLength(4),
          reason: 'a tab is drawing something from neither the artwork nor '
              'the icon font');
      expect(icons.map((i) => i.size).toSet(), hasLength(1),
          reason: 'the four tabs are not asking for the same size');

      // Exactly one tab is accented — the one you are on.
      //
      // It used to be "exactly one tab is *filled*". The supplied set has no
      // filled counterparts, so all four give the fill up together and the
      // accent carries the answer, alongside the chip behind it and the label.
      // Giving it up together is the part that matters: one tab keeping an
      // outline while the others filled is the bug this file was written for.
      final accented = icons.where((i) => i.color == AppThemeExtension.dark.accentGold);
      expect(accented, hasLength(1),
          reason: 'the selected tab is not the only accented glyph');
    }
  });

  testWidgets('chats is two bubbles, not the comment glyph', (t) async {
    // A conversation, per the design. The single bubble it used to carry is
    // what the app draws for a comment, and at 20 dp the two were the same
    // picture on two different surfaces.
    await t.pumpWidget(host(AppThemeExtension.dark, selected: 3));

    // A conversation, not the single bubble the app draws for a comment.
    final assets = t
        .widgetList<AppSvgIcon>(find.byType(AppSvgIcon))
        .map((w) => w.asset);
    expect(assets, contains(AppIcons.conversation));
    expect(assets, isNot(contains(AppIcons.comment)));
  });

  testWidgets('leaving the feed returns the bar to the theme', (t) async {
    // The rule is about the ground under the bar, so it has to switch back —
    // a black pill on the cream Profile page is the same mistake inverted.
    await t.pumpWidget(host(AppThemeExtension.light, selected: 3));
    expect(pill(t).color, AppThemeExtension.light.cardSurface);
  });

  testWidgets('in dark mode every tab keeps the dark pill', (t) async {
    for (final tab in [0, 1, 2, 3]) {
      await t.pumpWidget(host(AppThemeExtension.dark, selected: tab));
      expect(pill(t).color!.computeLuminance(), lessThan(0.2),
          reason: 'tab \$tab');
    }
  });

  testWidgets('every tab fits the pill when it is the active one', (t) async {
    // Only the active tab shows a label and the row is sized to its content,
    // so a long one overflows: 'Notifications' ran 97px past the edge. The
    // labels are the design's own words, which are also the short ones.
    for (final tab in [0, 1, 2, 3]) {
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      await t.pumpWidget(host(AppThemeExtension.light, selected: tab));
      FlutterError.onError = previous;
      expect(errors, isEmpty, reason: 'tab \$tab overflowed: \${errors.join()}');
    }
  });

  // ── Home is three pills, and only two of them are dark ──────────────────
  //
  // The bar asked whether the *outer* tab was Home and took that as "over dark
  // media". Home holds Found, Feed and Following; only the last two wrap
  // themselves in DarkMediaSurface. So on Found in light mode the bar wore the
  // dark treatment — Colors.white70 icons on a light pill, which is almost
  // exactly the pill's own colour. Reported from a device: "bottom nav icons
  // should be grey in light mode".

  group('on the Found pill in light mode', () {
    setUp(() => HomeNavigationPage.groundIsDark.value = false);
    tearDown(() => HomeNavigationPage.groundIsDark.value = true);

    testWidgets('the pill is light', (t) async {
      await t.pumpWidget(host(AppThemeExtension.light, selected: 0));

      expect(pill(t).color!.computeLuminance(), greaterThan(0.5),
          reason: 'Found is not a dark island; the bar should not pretend it is');
    });

    testWidgets('the inactive icons are grey, not white', (t) async {
      await t.pumpWidget(host(AppThemeExtension.light, selected: 0));

      final inactive = tabGlyphs(t)
          .where((i) => i.color != AppThemeExtension.light.accentGold);

      expect(inactive, hasLength(3));
      for (final icon in inactive) {
        expect(icon.color, AppThemeExtension.light.searchHintColor,
            reason: 'white on a light pill is all but invisible');
        expect(icon.color, isNot(Colors.white70));
      }
    });

    testWidgets('and they are actually readable against it', (t) async {
      // The real complaint, measured rather than named: whatever colour is
      // chosen has to be far enough from the pill to be seen on it.
      await t.pumpWidget(host(AppThemeExtension.light, selected: 0));

      final ground = pill(t).color!.computeLuminance();
      final glyph = tabGlyphs(t)
          .firstWhere((i) => i.color != AppThemeExtension.light.accentGold)
          .color!
          .computeLuminance();

      expect((ground - glyph).abs(), greaterThan(0.25),
          reason: 'the icons were within a hair of the pill they sit on');
    });

    testWidgets('the selected tab is still the accent', (t) async {
      await t.pumpWidget(host(AppThemeExtension.light, selected: 0));
      expect(labelColour(t, 'Home'), AppThemeExtension.light.accentGold);
    });
  });

  group('the other two pills are unchanged', () {
    testWidgets('Feed and Following keep the dark treatment', (t) async {
      // They wrap themselves in DarkMediaSurface and are dark whatever the
      // app theme is, which is what the bar was right about all along.
      HomeNavigationPage.groundIsDark.value = true;
      await t.pumpWidget(host(AppThemeExtension.light, selected: 0));

      expect(pill(t).color!.computeLuminance(), lessThan(0.2));
      final inactive = tabGlyphs(t)
          .where((i) => i.color != AppThemeExtension.light.accentGold);
      for (final icon in inactive) {
        expect(icon.color, Colors.white70);
      }
    });
  });

  group('dark mode is dark whatever the pill', () {
    testWidgets('even on Found', (t) async {
      // The ground only overrides *upwards*, towards dark. An app in dark mode
      // has no light pill to put grey icons on.
      HomeNavigationPage.groundIsDark.value = false;
      addTearDown(() => HomeNavigationPage.groundIsDark.value = true);

      await t.pumpWidget(host(AppThemeExtension.dark, selected: 0));

      expect(pill(t).color!.computeLuminance(), lessThan(0.2));
    });
  });

  group('away from Home the pill cannot be stale', () {
    testWidgets('a leftover dark ground does not follow other tabs', (t) async {
      // The notifier is a static that outlives the shell — the exact bug
      // FeedNavBarScope records for FeedChrome.visible. Here it is harmless
      // because it is only consulted on the Home tab.
      HomeNavigationPage.groundIsDark.value = true;
      addTearDown(() => HomeNavigationPage.groundIsDark.value = true);

      await t.pumpWidget(host(AppThemeExtension.light, selected: 3));

      expect(pill(t).color!.computeLuminance(), greaterThan(0.5));
    });
  });
}

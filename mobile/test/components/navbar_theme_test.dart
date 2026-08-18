import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/common/navbar.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

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

  testWidgets('dark mode is unchanged — the black pill needs no shadow',
      (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark));

    final decoration = pill(t);
    expect(decoration.color, Colors.black);
    expect(decoration.boxShadow, isNull);
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

    final icons = t.widgetList<Icon>(find.descendant(
      of: find.byType(AppNavbar),
      matching: find.byType(Icon),
    ));
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
    expect(decoration.color, Colors.black);
    expect(decoration.boxShadow, isNull,
        reason: 'a shadow is how the white pill earns an edge; the dark one '
            'does not need it');
  });

  testWidgets('over the feed the inactive icons go light, not grey',
      (t) async {
    await t.pumpWidget(host(AppThemeExtension.light, selected: 0));

    final inactive = t
        .widgetList<Icon>(find.byType(Icon))
        .where((i) => i.color != null)
        .toList();
    expect(inactive, isNotEmpty);
    for (final icon in inactive) {
      expect(icon.color, Colors.white70,
          reason: 'grey-on-dark-media is the case this fixes');
    }
  });

  testWidgets('over the feed the active label is the accent', (t) async {
    await t.pumpWidget(host(AppThemeExtension.light, selected: 0));
    expect(labelColour(t, 'Home'), AppThemeExtension.light.accentGold);
  });

  testWidgets('chats is two bubbles, not the comment glyph', (t) async {
    // A conversation, per the design. The single bubble it used to carry is
    // what the app draws for a comment, and at 20 dp the two were the same
    // picture on two different surfaces.
    await t.pumpWidget(host(AppThemeExtension.dark, selected: 3));

    expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
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
      expect(pill(t).color, Colors.black, reason: 'tab \$tab');
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
}

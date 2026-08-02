import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/components/common/navbar.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

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
    // A solid accent chip with a knocked-out label is right on black and the
    // loudest thing on screen in light mode.
    await t.pumpWidget(host(AppThemeExtension.light));
    expect(labelColour(t, 'Profile'), AppThemeExtension.light.accentGold);
  });

  testWidgets('dark mode keeps the knocked-out label', (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark));
    expect(labelColour(t, 'Profile'), Colors.black);
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
}

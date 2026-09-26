import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/common/navbar.dart';
import 'package:jperg_app/core/common/widgets/glass_surface.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// How far the nav pill floats above the bottom of the screen.
///
/// It used to take the whole system inset, and on a phone with a home
/// indicator that is ~34 dp — so the bar sat a visible band above the edge and
/// read as hovering rather than as the bottom of the app.
///
/// The rule is now: a *slim* inset is a home indicator, which is a hint and
/// not a control, so some of it is given back; a *tall* one is a button bar
/// full of real controls and is honoured in full. Neither case can be seen in
/// an ordinary test run — the default surface reports no inset at all — which
/// is exactly why they are pinned here. Getting the second one wrong puts the
/// tabs on top of Android's Back and Home.
void main() {
  setUp(() {
    // A real phone, so `.sp`/`.h` scale 1:1 against the design size and the
    // figures below are the figures a device would use. On the default 800x600
    // surface every one of them is multiplied by 0.71 and reads as arbitrary.
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  /// The gap between the bottom of the pill and the bottom of the screen.
  Future<double> gapWith(WidgetTester t, double inset) async {
    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            viewPadding: EdgeInsets.only(bottom: inset),
            padding: EdgeInsets.only(bottom: inset),
          ),
          child: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: AppNavbar(
              selectedIndex: 0,
              onchange: (_) {},
            ),
          ),
        ),
      ),
    ));
    await t.pump();

    final screenBottom = t.getRect(find.byType(MaterialApp)).bottom;
    // The pill itself. `AppNavbar`'s own rect includes the SafeArea padding
    // that *is* the gap, so measuring that would always answer zero.
    final pill = t.getRect(find.byType(GlassSurface).first);
    return screenBottom - pill.bottom;
  }

  testWidgets('a home indicator is not treated as a control', (t) async {
    // 34 is an iPhone's. Nothing is hit-tested there, so the bar may sit
    // close to it — this is the case the report was about.
    final gap = await gapWith(t, 34);

    expect(gap, lessThan(34),
        reason: 'the bar is still floating the full indicator height up');
    expect(gap, greaterThanOrEqualTo(6),
        reason: 'flush against the edge reads as a rendering fault');
  });

  testWidgets('a button bar is cleared in full', (t) async {
    // 48 is Android's three-button navigation: real controls, and giving any
    // of it back would put the tabs on top of Back and Home.
    expect(await gapWith(t, 48), 48);
  });

  testWidgets('a device reporting no inset still gets some air', (t) async {
    expect(await gapWith(t, 0), greaterThanOrEqualTo(6));
  });

  testWidgets('the band adds up to the pill plus the gap under it', (t) async {
    // What the feed lays its caption out against. It used to keep its own
    // figure — a flat 96 — which was a fair guess while the gap was the whole
    // home-indicator inset and wrong the moment the bar moved down: the
    // caption stayed put and the bar walked away from it.
    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewPadding: EdgeInsets.only(bottom: 34),
            padding: EdgeInsets.only(bottom: 34),
          ),
          child: Builder(
            builder: (context) => Text('${AppNavbar.bandHeight(context)}'),
          ),
        ),
      ),
    ));
    await t.pump();

    // 34 reported, 14 given back, 58 of pill.
    expect(find.text('78.0'), findsOneWidget);
  });

  testWidgets('the bar sits lower than it used to', (t) async {
    // The old rule, stated as the thing that changed: max(inset, 12).
    final now = await gapWith(t, 34);

    expect(now, lessThan(34));
  });
}

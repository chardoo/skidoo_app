import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/navigation/app_page_routes.dart';
import 'package:jperg_app/core/theme/customThemeData.dart';

/// Going back, from both ends: the glyph is the same on every screen of a
/// platform, and the gesture is the one that platform has.
///
/// Both used to be true only of the screens that opted in — the ~50 that pass
/// an [AppBackButton] as their `leading`, and the handful pushed with an
/// explicit `CupertinoPageRoute`. The other route into each behaviour is the
/// theme, and that is what these lock down.
///
/// The gesture is deliberately not the same on both. iOS has no system back, so
/// the app draws the edge drag itself — it is built by the Cupertino transition
/// rather than by the route, which is why the transition is what these tests
/// reach for. Android has had a system back gesture since gesture navigation,
/// so a second app-drawn drag there is not an affordance, it is an iOS-shaped
/// animation running over the system's own.
Widget app(GlobalKey<NavigatorState> navigator,
        {TargetPlatform platform = TargetPlatform.iOS}) =>
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        navigatorKey: navigator,
        // The transition is chosen per platform (see Styles' pageTransitions),
        // and `PageTransitionsTheme` resolves it against `Theme.platform`.
        theme: Styles.dark.copyWith(platform: platform),
        home: const Scaffold(body: Center(child: Text('first'))),
      ),
    );

void main() {
  testWidgets('the back arrow an AppBar draws for itself is the app arrow',
      (t) async {
    final navigator = GlobalKey<NavigatorState>();
    await t.pumpWidget(app(navigator));
    await t.pumpAndSettle();

    // No `leading:` — which is how a third of the app's screens are written.
    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(appBar: AppBar(title: const Text('second'))),
    ));
    await t.pumpAndSettle();

    final icon = t.widget<Icon>(
      find.descendant(of: find.byType(BackButton), matching: find.byType(Icon)),
    );
    expect(icon.icon, AppBackButton.icon);
  });

  testWidgets('on iOS a pushed screen pops when dragged from the leading edge',
      (t) async {
    final navigator = GlobalKey<NavigatorState>();
    await t.pumpWidget(app(navigator));
    await t.pumpAndSettle();

    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Center(child: Text('second'))),
    ));
    await t.pumpAndSettle();
    expect(find.text('second'), findsOneWidget);

    await t.dragFrom(const Offset(4, 300), const Offset(500, 0));
    await t.pumpAndSettle();

    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsNothing);
  });

  testWidgets('on Android the drag is the system gesture, not the app\'s',
      (t) async {
    // Nothing to assert about the system gesture from here — it is the OS's,
    // and it still pops the route. What this pins is that the app has stopped
    // drawing a second one of its own: the drag that pops on iOS above does
    // nothing here, because the Cupertino transition that builds it is not the
    // one Android is given.
    final navigator = GlobalKey<NavigatorState>();
    await t.pumpWidget(app(navigator, platform: TargetPlatform.android));
    await t.pumpAndSettle();

    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Center(child: Text('second'))),
    ));
    await t.pumpAndSettle();

    await t.dragFrom(const Offset(4, 300), const Offset(500, 0));
    await t.pumpAndSettle();

    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('a horizontally paged screen keeps the drag for itself',
      (t) async {
    final navigator = GlobalKey<NavigatorState>();
    await t.pumpWidget(app(navigator));
    await t.pumpAndSettle();

    // What the photo viewers push: the edge belongs to the pager, so a thumb
    // that lands slightly too far left turns the page instead of leaving.
    navigator.currentState!.push(NoSwipeBackPageRoute<void>(
      builder: (_) => const Scaffold(body: Center(child: Text('viewer'))),
    ));
    await t.pumpAndSettle();

    await t.dragFrom(const Offset(4, 300), const Offset(500, 0));
    await t.pumpAndSettle();

    expect(find.text('viewer'), findsOneWidget);
  });
}

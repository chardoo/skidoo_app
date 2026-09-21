import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/navigation/app_page_routes.dart';
import 'package:jperg_app/core/theme/customThemeData.dart';
import 'package:jperg_app/features/splash/presentation/pages/splash_page.dart';

/// How the splash leaves.
///
/// Everything in the app arrives by the same Cupertino slide — see
/// [AppPageTransitionsBuilder], which installs it on Android as well as iOS so
/// that swipe-back works everywhere. That is right for a push and wrong for
/// this one navigation: the feed slid in from the trailing edge as though it
/// were a detail screen opened on top of the brand moment, and the splash
/// slid a third of the way off the leading edge to make room for it.
///
/// It dissolves instead. Which is two things, and both are tested here: the
/// destination fades up, and the splash underneath holds still and stays
/// painted the whole way.

const _splash = SplashPage.routeName;
const _destination = '/home';

/// A stand-in for each screen — the real ones need the whole locator, and
/// nothing here is about what they draw.
Widget _screen(String label) =>
    Scaffold(body: Center(child: Text(label, textDirection: TextDirection.ltr)));

/// The app's own route table, reduced to the part under test: two names, and
/// [appRouteFor] deciding how each one arrives.
///
/// Under the real theme, because that is where the transition being replaced
/// comes from — [Styles] installs the Cupertino slide for every route, and a
/// bare [MaterialApp] would leave these passing against Flutter's default.
/// [ScreenUtilInit] because the theme is built from `.sp` sizes.
Widget _host() => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: Styles.light,
        initialRoute: _splash,
        onGenerateRoute: (settings) => appRouteFor(
          settings,
          (_) => _screen(settings.name == _splash ? 'SPLASH' : 'DESTINATION'),
        ),
      ),
    );

/// Where the named screen has been painted to, horizontally.
///
/// The parallax this is guarding against is a translation, so the question is
/// only ever "has it moved sideways" — not which widget did it.
double _leftEdgeOf(WidgetTester t, String label) =>
    t.getTopLeft(find.text(label)).dx;

/// The opacity actually being applied to the arriving screen, or null when
/// nothing is fading it.
double? _fadeOn(WidgetTester t, String label) {
  final fades = t.widgetList<FadeTransition>(find.ancestor(
    of: find.text(label),
    matching: find.byType(FadeTransition),
  ));
  if (fades.isEmpty) return null;
  // Innermost first; any one of them at less than 1 is the screen mid-fade.
  return fades.map((f) => f.opacity.value).reduce((a, b) => a * b);
}

void main() {
  group('the route table', () {
    test('gives the splash a route that does not animate', () {
      final route = appRouteFor(
        const RouteSettings(name: _splash),
        (_) => _screen('SPLASH'),
      );

      expect(route, isA<StillPageRoute<void>>());
      expect((route as TransitionRoute<void>).transitionDuration, Duration.zero);
    });

    test('dissolves the one navigation that comes from the splash', () {
      final route = appRouteFor(
        const RouteSettings(name: _destination, arguments: SplashPage.handoff),
        (_) => _screen('DESTINATION'),
      );

      expect(route, isA<SplashHandoffRoute<void>>());
      expect(route.settings.name, _destination,
          reason: 'the destination still has to know its own name');
      expect(route.settings.arguments, isNull,
          reason: 'the marker says how to arrive, not what to show — a screen '
              'reading its arguments must not find it there');
    });

    test('leaves every other navigation an ordinary push', () {
      // The same destination, reached from the tab bar or a deep link or
      // sign-in. Only the splash's own handover is special.
      final route = appRouteFor(
        const RouteSettings(name: _destination),
        (_) => _screen('DESTINATION'),
      );

      expect(route, isA<MaterialPageRoute<void>>());
      expect(route, isNot(isA<SplashHandoffRoute<void>>()));
    });

    test('carries arguments through to a screen that wants them', () {
      const payload = {'eventId': 'e1'};
      final route = appRouteFor(
        const RouteSettings(name: _destination, arguments: payload),
        (_) => _screen('DESTINATION'),
      );

      expect(route.settings.arguments, same(payload));
    });
  });

  group('the handover', () {
    testWidgets('fades the app up rather than sliding it in', (t) async {
      await t.pumpWidget(_host());
      expect(find.text('SPLASH'), findsOneWidget);

      t.state<NavigatorState>(find.byType(Navigator))
          .pushReplacementNamed(_destination, arguments: SplashPage.handoff);
      await t.pump(); // route built, transition at zero

      // Halfway through: the destination is present, partly transparent, and
      // exactly where it will end up. A slide would have it off to the right.
      await t.pump(kSplashHandoffDuration ~/ 2);

      final fade = _fadeOn(t, 'DESTINATION');
      expect(fade, isNotNull,
          reason: 'nothing is fading the destination in — it is arriving by '
              'the default page transition again');
      expect(fade, greaterThan(0.0));
      expect(fade, lessThan(1.0));
      // Where it is halfway through, to be compared with where it comes to
      // rest. Against its own final position rather than against a number:
      // the label is centred, so the resting `dx` is a property of how wide
      // the word is and says nothing on its own.
      final travellingAt = _leftEdgeOf(t, 'DESTINATION');

      await t.pumpAndSettle();
      expect(_fadeOn(t, 'DESTINATION'), 1.0);
      expect(find.text('SPLASH'), findsNothing);
      expect(travellingAt, _leftEdgeOf(t, 'DESTINATION'),
          reason: 'the destination travelled to its place instead of '
              'dissolving into it');
    });

    testWidgets('holds the splash still and painted underneath it', (t) async {
      await t.pumpWidget(_host());
      final restingAt = _leftEdgeOf(t, 'SPLASH');

      t.state<NavigatorState>(find.byType(Navigator))
          .pushReplacementNamed(_destination, arguments: SplashPage.handoff);
      await t.pump();

      // Sampled across the whole transition rather than once in the middle:
      // the Cupertino parallax this replaces is a slow drift, and a single
      // reading at the wrong moment can miss it.
      for (var i = 1; i <= 4; i++) {
        await t.pump(kSplashHandoffDuration ~/ 4);
        if (find.text('SPLASH').evaluate().isEmpty) break;

        expect(_leftEdgeOf(t, 'SPLASH'), restingAt,
            reason: 'the splash is sliding out from under the dissolve');
      }
    });

    testWidgets('never shows a frame with neither screen on it', (t) async {
      await t.pumpWidget(_host());

      t.state<NavigatorState>(find.byType(Navigator))
          .pushReplacementNamed(_destination, arguments: SplashPage.handoff);
      await t.pump();

      // An opaque route only hides what is below it once its transition has
      // *finished*, which is what makes this a cross-dissolve rather than a
      // fade through black. If the splash is ever gone while the destination
      // is still transparent, the scaffold's own background is what is on
      // screen — the blank frame the whole handover exists to remove.
      for (var i = 1; i <= 8; i++) {
        await t.pump(kSplashHandoffDuration ~/ 8);

        final arrived = _fadeOn(t, 'DESTINATION') ?? 1.0;
        if (arrived < 1.0) {
          expect(find.text('SPLASH'), findsOneWidget,
              reason: 'the splash left before the app had finished arriving');
        }
      }
    });
  });
}

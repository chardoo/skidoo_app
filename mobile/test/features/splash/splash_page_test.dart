import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/splash/presentation/pages/splash_page.dart';

/// The app opening.
///
/// Three things were wrong with it, and all three were about the seam between
/// the brand screen and the app:
///
///  1. The animation never finished. It runs 108 frames at 30 ms — 3.24 s — and
///     the page left after 1.2 s, which is frame 40: the mark half-drawn, no
///     dot, and the word "jperg" not started. A brand animation cut before its
///     own last frame is worse than no animation.
///  2. The artwork was the light cut, on a cream field, while every screen
///     behind it is black. Opening the app flashed white and then went dark.
///  3. It left by the platform's page transition, sliding away like an ordinary
///     page in a stack — which it is not.
///
/// The Instagram shape, which is what was asked for: the mark completes and
/// holds, anything still loading is said quietly underneath it rather than by
/// replacing the screen with a spinner, and the whole thing dissolves into the
/// feed rather than sliding off it.
Widget _host() => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        home: const SplashPage(nextRoute: '/home'),
        routes: {'/home': (_) => const Scaffold(body: Text('home'))},
      ),
    );

/// The pulsing dots, however many are on screen.
///
/// Matched by shape rather than by widget type: [AnimatedOpacity] builds an
/// [AnimatedBuilder] of its own, so anything looking for one of those finds
/// the page's own fade-out and reports a hit before a single dot exists.
Iterable<Container> dots(WidgetTester t) =>
    t.widgetList<Container>(find.byType(Container)).where((c) {
      final d = c.decoration;
      return d is BoxDecoration && d.shape == BoxShape.circle;
    });

/// Runs the page out to the end.
///
/// The splash holds for the animation, fades, then navigates — a chain of
/// timers that outlives the assertion being made, and a test that leaves one
/// pending fails on teardown rather than on its own terms.
Future<void> drain(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  group('the artwork', () {
    testWidgets('is the dark cut, not the cream one', (t) async {
      await t.pumpWidget(_host());

      // The light gif sat on a near-white field and every screen behind this
      // is black, so opening the app flashed.
      final image = t.widget<Image>(find.byType(Image));
      final asset = (image.image as AssetImage).assetName;
      expect(asset, contains('Splash_small'));
      expect(asset, isNot(contains('/splash.gif')));

      await drain(t);
    });

    testWidgets('sits on black, matching its own field', (t) async {
      await t.pumpWidget(_host());

      final scaffold = t.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, const Color(0xFF000000));

      await drain(t);
    });
  });

  group('the wait', () {
    testWidgets('says nothing while the animation is still playing',
        (t) async {
      await t.pumpWidget(_host());
      await t.pump(const Duration(milliseconds: 1500));

      // The animation *is* the loading state for its own three seconds. A
      // second thing moving over it is two things asking for attention.
      expect(dots(t), isEmpty);

      await drain(t);
    });

    testWidgets('and speaks up once it has finished', (t) async {
      await t.pumpWidget(_host());
      await t.pump(const Duration(milliseconds: 3300));
      await t.pump(const Duration(milliseconds: 500));

      // Three dots under the wordmark — the app still working, said in the
      // register the rest of the screen is in.
      expect(dots(t), hasLength(3));

      await drain(t);
    });
  });

  testWidgets('it never shows a blank black screen on the way out', (t) async {
    await t.pumpWidget(_host());
    await t.pump(const Duration(milliseconds: 3300));

    // The artwork is still painted at full opacity right up to the moment the
    // destination replaces it. Fading it out first would leave the scaffold's
    // own black on screen with nothing on it — a blank frame between the brand
    // moment and the app, which is the seam this whole change is about.
    final opacities = t
        .widgetList<AnimatedOpacity>(find.descendant(
          of: find.byType(SplashPage),
          matching: find.byType(AnimatedOpacity),
        ))
        .where((o) => o.opacity == 0);
    expect(opacities, isEmpty,
        reason: 'something is fading the splash to nothing before it leaves');
    expect(find.byType(Image), findsOneWidget);

    await drain(t);
  });
}

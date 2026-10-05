/// Holding the carousel still rather than swiping one spinner onto another.
///
/// The rule is narrow and the failure modes are wide, which is why most of
/// this is about the ways the gate must *open*: a reader who cannot leave a
/// slide is in a worse state than the one this feature exists to prevent, so
/// every path that could pin somebody has a test saying it does not.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/discovery/presentation/utils/media_readiness.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/card_photo_preview.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

const _a = 'https://res.cloudinary.com/demo/image/upload/a.jpg';
const _b = 'https://res.cloudinary.com/demo/image/upload/b.jpg';
const _c = 'https://res.cloudinary.com/demo/image/upload/c.jpg';

EventPicture _pic(String url) => EventPicture(
      id: url,
      url: url,
      imageId: url,
      price: 0,
      mediaType: MediaType.photo,
    );

/// A warm that never settles — a request that has gone out and will not come
/// back, which is the state the gate is about.
Future<void> _neverSettles(BuildContext _, String __, double ___) =>
    Completer<void>().future;

void main() {
  group('the rule', () {
    test('two blank slides is the one move refused', () {
      expect(canAdvance(currentResolved: false, nextResolved: false), isFalse);
    });

    test('a loaded slide may always be left', () {
      // Even onto one still loading. They are leaving something real behind,
      // which is an ordinary swipe into an ordinary spinner — refusing it
      // would mean barely being able to advance at all on a slow connection.
      expect(canAdvance(currentResolved: true, nextResolved: false), isTrue);
    });

    test('a ready destination is always reachable', () {
      expect(canAdvance(currentResolved: false, nextResolved: true), isTrue);
    });

    test('both ready is obviously fine', () {
      expect(canAdvance(currentResolved: true, nextResolved: true), isTrue);
    });
  });

  group('what counts as settled', () {
    testWidgets('a url nobody has warmed is not', (t) async {
      expect(MediaReadiness().isResolved(_a), isFalse);
    });

    testWidgets('a slide with nothing to warm never blocks', (t) async {
      // A video on somebody else's host: no still can be derived, so there is
      // no URL and nothing that could ever resolve. A slide that can never
      // resolve must never be the reason a carousel stops moving.
      expect(MediaReadiness().isResolved(null), isTrue);
    });

    testWidgets('a warm that settles resolves it', (t) async {
      final completer = Completer<void>();
      final readiness = MediaReadiness(
        warmer: (_, __, ___) => completer.future,
      );
      addTearDown(readiness.dispose); // safety net; the body disposes too
      await t.pumpWidget(_Tracker(readiness: readiness, url: _a));

      expect(readiness.isResolved(_a), isFalse);
      completer.complete();
      await t.pump();

      expect(readiness.isResolved(_a), isTrue);
    });

    testWidgets('a warm that FAILS resolves it too', (t) async {
      // Resolved means settled, not loaded. A photo that errored shows an
      // error widget and must be swipeable past — waiting for a success that
      // is never coming is how a reader gets stuck.
      final completer = Completer<void>();
      final readiness = MediaReadiness(
        warmer: (_, __, ___) => completer.future,
      );
      addTearDown(readiness.dispose); // safety net; the body disposes too
      await t.pumpWidget(_Tracker(readiness: readiness, url: _a));

      completer.completeError(Exception('404'));
      await t.pump();

      expect(readiness.isResolved(_a), isTrue);
    });

    testWidgets('a warm that never comes back resolves at the ceiling',
        (t) async {
      // The failure with no error to report: a hung request, a captive portal,
      // a network that vanished. Nothing will ever complete, and the gate has
      // to open anyway.
      final readiness = MediaReadiness(
        ceiling: const Duration(seconds: 2),
        warmer: _neverSettles,
      );
      addTearDown(readiness.dispose); // safety net; the body disposes too
      await t.pumpWidget(_Tracker(readiness: readiness, url: _a));

      await t.pump(const Duration(milliseconds: 1900));
      expect(readiness.isResolved(_a), isFalse, reason: 'not yet');

      await t.pump(const Duration(milliseconds: 200));
      expect(readiness.isResolved(_a), isTrue, reason: 'the ceiling expired');
      readiness.dispose();
    });

    testWidgets('it announces a slide settling', (t) async {
      // The carousel asks live during a drag, but anything listening has to
      // hear about it too.
      final completer = Completer<void>();
      final readiness = MediaReadiness(
        warmer: (_, __, ___) => completer.future,
      );
      var notified = 0;
      readiness.addListener(() => notified++);
      await t.pumpWidget(_Tracker(readiness: readiness, url: _a));

      completer.complete();
      await t.pump();

      expect(notified, 1);
    });

    testWidgets('the same url is warmed once, not once per page change',
        (t) async {
      var warms = 0;
      final readiness = MediaReadiness(warmer: (_, __, ___) {
        warms++;
        return Completer<void>().future;
      });
      addTearDown(readiness.dispose); // safety net; the body disposes too
      await t.pumpWidget(_Tracker(readiness: readiness, url: _a));
      await t.pumpWidget(_Tracker(readiness: readiness, url: _a));
      await t.pump();

      expect(warms, 1);
      readiness.dispose();
    });
  });

  group('the carousel', () {
    Widget host(List<EventPicture> pics, MediaReadiness readiness,
            {int initialPage = 0}) =>
        MaterialApp(
          theme: ThemeData(extensions: const [AppThemeExtension.dark]),
          home: Scaffold(
            body: PostPhotoCarousel(
              pics: pics,
              pageController: PageController(initialPage: initialPage),
              showBlur: false,
              onDoubleTap: () {},
              onTap: () {},
              readiness: readiness,
            ),
          ),
        );

    /// Let the pager's ballistic settle finish.
    ///
    /// Not pumpAndSettle: a slide that has not loaded draws a
    /// CircularProgressIndicator, which animates forever, so settling never
    /// comes. Fixed frames instead.
    Future<void> land(WidgetTester t) async {
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    /// A swipe towards the next slide.
    ///
    /// 600 of the 800-pixel test viewport, deliberately past the halfway mark:
    /// a `drag` carries no fling velocity, so PageScrollPhysics snaps to
    /// whichever page is nearer, and a 400-pixel drag sits exactly on the
    /// threshold and settles back where it started whatever the gate says.
    Future<void> swipeForward(WidgetTester t) async {
      await t.drag(find.byType(PageView), const Offset(-600, 0));
      await land(t);
    }

    Future<void> swipeBack(WidgetTester t) async {
      await t.drag(find.byType(PageView), const Offset(600, 0));
      await land(t);
    }

    double pageOf(WidgetTester t) =>
        t.widget<PageView>(find.byType(PageView)).controller!.page!;

    testWidgets('refuses the swipe while both slides are blank', (t) async {
      final readiness = MediaReadiness(warmer: _neverSettles);
      addTearDown(readiness.dispose); // safety net; the body disposes too
      await t.pumpWidget(host([_pic(_a), _pic(_b)], readiness));
      await t.pump();

      await swipeForward(t);

      expect(pageOf(t), 0, reason: 'it moved onto a slide that is not there');

      readiness.dispose();
    });

    testWidgets('allows it the moment the destination arrives', (t) async {
      final readiness = MediaReadiness(warmer: _neverSettles);
      addTearDown(readiness.dispose); // safety net; the body disposes too
      await t.pumpWidget(host([_pic(_a), _pic(_b)], readiness));
      await t.pump();

      readiness.markResolved(_b);
      await swipeForward(t);

      expect(pageOf(t), 1);

      readiness.dispose();
    });

    testWidgets('allows it once the slide being left has arrived', (t) async {
      // The other half of the rule: leaving something real is always allowed,
      // whatever is coming next.
      final readiness = MediaReadiness(warmer: _neverSettles);
      addTearDown(readiness.dispose); // safety net; the body disposes too
      await t.pumpWidget(host([_pic(_a), _pic(_b)], readiness));
      await t.pump();

      readiness.markResolved(_a);
      await swipeForward(t);

      expect(pageOf(t), 1);

      readiness.dispose();
    });

    testWidgets('never blocks going back', (t) async {
      // The one move a reader stuck on a spinner must always have.
      //
      // Opened on the middle slide with nothing resolved, so the gate forward
      // is genuinely shut — reaching this slide by swiping would have resolved
      // the one behind, and leaving a resolved slide is allowed by design.
      final readiness = MediaReadiness(warmer: _neverSettles);
      await t.pumpWidget(
        host([_pic(_a), _pic(_b), _pic(_c)], readiness, initialPage: 1),
      );
      await t.pump();

      await swipeForward(t);
      expect(pageOf(t), 1, reason: 'forward should be held');

      await swipeBack(t);
      expect(pageOf(t), 0, reason: 'back must never be held');

      readiness.dispose();
    });

    testWidgets('a carousel given no readiness scrolls freely', (t) async {
      // Every standalone use of the carousel opts out, and must behave as it
      // always did.
      await t.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(
          body: PostPhotoCarousel(
            pics: [_pic(_a), _pic(_b)],
            pageController: PageController(),
            showBlur: false,
            onDoubleTap: () {},
            onTap: () {},
          ),
        ),
      ));
      await t.pump();

      await swipeForward(t);

      expect(pageOf(t), 1);
    });
  });
}

/// Drives one [MediaReadiness.track] call from inside a real element tree,
/// since tracking needs a BuildContext.
class _Tracker extends StatefulWidget {
  const _Tracker({required this.readiness, required this.url});

  final MediaReadiness readiness;
  final String url;

  @override
  State<_Tracker> createState() => _TrackerState();
}

class _TrackerState extends State<_Tracker> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.readiness.track(context, widget.url, logicalWidth: 400);
      }
    });
  }

  @override
  Widget build(BuildContext context) => const MaterialApp(home: SizedBox());
}

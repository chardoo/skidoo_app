import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/navigation/chrome_visibility.dart';

/// Reading further collapses the chrome; coming back up restores it.
///
/// One notifier drives both bars. Given a scroll listener each they would
/// eventually disagree, and the failure is visible on screen — tabs gone while
/// the bar is still wide, or a bar collapsing on a scroll the tabs ignored.
///
/// The property that matters most is the one at the bottom: the chrome can
/// always be got back. A bar left collapsed on a screen with nothing to scroll
/// cannot be reopened by any gesture, which is a trap rather than a bug.
void main() {
  late BuildContext ctx;

  ScrollUpdateNotification _scroll(double delta, {double pixels = 500}) =>
      ScrollUpdateNotification(
        metrics: FixedScrollMetrics(
          minScrollExtent: 0,
          maxScrollExtent: 2000,
          pixels: pixels,
          viewportDimension: 800,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 3,
        ),
        context: ctx,
        scrollDelta: delta,
      );

  ScrollEndNotification _end({double pixels = 500}) => ScrollEndNotification(
        metrics: FixedScrollMetrics(
          minScrollExtent: 0,
          maxScrollExtent: 2000,
          pixels: pixels,
          viewportDimension: 800,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 3,
        ),
        context: ctx,
      );

  setUpAll(() {
    // A notification needs a real BuildContext; nothing here reads it.
    TestWidgetsFlutterBinding.ensureInitialized();
    ctx = _CaptureContext.instance;
  });

  setUp(ChromeVisibility.reset);
  tearDown(ChromeVisibility.reset);

  test('starts expanded', () {
    expect(ChromeVisibility.expanded.value, isTrue);
  });

  test('a small scroll down does not twitch it', () {
    // Overscroll bounce and a thumb resting on the glass both produce a few
    // pixels. Reacting to those flickers the bars.
    ChromeVisibility.handle(_scroll(10));

    expect(ChromeVisibility.expanded.value, isTrue);
  });

  test('reading further collapses it', () {
    ChromeVisibility.handle(_scroll(30));
    ChromeVisibility.handle(_scroll(30));

    expect(ChromeVisibility.expanded.value, isFalse);
  });

  test('any scroll up restores it at once', () {
    // Deliberately not thresholded. Reaching for the nav is a deliberate act,
    // and making someone drag twice for it reads as the bar being broken.
    ChromeVisibility.handle(_scroll(80));
    expect(ChromeVisibility.expanded.value, isFalse);

    ChromeVisibility.handle(_scroll(-4));

    expect(ChromeVisibility.expanded.value, isTrue);
  });

  test('a reversal restarts the budget rather than resuming it', () {
    // Otherwise a nudge up followed by a nudge down would collapse it, having
    // travelled almost nowhere.
    ChromeVisibility.handle(_scroll(40));
    ChromeVisibility.handle(_scroll(-10));
    ChromeVisibility.handle(_scroll(40));

    expect(ChromeVisibility.expanded.value, isTrue);
  });

  test('the top of the list always shows it', () {
    ChromeVisibility.handle(_scroll(100));
    expect(ChromeVisibility.expanded.value, isFalse);

    ChromeVisibility.handle(_scroll(20, pixels: 0));

    expect(ChromeVisibility.expanded.value, isTrue);
  });

  test('coming to rest at the top shows it', () {
    ChromeVisibility.handle(_scroll(100));
    ChromeVisibility.handle(_end(pixels: 0));

    expect(ChromeVisibility.expanded.value, isTrue);
  });

  test('coming to rest mid-list leaves it as it was', () {
    // It never re-opens on a timer: stopping to read is not a request for the
    // chrome back.
    ChromeVisibility.handle(_scroll(100));
    ChromeVisibility.handle(_end());

    expect(ChromeVisibility.expanded.value, isFalse);
  });

  test('reset always reopens it', () {
    // The escape hatch, called on every tab change. A screen with nothing to
    // scroll offers no gesture that could restore a collapsed bar, so leaving
    // one collapsed there would strand it.
    ChromeVisibility.handle(_scroll(100));
    expect(ChromeVisibility.expanded.value, isFalse);

    ChromeVisibility.reset();

    expect(ChromeVisibility.expanded.value, isTrue);
  });

  test('handle never swallows the notification', () {
    // It observes; the pages under it still need their own scroll handling.
    expect(ChromeVisibility.handle(_scroll(100)), isFalse);
    expect(ChromeVisibility.handle(_end()), isFalse);
  });

  test('notifies only when the answer changes', () {
    // Every rebuild of both bars hangs off this. Firing on each scroll frame
    // would rebuild the nav sixty times a second while nothing moved.
    var notifications = 0;
    void count() => notifications++;
    ChromeVisibility.expanded.addListener(count);
    addTearDown(() => ChromeVisibility.expanded.removeListener(count));

    for (var i = 0; i < 10; i++) {
      ChromeVisibility.handle(_scroll(60));
    }

    expect(notifications, 1);
  });
}

/// A throwaway element, purely to satisfy the notification's `context`.
class _CaptureContext {
  static final BuildContext instance =
      _ElementStub(const _WidgetStub());
}

class _WidgetStub extends StatelessWidget {
  const _WidgetStub();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ElementStub extends StatelessElement {
  _ElementStub(super.widget);
}

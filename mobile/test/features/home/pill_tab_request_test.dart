import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/features/home/presentation/pages/home_navigation_page.dart';

/// The guest shell hands off to /home by posting a tab request *before* that
/// page exists, then navigating. A ValueNotifier only notifies on change, so a
/// listener attached in the new page's initState never sees a value that was
/// already there — the request would be silently dropped and the user would
/// land on For You instead of Found.
///
/// The page consumes any pending value on mount and clears it. These pin the
/// contract that makes that safe; the consumption itself is exercised by the
/// page, which needs the full BLoC/service-locator stack to render.
void main() {
  tearDown(() => HomeNavigationPage.pillTabRequest.value = null);

  test('a request posted before mount is still readable', () {
    HomeNavigationPage.pillTabRequest.value = 0;
    // Nothing has consumed it yet — this is the state the page mounts into.
    expect(HomeNavigationPage.pillTabRequest.value, 0);
  });

  test('setting the same value twice does not notify', () {
    HomeNavigationPage.pillTabRequest.value = 0;

    var notifications = 0;
    void listener() => notifications++;
    HomeNavigationPage.pillTabRequest.addListener(listener);

    // Re-posting Found while Found is already pending is a no-op — which is
    // precisely why mount-time consumption cannot rely on the listener.
    HomeNavigationPage.pillTabRequest.value = 0;
    expect(notifications, 0);

    // A different value does notify, which is the in-app switch path.
    HomeNavigationPage.pillTabRequest.value = 2;
    expect(notifications, 1);

    HomeNavigationPage.pillTabRequest.removeListener(listener);
  });

  test('clearing to null is how a handled request is retired', () {
    HomeNavigationPage.pillTabRequest.value = 0;
    HomeNavigationPage.pillTabRequest.value = null;
    // A stale non-null value would re-fire on an unrelated later change.
    expect(HomeNavigationPage.pillTabRequest.value, isNull);
  });
}

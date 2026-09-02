import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/ads/models/ad_media.dart';
import 'package:jperg_app/features/ads/presentation/widgets/media_carousel.dart';

/// A request or a campaign can carry several images, and all of them have to be
/// reachable — the detail screen used to render `media.first` alone, so a
/// campaign built from five photos showed one and hid four.
///
/// The other half of the rule is that it must never move by itself. These
/// images are the thing being decided about, not a slideshow: one that slides
/// away mid-read takes the decision with it.
List<AdMedia> media(int n) => [
      for (var i = 0; i < n; i++)
        AdMedia(id: 'm$i', url: 'https://cdn/$i.jpg', mediaType: 'image'),
    ];

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('every image is in the carousel, not just the first',
      (tester) async {
    await tester.pumpWidget(
      host(MediaCarousel(media: media(4), height: 240)),
    );

    final view = tester.widget<PageView>(find.byType(PageView));
    expect(view.controller!.hasClients, isTrue);
    // The builder is lazy, so the count is the honest measure of how many are
    // reachable — not how many widgets happen to be built right now.
    expect(
      (view.childrenDelegate as SliverChildBuilderDelegate).childCount,
      4,
    );
  });

  testWidgets('it never advances on its own', (tester) async {
    await tester.pumpWidget(
      host(MediaCarousel(media: media(3), height: 240)),
    );

    final controller =
        tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(controller.page, 0);

    // Well past any plausible slideshow interval. A pumpAndSettle would hide a
    // timer by draining it; these pumps let real time pass instead, and the
    // test would hang on a repeating timer rather than quietly passing.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 10));

    expect(controller.page, 0, reason: 'the carousel moved without a finger');
  });

  testWidgets('a swipe moves it, and the dots follow', (tester) async {
    await tester.pumpWidget(
      host(MediaCarousel(media: media(3), height: 240)),
    );

    expect(tester.widget<MediaPageDots>(find.byType(MediaPageDots)).current, 0);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    // Fixed pumps rather than pumpAndSettle: the frames hold a loading spinner
    // for images that never arrive in a test, so "settled" never comes. This is
    // long enough for the page-snap animation to finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final controller =
        tester.widget<PageView>(find.byType(PageView)).controller!;
    // closeTo, not equals: the snap settles asymptotically and is still a
    // fraction short of 1.0 when the animation ends. The dot below is the
    // integer the user actually sees, and that one is exact.
    expect(controller.page, closeTo(1, 0.01));
    expect(tester.widget<MediaPageDots>(find.byType(MediaPageDots)).current, 1);
  });

  testWidgets('one image gets no pager and no dots', (tester) async {
    // Nothing to page to. A PageView here would also swallow horizontal drags
    // belonging to whatever the carousel is sitting inside.
    await tester.pumpWidget(
      host(MediaCarousel(media: media(1), height: 240)),
    );

    expect(find.byType(PageView), findsNothing);
    expect(find.byType(MediaPageDots), findsNothing);
  });

  testWidgets('no media renders nothing at all', (tester) async {
    await tester.pumpWidget(
      host(MediaCarousel(media: const [], height: 240)),
    );

    expect(find.byType(PageView), findsNothing);
    // Not an empty 240-high box: a campaign with no images should not reserve
    // a blank slab at the top of its own page.
    expect(tester.getSize(find.byType(MediaCarousel)).height, 0);
  });
}

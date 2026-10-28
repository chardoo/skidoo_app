import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/widgets/media_backdrop.dart';

/// The blurred fill is scenery *around* a photo, so it must not be the whole
/// screen while the photo is still coming.
///
/// It used to be. The backdrop is a copy at 80 px and the photo is a rung — or,
/// for a row the ladder backfill has not reached, a camera original of several
/// megabytes — so the small one always won and opening an album showed a full
/// screen of blur that resolved seconds later. It only did it the *first*
/// time, too: tap the same photo again and the cached image paints on the
/// first frame, so the blur never shows and nobody can reproduce it on the
/// device in their hand.
///
/// These pin the first frame, which is the one that was wrong.
void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(body: SizedBox(width: 400, height: 800, child: child)),
      );

  double opacityOf(WidgetTester tester) =>
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

  testWidgets('a photo slot draws no blur on its first frame', (tester) async {
    await tester.pumpWidget(host(
      const MediaBackdrop(
        url: 'https://images.example.com/newImages/abc.jpg',
        child: SizedBox.shrink(key: Key('photo')),
      ),
    ));

    // One frame. Nothing can have been fetched in it, so the bands must be
    // hidden — this is the assertion the bug was a violation of.
    expect(opacityOf(tester), 0);
  });

  testWidgets('the photo is painted whether or not the blur is', (tester) async {
    await tester.pumpWidget(host(
      const MediaBackdrop(
        url: 'https://images.example.com/newImages/abc.jpg',
        child: SizedBox.shrink(key: Key('photo')),
      ),
    ));

    // Holding the backdrop back must never hold the media back with it.
    expect(find.byKey(const Key('photo')), findsOneWidget);
  });

  testWidgets('a clip shows its backdrop at once', (tester) async {
    // A video's first frame is its own placeholder, so there is nothing to
    // wait for — and handing an mp4 to an image loader would download the
    // whole clip in order to fail on it.
    await tester.pumpWidget(host(
      const MediaBackdrop(
        url: 'https://images.example.com/newImages/clip.mp4',
        child: SizedBox.shrink(key: Key('clip')),
      ),
    ));

    expect(opacityOf(tester), 1);
  });

  testWidgets('the ground is painted under both states', (tester) async {
    // The reveal has to be the blur fading up, not the screen changing colour
    // underneath it, so the veil is there before the blur is.
    await tester.pumpWidget(host(
      const MediaBackdrop(
        url: 'https://images.example.com/newImages/abc.jpg',
        child: SizedBox.shrink(key: Key('photo')),
      ),
    ));

    expect(find.byType(ColoredBox), findsWidgets);
  });
}

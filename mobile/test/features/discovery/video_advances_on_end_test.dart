import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/video_player/jperg_video_player.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/card_photo_preview.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// A clip plays through, then the carousel moves on.
///
/// The auto-slide has always refused to advance off a video — sliding away
/// after a few seconds cuts it mid-sentence — and the video looped forever, so
/// between those two a card carrying a clip simply stopped until somebody
/// swiped. Waiting for the end is the same courtesy with a terminating
/// condition.
///
/// The half worth pinning is the wiring, because it is invisible until someone
/// watches a video to the end: looping has to be off for a clip to *have* an
/// end, and the callback has to survive two wrappers on its way down.
const _videoUrl = 'https://res.cloudinary.com/demo/video/upload/a.mp4';
const _photoUrl = 'https://res.cloudinary.com/demo/image/upload/a.jpg';

EventPicture _pic(String url, {bool isVideo = false}) => EventPicture(
      id: url,
      url: url,
      imageId: url,
      price: 0,
      mediaType: isVideo ? MediaType.video : MediaType.photo,
    );

Widget host(List<EventPicture> pics, {VoidCallback? onVideoEnded}) => MaterialApp(
      theme: ThemeData(extensions: const [AppThemeExtension.dark]),
      home: Scaffold(
        body: PostPhotoCarousel(
          pics: pics,
          pageController: PageController(),
          showBlur: false,
          onDoubleTap: () {},
          onTap: () {},
          onVideoEnded: onVideoEnded,
        ),
      ),
    );

void main() {
  JpergVideoPlayer playerIn(WidgetTester t) =>
      t.widget<JpergVideoPlayer>(find.byType(JpergVideoPlayer));

  testWidgets('a clip stops looping once something waits for it to end',
      (t) async {
    // The reason this could never work before: a looping video has no end to
    // report, so the card was never handed a moment to move on from.
    await t.pumpWidget(host([_pic(_videoUrl, isVideo: true)],
        onVideoEnded: () {}));
    await t.pump();

    expect(playerIn(t).loop, isFalse);
    expect(playerIn(t).onEnded, isNotNull);
  });

  testWidgets('it keeps looping where nobody is listening', (t) async {
    // The album viewer and anywhere else that just wants a clip playing. A
    // video that stops dead after one pass there would be a regression.
    await t.pumpWidget(host([_pic(_videoUrl, isVideo: true)]));
    await t.pump();

    expect(playerIn(t).loop, isTrue);
    expect(playerIn(t).onEnded, isNull);
  });

  testWidgets('the callback survives the trip down to the player', (t) async {
    // Two wrappers sit between the card and the player — the carousel and the
    // slide — and a callback dropped by either is a video that plays through
    // and sits there, with nothing to show for the change.
    var fired = 0;
    await t.pumpWidget(host([_pic(_videoUrl, isVideo: true)],
        onVideoEnded: () => fired++));
    await t.pump();

    playerIn(t).onEnded!.call();
    expect(fired, 1, reason: 'the card was never told the clip finished');
  });

  testWidgets('a photo slide has no player to end', (t) async {
    await t.pumpWidget(host([_pic(_photoUrl)], onVideoEnded: () {}));
    await t.pump();

    expect(find.byType(JpergVideoPlayer), findsNothing);
  });

  testWidgets('a standalone player is untouched by any of this', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [AppThemeExtension.dark]),
      home: const Scaffold(
        body: JpergVideoPlayer(url: _videoUrl, isActive: false),
      ),
    ));
    await t.pump();

    final player = playerIn(t);
    expect(player.loop, isTrue, reason: 'looping is still the default');
    expect(player.onEnded, isNull);
  });
}

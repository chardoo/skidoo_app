import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/media_backdrop.dart';
import 'package:jperg_app/core/widgets/video_player/jperg_video_player.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/card_photo_preview.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// Both feed tabs — Feed and Following — draw their cards through this
/// carousel, so it is the one place the backdrop has to be right.
const _photoUrl = 'https://res.cloudinary.com/demo/image/upload/a.jpg';
const _videoUrl = 'https://res.cloudinary.com/demo/video/upload/a.mp4';

Widget host(List<EventPicture> pics) => MaterialApp(
      theme: ThemeData(extensions: const [AppThemeExtension.dark]),
      home: Scaffold(
        body: PostPhotoCarousel(
          pics: pics,
          pageController: PageController(),
          showBlur: false,
          onDoubleTap: () {},
          onTap: () {},
        ),
      ),
    );

EventPicture _pic(String url, {bool isVideo = false}) => EventPicture(
      id: url,
      url: url,
      imageId: url,
      price: 0,
      mediaType: isVideo ? MediaType.video : MediaType.photo,
    );

void main() {
  testWidgets('a photo slide is backed by the photo itself', (t) async {
    await t.pumpWidget(host([_pic(_photoUrl)]));
    await t.pump();

    expect(find.byType(MediaBackdrop), findsOneWidget);
    expect(t.widget<MediaBackdrop>(find.byType(MediaBackdrop)).url, _photoUrl);
  });

  testWidgets('a video slide is backed by its own poster frame', (t) async {
    // This is the case that had no backdrop at all: a contained video
    // letterboxes on nearly every card, and the bands used to be a flat colour.
    await t.pumpWidget(host([_pic(_videoUrl, isVideo: true)]));
    await t.pump();

    expect(find.byType(MediaBackdrop), findsOneWidget);
    expect(t.widget<MediaBackdrop>(find.byType(MediaBackdrop)).url, _videoUrl);
  });

  testWidgets('the video player does not paint over the backdrop', (t) async {
    // The player fills its whole box with backgroundColor. Any opaque value
    // there — themed or not — hides the backdrop completely and puts the flat
    // letterbox fill straight back.
    await t.pumpWidget(host([_pic(_videoUrl, isVideo: true)]));
    await t.pump();

    final player = t.widget<JpergVideoPlayer>(find.byType(JpergVideoPlayer));
    expect(player.backgroundColor, Colors.transparent);
    expect(player.fit, BoxFit.contain,
        reason: 'the video keeps its own shape — the backdrop fills the rest');
  });

  testWidgets('the real media keeps its size and shape', (t) async {
    await t.pumpWidget(host([_pic(_photoUrl)]));
    await t.pump();

    // The backdrop covers; the media it wraps is never stretched to match.
    final backdrop = t.widget<MediaBackdrop>(find.byType(MediaBackdrop));
    expect(backdrop.child, isNotNull);
    expect(find.byType(MediaBackdrop), findsOneWidget);
  });
}

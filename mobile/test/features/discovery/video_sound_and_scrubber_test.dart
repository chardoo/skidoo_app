import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/video_mute_preference.dart';
import 'package:jperg_app/core/widgets/video_player/jperg_video_player.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/card_photo_preview.dart';
import 'package:jperg_app/features/music/presentation/widgets/feed_volume_button.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// The feed's sound switch, and the band its scrubber has to clear.
///
/// Two complaints, one cause: a video's controls belonged to the player, and
/// the player owns the whole screen on a full-bleed card.
///
///   * mute sat in the player's overlay, top-right, behind the tap-to-reveal
///     controls that fade on a timer — so it was invisible nearly all the time,
///     and in a different corner from the sound switch a soundtrack uses.
///   * the scrubber sat on the player's bottom edge, which is the screen's
///     bottom edge, which is underneath the floating navigation bar. Not merely
///     hidden: the bar takes the drags that would have seeked.
///
/// The card knows things the player cannot — whether the bar is up, and where
/// the other sound switch lives. So the card places both.
void main() {
  Widget host(Widget child) => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark()
              .copyWith(extensions: const [AppThemeExtension.dark]),
          home: Scaffold(body: Stack(children: [child])),
        ),
      );

  group('the sound switch', () {
    setUp(() => VideoMutePreference.muted = false);

    testWidgets('says whether it is muting music or video', (t) async {
      // The label was hardcoded to "music". Video reuses the widget, and a
      // screen reader announcing "Mute music" over a silent photograph with a
      // clip playing is simply wrong.
      await t.pumpWidget(host(
        FeedVolumeButton(muted: false, sourceName: 'video', onTap: () {}),
      ));

      expect(find.bySemanticsLabel('Mute video'), findsOneWidget);
      expect(find.bySemanticsLabel('Mute music'), findsNothing);
    });

    testWidgets('defaults to the music wording, as it always did', (t) async {
      await t.pumpWidget(host(FeedVolumeButton(muted: false, onTap: () {})));

      expect(find.bySemanticsLabel('Mute music'), findsOneWidget);
    });

    testWidgets('reads muted state off the icon', (t) async {
      await t.pumpWidget(host(
        FeedVolumeButton(muted: true, sourceName: 'video', onTap: () {}),
      ));

      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('Unmute video'), findsOneWidget);
    });
  });

  group('VideoMutePreference is what the card drives', () {
    setUp(() => VideoMutePreference.muted = false);

    testWidgets('a tap flips it, and every player hears', (t) async {
      // The card holds no reference to the player. It sets this, and the player
      // on screen is listening — which is how one button in the navigation band
      // reaches a video several widgets away.
      var heard = 0;
      void listener() => heard++;
      VideoMutePreference.notifier.addListener(listener);
      addTearDown(() => VideoMutePreference.notifier.removeListener(listener));

      await t.pumpWidget(host(
        ValueListenableBuilder<bool>(
          valueListenable: VideoMutePreference.notifier,
          builder: (_, muted, __) => FeedVolumeButton(
            muted: muted,
            sourceName: 'video',
            onTap: () => VideoMutePreference.muted = !muted,
          ),
        ),
      ));

      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      await t.tap(find.byType(FeedVolumeButton));
      await t.pump();

      expect(VideoMutePreference.muted, isTrue);
      expect(heard, 1);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget,
          reason: 'the button has to show the state it just set');
    });

    testWidgets('it survives being toggled back', (t) async {
      VideoMutePreference.muted = true;
      VideoMutePreference.muted = false;

      expect(VideoMutePreference.muted, isFalse);
    });
  });

  group('the scrubber clears the navigation bar', () {
    const videoUrl = 'https://res.cloudinary.com/demo/video/upload/a.mp4';

    EventPicture videoPic() => const EventPicture(
          id: videoUrl,
          url: videoUrl,
          imageId: videoUrl,
          price: 0,
          mediaType: MediaType.video,
        );

    Widget carousel({double inset = 0}) => MaterialApp(
          theme: ThemeData(extensions: const [AppThemeExtension.dark]),
          home: Scaffold(
            body: PostPhotoCarousel(
              pics: [videoPic()],
              pageController: PageController(),
              showBlur: false,
              onDoubleTap: () {},
              onTap: () {},
              videoControlsBottomInset: inset,
            ),
          ),
        );

    testWidgets('the card\'s inset reaches the player', (t) async {
      // The card is the only thing that knows whether the bar is up, so it
      // works the number out and hands it down. Two wrappers sit in between —
      // the carousel and the slide — and a value dropped by either puts the
      // scrubber back under the glass with nothing to show for it.
      await t.pumpWidget(carousel(inset: 96));
      await t.pump();

      final player =
          t.widget<JpergVideoPlayer>(find.byType(JpergVideoPlayer));
      expect(player.controlsBottomInset, 96);
    });

    testWidgets('nothing is reserved when the bar is down', (t) async {
      // With the chrome hidden the player owns the bottom edge, and its
      // controls belong on it — a permanent gap would be a strip of nothing.
      await t.pumpWidget(carousel());
      await t.pump();

      expect(
        t.widget<JpergVideoPlayer>(find.byType(JpergVideoPlayer))
            .controlsBottomInset,
        0,
      );
    });

    testWidgets('the feed player draws no mute button of its own', (t) async {
      // It would be a second mute for one video, in a corner people were not
      // looking at, fading out on a timer. The card puts the only one in the
      // navigation band.
      await t.pumpWidget(carousel(inset: 96));
      await t.pump();

      expect(
        t.widget<JpergVideoPlayer>(find.byType(JpergVideoPlayer))
            .showMuteButton,
        isFalse,
      );
    });

    testWidgets('a player left to itself keeps both, as before', (t) async {
      // The album viewer and fullscreen own their whole box. Nothing about
      // this change should have reached them.
      await t.pumpWidget(MaterialApp(
        // The player's buffering spinner reads AppThemeExtension, so a bare
        // ThemeData throws before anything under test is reached.
        theme: ThemeData(extensions: const [AppThemeExtension.dark]),
        home: const Scaffold(
          body: JpergVideoPlayer(url: videoUrl, isActive: false),
        ),
      ));
      await t.pump();

      final player =
          t.widget<JpergVideoPlayer>(find.byType(JpergVideoPlayer));
      expect(player.controlsBottomInset, 0);
      expect(player.showMuteButton, isTrue);
    });
  });
}

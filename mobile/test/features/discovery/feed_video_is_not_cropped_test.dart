import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/cache/comment_counts.dart';
import 'package:jperg_app/core/navigation/feed_chrome.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/media_backdrop.dart';
import 'package:jperg_app/core/widgets/video_player/jperg_video_player.dart';
import 'package:jperg_app/features/admin/data/models/app_config.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/card_photo_preview.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/full_bleed_event_card.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// A clip on the feed is shown whole.
///
/// The card asked for [BoxFit.cover] for a while, to make video reach every
/// edge the way the photographs around it do. It reached the edges by cropping:
/// covering a 19.5:9 screen with the 9:16 a phone records scales the clip up by
/// about a fifth and spends the difference on the sides, so whoever stood at
/// the edge of the shot was cut out of it. That is what people reported — "some
/// part are cut" — on both the Feed and Following tabs, which is one bug,
/// because both tabs build the same [FullBleedEventCard].
///
/// The screen is still filled; the clip is simply not what fills it. A
/// [MediaBackdrop] paints a blurred copy of the clip's own poster frame across
/// the card, so the bands carry the video's light instead of reading as dead
/// space — the same bargain the photographs already strike.
///
/// Pinned at the card, because the card is where it regressed: every layer
/// below this already defaults to contain, and the fit travels through two
/// wrappers to reach the player.
const _videoUrl = 'https://res.cloudinary.com/demo/video/upload/clip.mp4';

EventDiscovery _eventWithVideo() => const EventDiscovery(
      id: 'e1',
      eventName: 'University Graduation',
      photographerName: 'Kwame Studios',
      photographerId: 'p1',
      pictures: [
        EventPicture(
          id: 'pic0',
          url: _videoUrl,
          imageId: 'img0',
          price: 0,
          mediaType: MediaType.video,
          // Portrait, the shape a phone records in — and never the shape of
          // the screen it plays back on.
          width: 1080,
          height: 1920,
        ),
      ],
    );

class _StubDiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState>
    implements DiscoveryBloc {
  _StubDiscoveryBloc() : super(const DiscoveryState());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;

    // Nothing may slide while this is measured: the auto-advance would carry
    // the carousel off the slide under test.
    AppConfigRepository.current = const AppConfig(feedSlideIntervalSeconds: 0);
    CommentCounts.instance.clear();
    FeedChrome.hide();
  });

  tearDown(() {
    AppConfigRepository.current = const AppConfig();
    CommentCounts.instance.clear();
  });

  Future<void> pumpCard(WidgetTester t) async {
    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(
          body: BlocProvider<DiscoveryBloc>(
            create: (_) => _StubDiscoveryBloc(),
            child: PageView(
              scrollDirection: Axis.vertical,
              children: [
                FullBleedEventCard(
                  event: _eventWithVideo(),
                  cardIndex: 0,
                  activeCardIndex: ValueNotifier<int>(0),
                  onTap: () {},
                  onHide: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    await t.pump();
  }

  testWidgets('the feed card asks for the whole clip, not a crop', (t) async {
    await pumpCard(t);

    final carousel =
        t.widget<PostPhotoCarousel>(find.byType(PostPhotoCarousel));
    expect(carousel.videoFit, BoxFit.contain,
        reason: 'cover crops the sides off a vertical clip');
  });

  testWidgets('and the fit survives the trip down to the player', (t) async {
    // Two wrappers in between — the carousel and its slide. A fit dropped by
    // either leaves the player on its own default, which is the right answer
    // here by luck rather than by wiring, and would hide the next regression.
    await pumpCard(t);

    expect(
      t.widget<JpergVideoPlayer>(find.byType(JpergVideoPlayer)).fit,
      BoxFit.contain,
    );
  });

  testWidgets('the bands a contained clip leaves are not bare', (t) async {
    // What makes showing the whole clip acceptable on a feed people arrive at
    // expecting full-bleed media. Without the backdrop this fix trades a crop
    // for two black strips.
    await pumpCard(t);

    final backdrop = t.widget<MediaBackdrop>(find.byType(MediaBackdrop));
    expect(backdrop.url, _videoUrl,
        reason: 'the bands are made from the clip, not from a flat fill');
  });

  testWidgets('a thumbnail may still crop', (t) async {
    // The carousel keeps [videoFit] a parameter for this: a grid tile is a
    // crop by definition, and the default must not be mistaken for a rule
    // against ever cropping anywhere.
    await t.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [AppThemeExtension.dark]),
      home: Scaffold(
        body: PostPhotoCarousel(
          pics: _eventWithVideo().pictures,
          pageController: PageController(),
          showBlur: false,
          onDoubleTap: () {},
          onTap: () {},
          videoFit: BoxFit.cover,
        ),
      ),
    ));
    await t.pump();

    expect(
      t.widget<JpergVideoPlayer>(find.byType(JpergVideoPlayer)).fit,
      BoxFit.cover,
    );
  });
}

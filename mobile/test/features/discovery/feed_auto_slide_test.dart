import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/navigation/feed_chrome.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/admin/data/models/app_config.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/event_card/explore_event_cta.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/full_bleed_event_card.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// A post that is landed on and left alone introduces its own album: the photos
/// step forward by themselves until the third, where "Explore event photos"
/// comes up and the stepping stops for good.
///
/// The two halves of that sentence are what these hold. The slide is help,
/// offered once — it must never turn into a slideshow running under somebody
/// who has started swiping themselves, and the offer has to keep coming back as
/// they swipe or it would be a one-time thing they scrolled past.
EventDiscovery event({int photos = 6}) => EventDiscovery(
      id: 'e1',
      eventName: 'University Graduation',
      photographerName: 'Kwame Studios',
      photographerId: 'p1',
      pictures: [
        for (var i = 0; i < photos; i++)
          EventPicture(
            id: 'pic$i',
            url: 'https://cdn.example.com/$i.jpg',
            imageId: 'img$i',
            price: 0,
            width: 1000,
            height: 1500,
          ),
      ],
    );

class _StubDiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState>
    implements DiscoveryBloc {
  _StubDiscoveryBloc() : super(const DiscoveryState());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget host(EventDiscovery ev) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(
          body: BlocProvider<DiscoveryBloc>(
            create: (_) => _StubDiscoveryBloc(),
            child: FullBleedEventCard(
              event: ev,
              cardIndex: 0,
              activeCardIndex: ValueNotifier<int>(0),
              onTap: () {},
              onHide: () {},
            ),
          ),
        ),
      ),
    );

/// The photo on show. Rounded, because a carousel that has come to rest a
/// hundredth of a page off is on that page as far as anyone looking at it is
/// concerned — and as far as the card is, which reads whole indices.
int currentPage(WidgetTester t) {
  final pager = t.widget<PageView>(find.byType(PageView));
  final ctrl = pager.controller!;
  return (ctrl.page ?? ctrl.initialPage.toDouble()).round();
}

/// Never pumpAndSettle: the photos are network images that never arrive in a
/// test, so the tree has a frame pending forever. Time is advanced explicitly,
/// which is the point here anyway.
Future<void> hold(WidgetTester t, Duration d) async {
  await t.pump(d);
  // Two turns to let a page settle: the spring is started by the first.
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(milliseconds: 500));
}

/// One deliberate swipe to the next photo, settled.
///
/// A fling rather than a drag: a drag of less than half the viewport snaps
/// back, and the point here is that the reader moved on, not how hard they
/// pushed.
Future<void> swipeOn(WidgetTester t) async {
  await t.fling(find.byType(PageView), const Offset(-300, 0), 1200);
  await hold(t, const Duration(milliseconds: 400));
}

void main() {
  setUp(() {
    // A phone, not the 800 x 600 test surface: the card is full-bleed media and
    // a swipe has to cross a phone's width to mean anything.
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;

    // A second rather than the shipped three, so the tests read quickly. The
    // number is the admin's to set — see AppConfig.feedSlideIntervalSeconds.
    AppConfigRepository.current = const AppConfig(feedSlideIntervalSeconds: 1);
    FeedChrome.hide();
  });

  tearDown(() => AppConfigRepository.current = const AppConfig());

  group('the slide', () {
    testWidgets('a post left alone walks itself to the third photo', (t) async {
      await t.pumpWidget(host(event()));
      await t.pump();

      expect(currentPage(t), 0, reason: 'nothing has moved yet');

      await hold(t, const Duration(seconds: 1));
      expect(currentPage(t), 1);

      await hold(t, const Duration(seconds: 1));
      expect(currentPage(t), 2);
    });

    testWidgets('and stops there, however long it is left', (t) async {
      await t.pumpWidget(host(event()));
      await t.pump();

      await hold(t, const Duration(seconds: 1));
      await hold(t, const Duration(seconds: 1));
      expect(currentPage(t), 2);

      // Four more turns of the timer that no longer exists.
      await hold(t, const Duration(seconds: 4));
      expect(currentPage(t), 2,
          reason: 'the third photo is where the offer is, not a checkpoint');
    });

    testWidgets('a swipe ends it — nothing moves under the reader again',
        (t) async {
      await t.pumpWidget(host(event()));
      await t.pump();

      await swipeOn(t);
      expect(currentPage(t), 1, reason: 'the swipe landed');

      await hold(t, const Duration(seconds: 3));
      expect(currentPage(t), 1,
          reason: 'a second hand on the wheel is the last thing they want');
    });

    testWidgets('zero seconds turns it off', (t) async {
      AppConfigRepository.current =
          const AppConfig(feedSlideIntervalSeconds: 0);

      await t.pumpWidget(host(event()));
      await t.pump();
      await hold(t, const Duration(seconds: 5));

      expect(currentPage(t), 0);
    });

    testWidgets('a post with one photo has nothing to slide', (t) async {
      await t.pumpWidget(host(event(photos: 1)));
      await t.pump();
      await hold(t, const Duration(seconds: 3));

      expect(currentPage(t), 0);
    });
  });

  group('the offer', () {
    testWidgets('is absent on the first photos and up on the third', (t) async {
      await t.pumpWidget(host(event()));
      await t.pump();
      expect(find.byType(ExploreEventCta), findsNothing);

      await hold(t, const Duration(seconds: 1));
      expect(find.byType(ExploreEventCta), findsNothing,
          reason: 'on the second photo there is still album to see');

      await hold(t, const Duration(seconds: 1));
      expect(find.byType(ExploreEventCta), findsOneWidget);
    });

    testWidgets('comes back every third photo as they swipe on', (t) async {
      await t.pumpWidget(host(event(photos: 9)));
      await t.pump();

      await swipeOn(t); // 2nd
      await swipeOn(t); // 3rd
      expect(find.byType(ExploreEventCta), findsOneWidget);

      await swipeOn(t); // 4th
      expect(find.byType(ExploreEventCta), findsNothing,
          reason: 'an offer on every photo is wallpaper');

      await swipeOn(t); // 5th
      await swipeOn(t); // 6th
      expect(find.byType(ExploreEventCta), findsOneWidget);
    });

    testWidgets('stands on the last photo whatever number it is', (t) async {
      // Four photos: the fourth is not a multiple of three, and it is the last
      // chance to offer the album before the reader swipes to the next post.
      await t.pumpWidget(host(event(photos: 4)));
      await t.pump();

      for (var i = 0; i < 3; i++) {
        await swipeOn(t);
      }

      expect(currentPage(t), 3);
      expect(find.byType(ExploreEventCta), findsOneWidget);
    });

    testWidgets('a single-photo post offers the photo, not an album',
        (t) async {
      // Its only photo is also its last, so the offer stands — with the tap
      // given over to the chrome it is the only way to see that photo
      // properly. What it must not do is promise an album: whoever tapped
      // "Explore event photos" would land on the picture they were already
      // looking at, wondering where the rest went.
      await t.pumpWidget(host(event(photos: 1)));
      await t.pump();

      expect(find.byType(ExploreEventCta), findsOneWidget);
      expect(find.text('View full image'), findsOneWidget);
      expect(find.text('Explore event photos'), findsNothing);
    });

    testWidgets('a single clip is offered as a clip', (t) async {
      // Same case, different noun. "View full image" over a video is the kind
      // of wrong that reads as the app not knowing what it is showing.
      await t.pumpWidget(host(EventDiscovery(
        id: 'e1',
        eventName: 'University Graduation',
        photographerName: 'Kwame Studios',
        photographerId: 'p1',
        pictures: const [
          EventPicture(
            id: 'clip',
            url: 'https://cdn.example.com/clip.mp4',
            imageId: 'clip',
            price: 0,
            mediaType: MediaType.video,
          ),
        ],
      )));
      await t.pump();

      expect(find.text('View full video'), findsOneWidget);
    });

    testWidgets('two photos are an album again', (t) async {
      // The moment there is something to browse, the offer says so. Two is the
      // boundary, and the CTA stands on the last photo whatever the number.
      await t.pumpWidget(host(event(photos: 2)));
      await t.pump();
      await swipeOn(t);

      expect(find.text('Explore event photos'), findsOneWidget);
    });
  });
}

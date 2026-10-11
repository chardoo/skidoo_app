import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/navigation/feed_chrome.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/admin/data/models/app_config.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/utils/media_readiness.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/event_card/explore_event_cta.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/full_bleed_event_card.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// An album opened from a chat message is already the album.
///
/// Reported: the "Explore event photos" offer is unnecessary there, because
/// the card already lets you swipe every photo in the set — the pill invites
/// you into the place you are standing, and it comes back every third photo.
///
/// Removing it alone would have stranded the reader. The pill was the only
/// route to the full-screen viewer, where a photo zooms and can be bought or
/// downloaded: a tap on the card calls `FeedChrome.toggle()`, and this page
/// has no navigation bar for that to move. So the tap opens the viewer here
/// instead, which is where somebody taps anyway.
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

Widget host(EventDiscovery ev, {required bool isOwnPage}) => ScreenUtilInit(
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
              isOwnPage: isOwnPage,
              readiness: MediaReadiness.resolved(),
            ),
          ),
        ),
      ),
    );

/// Never pumpAndSettle: the photos are network images that never arrive in a
/// test, so the tree has a frame pending forever. Same rule as
/// feed_auto_slide_test, where it is documented at length.
Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(milliseconds: 500));
}

/// Swipes to the photo the offer would normally stand on — the third.
Future<void> swipeToTheOfferPhoto(WidgetTester t) async {
  for (var i = 0; i < 2; i++) {
    await t.drag(find.byType(PageView).first, const Offset(-400, 0));
    await settle(t);
  }
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
    FeedChrome.hide();
    // The card walks itself through the first photos unless the slide is off,
    // which would move the carousel under these.
    AppConfigRepository.current = const AppConfig(feedSlideIntervalSeconds: 0);

    // Opening the viewer posts a view signal through this. Registered rather
    // than stubbed: it is fire-and-forget and the request fails harmlessly
    // with no network, which is exactly how it behaves in production when
    // the call does not land.
    if (!GetIt.I.isRegistered<Api>()) GetIt.I.registerSingleton<Api>(Api());
  });

  tearDown(() {
    AppConfigRepository.current = const AppConfig();
    GetIt.I.reset();
  });

  group('on the album own page', () {
    testWidgets('the explore offer is never made', (t) async {
      await t.pumpWidget(host(event(), isOwnPage: true));
      await settle(t);

      expect(find.byType(ExploreEventCta), findsNothing);

      // Nor on the photo it would normally appear on.
      await swipeToTheOfferPhoto(t);
      expect(find.byType(ExploreEventCta), findsNothing);
    });

    testWidgets('and not on the last photo either', (t) async {
      // The fallback rule puts it on the final photo of an album that does
      // not end on a multiple of three.
      await t.pumpWidget(host(event(photos: 1), isOwnPage: true));
      await settle(t);

      expect(find.byType(ExploreEventCta), findsNothing);
    });

    testWidgets('the whole album is still swipeable', (t) async {
      // The reason the offer is redundant in the first place: nothing is
      // held back here.
      await t.pumpWidget(host(event(), isOwnPage: true));
      await settle(t);

      final pager = t.widget<PageView>(find.byType(PageView).first);
      expect(pager.childrenDelegate.estimatedChildCount, 6);
    });

    testWidgets('a tap does not toggle chrome that is not there', (t) async {
      // It used to, and this page has no navigation bar — so the tap moved
      // nothing a reader could see.
      await t.pumpWidget(host(event(), isOwnPage: true));
      await settle(t);
      expect(FeedChrome.visible.value, isFalse);

      await t.tap(find.byType(PageView).first);
      await settle(t);

      expect(FeedChrome.visible.value, isFalse,
          reason: 'the tap opens the photo now, it does not toggle chrome');
      // And it really did open it — the viewer is on top.
      expect(find.byType(FoundPhotoViewerPage), findsOneWidget);
    });
  });

  group('in the feed, where the album is somewhere else', () {
    testWidgets('the offer is still made', (t) async {
      await t.pumpWidget(host(event(), isOwnPage: false));
      await settle(t);
      await swipeToTheOfferPhoto(t);

      expect(find.byType(ExploreEventCta), findsOneWidget);
    });

    testWidgets('and a tap still toggles the chrome', (t) async {
      await t.pumpWidget(host(event(), isOwnPage: false));
      await settle(t);
      expect(FeedChrome.visible.value, isFalse);

      await t.tap(find.byType(PageView).first);
      await settle(t);

      expect(FeedChrome.visible.value, isTrue);
    });
  });
}

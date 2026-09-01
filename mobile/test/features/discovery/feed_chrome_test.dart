import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/navigation/feed_chrome.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/admin/data/models/app_config.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/full_bleed_event_card.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// What a tap on a post does, and what the caption does about it.
///
/// A tap used to open the event's grid. It brings up the navigation bar and the
/// sound control now, because that is the gesture people make repeatedly while
/// reading a feed and a full-bleed photo leaves nowhere else to put it — the
/// way into the album is the card's own "Explore event photos" instead.
///
/// The second half matters as much as the first: the bar arriving used to bury
/// the last line of the caption and the music pill behind frosted glass, so
/// what the post actually says has to move out of its way.
EventDiscovery event() => EventDiscovery(
      id: 'e1',
      eventName: 'University Graduation',
      photographerName: 'Kwame Studios',
      photographerId: 'p1',
      description: 'Camping at Safari Valley',
      pictures: const [
        EventPicture(
          id: 'pic0',
          url: 'https://cdn.example.com/0.jpg',
          imageId: 'img0',
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

Widget host({bool isAuthenticated = true, VoidCallback? onTap}) =>
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(
          body: BlocProvider<DiscoveryBloc>(
            create: (_) => _StubDiscoveryBloc(),
            child: FullBleedEventCard(
              event: event(),
              cardIndex: 0,
              activeCardIndex: ValueNotifier<int>(0),
              isAuthenticated: isAuthenticated,
              onTap: onTap ?? () {},
              onHide: () {},
            ),
          ),
        ),
      ),
    );

/// Where the caption block sits above the bottom edge.
double captionBottom(WidgetTester t) {
  final card = find.byType(FullBleedEventCard);
  final caption = find.text('University Graduation');
  return t.getRect(card).bottom - t.getRect(caption).bottom;
}

Future<void> tapPhoto(WidgetTester t) async {
  await t.tap(find.byType(PageView));
  // A double-tap recognizer shares the photo with this tap, so the single tap
  // only fires once the double-tap window has passed.
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;

    AppConfigRepository.current = const AppConfig(feedSlideIntervalSeconds: 0);
    FeedChrome.hide();
  });

  tearDown(() {
    AppConfigRepository.current = const AppConfig();
    FeedChrome.hide();
  });

  testWidgets('a tap brings the chrome up, and another sends it away',
      (t) async {
    await t.pumpWidget(host());
    await t.pump();

    expect(FeedChrome.visible.value, isFalse,
        reason: 'the feed opens on the photograph');

    await tapPhoto(t);
    expect(FeedChrome.visible.value, isTrue);

    await tapPhoto(t);
    expect(FeedChrome.visible.value, isFalse);
  });

  testWidgets('a tap no longer opens anything', (t) async {
    await t.pumpWidget(host());
    await t.pump();

    await tapPhoto(t);

    // The grid page used to be pushed here. Nothing is pushed now — the offer
    // on the photo is the way into the album.
    expect(find.byType(FullBleedEventCard), findsOneWidget);
    expect(FeedChrome.visible.value, isTrue);
  });

  testWidgets('on the guest feed a tap still asks them to sign in', (t) async {
    var prompted = 0;

    await t.pumpWidget(host(isAuthenticated: false, onTap: () => prompted++));
    await t.pump();

    await tapPhoto(t);

    expect(prompted, 1);
    expect(FeedChrome.visible.value, isFalse,
        reason: 'a guest has no navigation bar to summon');
  });

  testWidgets('the caption steps over the bar rather than under it',
      (t) async {
    await t.pumpWidget(host());
    await t.pump();

    final resting = captionBottom(t);

    await tapPhoto(t);
    await t.pump(const Duration(milliseconds: 400)); // the lift animates

    final lifted = captionBottom(t);

    // The bar is 58 high on a margin; the caption has to clear all of it.
    expect(lifted - resting, greaterThanOrEqualTo(58.0),
        reason: 'the event name, the track and the hashtags all sit in this '
            'block, and the bar frosts whatever is behind it');
  });
}

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

/// [hasNavBar] is what the Home shell provides and the guest feed does not —
/// see [FeedNavBarScope]. Defaulted true because most of this file is about
/// the Home feed; the guest case asks for false explicitly.
Widget host({
  bool isAuthenticated = true,
  bool hasNavBar = true,
  VoidCallback? onTap,
}) =>
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(
          body: _maybeScope(
            hasNavBar,
            BlocProvider<DiscoveryBloc>(
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
      ),
    );

Widget _maybeScope(bool hasNavBar, Widget child) =>
    hasNavBar ? FeedNavBarScope(child: child) : child;

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

  testWidgets('the caption steps over the bar rather than under it', (t) async {
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

  group('a screen with no navigation bar', () {
    // The reported bug. [FeedChrome.visible] is a static and nothing reset it
    // when the shell owning the bar went away, so signing out and continuing
    // as a guest left it true — and the guest feed, which has no bar at all,
    // cleared ninety-six points for one anyway. The description and its
    // hashtags sat with dead space under them until the app was restarted.

    testWidgets('the flag makes no difference to it', (t) async {
      // Measured off two fresh pumps rather than by toggling a live card: the
      // caption animates between the two positions, so a single pump after a
      // toggle reads the place it is leaving and would agree with itself
      // whatever the rule said.
      FeedChrome.hide();
      await t.pumpWidget(host(hasNavBar: false, isAuthenticated: false));
      await t.pump();
      final flagClear = captionBottom(t);

      // The flag as a logout leaves it: set by the Home feed this session,
      // with nothing to reset it. Nothing here has a bar.
      FeedChrome.show();
      await t.pumpWidget(host(hasNavBar: false, isAuthenticated: false));
      // Long enough for the lift to finish. An identical tree reuses its
      // elements, so the caption would be caught mid-travel and read as though
      // it had never moved — which is the answer this test wants, arrived at
      // for the wrong reason.
      await t.pump(const Duration(milliseconds: 400));

      expect(captionBottom(t), closeTo(flagClear, 1),
          reason: 'with no bar to step over, the flag must change nothing');
    });

    testWidgets('sits where the Home feed sits with its bar away', (t) async {
      // Same card, same resting place. The guest caption was ~96 higher.
      FeedChrome.hide();
      await t.pumpWidget(host());
      await t.pump();
      final home = captionBottom(t);

      FeedChrome.show();
      await t.pumpWidget(host(hasNavBar: false, isAuthenticated: false));
      await t.pump(const Duration(milliseconds: 400));

      expect(captionBottom(t), closeTo(home, 1),
          reason: 'a guest caption rests on the same edge, not above a bar '
              'that is not there');
    });
  });
}

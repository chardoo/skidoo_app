import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/full_bleed_event_card.dart';
import 'package:jperg_app/features/music/domain/entities/music_track.dart';
import 'package:jperg_app/features/music/presentation/feed_music_controller.dart';
import 'package:jperg_app/features/music/presentation/feed_music_player.dart';
import 'package:jperg_app/features/music/presentation/widgets/feed_music_pill.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// The caption block must not jump when the music pill arrives.
///
/// The pill cannot arrive with the card. Claiming publishes null immediately,
/// then waits out the controller's settle delay, then loads the source over the
/// network — so it lands half a second or more after you have landed on the
/// post and started reading it. The block is pinned by its *bottom* edge and
/// grows upward, so inserting the pill at that moment shoved the event's name
/// and description up in a single frame, once per card, every time the feed was
/// scrolled.
///
/// The fix is to hold the row from the first frame on any card that has a track
/// to play, and fade the pill into space that was already there. What these pin
/// is the consequence: **the title does not move.**
const track = MusicTrack(
  id: 't1',
  title: 'Regular',
  artist: 'Mercy Chinwo',
  streamUrl: 'https://cdn.example.com/t1.mp3',
);

EventDiscovery event({List<MusicTrack> music = const []}) => EventDiscovery(
      id: 'e1',
      eventName: 'University Graduation',
      photographerName: 'Kwame Studios',
      photographerId: 'p1',
      description: 'Camping at Safari Valley',
      contentTags: const ['vacation', 'holidays'],
      music: music,
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

/// Enough of a player for a controller to exist. Nothing here ever plays: the
/// state under test is the half-second before anything does.
class _SilentPlayer implements FeedMusicPlayer {
  @override
  Stream<int?> get currentIndexStream => const Stream<int?>.empty();

  @override
  Stream<Object> get errorStream => const Stream<Object>.empty();

  @override
  Duration get position => Duration.zero;

  @override
  Future<void> load(List<String> urls) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position, {int index = 0}) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {}
}

class _StubDiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState>
    implements DiscoveryBloc {
  _StubDiscoveryBloc() : super(const DiscoveryState());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget host(EventDiscovery e) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(
          body: BlocProvider<DiscoveryBloc>(
            create: (_) => _StubDiscoveryBloc(),
            child: FullBleedEventCard(
              event: e,
              cardIndex: 0,
              activeCardIndex: ValueNotifier<int>(0),
              onTap: () {},
              onHide: () {},
            ),
          ),
        ),
      ),
    );

/// Where the event's name sits, as the reader sees it.
double titleTop(WidgetTester t) =>
    t.getRect(find.text('University Graduation')).top;

void main() {
  late FeedMusicController controller;

  setUp(() {
    // A settle delay long enough that nothing ever starts. That is not a
    // contrivance — it is the state every card is in from the moment it is
    // scrolled to until the source has loaded, and the state the jump used to
    // happen out of.
    controller = FeedMusicController(
      player: _SilentPlayer(),
      settleDelay: const Duration(hours: 1),
      persistMuted: (_) async {},
    );
    if (sl.isRegistered<FeedMusicController>()) {
      sl.unregister<FeedMusicController>();
    }
    sl.registerSingleton<FeedMusicController>(controller);

    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  tearDown(() {
    controller.dispose();
    if (sl.isRegistered<FeedMusicController>()) {
      sl.unregister<FeedMusicController>();
    }
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('a scored card holds the pill\'s row before it plays',
      (t) async {
    // Nothing has started playing yet — the state a card is in for the first
    // half-second after it is scrolled to, and the state the jump used to
    // happen out of.
    await t.pumpWidget(host(event(music: const [track])));
    await t.pump();

    // The row is there, holding its height, with the pill inside it invisible.
    final pill = find.byType(FeedMusicPill);
    expect(pill, findsOneWidget);
    expect(
      t.widget<AnimatedOpacity>(
        find.ancestor(of: pill, matching: find.byType(AnimatedOpacity)).first,
      ).opacity,
      0,
      reason: 'a pill for a track that is not playing must not be visible',
    );
  });

  testWidgets('an invisible pill takes no taps', (t) async {
    // It is transparent but laid out, sitting over the photograph. Without the
    // guard it would swallow taps meant for the card underneath.
    await t.pumpWidget(host(event(music: const [track])));
    await t.pump();

    final ignoring = t
        .widgetList<IgnorePointer>(find.ancestor(
          of: find.byType(FeedMusicPill),
          matching: find.byType(IgnorePointer),
        ))
        .map((w) => w.ignoring);

    expect(ignoring, contains(true));
  });

  testWidgets('a card with no music holds nothing', (t) async {
    // The reservation costs the silent cards nothing, and they are most of
    // them. An always-held row would be a permanent empty strip on every post.
    await t.pumpWidget(host(event()));
    await t.pump();

    expect(find.byType(FeedMusicPill), findsNothing);
  });

  testWidgets('the title does not move when the track starts playing',
      (t) async {
    // The whole point, and the thing that was wrong: one card, measured before
    // and after the pill goes live. A scored card is legitimately taller than a
    // silent one — it has a row the other does not — but that height is settled
    // at build time now, so nothing shifts when the music finally arrives.
    //
    // Its own controller, because this one has to actually reach playback.
    final playing = FeedMusicController(
      player: _SilentPlayer(),
      settleDelay: const Duration(milliseconds: 10),
      persistMuted: (_) async {},
      resolveSource: (url) async => url,
    );
    sl.unregister<FeedMusicController>();
    sl.registerSingleton<FeedMusicController>(playing);

    await t.pumpWidget(host(event(music: const [track])));
    await t.pump();
    final before = titleTop(t);
    expect(playing.nowPlaying.value, isNull, reason: 'nothing yet');

    // Past the settle delay and the load, so the pill lights. Fixed pumps
    // rather than pumpAndSettle: the card holds a loading spinner for images
    // that never arrive in a test, so "settled" never comes.
    await t.pump(const Duration(milliseconds: 20));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 60));
    }
    expect(playing.nowPlaying.value, isNotNull,
        reason: 'the pill should be live by now');

    expect(titleTop(t), closeTo(before, 0.5));

    playing.dispose();
  });

  group('the caption reads as one paragraph', () {
    // The hashtags used to be their own block *under* the music pill, so a post
    // read description → pill → tags, with the tags always opening a new line.
    // They belong to the words: they run on from the description, and the pill
    // sits under the writing rather than in the middle of it.
    const runOn = 'Camping at Safari Valley #vacation #holidays';

    testWidgets('the tags continue the description rather than starting a '
        'line of their own', (t) async {
      await t.pumpWidget(host(event(music: const [track])));
      await t.pump();

      // One string in one Text — so they wrap together, and the tags pick up on
      // whatever line the description finished on.
      expect(find.text(runOn), findsOneWidget);
      // And not the two separate blocks it used to be.
      expect(find.text('Camping at Safari Valley'), findsNothing);
      expect(find.text('#vacation #holidays'), findsNothing);
    });

    testWidgets('the hashtags come before the music', (t) async {
      await t.pumpWidget(host(event(music: const [track])));
      await t.pump();

      expect(t.getRect(find.text(runOn)).bottom,
          lessThanOrEqualTo(t.getRect(find.byType(FeedMusicPill)).top));
    });

    testWidgets('tags with no description still read as the caption',
        (t) async {
      await t.pumpWidget(host(EventDiscovery(
        id: 'e2',
        eventName: 'University Graduation',
        photographerName: 'Kwame Studios',
        photographerId: 'p1',
        description: '',
        contentTags: const ['vacation'],
        pictures: const [],
      )));
      await t.pump();

      // No stray leading space where the description would have been.
      expect(find.text('#vacation'), findsOneWidget);
    });
  });

  testWidgets('the block eases rather than snapping', (t) async {
    // The position was already animated for the navigation bar and for a
    // video's taller control band; the height was not, so whenever both moved
    // the edge glided while the content jumped. Both are on the same curve now.
    await t.pumpWidget(host(event(music: const [track])));
    await t.pump();

    final sized = t.widget<AnimatedSize>(
      find
          .ancestor(
            of: find.text('University Graduation'),
            matching: find.byType(AnimatedSize),
          )
          .first,
    );

    expect(sized.duration, const Duration(milliseconds: 200));
    expect(sized.curve, Curves.easeOut);
    // Bottom-anchored, because that is the edge the block is pinned by and the
    // direction it grows in. Any other alignment animates from the wrong end.
    expect(sized.alignment, Alignment.bottomLeft);
  });
}

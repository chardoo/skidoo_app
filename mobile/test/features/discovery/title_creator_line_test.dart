import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/full_bleed_event_card.dart';
import 'package:jperg_app/features/music/presentation/feed_music_controller.dart';
import 'package:jperg_app/features/music/presentation/feed_music_player.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// "<event> by <creator>", when the two names do not fit on one line.
///
/// The pair is unbounded in both halves — an event name and a person's name,
/// each as long as whoever typed it. Laid out as a Row they overflowed, and the
/// only alternative that geometry offers is two half-ellipsised names, which
/// reads as neither one thing nor the other.
///
/// So the creator drops to a second line when the pair is too wide, and stays
/// on the first when it is not. These pin that, and pin the assertion that came
/// with the Row: a `Flexible` nested inside the `GestureDetector` rather than
/// sitting directly under the Row, which threw on every single build and left
/// the name unable to shrink — which is what overflowed it in the first place.
EventDiscovery event({
  required String name,
  required String photographer,
}) =>
    EventDiscovery(
      id: 'e1',
      eventName: name,
      photographerName: photographer,
      photographerId: 'p1',
      description: '',
      contentTags: const [],
      music: const [],
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

void main() {
  late FeedMusicController controller;

  setUp(() {
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

  testWidgets('a short pair shares one line', (t) async {
    await t.pumpWidget(host(event(name: 'Beach Day', photographer: 'Kojo')));
    await t.pump();

    expect(
      t.getCenter(find.text('Beach Day')).dy,
      closeTo(t.getCenter(find.text('Kojo')).dy, 1),
      reason: 'names that fit should read as one sentence on one line',
    );
  });

  testWidgets('a long pair puts the creator on the next line', (t) async {
    await t.pumpWidget(host(event(
      name: 'University Graduation Ceremony 2026',
      photographer: 'Kwame Mensah Photography',
    )));
    await t.pump();

    final title = find.text('University Graduation Ceremony 2026');
    final creator = find.text('Kwame Mensah Photography');

    expect(
      t.getTopLeft(creator).dy,
      greaterThan(t.getCenter(title).dy),
      reason: 'the creator should drop below the title rather than squeeze '
          'both names into ellipses',
    );
    // Down, not sideways: it starts a line rather than being pushed off one.
    expect(t.getTopLeft(creator).dx, lessThan(t.getCenter(title).dx));
  });

  testWidgets('neither layout throws', (t) async {
    // The reported crash: `Flexible` under a `GestureDetector` applies
    // FlexParentData to something that cannot take it, on every build. The
    // overflow was the same bug seen from the other side — an unshrinkable
    // name in a bounded row.
    for (final e in [
      event(name: 'Beach Day', photographer: 'Kojo'),
      event(
        name: 'University Graduation Ceremony 2026',
        photographer: 'Kwame Mensah Photography',
      ),
      // Nothing on either side of the break should overflow alone either.
      event(
        name: 'A Very Long Single Event Name That Fills The Whole Line Alone',
        photographer: 'An Equally Long Photographer Studio Name Here',
      ),
    ]) {
      await t.pumpWidget(host(e));
      await t.pump();

      expect(t.takeException(), isNull, reason: '${e.eventName} threw');
    }
  });

  testWidgets('no creator means no dangling "by"', (t) async {
    await t.pumpWidget(host(event(name: 'Beach Day', photographer: '')));
    await t.pump();

    expect(find.text('by'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/media/media_rail_action.dart';
import 'package:jperg_app/core/navigation/feed_chrome.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/admin/data/models/app_config.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/event_card/heart_burst.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/full_bleed_event_card.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// What a like looks like.
///
/// Liking used to be silent: the heart swapped colour under the thumb that was
/// covering it, and a double-tap on the photo did nothing visible at all. This
/// is the acknowledgement — the rail glyph pops, and a double-tap bursts a
/// heart over the photograph.
///
/// The curves are the feature, so they are what is pinned: an overshoot that
/// passes the resting size and comes back. A scale that merely approaches its
/// target reads as a zoom, which is what this replaced.

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        home: Scaffold(backgroundColor: Colors.black, body: Center(child: child)),
      ),
    );

/// The scale on each [ScaleTransition] inside the control, outermost first.
/// [MediaRailAction] nests two: the press dip around the whole thing, the pop
/// around the glyph.
///
/// Scoped to the control rather than the whole tree: MaterialApp's own route
/// machinery keeps a ScaleTransition parked at zero, and an unscoped search
/// finds it and reports the rail as mid-animation before anything has
/// happened.
List<double> scalesIn(WidgetTester t) => t
    .widgetList<ScaleTransition>(find.descendant(
      of: find.byType(MediaRailAction),
      matching: find.byType(ScaleTransition),
    ))
    .map((w) => w.scale.value)
    .toList();

void main() {
  group('the rail glyph', () {
    testWidgets('pops when the reaction turns on', (t) async {
      var liked = false;
      late StateSetter set;

      await t.pumpWidget(host(StatefulBuilder(builder: (_, setState) {
        set = setState;
        return MediaRailAction(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          active: liked,
          onTap: () {},
        );
      })));
      await t.pump();
      expect(scalesIn(t).every((s) => s == 1.0), isTrue, reason: 'at rest');

      set(() => liked = true);
      await t.pump();
      await t.pump(const Duration(milliseconds: 120));

      // Past its resting size, which is the whole effect.
      expect(scalesIn(t).any((s) => s > 1.2), isTrue,
          reason: 'the glyph has to overshoot, not swell');
    });

    testWidgets('settles back to its own size', (t) async {
      // A heart left larger than its neighbours is a layout bug, not a pop.
      var liked = false;
      late StateSetter set;

      await t.pumpWidget(host(StatefulBuilder(builder: (_, setState) {
        set = setState;
        return MediaRailAction(
          icon: Icons.favorite_rounded,
          active: liked,
          onTap: () {},
        );
      })));
      await t.pump();

      set(() => liked = true);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      for (final s in scalesIn(t)) {
        expect(s, closeTo(1.0, 0.02));
      }
    });

    testWidgets('stays still when the reaction turns off', (t) async {
      // Un-liking is not an achievement, and a heart that pops as it empties
      // reads as a second like.
      var liked = true;
      late StateSetter set;

      await t.pumpWidget(host(StatefulBuilder(builder: (_, setState) {
        set = setState;
        return MediaRailAction(
          icon: Icons.favorite_rounded,
          active: liked,
          onTap: () {},
        );
      })));
      await t.pump();

      set(() => liked = false);
      await t.pump();
      await t.pump(const Duration(milliseconds: 120));

      for (final s in scalesIn(t)) {
        expect(s, closeTo(1.0, 0.02), reason: 'nothing should move');
      }
    });
  });

  group('double-tapping the photo', () {
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

    testWidgets('likes, and bursts a heart over the photo', (t) async {
      final bloc = _RecordingBloc();
      await t.pumpWidget(cardHost(bloc));
      await t.pump();

      await doubleTapPhoto(t);
      await t.pump(const Duration(milliseconds: 120));

      expect(bloc.sent.single.isLike, isTrue);
      final scale = t
          .widget<Transform>(find.descendant(
            of: find.byType(HeartBurst),
            matching: find.byType(Transform),
          ))
          .transform
          .storage[0];
      expect(scale, greaterThan(1.1), reason: 'the heart has to be up by now');

      await t.pump(HeartBurst.duration);
    });

    testWidgets('never takes a like back off', (t) async {
      // The one that matters. This used to call the rail's toggle, so a second
      // double-tap un-liked — on the very gesture people repeat when they are
      // not sure the first one registered. Un-liking lives on the rail, where
      // it is one deliberate tap on a glyph that is visibly full.
      final bloc = _RecordingBloc(alreadyLiked: true);
      await t.pumpWidget(cardHost(bloc));
      await t.pump();

      await doubleTapPhoto(t);
      await t.pump(const Duration(milliseconds: 120));

      expect(bloc.sent, isEmpty,
          reason: 'already liked — there is nothing to send');

      // But the gesture still gets its answer.
      final scale = t
          .widget<Transform>(find.descendant(
            of: find.byType(HeartBurst),
            matching: find.byType(Transform),
          ))
          .transform
          .storage[0];
      expect(scale, greaterThan(1.1),
          reason: 'the burst plays whether or not the like moved');

      await t.pump(HeartBurst.duration);
    });
  });

  group('the burst over the photo', () {
    testWidgets('springs past its resting size, then leaves', (t) async {
      late AnimationController ctrl;

      await t.pumpWidget(host(_BurstHost(onReady: (c) => ctrl = c)));
      await t.pump();

      // Scoped to the burst, for the reason in [scalesIn].
      double scale() => t
          .widget<Transform>(find.descendant(
            of: find.byType(HeartBurst),
            matching: find.byType(Transform),
          ))
          .transform
          .storage[0];
      double opacity() => t
          .widget<Opacity>(find.descendant(
            of: find.byType(HeartBurst),
            matching: find.byType(Opacity),
          ))
          .opacity;

      expect(scale(), 0.0, reason: 'nothing is drawn until it is asked for');

      ctrl.forward();
      await t.pump();

      // Up and over by the time an eye could find it.
      await t.pump(const Duration(milliseconds: 120));
      expect(scale(), greaterThan(1.1));
      expect(opacity(), 1.0, reason: 'a heart that fades in arrives too late');

      // Settled around its resting size in the middle.
      await t.pump(const Duration(milliseconds: 180));
      expect(scale(), closeTo(1.0, 0.05));

      // And gone by the end, rather than sitting on the next post.
      await t.pump(HeartBurst.duration);
      expect(opacity(), 0.0);
    });
  });
}

/// Records the reactions the card asks for, so a double-tap can be checked
/// against what it actually sent rather than against what the screen shows.
class _RecordingBloc extends Bloc<DiscoveryEvent, DiscoveryState>
    implements DiscoveryBloc {
  _RecordingBloc({this.alreadyLiked = false})
      : super(alreadyLiked
            ? const DiscoveryState(reactions: {
                'e1': EventReactionState(
                    likes: 1, dislikes: 0, userReaction: 'like')
              })
            : const DiscoveryState());

  final bool alreadyLiked;
  final sent = <DiscoveryReactionToggled>[];

  /// Recorded, not forwarded: this stub registers no handlers, and a real
  /// `add` would throw looking for one. What is under test is what the card
  /// asks for, not what the bloc does about it.
  @override
  void add(DiscoveryEvent event) {
    if (event is DiscoveryReactionToggled) sent.add(event);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

EventDiscovery _event() => EventDiscovery(
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

Widget cardHost(_RecordingBloc bloc) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(
          body: BlocProvider<DiscoveryBloc>.value(
            value: bloc,
            child: FullBleedEventCard(
              event: _event(),
              cardIndex: 0,
              activeCardIndex: ValueNotifier<int>(0),
              onTap: () {},
              onHide: () {},
            ),
          ),
        ),
      ),
    );

Future<void> doubleTapPhoto(WidgetTester t) async {
  await t.tap(find.byType(PageView));
  await t.pump(const Duration(milliseconds: 40));
  await t.tap(find.byType(PageView));
  await t.pump(const Duration(milliseconds: 40));
}

class _BurstHost extends StatefulWidget {
  const _BurstHost({required this.onReady});
  final void Function(AnimationController) onReady;

  @override
  State<_BurstHost> createState() => _BurstHostState();
}

class _BurstHostState extends State<_BurstHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController ctrl =
      AnimationController(vsync: this, duration: HeartBurst.duration);

  @override
  void initState() {
    super.initState();
    widget.onReady(ctrl);
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HeartBurst(ctrl: ctrl);
}

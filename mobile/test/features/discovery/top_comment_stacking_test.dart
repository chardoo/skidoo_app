import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/cache/comment_counts.dart';
import 'package:jperg_app/core/navigation/feed_chrome.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/admin/data/models/app_config.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/feed_active_event.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/full_bleed_event_card.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/top_comment_line.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// Where the standout comment sits on the card, when it appears, and what it
/// is allowed to displace: nothing.
///
/// It used to *take* the caption's line for five seconds and then hand it back
/// — so the description and the hashtags disappeared while the comment was up,
/// and the comment disappeared for the rest of the time. The reference (Shorts)
/// stacks the two: the comment capsule, then the creator row, then the caption,
/// all on screen together.
///
/// It arrives a beat after the card rather than with it. Present from the first
/// frame it is just more furniture — the eye has nothing to catch, because
/// nothing happened. Unlike the old version it never leaves again: the capsule
/// has its own space, so there is nothing to give back.
///
/// These assert the order, the coexistence and the timing, because that is the
/// whole of what changed and none of it survives a refactor by accident.

const _comment = TopComment(
  id: 'c1',
  authorName: 'Kofi',
  content: 'the light in the third one is unreal',
  likeCount: 312,
  replyCount: 9,
);

EventDiscovery _event({TopComment? topComment = _comment}) => EventDiscovery(
      id: 'e1',
      eventName: 'Labadi Sunset',
      description: 'Golden hour on the shore',
      contentTags: const ['beach', 'accra'],
      photographerName: 'Ama',
      photographerId: 'p1',
      topComment: topComment,
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

Widget _host(
  EventDiscovery event, {
  ValueNotifier<int>? active,
  int cardIndex = 0,
}) =>
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(
          body: BlocProvider<DiscoveryBloc>(
            create: (_) => _StubDiscoveryBloc(),
            child: FullBleedEventCard(
              event: event,
              cardIndex: cardIndex,
              activeCardIndex: active ?? ValueNotifier<int>(0),
              onTap: () {},
              onHide: () {},
            ),
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;

    AppConfigRepository.current = const AppConfig(feedSlideIntervalSeconds: 0);
    CommentCounts.instance.clear();
    FeedActiveEvent.reset();
    FeedChrome.hide();
  });

  tearDown(() {
    AppConfigRepository.current = const AppConfig();
    CommentCounts.instance.clear();
    FeedActiveEvent.reset();
  });

  /// Past the delay and through the arrival animation.
  Future<void> settle(WidgetTester t) async {
    await t.pump(const Duration(seconds: 2));
    await t.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the comment sits above the event name', (t) async {
    await t.pumpWidget(_host(_event()));
    await settle(t);

    final comment = t.getTopLeft(find.byType(TopCommentLine)).dy;
    final name = t.getTopLeft(find.text('Labadi Sunset')).dy;

    expect(comment, lessThan(name));
  });

  testWidgets('the name, the description and the hashtags are all still there',
      (t) async {
    await t.pumpWidget(_host(_event()));
    await settle(t);

    // The whole complaint about the takeover: while the comment was up, this
    // was the text that had gone.
    expect(find.byType(TopCommentLine), findsOneWidget);
    expect(find.text('Labadi Sunset'), findsOneWidget);
    expect(find.textContaining('Ama'), findsWidgets);
    expect(find.textContaining('Golden hour on the shore'), findsOneWidget);
    expect(find.textContaining('#beach'), findsOneWidget);
    expect(find.textContaining('#accra'), findsOneWidget);
  });

  group('it arrives rather than being there', () {
    testWidgets('nothing on the first frame', (t) async {
      await t.pumpWidget(_host(_event()));

      // Present from the start it is part of the furniture. The arrival is
      // what makes it read as the card offering something.
      expect(find.byType(TopCommentLine), findsNothing);
    });

    testWidgets('the card itself is not waiting on it', (t) async {
      await t.pumpWidget(_host(_event()));

      // Only the capsule is delayed. A reader who lands and looks away before
      // it arrives has still had the whole post.
      expect(find.text('Labadi Sunset'), findsOneWidget);
      expect(find.textContaining('Golden hour on the shore'), findsOneWidget);
    });

    testWidgets('then it pops in', (t) async {
      await t.pumpWidget(_host(_event()));
      await settle(t);

      expect(find.byType(TopCommentLine), findsOneWidget);
    });

    testWidgets('and it stays — there is nothing to give back', (t) async {
      await t.pumpWidget(_host(_event()));
      await settle(t);
      await t.pump(const Duration(seconds: 30));

      // The old version borrowed the caption's line and had five seconds to
      // return it. This one has its own space.
      expect(find.byType(TopCommentLine), findsOneWidget);
    });
  });

  testWidgets('a card the reader never reaches never starts its clock',
      (t) async {
    // The pager builds its neighbours ahead of time. A card timed from
    // initState would spend its delay off-screen and be sitting there fully
    // arrived by the time anybody swiped to it.
    final active = ValueNotifier<int>(1);
    await t.pumpWidget(_host(_event(), active: active, cardIndex: 0));
    await settle(t);

    expect(find.byType(TopCommentLine), findsNothing);

    active.value = 0;
    await settle(t);

    expect(find.byType(TopCommentLine), findsOneWidget);
  });

  testWidgets('scrolling away takes it back, so returning is a new arrival',
      (t) async {
    final active = ValueNotifier<int>(0);
    await t.pumpWidget(_host(_event(), active: active, cardIndex: 0));
    await settle(t);
    expect(find.byType(TopCommentLine), findsOneWidget);

    active.value = 1;
    await t.pump();

    expect(find.byType(TopCommentLine), findsNothing);
  });

  testWidgets('a card with no standout comment draws none of it', (t) async {
    await t.pumpWidget(_host(_event(topComment: null)));
    await settle(t);

    // The ordinary case — most cards have no comment that clears the floor.
    expect(find.byType(TopCommentLine), findsNothing);
    expect(find.text('Labadi Sunset'), findsOneWidget);
    expect(find.textContaining('Golden hour on the shore'), findsOneWidget);
  });
}

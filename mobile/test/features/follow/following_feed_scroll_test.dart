import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/follow/data/follow_repository.dart';
import 'package:jperg_app/features/follow/presentation/widgets/feed_suggestions_card.dart';
import 'package:jperg_app/features/follow/presentation/widgets/following_feed.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// The Following tab pages, exactly as the Feed tab does.
///
/// It scrolled freely for a while, because as a page the suggested-creators
/// card was stretched to a whole screen for the sake of five rows. Stretching
/// was the real problem rather than paging: a [FittedBox] — the same wrapper
/// the Feed tab puts round its ads and requests — keeps the card its own size
/// inside a full-screen page, so the feed can snap and the card can still look
/// like a card.
EventDiscovery event(String id) => EventDiscovery(
      id: id,
      eventName: 'Event $id',
      photographerName: 'Creator',
      photographerId: 'c1',
      pictures: const [],
    );

const _suggestions = [
  SuggestedPhotographer(
    id: 's1',
    name: 'Hussein Amadu',
    contact: '',
    email: 'h@example.com',
    followerCount: 4,
  ),
  SuggestedPhotographer(
    id: 's2',
    name: 'Omg photos',
    contact: '',
    email: 'o@example.com',
    followerCount: 4,
  ),
];

/// The post cards read reaction state off a [DiscoveryBloc]; nothing here
/// touches reactions, so an inert one is enough to let them build.
class _StubDiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState>
    implements DiscoveryBloc {
  _StubDiscoveryBloc() : super(const DiscoveryState());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget host({required List<EventDiscovery> feed}) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(
          body: BlocProvider<DiscoveryBloc>(
            create: (_) => _StubDiscoveryBloc(),
            child: FollowingFeed(
              loadFeed: (page, limit) async => (
                events: page == 1 ? feed : <EventDiscovery>[],
                hasMore: false
              ),
              loadSuggestions: (limit) async => _suggestions,
            ),
          ),
        ),
      ),
    );

/// Enough posts for the feed to deal one suggestions card.
List<EventDiscovery> feedOf(int n) =>
    [for (var i = 0; i < n; i++) event('e$i')];

void main() {
  setUp(FollowRepository.debugClearFollowed);
  tearDown(FollowRepository.debugClearFollowed);

  /// The feed's own pager, as opposed to the horizontal one inside each post
  /// that swipes through its photos.
  PageView verticalPager(WidgetTester t) => t
      .widgetList<PageView>(find.byType(PageView))
      .firstWhere((p) => p.scrollDirection == Axis.vertical);

  testWidgets('the feed pages, like the Feed tab', (t) async {
    await t.pumpWidget(host(feed: feedOf(3)));
    await t.pumpAndSettle();

    // Snapping is the whole ask: the two tabs should feel the same under the
    // thumb rather than one gliding and the other catching.
    expect(verticalPager(t).physics, isNot(isA<NeverScrollableScrollPhysics>()));
  });

  testWidgets('a post takes a screen of its own', (t) async {
    await t.pumpWidget(host(feed: feedOf(3)));
    await t.pumpAndSettle();

    final screen = t.getSize(find.byType(Scaffold));
    final pager = t.getSize(find.byType(PageView).first);

    // A page *is* the viewport now, rather than a sized box inside a list.
    expect(pager.height, moreOrLessEquals(screen.height, epsilon: 1));
  });

  testWidgets('one swipe moves exactly one post', (t) async {
    // What snapping buys, and what free scrolling could not promise: a swipe
    // lands on a post rather than between two.
    await t.pumpWidget(host(feed: feedOf(3)));
    await t.pumpAndSettle();

    final screen = t.getSize(find.byType(Scaffold));
    await t.drag(find.byType(PageView).first, Offset(0, -screen.height / 2));
    await t.pumpAndSettle();

    expect(verticalPager(t).controller!.page, 1.0);
  });

  testWidgets('the suggestions card is dealt in, and is still card-shaped',
      (t) async {
    // Five posts is exactly one card's worth.
    await t.pumpWidget(host(feed: feedOf(5)));
    await t.pumpAndSettle();

    final screen = t.getSize(find.byType(Scaffold));

    // Page down through the posts until the card comes into view.
    for (var i = 0; i < 8 && find.byType(FeedSuggestionsCard).evaluate().isEmpty;
        i++) {
      await t.drag(find.byType(PageView).first, Offset(0, -screen.height / 2));
      await t.pumpAndSettle();
    }

    expect(find.byType(FeedSuggestionsCard), findsOneWidget);
    // The page is a full screen; the card inside it must not be. This is the
    // regression that sent the feed to a ListView in the first place — five
    // rows of creators pulled to the height of the viewport.
    expect(t.getSize(find.byType(FeedSuggestionsCard)).height,
        lessThan(screen.height * 0.75));
  });
}

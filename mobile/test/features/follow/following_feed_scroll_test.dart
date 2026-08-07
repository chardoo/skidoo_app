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

/// The Following tab scrolls rather than pages.
///
/// It used to be a vertical [PageView], which forced the suggested-creators
/// card to be a whole screen for the sake of five rows. Scrolling is what lets
/// that card be an item the reader passes on the way to the next post — the
/// posts still take a screen each, they are just no longer snapped to.
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

  testWidgets('the feed scrolls instead of paging', (t) async {
    await t.pumpWidget(host(feed: feedOf(3)));
    await t.pumpAndSettle();

    // A post still pages *horizontally* through its own photos — that one
    // stays. What's gone is the vertical pager the feed itself was, because
    // paging is what forced the suggestions card to be a full screen.
    final vertical = t
        .widgetList<PageView>(find.byType(PageView))
        .where((p) => p.scrollDirection == Axis.vertical);
    expect(vertical, isEmpty);
    expect(find.byType(ListView), findsWidgets);
  });

  testWidgets('a post still takes a screen of its own', (t) async {
    await t.pumpWidget(host(feed: feedOf(3)));
    await t.pumpAndSettle();

    final screen = t.getSize(find.byType(Scaffold));
    final post = t.getSize(find.byType(ListView).first).height;

    // The list fills the viewport, and the first item in it is a whole post.
    expect(post, moreOrLessEquals(screen.height, epsilon: 1));
  });

  testWidgets('the suggestions card is dealt in, and is not a full screen',
      (t) async {
    // Five posts is exactly one card's worth.
    await t.pumpWidget(host(feed: feedOf(5)));
    await t.pumpAndSettle();

    final screen = t.getSize(find.byType(Scaffold));

    // Scroll down through the posts until the card comes into view.
    for (var i = 0; i < 6 && find.byType(FeedSuggestionsCard).evaluate().isEmpty;
        i++) {
      await t.drag(find.byType(ListView).first, Offset(0, -screen.height));
      await t.pump();
    }

    expect(find.byType(FeedSuggestionsCard), findsOneWidget);
    expect(t.getSize(find.byType(FeedSuggestionsCard)).height,
        lessThan(screen.height * 0.75));
  });
}

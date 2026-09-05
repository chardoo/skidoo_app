import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/follow/data/follow_repository.dart';
import 'package:jperg_app/features/follow/presentation/widgets/following_feed.dart';
import 'package:jperg_app/features/home/presentation/pages/home_navigation_page.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// Tapping Home while Home is already the tab you are on.
///
/// Somebody forty cards into the feed had no way back to the top short of
/// swiping all the way, and nothing they could do would show them anything
/// posted since the tab was opened. Chat and Profile already reload when their
/// tab is opened; Home was the one that did neither.
///
/// Both halves have to happen together, and neither substitutes for the other:
/// going back to the top of an hour-old feed shows an hour-old first card, and
/// refetching without moving leaves the reader where they were, looking at
/// nothing that changed.
EventDiscovery event(String id) => EventDiscovery(
      id: id,
      eventName: 'Event $id',
      photographerName: 'Creator',
      photographerId: 'c1',
      pictures: const [],
    );

/// The post cards read reaction state off a [DiscoveryBloc]; nothing here
/// touches reactions, so an inert one is enough to let them build.
class _StubDiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState>
    implements DiscoveryBloc {
  _StubDiscoveryBloc() : super(const DiscoveryState());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUp(FollowRepository.debugClearFollowed);
  tearDown(FollowRepository.debugClearFollowed);

  group('the signal that carries the tap', () {
    tearDown(() => HomeNavigationPage.feedResetRequest.value = 0);

    test('two taps are two resets', () {
      // The whole reason this is a counter and not a flag. A ValueNotifier only
      // notifies when the value *changes*, so a boolean would deliver the first
      // tap and silently swallow every one after it — and tapping Home twice is
      // exactly what somebody does when the first tap did not appear to work.
      var resets = 0;
      void listener() => resets++;
      HomeNavigationPage.feedResetRequest.addListener(listener);

      HomeNavigationPage.feedResetRequest.value++;
      HomeNavigationPage.feedResetRequest.value++;
      HomeNavigationPage.feedResetRequest.value++;

      expect(resets, 3);
      HomeNavigationPage.feedResetRequest.removeListener(listener);
    });
  });

  group('the feed it reaches', () {
    /// The feed's own pager, as opposed to the horizontal one inside each post
    /// that swipes through its photos.
    PageView verticalPager(WidgetTester t) => t
        .widgetList<PageView>(find.byType(PageView))
        .firstWhere((p) => p.scrollDirection == Axis.vertical);

    testWidgets('goes back to the first post and asks the server again',
        (t) async {
      final key = GlobalKey<FollowingFeedState>();
      var fetches = 0;

      await t.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark()
              .copyWith(extensions: const [AppThemeExtension.dark]),
          home: Scaffold(
            body: BlocProvider<DiscoveryBloc>(
              create: (_) => _StubDiscoveryBloc(),
              child: FollowingFeed(
                key: key,
                loadFeed: (page, limit) async {
                  fetches++;
                  return (
                    events: [for (var i = 0; i < 6; i++) event('e$i')],
                    hasMore: false,
                  );
                },
                loadSuggestions: (limit) async => const [],
              ),
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();
      expect(fetches, 1, reason: 'the tab loaded once on open');

      // Deep into the feed, the way somebody who has been reading for a while
      // is.
      final controller = verticalPager(t).controller!;
      controller.jumpToPage(4);
      await t.pumpAndSettle();
      expect(controller.page, 4);

      key.currentState!.resetAndRefresh();
      await t.pumpAndSettle();

      expect(controller.page, 0, reason: 'back to the first post');
      expect(fetches, 2, reason: 'and the endpoint was called again');
    });

    testWidgets('asks again even when already at the top', (t) async {
      // Someone sitting on the first post taps Home to see what is new. There
      // is nowhere to scroll to, so the refetch is the entire point — skipping
      // it because the position is unchanged would make the tap do nothing.
      final key = GlobalKey<FollowingFeedState>();
      var fetches = 0;

      await t.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark()
              .copyWith(extensions: const [AppThemeExtension.dark]),
          home: Scaffold(
            body: BlocProvider<DiscoveryBloc>(
              create: (_) => _StubDiscoveryBloc(),
              child: FollowingFeed(
                key: key,
                loadFeed: (page, limit) async {
                  fetches++;
                  return (events: [event('e0'), event('e1')], hasMore: false);
                },
                loadSuggestions: (limit) async => const [],
              ),
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();
      expect(fetches, 1);

      key.currentState!.resetAndRefresh();
      await t.pumpAndSettle();

      expect(fetches, 2);
    });

    testWidgets('refetches from the first page, not from where paging got to',
        (t) async {
      // The feed pages as you read, so `_page` climbs. A reset that asked for
      // page 3 would return the middle of the feed and call it the top.
      final key = GlobalKey<FollowingFeedState>();
      final pagesAsked = <int>[];

      await t.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark()
              .copyWith(extensions: const [AppThemeExtension.dark]),
          home: Scaffold(
            body: BlocProvider<DiscoveryBloc>(
              create: (_) => _StubDiscoveryBloc(),
              child: FollowingFeed(
                key: key,
                loadFeed: (page, limit) async {
                  pagesAsked.add(page);
                  return (
                    events: [for (var i = 0; i < 4; i++) event('e$i')],
                    hasMore: true,
                  );
                },
                loadSuggestions: (limit) async => const [],
              ),
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();

      key.currentState!.resetAndRefresh();
      await t.pumpAndSettle();

      expect(pagesAsked, everyElement(1));
    });

    testWidgets('keeps the posts on screen while it refetches', (t) async {
      // No spinner over content that is already correct: the tap should read
      // as the feed going back to the top, not as it emptying and refilling.
      final key = GlobalKey<FollowingFeedState>();

      await t.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark()
              .copyWith(extensions: const [AppThemeExtension.dark]),
          home: Scaffold(
            body: BlocProvider<DiscoveryBloc>(
              create: (_) => _StubDiscoveryBloc(),
              child: FollowingFeed(
                key: key,
                loadFeed: (page, limit) async {
                  await Future<void>.delayed(const Duration(milliseconds: 40));
                  return (events: [event('e0'), event('e1')], hasMore: false);
                },
                loadSuggestions: (limit) async => const [],
              ),
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();

      key.currentState!.resetAndRefresh();
      await t.pump(); // mid-flight, before the loader returns

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(verticalPager(t), isNotNull, reason: 'the posts are still there');

      await t.pumpAndSettle();
    });
  });
}

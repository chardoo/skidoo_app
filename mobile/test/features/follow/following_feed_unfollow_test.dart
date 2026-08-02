import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:skidoo_app/features/follow/data/follow_repository.dart';
import 'package:skidoo_app/features/follow/presentation/widgets/following_empty_state.dart';
import 'package:skidoo_app/features/follow/presentation/widgets/following_feed.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';

EventDiscovery event(String id) => EventDiscovery(
      id: id,
      eventName: 'Event $id',
      photographerName: 'Creator',
      photographerId: 'c1',
      pictures: const [],
    );

/// The post cards read reaction state off a [DiscoveryBloc]. Nothing in these
/// tests touches reactions, so a bloc that answers with an empty state and
/// swallows everything else is enough to let the cards build.
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
              loadSuggestions: (limit) async =>
                  const <SuggestedPhotographer>[],
            ),
          ),
        ),
      ),
    );

/// The Following feed is built entirely from people the user follows, so
/// unfollowing the last of them empties it — and it has to say so at once,
/// not the next time something happens to rebuild it.
void main() {
  setUp(FollowRepository.debugClearFollowed);
  tearDown(FollowRepository.debugClearFollowed);

  testWidgets('unfollowing the last creator swaps the posts for suggestions',
      (t) async {
    FollowRepository.seedFollowed(['c1', 'c2']);

    await t.pumpWidget(host(feed: [event('e1'), event('e2')]));
    await t.pumpAndSettle();
    expect(find.byType(FollowingEmptyState), findsNothing);

    // Unfollowed from somewhere else entirely — a profile page, the
    // following list — while this feed is on screen.
    FollowRepository.debugClearFollowed();
    await t.pumpAndSettle();

    expect(find.byType(FollowingEmptyState), findsOneWidget);
    expect(find.text('Follow creators to see their works here'), findsOneWidget);
  });

  testWidgets('unfollowing only some of them leaves the feed alone',
      (t) async {
    FollowRepository.seedFollowed(['c1', 'c2']);

    await t.pumpWidget(host(feed: [event('e1'), event('e2')]));
    await t.pumpAndSettle();

    // One down, one to go — their posts are still the feed.
    FollowRepository.debugSetFollowed(['c2']);
    await t.pumpAndSettle();

    expect(find.byType(FollowingEmptyState), findsNothing);
  });

  testWidgets('an empty followed set at startup is not treated as an unfollow',
      (t) async {
    // Nothing seeded yet — the app simply hasn't learned who the user
    // follows. The feed's own response is what decides, and it has posts.
    await t.pumpWidget(host(feed: [event('e1')]));
    await t.pumpAndSettle();

    expect(find.byType(FollowingEmptyState), findsNothing);

    // A later seed must not be mistaken for a change of heart either.
    FollowRepository.seedFollowed(['c1']);
    await t.pumpAndSettle();
    expect(find.byType(FollowingEmptyState), findsNothing);
  });
}

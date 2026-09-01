import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/full_bleed_event_card.dart';
import 'package:jperg_app/features/follow/data/follow_repository.dart';
import 'package:jperg_app/features/follow/presentation/widgets/following_feed.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// Following builds the same card as the Feed tab, with the same wiring.
///
/// This file was written for an older bug — the feed handed its cards
/// `onTap: () {}`, so a post from someone you had gone out of your way to
/// follow was the one post in the app you could not get into. The fix then was
/// a callback down to the host that opened the event's grid.
///
/// Both ends of that have since gone. A tap belongs to the navigation chrome
/// now and the card handles it itself, and the grid is out of the feed flow
/// entirely — the way into an album is the card's own "Explore event photos".
/// So there is no destination for this feed to hand down, and what is worth
/// holding is the other half of the original bug: that Following builds real
/// cards, wired the same way the Feed tab wires them, rather than something
/// inert.
EventDiscovery event(String id) => EventDiscovery(
      id: id,
      eventName: 'Event $id',
      photographerName: 'Creator',
      photographerId: 'c1',
      pictures: const [],
    );

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
              loadSuggestions: (limit) async => const [],
            ),
          ),
        ),
      ),
    );

List<FullBleedEventCard> cards(WidgetTester t) =>
    t.widgetList<FullBleedEventCard>(find.byType(FullBleedEventCard)).toList();

void main() {
  setUp(FollowRepository.debugClearFollowed);
  tearDown(FollowRepository.debugClearFollowed);

  testWidgets('every post is dealt a card of its own event', (t) async {
    await t.pumpWidget(host(feed: [event('e0'), event('e1')]));
    await t.pumpAndSettle();

    // The first post's event specifically, not merely "an" event — the pager
    // and the card have to agree about which post is which.
    expect(cards(t).first.event.id, 'e0');
  });

  testWidgets('the cards are told where they sit in the pager', (t) async {
    // [cardIndex] against [activeCardIndex] is what decides which post may play
    // its video and hold the feed's soundtrack, and it is the slot index here
    // rather than the post index because a suggestions card takes a slot too.
    await t.pumpWidget(host(feed: [event('e0'), event('e1')]));
    await t.pumpAndSettle();

    expect(cards(t).first.cardIndex, 0);
    expect(cards(t).first.activeCardIndex.value, 0);
  });

  testWidgets('tapping a post is not wired to a destination any more',
      (t) async {
    // The card decides what a tap means — chrome, or a login prompt for a
    // guest. A feed handing down a page to push would be the old flow coming
    // back through the side door.
    await t.pumpWidget(host(feed: [event('e0')]));
    await t.pumpAndSettle();

    expect(cards(t).first.onTap, returnsNormally);
    expect(find.byType(FullBleedEventCard), findsOneWidget);
  });
}

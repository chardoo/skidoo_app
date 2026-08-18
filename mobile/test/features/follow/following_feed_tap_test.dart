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

/// Tapping a post in Following opens its event, exactly as the Feed tab has
/// always done.
///
/// It did nothing at all before: the card was handed `onTap: () {}`, so a post
/// from someone you had gone out of your way to follow was the one post in the
/// app you could not get into.
///
/// The card's own tap gesture belongs to its media, which these do not render
/// — an image in a widget test leaves a network timer pending and the feed
/// never settles. What broke was the callback the feed hands down, so that is
/// what is checked: the card is asked for the callback it was built with.
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

Widget host({
  required List<EventDiscovery> feed,
  ValueChanged<EventDiscovery>? onEventTap,
}) =>
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(
          body: BlocProvider<DiscoveryBloc>(
            create: (_) => _StubDiscoveryBloc(),
            child: FollowingFeed(
              onEventTap: onEventTap,
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

/// The tap callback the feed built the first post's card with.
VoidCallback firstCardTap(WidgetTester t) =>
    t.widgetList<FullBleedEventCard>(find.byType(FullBleedEventCard)).first
        .onTap;

void main() {
  setUp(FollowRepository.debugClearFollowed);
  tearDown(FollowRepository.debugClearFollowed);

  testWidgets('a post opens its own event', (t) async {
    EventDiscovery? opened;

    await t.pumpWidget(host(
      feed: [event('e0'), event('e1')],
      onEventTap: (e) => opened = e,
    ));
    await t.pumpAndSettle();

    firstCardTap(t)();

    // The first post's event specifically, not merely "an" event — it is what
    // the grid on the other side is built from.
    expect(opened?.id, 'e0');
  });

  testWidgets('the callback is optional', (t) async {
    // Nothing wired up must not mean a crash on tap: the parameter is
    // nullable and the Following tab is not its only possible host.
    await t.pumpWidget(host(feed: [event('e0')]));
    await t.pumpAndSettle();

    expect(firstCardTap(t), returnsNormally);
  });

  testWidgets('the wiring is not the empty callback it used to be', (t) async {
    // The regression this file exists for. A card built with `() {}` passes
    // every other test here — it is a perfectly good VoidCallback that does
    // nothing — so the assertion has to be that calling it reaches the host.
    var reached = 0;

    await t.pumpWidget(host(
      feed: [event('e0')],
      onEventTap: (_) => reached++,
    ));
    await t.pumpAndSettle();

    firstCardTap(t)();

    expect(reached, 1);
  });
}

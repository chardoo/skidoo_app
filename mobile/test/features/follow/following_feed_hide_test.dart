import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/cache/hidden_events.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/l10n/app_localizations.dart';
import 'package:jperg_app/features/follow/data/follow_repository.dart';
import 'package:jperg_app/features/follow/presentation/widgets/following_feed.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hiding a post on Following has to hide it *when you tap Hide*.
///
/// The reported bug, twice over. First the hide was never written down, so the
/// next fetch handed the post straight back — fixed by [HiddenEvents]. Then it
/// still "did not hide", and this is why: the card was only removed inside the
/// snackbar's `.then`, which runs when the snackbar *closes*. Tapping Hide
/// appeared to do nothing for several seconds. Discover has always removed the
/// card on the tap and kept the removal pending until the snackbar resolves,
/// which is the whole of "it works nicely on the feed".
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

Widget host(List<EventDiscovery> feed) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        // The card's Hide/Undo strings come from l10n; without the delegates
        // `AppLocalizations.of(context)!` is null and the tap throws.
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(
          body: BlocProvider<DiscoveryBloc>(
            create: (_) => _StubDiscoveryBloc(),
            child: FollowingFeed(
              loadFeed: (page, limit) async => (
                events: page == 1 ? feed : <EventDiscovery>[],
                hasMore: false,
              ),
              loadSuggestions: (limit) async => const <SuggestedPhotographer>[],
            ),
          ),
        ),
      ),
    );

Finder card(String id) => find.byKey(ValueKey('following_event_$id'));

/// Open the card's "…" sheet and press Hide event.
Future<void> tapHide(WidgetTester t) async {
  await t.tap(find.byIcon(Icons.more_horiz_rounded).first);
  await t.pumpAndSettle();
  await t.tap(find.text('Hide event'));
  // One frame. Deliberately not pumpAndSettle: settling would run the
  // snackbar out, and the entire question is whether the card goes *now*
  // rather than when the snackbar closes.
  await t.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HiddenEvents.resetForTest(<String>{});
    FollowRepository.debugClearFollowed();
  });
  tearDown(FollowRepository.debugClearFollowed);

  testWidgets('the post goes when Hide is tapped, not when the snackbar closes',
      (t) async {
    await t.pumpWidget(host([event('a'), event('b')]));
    await t.pumpAndSettle();
    expect(card('a'), findsOneWidget);

    await tapHide(t);

    expect(card('a'), findsNothing);
    await t.pumpAndSettle();
  });

  testWidgets('Undo puts it back', (t) async {
    await t.pumpWidget(host([event('a'), event('b')]));
    await t.pumpAndSettle();

    await tapHide(t);
    expect(card('a'), findsNothing);

    // Let the snackbar finish sliding in. Tapping it mid-animation lands
    // outside the button and silently does nothing.
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();

    expect(card('a'), findsOneWidget);
    // And nothing was written down — a hide that was taken back must leave no
    // trace, or the post vanishes again on the next fetch.
    expect(HiddenEvents.isHidden('a'), isFalse);
  });

  // The fourth case — "let the snackbar time out and the hide is written to
  // storage" — is not here on purpose. `ScaffoldMessenger`'s `closed` future
  // does not resolve under the widget-test harness however the clock is
  // advanced, so the commit branch cannot be driven from here. The two halves
  // are covered where they can be: that a dismissal without Undo persists is
  // `HiddenEvents.hide` itself (test/core/hidden_events_test.dart), and that a
  // persisted hide keeps the post out of the feed is the last test below.

  testWidgets('a hidden post does not come back on a refresh', (t) async {
    // The other half of the original bug: the server does not know what this
    // reader has hidden, so every page it sends can carry one back.
    HiddenEvents.resetForTest({'a'});

    await t.pumpWidget(host([event('a'), event('b')]));
    await t.pumpAndSettle();

    expect(card('a'), findsNothing);
    expect(card('b'), findsOneWidget);
  });
}

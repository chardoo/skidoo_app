import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/features/discovery/data/services/feed_cache_service.dart';
import 'package:jperg_app/features/discovery/domain/usecases/get_random_images_usecase.dart';
import 'package:jperg_app/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:jperg_app/features/splash/presentation/pages/splash_page.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/services/auth_service.dart';

/// The splash used to leave after a fixed 1.8 s whatever was behind it. On a
/// warm cache that was too long; on a first launch it was too short — the feed
/// hadn't loaded, so the brand animation handed over to an empty screen.
///
/// It now waits for the destination to have something to draw, floored so the
/// gif isn't a flicker and ceilinged so a dead network can't strand anyone.

const _destination = '/home';

EventDiscovery event(String id, {List<EventPicture> pictures = const []}) =>
    EventDiscovery(
      id: id,
      eventName: 'Event $id',
      photographerName: 'Creator',
      photographerId: 'c1',
      pictures: pictures,
    );

/// A picture whose bytes cannot be had: there is no HTTP server and no
/// path_provider behind a widget test, so warming it always fails.
///
/// Which is the case worth pinning. The splash now waits for the top card's
/// photo to decode before handing over, and a wait on something that can never
/// arrive is the way that turns into a splash nobody can get past.
const _unreachable = EventPicture(
  id: 'p1',
  url: 'https://res.cloudinary.com/demo/image/upload/v1/nope.jpg',
  imageId: 'i1',
  price: 0,
);

class _FakeAuth extends AuthService {
  @override
  Future<String> getUserId() async => 'u1';
}

class _FakeCache implements FeedCacheService {
  _FakeCache({List<EventDiscovery>? seed}) : stored = seed ?? [];

  List<EventDiscovery> stored;
  int saves = 0;

  /// Whether the last save marked the page as this launch's own.
  bool handedOver = false;

  @override
  List<EventDiscovery> restore() => stored;

  @override
  bool takeHandoff() {
    final was = handedOver;
    handedOver = false;
    return was;
  }

  @override
  Future<void> save(List<EventDiscovery> events,
      {bool warmedForLaunch = false}) async {
    saves++;
    stored = events;
    if (warmedForLaunch) handedOver = true;
  }

  @override
  Future<void> clear() async {
    stored = [];
    handedOver = false;
  }

  @override
  Future<bool> removeEvent(String eventId) async {
    final before = stored.length;
    stored = stored.where((e) => e.id != eventId).toList();
    return stored.length != before;
  }
}

/// Stands in for the first-page fetch. [completer] left unresolved simulates a
/// request that never comes back.
class _FakeFeed implements GetRandomImagesUseCase {
  _FakeFeed({this.result = const [], this.completer, this.throws = false});

  final List<EventDiscovery> result;
  final Completer<List<EventDiscovery>>? completer;
  final bool throws;
  int calls = 0;

  @override
  Future<List<EventDiscovery>> call({
    required int take,
    required int skip,
    String? userId,
    List<String>? followedPhotographerIds,
  }) {
    calls++;
    if (completer != null) return completer!.future;
    if (throws) return Future.error(Exception('offline'));
    return Future.value(result);
  }
}

/// The splash plus a stub destination, so "did it hand over?" is observable.
Widget host() => MaterialApp(
      initialRoute: SplashPage.routeName,
      routes: {
        SplashPage.routeName: (_) =>
            const SplashPage(nextRoute: _destination),
        _destination: (_) =>
            const Scaffold(body: Center(child: Text('DESTINATION'))),
        OnboardingPage.routeName: (_) =>
            const Scaffold(body: Center(child: Text('ONBOARDING'))),
      },
    );

bool handedOver(WidgetTester t) =>
    find.text('DESTINATION').evaluate().isNotEmpty;

/// Just past the point where the splash is free to hand over.
///
/// The floor is the length of the brand animation — the artwork writes the
/// wordmark on, and leaving before its last frame showed a half-drawn logo —
/// plus the dissolve into the destination. Named here rather than repeated as
/// a number, so moving either does not silently strand these.
const _pastTheBeat = Duration(milliseconds: 4200);

/// Advances the clock by [by], then lets the replacement route build and its
/// transition finish. Discrete pumps rather than `pumpAndSettle`, which would
/// be at the mercy of the animated gif still producing frames.
Future<void> advance(WidgetTester t, Duration by) async {
  await t.pump(by);
  // Handing over is two waits now, not one — the beat, then the dissolve into
  // the destination — and the replacement route's own transition follows both.
  // Pumped in steps rather than settled, because the animated gif and the
  // pulsing dots never stop producing frames and `pumpAndSettle` would wait
  // for a still one that never comes.
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  late _FakeCache cache;

  /// Replaces whatever is registered — the locator is process-wide, so a
  /// previous test (or file) may have left its own instance behind.
  void put<T extends Object>(T instance) {
    if (sl.isRegistered<T>()) sl.unregister<T>();
    sl.registerSingleton<T>(instance);
  }

  void register({required _FakeCache withCache, required _FakeFeed feed}) {
    cache = withCache;
    put<FeedCacheService>(withCache);
    put<GetRandomImagesUseCase>(feed);
    put<AuthService>(_FakeAuth());
  }

  tearDown(() {
    for (final drop in [
      () => sl.isRegistered<FeedCacheService>()
          ? sl.unregister<FeedCacheService>()
          : null,
      () => sl.isRegistered<GetRandomImagesUseCase>()
          ? sl.unregister<GetRandomImagesUseCase>()
          : null,
      () => sl.isRegistered<AuthService>() ? sl.unregister<AuthService>() : null,
    ]) {
      drop();
    }
  });

  testWidgets('a warm cache hands over without fetching anything', (t) async {
    // The destination restores the cache synchronously on its first frame, so
    // there is nothing to wait for beyond the brand beat.
    final feed = _FakeFeed();
    register(withCache: _FakeCache(seed: [event('a')]), feed: feed);

    await t.pumpWidget(host());
    expect(handedOver(t), isFalse, reason: 'the floor still applies');

    await advance(t, _pastTheBeat);
    expect(handedOver(t), isTrue);
    expect(feed.calls, 0);
  });

  testWidgets('a cold cache is filled before handing over', (t) async {
    final feed = _FakeFeed(result: [event('a'), event('b')]);
    register(withCache: _FakeCache(), feed: feed);

    await t.pumpWidget(host());
    await advance(t, _pastTheBeat);

    expect(feed.calls, 1);
    expect(cache.saves, 1,
        reason: 'persisted so the destination restores it on its first frame');
    expect(cache.stored, hasLength(2));
    expect(handedOver(t), isTrue);
  });

  testWidgets('a fetch that never returns does not strand the user',
      (t) async {
    final never = Completer<List<EventDiscovery>>();
    register(withCache: _FakeCache(), feed: _FakeFeed(completer: never));

    await t.pumpWidget(host());
    await t.pump(const Duration(seconds: 3));
    expect(handedOver(t), isFalse, reason: 'still inside the ceiling');

    // Past the ceiling the app goes on and the feed shows its own loading
    // state, which is more honest than holding the splash indefinitely.
    await advance(t, const Duration(seconds: 8));
    expect(handedOver(t), isTrue);
  });

  testWidgets('a failed fetch hands over rather than blocking', (t) async {
    register(withCache: _FakeCache(), feed: _FakeFeed(throws: true));

    await t.pumpWidget(host());
    await advance(t, _pastTheBeat);

    expect(handedOver(t), isTrue);
    expect(cache.saves, 0);
  });

  testWidgets('a photo that never arrives does not hold the splash',
      (t) async {
    // Feed data on its own was never the thing worth waiting for: it buys a
    // card with a blurred backdrop and a spinner on it, because the photo is a
    // separate download that had not started. So the warm-up now includes the
    // top card's picture — and everything that wait is bounded by has to hold
    // for it too, or the fix for an empty first screen becomes a stuck splash.
    register(
      withCache: _FakeCache(seed: [event('a', pictures: const [_unreachable])]),
      feed: _FakeFeed(),
    );

    // Restored before the assertions, not in a tearDown: the binding checks
    // that no foundation debug variable outlives the test body, and a tearDown
    // runs after that check.
    final said = <String>[];
    final wasPrinting = debugPrint;
    debugPrint = (message, {wrapWidth}) => said.add(message ?? '');
    try {
      await t.pumpWidget(host());
      await advance(t, _pastTheBeat);
    } finally {
      debugPrint = wasPrinting;
    }

    expect(handedOver(t), isTrue);
    // A warm cache is the path with no await before the picture, so the warm-up
    // ran inside `initState` and reading MediaQuery there threw — abandoning it
    // on exactly the start it exists for. The photo still cannot be fetched
    // here; what must not happen is the warm-up giving up before trying.
    expect(said.where((l) => l.startsWith('[Splash] warm-up failed')), isEmpty);
  });

  testWidgets('onboarding waits for nothing — there is no feed behind it',
      (t) async {
    final feed = _FakeFeed();
    register(withCache: _FakeCache(), feed: feed);

    await t.pumpWidget(MaterialApp(
      initialRoute: SplashPage.routeName,
      routes: {
        SplashPage.routeName: (_) =>
            SplashPage(nextRoute: OnboardingPage.routeName),
        OnboardingPage.routeName: (_) =>
            const Scaffold(body: Center(child: Text('ONBOARDING'))),
      },
    ));
    await advance(t, _pastTheBeat);

    expect(find.text('ONBOARDING'), findsOneWidget);
    expect(feed.calls, 0);
  });
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/features/discovery/domain/usecases/get_random_images_usecase.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/services/auth_service.dart';

/// The feed's first page, asked for before the app has a widget tree.
///
/// **Why this exists at all is the connection, not the query.** Measured
/// against production on 2026-11-02, a cold first call costs about a second,
/// and the server is 30 ms of it:
///
///     TCP connect   253 ms      one round trip
///     TLS ready     439 ms      handshake complete
///     first byte    658 ms      + one round trip + 30 ms of server
///
/// So roughly 440 ms of a launch is a handshake doing no work. The obvious
/// repair — "warm the socket early" — does not survive contact with
/// `dart:io`, whose `HttpClient` speaks HTTP/1.1 only: it cannot multiplex, so
/// a warm-up request *running at the same time* as the feed fetch does not
/// lend it a connection. The second caller opens a second socket and pays the
/// handshake again. Only a connection that is already **idle** gets reused.
///
/// Which leaves one lever that actually works: make the request that matters
/// the first thing on the wire. This starts it from `main()`, ahead of the
/// config fetches that used to race it, and the splash adopts the same future
/// rather than issuing its own.
///
/// **It must stay exactly one request.** Every `skip == 0` is a fresh deal
/// server-side — the ranking is rebuilt and the recommender damps whatever it
/// served last — so asking twice hands back a different top card and throws
/// away the one the splash spent the brand animation decoding. [take] is that
/// single request; [SplashPage] awaits it instead of making its own, and
/// `DiscoveryBloc` adopts the page from the cache. See `first-card-must-not-
/// move` in the splash's own notes.
class LaunchPrefetch {
  LaunchPrefetch._();

  static Future<List<EventDiscovery>>? _inFlight;

  /// How many events the launch asks for.
  ///
  /// Three, not the twenty this used to fetch. The splash needs enough to
  /// paint one card and give the reader somewhere to swipe to; the rest is a
  /// page request that lands while they are still looking at the first photo.
  ///
  /// The twenty was waste twice over. `FeedCacheService` keeps only the first
  /// eight, so the remainder was parsed and dropped — and on the wire it is
  /// 30.9 KB against 5.2 KB for three, gzipped, measured against production.
  /// On a phone that is JSON to decode and hold before the first frame.
  static const pageSize = 3;

  /// Start it. Safe to call more than once — the second call is a no-op, which
  /// is what keeps the "one first-page request" promise if a future caller
  /// forgets.
  static void start() {
    if (_inFlight != null) return;
    _inFlight = _fetch();
  }

  /// The page, awaited by whoever gets there first.
  ///
  /// Returns null when nothing was started, so a caller that runs before
  /// [start] — or in a test — falls back to fetching for itself rather than
  /// hanging on a future nobody created.
  static Future<List<EventDiscovery>>? take() => _inFlight;

  /// Forget it, for tests and for a sign-out that invalidates the page.
  @visibleForTesting
  static void reset() => _inFlight = null;

  static Future<List<EventDiscovery>> _fetch() async {
    final sw = Stopwatch()..start();
    try {
      final events = await sl<GetRandomImagesUseCase>()(
        take: pageSize,
        skip: 0,
        userId: await sl<AuthService>().getUserId(),
      );
      debugPrint('[LaunchPrefetch] ${events.length} events in '
          '${sw.elapsedMilliseconds}ms');
      return events;
    } catch (e) {
      // Swallowed to a empty page, deliberately. The splash treats "nothing
      // came back" exactly as it treats a cold cache and goes on; a launch is
      // not a place to surface a network error, and the feed shows its own
      // state a moment later.
      debugPrint('[LaunchPrefetch] failed after ${sw.elapsedMilliseconds}ms: $e');
      return const [];
    }
  }
}

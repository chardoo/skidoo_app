import 'package:flutter/foundation.dart';

import 'package:jperg_app/core/cache/disk_cache.dart';
import 'package:jperg_app/core/cache/session_cache.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/features/discovery/data/services/feed_cache_service.dart';

/// Forgetting content the server no longer has.
///
/// Everything else in this directory caches things that go *stale* — a like
/// count that moved, a profile that was edited — and the answer to stale is to
/// fetch again. A deleted album is not stale. There is nothing to fetch, and a
/// cache holding one will hold it until something overwrites the whole entry,
/// which on the feed caches means until the next successful first page.
///
/// That gap is visible. [FeedCacheService] and [DiskCache] restore
/// synchronously at launch, before any request goes out, so a deleted album is
/// the first thing on screen on a cold start and stays there until the network
/// answers. Tapping it opens nothing.
///
/// So when the app finds out an album is gone, it says so once, here, and every
/// cache that could be holding it drops it. The phone learns this the only way
/// it can without a push: the next request for that album comes back 404. See
/// `AppInterceptors.onError`, which calls this.
///
/// Ordinary staleness is still the signal's job — [AppCacheSignals.content] is
/// bumped at the end so the session caches and any on-screen list refetch. What
/// this adds is the durable half: the rows on disk, which no signal can reach.
class DeletedContent {
  DeletedContent._();

  /// Ids already forgotten this session.
  ///
  /// A dead album is usually 404'd more than once — the feed card, the grid
  /// behind it and the recommendation ping all ask about the same id, and a
  /// list can hold the same row twice. Without this, one deleted album means
  /// several passes over every cache and several rebuilds of every screen
  /// listening to the signal.
  static final Set<String> _forgotten = <String>{};

  /// Whether this id has already been dealt with. Lets a caller skip the work
  /// and, more usefully, skip telling the reader twice.
  static bool alreadyForgotten(String eventId) => _forgotten.contains(eventId);

  /// Drop an album from every cache that could be holding it.
  ///
  /// Safe to call with an id that was never cached: each cache reports whether
  /// it removed anything and writes nothing when it did not.
  ///
  /// Never throws. This runs from an error interceptor, and a failure to tidy
  /// up must not turn one failed request into two.
  static Future<void> forgetEvent(String eventId) async {
    if (eventId.isEmpty || !_forgotten.add(eventId)) return;

    var removed = 0;
    try {
      // The feed: what the home screen draws before the first request lands.
      if (sl.isRegistered<FeedCacheService>()) {
        if (await sl<FeedCacheService>().removeEvent(eventId)) removed++;
      }

      // Following — rows are the event map itself.
      removed += await _pruneDisk(
        kFollowingFeedCache,
        (row) => row['id']?.toString() == eventId,
      );

      // Found albums — each row wraps the event: {event: {...}, photos: [...]}.
      removed += await _pruneDisk(
        kFoundAlbumsCache,
        (row) {
          final event = row['event'];
          return event is Map && event['id']?.toString() == eventId;
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[DeletedContent] prune failed for $eventId: $e');
    }

    // Bumped whether or not anything was on disk: the in-memory lists a screen
    // is holding right now are not reached by any of the above, and they are
    // the copy the reader is actually looking at.
    AppCacheSignals.content.bump();

    if (kDebugMode) {
      debugPrint('[DeletedContent] forgot event $eventId (from $removed cache(s))');
    }
  }

  static Future<int> _pruneDisk(
    String instanceName,
    bool Function(Map<String, dynamic> row) test,
  ) async {
    if (!sl.isRegistered<DiskCache>(instanceName: instanceName)) return 0;
    final dropped =
        await sl<DiskCache>(instanceName: instanceName).removeWhere(test);
    return dropped > 0 ? 1 : 0;
  }

  /// Forget the forgetting. Called on sign-out with the caches themselves, so
  /// the next account does not inherit a list of ids it never saw — and so an
  /// album that 404'd for a permission reason under one account is asked about
  /// again under the next.
  static void reset() => _forgotten.clear();
}

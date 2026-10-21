import 'package:flutter/foundation.dart';

import 'package:jperg_app/core/cache/disk_cache.dart';
import 'package:jperg_app/core/cache/session_cache.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/features/discovery/data/services/feed_cache_service.dart';

/// Forgetting content the server will not serve any more.
///
/// Everything else in this directory caches things that go *stale* — a like
/// count that moved, a profile that was edited — and the answer to stale is to
/// fetch again. An album that is gone is not stale. There is nothing to fetch,
/// and a cache holding one will hold it until something overwrites the whole
/// entry, which on the feed caches means until the next successful first page.
///
/// That gap is visible. [FeedCacheService] and [DiskCache] restore
/// synchronously at launch, before any request goes out, so content the server
/// no longer has is the first thing on screen on a cold start and stays there
/// until the network answers. Tapping it opens nothing.
///
/// Two things end up here, for the same reason and by different routes:
///
///   * **deleted** — a photographer removed it. The phone finds out the only
///     way it can without a push: the next request for that album comes back
///     404. See `AppInterceptors.onError`, which calls [forgetEvent].
///   * **blocked** — a moderator took it down, and leaving it on the device is
///     the half of a takedown that matters most. Waiting for a 404 is too
///     slow for that, so the server names blocked ids in the `blocked` block
///     of every event list and at `GET /client/blocked-content`; [forgetAll]
///     is what acts on them. See `BlockSync`.
///
/// Ordinary staleness is still the signal's job — [AppCacheSignals.content] is
/// bumped at the end so the session caches and any on-screen list refetch. What
/// this adds is the durable half: the rows on disk, which no signal can reach.
class DeletedContent {
  DeletedContent._();

  /// Ids already forgotten this session, events and pictures together.
  ///
  /// A dead album is usually 404'd more than once — the feed card, the grid
  /// behind it and the recommendation ping all ask about the same id, and a
  /// list can hold the same row twice. The block sync re-sends an id until the
  /// phone's watermark moves past it, which is the same story arriving by a
  /// different road. Without this, one id means several passes over every
  /// cache and several rebuilds of every screen listening to the signal.
  static final Set<String> _forgotten = <String>{};

  /// Whether this id has already been dealt with. Lets a caller skip the work
  /// and, more usefully, skip telling the reader twice.
  static bool alreadyForgotten(String id) => _forgotten.contains(id);

  /// Drop an album from every cache that could be holding it.
  ///
  /// Safe to call with an id that was never cached: each cache reports whether
  /// it removed anything and writes nothing when it did not.
  ///
  /// Never throws. This runs from an error interceptor, and a failure to tidy
  /// up must not turn one failed request into two.
  static Future<void> forgetEvent(String eventId) =>
      forgetAll(events: [eventId]);

  /// Drop one photo from every cache that could be holding it.
  ///
  /// A photo is not reached by forgetting its album: the gallery and Found
  /// caches hold photo rows in their own right, and one blocked frame out of
  /// an album of four hundred leaves the album alone.
  static Future<void> forgetPicture(String pictureId) =>
      forgetAll(pictures: [pictureId]);

  /// Drop a batch — which is how the block sync arrives.
  ///
  /// One pass over each cache for the whole batch rather than one per id, and
  /// one signal bump at the end, so a moderator blocking an album of two
  /// hundred photos costs the phone one rebuild instead of two hundred.
  static Future<void> forgetAll({
    Iterable<String> events = const [],
    Iterable<String> pictures = const [],
  }) async {
    final newEvents = events.where((id) => id.isNotEmpty && _forgotten.add(id)).toSet();
    final newPictures =
        pictures.where((id) => id.isNotEmpty && _forgotten.add(id)).toSet();
    if (newEvents.isEmpty && newPictures.isEmpty) return;

    var removed = 0;
    try {
      if (newEvents.isNotEmpty) {
        // The feed: what the home screen draws before the first request lands.
        if (sl.isRegistered<FeedCacheService>()) {
          for (final id in newEvents) {
            if (await sl<FeedCacheService>().removeEvent(id)) removed++;
          }
        }

        // Following — rows are the event map itself.
        removed += await _pruneDisk(
          kFollowingFeedCache,
          (row) => newEvents.contains(row['id']?.toString()),
        );

        // Found albums — each row wraps the event: {event: {...}, photos: [...]}.
        removed += await _pruneDisk(
          kFoundAlbumsCache,
          (row) {
            final event = row['event'];
            return event is Map &&
                newEvents.contains(event['id']?.toString());
          },
        );
      }

      if (newPictures.isNotEmpty) {
        // A photo can be a row of its own (the Found photo pages) or sit
        // inside an album's row, so both shapes are pruned: the row goes if it
        // *is* the photo, and otherwise has the photo lifted out of it.
        removed += await _pruneDisk(
          kFoundAlbumsCache,
          (row) => newPictures.contains(row['id']?.toString()),
        );
        removed += await _pruneNested(kFoundAlbumsCache, newPictures);
        removed += await _pruneNested(kFollowingFeedCache, newPictures);
        if (sl.isRegistered<FeedCacheService>()) {
          if (await sl<FeedCacheService>().removePictures(newPictures)) removed++;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[DeletedContent] prune failed: $e');
    }

    // Bumped whether or not anything was on disk: the in-memory lists a screen
    // is holding right now are not reached by any of the above, and they are
    // the copy the reader is actually looking at.
    AppCacheSignals.content.bump();

    if (kDebugMode) {
      debugPrint('[DeletedContent] forgot ${newEvents.length} event(s), '
          '${newPictures.length} picture(s) (from $removed cache(s))');
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

  /// Lift blocked photos out of the album rows that hold them.
  ///
  /// The row itself stays: an album is not gone because one frame in it was
  /// taken down, and dropping the row would make the album vanish from the tab
  /// until the next fetch — which reads as the platform having lost it.
  static Future<int> _pruneNested(
    String instanceName,
    Set<String> pictureIds,
  ) async {
    if (!sl.isRegistered<DiskCache>(instanceName: instanceName)) return 0;
    final dropped = await sl<DiskCache>(instanceName: instanceName)
        .editWhere((row) => _withoutPictures(row, pictureIds));
    return dropped > 0 ? 1 : 0;
  }

  /// A cached row with the named photos taken out, or null if it has none of
  /// them. Both key spellings, because the API has answered with each.
  static Map<String, dynamic>? _withoutPictures(
    Map<String, dynamic> row,
    Set<String> pictureIds,
  ) {
    Map<String, dynamic>? changed;
    for (final key in const ['pictures', 'images', 'photos']) {
      final list = row[key];
      if (list is! List) continue;
      final kept = list
          .where((p) => !(p is Map && pictureIds.contains(p['id']?.toString())))
          .toList();
      if (kept.length == list.length) continue;
      changed ??= Map<String, dynamic>.of(row);
      changed[key] = kept;
    }

    // Found rows nest the album one level down: {event: {...}, photos: [...]}.
    final event = row['event'];
    if (event is Map<String, dynamic>) {
      final inner = _withoutPictures(event, pictureIds);
      if (inner != null) {
        changed ??= Map<String, dynamic>.of(row);
        changed['event'] = inner;
      }
    }
    return changed;
  }

  /// Forget the forgetting. Called on sign-out with the caches themselves, so
  /// the next account does not inherit a list of ids it never saw — and so an
  /// album that 404'd for a permission reason under one account is asked about
  /// again under the next.
  static void reset() => _forgotten.clear();
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A screen's last good answer, kept on disk so it survives a launch.
///
/// [SessionCache] holds data for the life of the process and no longer, which
/// is enough to stop a tab refetching every time it is nudged but is nothing
/// to a person opening the app on a train. This is the other half: the last
/// response written as JSON, restored synchronously at startup, so a screen
/// has something to draw before — or instead of — a request.
///
/// It pairs with the image cache rather than duplicating it. The photo bytes
/// are already on disk for sixty days (see `JpergImageCache`); what was
/// missing was the list telling a screen *which* photos to draw. Restore that
/// and the pictures come back with it, offline.
///
/// Modelled on `FeedCacheService`, which did exactly this for the feed and was
/// the reason the feed alone survived without a connection.
///
/// ## Raw rows, not parsed models
///
/// What is stored is the response's own list of maps, exactly as it arrived,
/// and callers parse it with the same constructor they use for the network.
/// So there is one parse path rather than two, and adding a cache to a screen
/// costs nothing in the model: no `toJson` to write, and none to keep in step
/// with a `fromJson` that is already there. A field added to the API appears
/// in the cache the day it ships.
///
/// ## What must not be cached
///
/// Anything here is read back under whatever account is signed in next, so
/// [clear] runs on sign-out and every cache must be registered for it with
/// `SessionReset`. Feed rows carry `isLikedByUser`, `owner` and `isPurchased`
/// — one person's answers — and restoring those under another account shows
/// someone else's likes and marks photos as bought that are not. The restore
/// is synchronous and lands before the first request returns, so the wrong
/// data would not merely be stored, it would be the first thing on screen.
/// What [DiskCache.restore] gives back: the rows, and where the paging had
/// got to when they were written.
///
/// The page number matters as much as the rows. Restoring three pages and
/// telling the screen it is on page 1 would make the next "load more" refetch
/// page 2 — content already on screen, appended a second time.
class CachedPages {
  const CachedPages({
    required this.rows,
    required this.page,
    required this.hasMore,
  });

  const CachedPages.empty()
      : rows = const [],
        page = 0,
        hasMore = true;

  final List<Map<String, dynamic>> rows;

  /// The highest page included. Paging resumes at `page + 1`.
  final int page;

  /// Whether the server said there was more after that page.
  final bool hasMore;

  bool get isEmpty => rows.isEmpty;
  bool get isNotEmpty => rows.isNotEmpty;
}

class DiskCache {
  DiskCache(this._prefs, {required this.key, this.maxEntries = 40});

  final SharedPreferences _prefs;

  /// Versioned by convention — `jperg.<name>.v1`. Bump the suffix when the
  /// shape changes, so an old payload is ignored rather than half-parsed into
  /// something that throws on a field that no longer exists.
  final String key;

  /// A ceiling on what is written, across every page.
  ///
  /// Not a tuning knob so much as a memory budget: SharedPreferences is read
  /// into memory in full at launch, and both of these are read on every
  /// launch whether the tab is opened or not. Measured against production,
  /// a feed row is about 2.4 KB, so forty is roughly 95 KB per cache — a few
  /// screens of scrolling kept, without putting a quarter of a megabyte of
  /// JSON in front of the first frame.
  final int maxEntries;

  /// The rows last saved and the page they reached, or empty when there is
  /// nothing or it will not parse.
  ///
  /// Synchronous: SharedPreferences is already in memory by the time any
  /// screen builds, so this runs in `initState` without an await and without a
  /// frame of spinner.
  ///
  /// Never throws. A cache that cannot be read is a cache miss — the screen
  /// fetches, exactly as it would have without one.
  CachedPages restore() {
    try {
      final raw = _prefs.getString(key);
      if (raw == null || raw.isEmpty) return const CachedPages.empty();
      final decoded = jsonDecode(raw);

      // A bare list is the shape this held before it carried paging state.
      // Read as a first page rather than discarded — the rows are still good,
      // and `hasMore: true` simply lets the screen page on from there.
      if (decoded is List) {
        return CachedPages(
          rows: decoded.whereType<Map<String, dynamic>>().toList(growable: false),
          page: 1,
          hasMore: true,
        );
      }

      if (decoded is! Map<String, dynamic>) return const CachedPages.empty();
      final rows = (decoded['rows'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      if (rows.isEmpty) return const CachedPages.empty();
      return CachedPages(
        rows: rows,
        page: (decoded['page'] as num?)?.toInt() ?? 1,
        hasMore: decoded['hasMore'] as bool? ?? true,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[DiskCache] $key unreadable, ignoring: $e');
      return const CachedPages.empty();
    }
  }

  /// Records one page.
  ///
  /// The first page replaces what was there; later pages append, so scrolling
  /// builds the cache up exactly as it builds the screen up, and a cold launch
  /// restores as far as the reader had actually got. Appending stops at
  /// [maxEntries] — paging on from a restored cache still works, it just is
  /// not all kept.
  ///
  /// Never throws, and never awaited by a screen: a cache write failing must
  /// not be something a person can see.
  ///
  /// An empty first page is not written. "The request came back with nothing"
  /// and "we have not fetched yet" look identical here, and letting one empty
  /// response — a blip, a filter that matched nothing — erase a good cache
  /// would take the screen offline-blank until the next success.
  Future<void> save(
    List<dynamic> rows, {
    required int page,
    required bool hasMore,
  }) async {
    final incoming = rows.whereType<Map<String, dynamic>>().toList();
    final isFirst = page <= 1;
    if (isFirst && incoming.isEmpty) return;

    try {
      final kept = isFirst
          ? incoming
          : [...restore().rows, ...incoming];
      if (kept.isEmpty) return;

      await _prefs.setString(
        key,
        jsonEncode({
          'page': page,
          'hasMore': hasMore,
          'rows': kept.take(maxEntries).toList(),
        }),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[DiskCache] $key save failed: $e');
    }
  }

  /// Drops it. Registered with `SessionReset` by whoever owns the cache — see
  /// the class comment for why that is not optional.
  Future<void> clear() async {
    try {
      await _prefs.remove(key);
    } catch (_) {}
  }
}

/// Named instances in the service locator. Constants rather than bare strings
/// so a typo is a compile error and not a second, empty cache.
const String kFollowingFeedCache = 'followingFeedCache';
const String kFoundAlbumsCache = 'foundAlbumsCache';

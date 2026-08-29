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
class DiskCache {
  DiskCache(this._prefs, {required this.key, this.maxEntries = 30});

  final SharedPreferences _prefs;

  /// Versioned by convention — `jperg.<name>.v1`. Bump the suffix when the
  /// shape changes, so an old payload is ignored rather than half-parsed into
  /// something that throws on a field that no longer exists.
  final String key;

  /// A cap on what is written, not on what is shown. A screen that pages
  /// forever would otherwise grow this without limit, and the point is the
  /// first screenful — enough to open to something, not the whole history.
  final int maxEntries;

  /// The rows last saved, or empty when there are none or they will not parse.
  ///
  /// Synchronous: SharedPreferences is already in memory by the time any
  /// screen builds, so this runs in `initState` without an await and without a
  /// frame of spinner.
  ///
  /// Never throws. A cache that cannot be read is a cache miss — the screen
  /// fetches, exactly as it would have without one.
  List<Map<String, dynamic>> restore() {
    try {
      final raw = _prefs.getString(key);
      if (raw == null || raw.isEmpty) return const [];
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    } catch (e) {
      if (kDebugMode) debugPrint('[DiskCache] $key unreadable, ignoring: $e');
      return const [];
    }
  }

  /// Writes the first [maxEntries]. Never throws, and never awaited by a
  /// screen: a cache write failing must not be something a person can see.
  ///
  /// An empty list is not written. "The request came back with nothing" and
  /// "we have not fetched yet" look identical here, and letting one empty
  /// response — a blip, a filter that matched nothing — erase a good cache
  /// would take the screen offline-blank until the next success.
  Future<void> save(List<dynamic> rows) async {
    if (rows.isEmpty) return;
    try {
      await _prefs.setString(
        key,
        jsonEncode(
          rows.whereType<Map<String, dynamic>>().take(maxEntries).toList(),
        ),
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

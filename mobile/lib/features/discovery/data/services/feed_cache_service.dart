import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// Persists the last successful feed response so the first screen is
/// populated instantly from disk while the network fetch is in-flight.
class FeedCacheService {
  FeedCacheService(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'jperg.feed_cache.v2';

  /// Set by the splash when the page it stored is one it fetched *for this
  /// launch*, and cleared by the first reader — see [takeHandoff].
  static const _handoffKey = 'jperg.feed_cache.handoff';
  static const _maxEvents = 8;

  /// Synchronous read — SharedPreferences is already loaded in memory.
  List<EventDiscovery> restore() {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => EventDiscovery.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Whether what [restore] just handed back is this launch's own first page,
  /// rather than a page left over from a previous session. Answering clears
  /// it, so it is true exactly once.
  ///
  /// The splash fetches the first page when the cache is cold, stores it, and
  /// spends the rest of the brand animation decoding the top card's photograph
  /// so the feed opens on a picture rather than a spinner. The bloc then used
  /// to ask for the first page all over again — and `/client/random-images`
  /// treats every `skip == 0` as "deal again": it rebuilds the ranking
  /// snapshot, reshuffles it through `banded()`, and applies the impression
  /// damping that is aimed at whatever was served on top last time. Which was
  /// the splash's request, moments earlier. So the launch warmed one card and
  /// its very next act was to ask the server for a different one, which landed
  /// a second or two later and took the card away.
  ///
  /// Synchronous like [restore], and for the same reason: it is read on the
  /// path that decides the first frame.
  bool takeHandoff() {
    try {
      if (!(_prefs.getBool(_handoffKey) ?? false)) return false;
      _prefs.remove(_handoffKey).ignore();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Drops the cached feed. Called on sign-out.
  ///
  /// The events themselves are public, but what is stored with them is not:
  /// each carries `isLikedByUser`, `owner` and `isPurchased` for whoever
  /// fetched it. Restored under a different account those flags are simply
  /// wrong — someone else's likes on their feed, photos marked as bought that
  /// they have not bought — and they are shown instantly, because this restore
  /// is synchronous and lands before the first request comes back.
  Future<void> clear() async {
    try {
      await _prefs.remove(_key);
      // Or the next account adopts a handoff pointing at a page that is gone.
      await _prefs.remove(_handoffKey);
    } catch (_) {}
  }

  /// Stores [events] as the feed to paint from on the next cold open.
  ///
  /// [warmedForLaunch] marks the page as this launch's own — only the splash
  /// passes it, and only for a page it fetched itself. See [takeHandoff].
  Future<void> save(
    List<EventDiscovery> events, {
    bool warmedForLaunch = false,
  }) async {
    try {
      final data = jsonEncode(
        events.take(_maxEvents).map((e) => e.toMap()).toList(),
      );
      await _prefs.setString(_key, data);
      if (warmedForLaunch) await _prefs.setBool(_handoffKey, true);
    } catch (_) {}
  }

  /// Drops one event from the cached feed, keeping the rest.
  ///
  /// The restore above is synchronous and lands before the first request comes
  /// back, so a deleted album stays on the first screen of every cold launch
  /// until a fetch replaces the whole cache. That is a card that opens on
  /// nothing. Removing just the one row leaves the other seven to draw.
  ///
  /// Returns whether anything was removed, so a caller can tell a real
  /// deletion from a 404 for some other reason.
  Future<bool> removeEvent(String eventId) async {
    try {
      final current = restore();
      final kept = current.where((e) => e.id != eventId).toList();
      if (kept.length == current.length) return false;
      if (kept.isEmpty) {
        await _prefs.remove(_key);
      } else {
        await save(kept);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

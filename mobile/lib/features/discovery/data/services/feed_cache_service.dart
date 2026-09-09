import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// Persists the last successful feed response so the first screen is
/// populated instantly from disk while the network fetch is in-flight.
class FeedCacheService {
  FeedCacheService(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'jperg.feed_cache.v2';
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
    } catch (_) {}
  }

  Future<void> save(List<EventDiscovery> events) async {
    try {
      final data = jsonEncode(
        events.take(_maxEvents).map((e) => e.toMap()).toList(),
      );
      await _prefs.setString(_key, data);
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

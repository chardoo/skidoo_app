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

  Future<void> save(List<EventDiscovery> events) async {
    try {
      final data = jsonEncode(
        events.take(_maxEvents).map((e) => e.toMap()).toList(),
      );
      await _prefs.setString(_key, data);
    } catch (_) {}
  }
}

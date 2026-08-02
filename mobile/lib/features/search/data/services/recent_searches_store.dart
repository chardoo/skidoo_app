import 'package:shared_preferences/shared_preferences.dart';

/// Recent searches live on the device — there is no endpoint and nothing is
/// sent to the server. Newest first, case-insensitively de-duplicated so
/// retyping a query moves it to the top instead of stacking a second copy.
///
/// Every method swallows storage failures: an unavailable [SharedPreferences]
/// should cost the user their history, not the search screen.
class RecentSearchesStore {
  const RecentSearchesStore();

  static const _key = 'search.recent_queries';

  /// How many are kept. The screen shows fewer (see `RecentSearchesList`);
  /// the surplus is what makes room after a removal.
  static const maxEntries = 10;

  Future<List<String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_key) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// Adds [query] at the top and returns the new list.
  Future<List<String>> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return load();
    final current = await load();
    final next = <String>[
      trimmed,
      ...current.where((e) => e.toLowerCase() != trimmed.toLowerCase()),
    ].take(maxEntries).toList();
    return _save(next);
  }

  /// Removes the row the user tapped ✕ on and returns the new list.
  Future<List<String>> remove(String query) async {
    final current = await load();
    return _save(current.where((e) => e != query).toList());
  }

  Future<List<String>> clear() => _save(const []);

  Future<List<String>> _save(List<String> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, entries);
    } catch (_) {
      // Storage unavailable — the in-memory list is still correct for this
      // session, so hand it back rather than reporting a failure.
    }
    return entries;
  }
}

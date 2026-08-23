import 'package:flutter/foundation.dart';

/// A revision counter that says when cached data stopped being true.
///
/// Bumped by whatever changed the data — a like, a saved event, an arriving
/// push — rather than by the screen that shows it, so a screen never has to
/// know who else can move what it is displaying. Caches built on the same
/// signal all go stale together, and a screen that is currently on-screen can
/// listen to it and refetch on the spot.
class CacheSignal extends ValueNotifier<int> {
  CacheSignal(this.debugName) : super(0);

  final String debugName;

  void bump() {
    value++;
    if (kDebugMode) debugPrint('[Cache] $debugName stale (rev $value)');
  }
}

/// Data a screen already fetched, kept for the rest of the session.
///
/// Screens that fetch in `initState` refetch on every build, and several of
/// ours are built far more often than their data changes: the notification and
/// profile tabs live in an IndexedStack that is nudged on every visit, and
/// Account & Security, Privacy, Face Data and Portfolio are pushed fresh from
/// Settings each time. Every one of those visits was a spinner over content
/// that had not moved.
///
/// This holds the answer, and the [CacheSignal] it was given decides when to
/// stop trusting it. Nothing here survives a launch, and [clearAll] runs on
/// logout so the next account never sees the last one's data.
class SessionCache<T> {
  SessionCache(this.debugName, {this.signal}) {
    _registry.add(clear);
  }

  final String debugName;

  /// Null means the value only ever goes stale when something clears it
  /// outright — settings nobody else can change, for instance.
  final CacheSignal? signal;

  T? _value;
  int _loadedAt = -1;

  int get _revision => signal?.value ?? 0;

  /// True when there is a value and nothing has invalidated it since.
  bool get isFresh => _value != null && _loadedAt == _revision;

  /// What was cached, stale or not. Showing a stale value while a refetch runs
  /// beats showing a spinner, so this stays readable either way — [isFresh] is
  /// what decides whether to refetch, not whether to render.
  T? get value => _value;

  void save(T value) {
    _value = value;
    _loadedAt = _revision;
  }

  void clear() {
    _value = null;
    _loadedAt = -1;
  }

  // ── Session teardown ────────────────────────────────────────────────────────
  static final List<VoidCallback> _registry = [];

  /// Lets a store that is not a [SessionCache] — one with its own mutation
  /// methods, like the notification inbox — be emptied by [clearAll] too.
  static void register(VoidCallback clear) => _registry.add(clear);

  /// Empties every cache in the app. Called from `AuthService.removeToken`:
  /// these are all per-account, and one signed-in user must never be shown
  /// another's leftovers.
  static void clearAll() {
    for (final clear in _registry) {
      clear();
    }
  }
}

/// The signals the app shares. Each names a thing that can change from more
/// than one screen, which is exactly when a cache needs telling.
class AppCacheSignals {
  AppCacheSignals._();

  /// A photo or event was liked or unliked, anywhere.
  static final likes = CacheSignal('likes');

  /// Something was bookmarked or un-bookmarked, anywhere.
  static final saves = CacheSignal('saves');

  /// A notification arrived, or the inbox was written to.
  static final notifications = CacheSignal('notifications');

  /// The signed-in account's settings row changed.
  static final accountSettings = CacheSignal('accountSettings');

  /// The photographer's portfolio or samples changed.
  static final portfolio = CacheSignal('portfolio');

  /// A face scan found more photos of the signed-in person.
  ///
  /// Bumped while `POST /client/search-images` is still streaming — see
  /// [EventScan]. The scan writes an identification row per match, so a grid
  /// already on screen is out of date the moment the next one lands; this is
  /// what tells it to ask again.
  static final foundPhotos = CacheSignal('foundPhotos');
}

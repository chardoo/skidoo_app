import 'package:jperg_app/core/cache/session_cache.dart';
import 'package:jperg_app/features/notifications/data/notification_service.dart';

/// The inbox as the app last saw it.
///
/// The notification tab lives in Home's IndexedStack, so it is torn down and
/// rebuilt around every visit — and fetching in `initState` meant every visit
/// paid for the same list again, scrolled back to the top, and dropped whatever
/// had been paged in. What is on screen is the same rows the server would
/// return, so it is kept here instead and reused until something actually
/// changes it.
///
/// Stale means a push arrived or the rows were written to from elsewhere; only
/// then is a refetch worth it. Pull-to-refresh still asks regardless — that is
/// what the gesture is for.
///
/// One bucket per filter tab, because each tab is its own paged list on the
/// server. They are separate lists of the *same* rows though, so a row marked
/// read or deleted is changed in every bucket holding it — otherwise switching
/// tabs shows the row you just read still bold.
class NotificationInbox {
  NotificationInbox._() {
    SessionCache.register(clear);
  }

  static final NotificationInbox instance = NotificationInbox._();

  final Map<String, _Bucket> _buckets = {};

  /// The empty string is the "All" tab. A map key has to be non-null, and
  /// "no filter" is a real bucket rather than the absence of one.
  _Bucket _bucket(String? filter) =>
      _buckets.putIfAbsent(filter ?? '', _Bucket.new);

  List<AppNotification> items({String? filter}) => _bucket(filter).items;

  /// The last page fetched. Zero means this tab has never been loaded.
  int page({String? filter}) => _bucket(filter).page;

  /// The server has no more rows past what is held here.
  bool exhausted({String? filter}) => _bucket(filter).exhausted;

  /// True when there is a list to show and nothing has invalidated it since.
  bool isFresh({String? filter}) {
    final bucket = _bucket(filter);
    return bucket.page > 0 &&
        bucket.loadedAt == AppCacheSignals.notifications.value;
  }

  /// Replaces the whole list — the first page of a fresh load.
  ///
  /// [at] is the revision read when the request went out, not when it came
  /// back: a push that arrives mid-flight describes a row this response cannot
  /// contain, so stamping "now" would mark the list current when it is already
  /// one short.
  void reset(
    List<AppNotification> rows, {
    required bool exhausted,
    required int at,
    String? filter,
  }) {
    final bucket = _bucket(filter);
    bucket.items
      ..clear()
      ..addAll(rows);
    bucket.page = 1;
    bucket.exhausted = exhausted;
    bucket.loadedAt = at;
  }

  /// Appends a page fetched by scrolling.
  void append(
    List<AppNotification> rows, {
    required bool exhausted,
    String? filter,
  }) {
    final bucket = _bucket(filter);
    bucket.items.addAll(rows);
    bucket.page += 1;
    bucket.exhausted = exhausted;
  }

  /// Marks one row read in place, in every tab holding it. Returns false when
  /// the row is nowhere here, which is what tells a caller its list came from
  /// somewhere else.
  bool markRead(String id) {
    var found = false;
    for (final bucket in _buckets.values) {
      final index = bucket.items.indexWhere((n) => n.id == id);
      if (index == -1) continue;
      bucket.items[index] = bucket.items[index].copyWith(isRead: true);
      found = true;
    }
    return found;
  }

  void markAllRead() {
    for (final bucket in _buckets.values) {
      for (var i = 0; i < bucket.items.length; i++) {
        bucket.items[i] = bucket.items[i].copyWith(isRead: true);
      }
    }
  }

  /// Takes a row out of every tab. The delete request is sent alongside; this
  /// is what makes the row leave the screen without waiting for it.
  void remove(String id) {
    for (final bucket in _buckets.values) {
      bucket.items.removeWhere((n) => n.id == id);
    }
  }

  /// A push landed — what is held here is now missing a row. Bumping the shared
  /// signal is what makes an open inbox reload and a closed one reload on its
  /// next visit. Every tab is stale at once: freshness is measured against this
  /// one signal.
  void invalidate() => AppCacheSignals.notifications.bump();

  void clear() => _buckets.clear();
}

class _Bucket {
  final List<AppNotification> items = [];
  int page = 0;
  bool exhausted = false;
  int loadedAt = -1;
}

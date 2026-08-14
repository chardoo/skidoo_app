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
class NotificationInbox {
  NotificationInbox._() {
    SessionCache.register(clear);
  }

  static final NotificationInbox instance = NotificationInbox._();

  final List<AppNotification> items = [];

  /// The last page fetched. Zero means the inbox has never been loaded.
  int page = 0;

  /// The server has no more rows past what is held here.
  bool exhausted = false;

  int _loadedAt = -1;

  /// True when there is a list to show and nothing has invalidated it since.
  bool get isFresh =>
      page > 0 && _loadedAt == AppCacheSignals.notifications.value;

  /// Replaces the whole list — the first page of a fresh load.
  ///
  /// [at] is the revision read when the request went out, not when it came
  /// back: a push that arrives mid-flight describes a row this response cannot
  /// contain, so stamping "now" would mark the list current when it is already
  /// one short.
  void reset(List<AppNotification> rows,
      {required bool exhausted, required int at}) {
    items
      ..clear()
      ..addAll(rows);
    page = 1;
    this.exhausted = exhausted;
    _loadedAt = at;
  }

  /// Appends a page fetched by scrolling.
  void append(List<AppNotification> rows, {required bool exhausted}) {
    items.addAll(rows);
    page += 1;
    this.exhausted = exhausted;
  }

  /// Marks one row read in place. Returns false when the row is not held here,
  /// which is what tells a caller its list came from somewhere else.
  bool markRead(String id) {
    final index = items.indexWhere((n) => n.id == id);
    if (index == -1) return false;
    items[index] = items[index].copyWith(isRead: true);
    return true;
  }

  void markAllRead() {
    for (var i = 0; i < items.length; i++) {
      items[i] = items[i].copyWith(isRead: true);
    }
  }

  /// A push landed — what is held here is now missing a row. Bumping the shared
  /// signal is what makes an open inbox reload and a closed one reload on its
  /// next visit.
  void invalidate() => AppCacheSignals.notifications.bump();

  void clear() {
    items.clear();
    page = 0;
    exhausted = false;
    _loadedAt = -1;
  }
}

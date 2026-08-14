import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/cache/session_cache.dart';
import 'package:jperg_app/features/notifications/data/notification_inbox.dart';
import 'package:jperg_app/features/notifications/data/notification_service.dart';

/// What these lock down: screens that fetch in `initState` used to refetch on
/// every build, and several of ours are built far more often than their data
/// changes — the notification tab and the profile tabs are rebuilt on every
/// visit, and the settings screens are pushed fresh each time. The rule is now
/// "hold it until something changes it", so the thing worth testing is exactly
/// when a cache stops being trusted.
void main() {
  AppNotification row(String id, {bool isRead = false}) => AppNotification(
        id: id,
        type: 'photo_found',
        title: 'Found you',
        body: 'in an album',
        data: const {},
        isRead: isRead,
        createdAt: DateTime(2026, 8, 14),
      );

  group('SessionCache', () {
    test('a value is fresh until its signal says otherwise', () {
      final signal = CacheSignal('test');
      final cache = SessionCache<String>('test', signal: signal);

      expect(cache.isFresh, isFalse, reason: 'nothing fetched yet');

      cache.save('hello');
      expect(cache.isFresh, isTrue);
      expect(cache.value, 'hello');

      signal.bump();
      expect(cache.isFresh, isFalse,
          reason: 'something changed the data underneath it');
      expect(cache.value, 'hello',
          reason: 'still readable — stale content beats a spinner while a '
              'refetch runs');

      cache.save('hello again');
      expect(cache.isFresh, isTrue);
    });

    test('without a signal, only a clear invalidates', () {
      final cache = SessionCache<int>('unsignalled');
      cache.save(1);
      expect(cache.isFresh, isTrue);

      cache.clear();
      expect(cache.isFresh, isFalse);
      expect(cache.value, isNull);
    });

    test('clearAll empties every cache — this is what logout calls', () {
      final a = SessionCache<String>('a')..save('one account');
      final b = SessionCache<String>('b')..save('its data');

      SessionCache.clearAll();

      expect(a.value, isNull);
      expect(b.value, isNull);
      expect(a.isFresh, isFalse);
      expect(b.isFresh, isFalse);
    });
  });

  group('NotificationInbox', () {
    final inbox = NotificationInbox.instance;

    setUp(inbox.clear);

    test('an untouched inbox is not fresh, so the first visit fetches', () {
      expect(inbox.isFresh, isFalse);
      expect(inbox.page, 0);
    });

    test('rows survive between visits once loaded', () {
      inbox.reset([row('1'), row('2')],
          exhausted: false, at: AppCacheSignals.notifications.value);

      expect(inbox.isFresh, isTrue);
      expect(inbox.items, hasLength(2));
      expect(inbox.page, 1);
    });

    test('paging appends rather than replacing', () {
      inbox.reset([row('1')],
          exhausted: false, at: AppCacheSignals.notifications.value);
      inbox.append([row('2')], exhausted: true);

      expect(inbox.items.map((n) => n.id), ['1', '2']);
      expect(inbox.page, 2);
      expect(inbox.exhausted, isTrue);
    });

    test('read marks persist — the whole point of not refetching', () {
      inbox.reset([row('1'), row('2')],
          exhausted: true, at: AppCacheSignals.notifications.value);

      expect(inbox.markRead('2'), isTrue);
      expect(inbox.items[1].isRead, isTrue);
      expect(inbox.items[0].isRead, isFalse);
      expect(inbox.isFresh, isTrue,
          reason: 'the app made this change, so there is nothing to go and ask '
              'the server about');

      inbox.markAllRead();
      expect(inbox.items.every((n) => n.isRead), isTrue);
    });

    test('marking a row it does not hold reports so', () {
      inbox.reset([row('1')],
          exhausted: true, at: AppCacheSignals.notifications.value);
      expect(inbox.markRead('nope'), isFalse);
    });

    test('a push makes it stale — this is what triggers the next fetch', () {
      inbox.reset([row('1')],
          exhausted: true, at: AppCacheSignals.notifications.value);
      expect(inbox.isFresh, isTrue);

      inbox.invalidate();

      expect(inbox.isFresh, isFalse);
      expect(inbox.items, hasLength(1),
          reason: 'the rows stay up while the refetch runs');
    });

    test('a push that lands mid-fetch still leaves it stale', () {
      // The revision is read when the request goes out; a push arriving before
      // it comes back describes a row that response cannot contain, so
      // stamping the answer must not mark the list current.
      final at = AppCacheSignals.notifications.value;
      AppCacheSignals.notifications.bump();
      inbox.reset([row('1')], exhausted: true, at: at);

      expect(inbox.isFresh, isFalse);
    });

    test('logout empties it', () {
      inbox.reset([row('1')],
          exhausted: true, at: AppCacheSignals.notifications.value);

      SessionCache.clearAll();

      expect(inbox.items, isEmpty);
      expect(inbox.page, 0);
      expect(inbox.isFresh, isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/cache/disk_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Forgetting an album the photographer deleted.
///
/// The caches in this app hold things that go *stale*, and the cure for stale
/// is another fetch. A deleted album is not stale — there is nothing to fetch —
/// and both feed caches restore synchronously at launch, before any request
/// goes out. So a deleted album was the first thing on screen on a cold start
/// and stayed there until the network answered, as a card that opened on
/// nothing.
///
/// [DiskCache.removeWhere] is the surgical half of the fix: drop the one dead
/// row and keep the rest, rather than clearing three good screens to be rid of
/// it. `DeletedContent` drives it from the 404 interceptor; what is exercised
/// here is the primitive, because that is where getting it wrong costs someone
/// their offline feed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  DiskCache cacheFor(String key) => DiskCache(prefs, key: key, maxEntries: 30);

  Future<DiskCache> seeded(String key) async {
    final cache = cacheFor(key);
    await cache.save([
      {'id': 'a', 'url': 'https://x/a.jpg'},
      {'id': 'gone', 'url': 'https://x/gone.jpg'},
      {'id': 'c', 'url': 'https://x/c.jpg'},
    ], page: 2, hasMore: true);
    return cache;
  }

  group('removing one row', () {
    test('the matched row goes and the others stay', () async {
      final cache = await seeded('k');

      final removed = await cache.removeWhere((row) => row['id'] == 'gone');

      expect(removed, 1);
      expect(
        cache.restore().rows.map((r) => r['id']),
        ['a', 'c'],
        reason: 'dropping one dead album must not take the live ones with it',
      );
    });

    test('paging state is left alone', () async {
      final cache = await seeded('k');
      await cache.removeWhere((row) => row['id'] == 'gone');

      final after = cache.restore();
      // Recomputing `page` from the new row count would make the next
      // "load more" refetch a page already on screen and append it twice.
      expect(after.page, 2);
      expect(after.hasMore, isTrue);
    });

    test('a row that is not there changes nothing and writes nothing',
        () async {
      final cache = await seeded('k');

      final removed = await cache.removeWhere((row) => row['id'] == 'absent');

      expect(removed, 0);
      expect(cache.restore().rows, hasLength(3));
    });

    test('removing the last row empties the cache rather than leaving a husk',
        () async {
      final cache = cacheFor('k');
      await cache.save([
        {'id': 'only', 'url': 'https://x/only.jpg'},
      ], page: 1, hasMore: false);

      expect(await cache.removeWhere((row) => row['id'] == 'only'), 1);
      // Not an entry holding an empty list: `restore` treats that as a miss
      // anyway, and leaving it behind would keep dead JSON in the payload
      // SharedPreferences reads in full at launch.
      expect(cache.restore().isEmpty, isTrue);
      expect(prefs.getString('k'), isNull);
    });

    test('every copy of the same album goes', () async {
      final cache = cacheFor('k');
      // A feed paged twice can hold the same album on both pages.
      await cache.save([
        {'id': 'gone', 'url': 'https://x/1.jpg'},
        {'id': 'a', 'url': 'https://x/a.jpg'},
      ], page: 1, hasMore: true);
      await cache.save([
        {'id': 'gone', 'url': 'https://x/2.jpg'},
      ], page: 2, hasMore: false);

      expect(await cache.removeWhere((row) => row['id'] == 'gone'), 2);
      expect(cache.restore().rows.map((r) => r['id']), ['a']);
    });

    test('an unreadable cache is survived, not thrown from', () async {
      await prefs.setString('k', 'not json at all');

      expect(await cacheFor('k').removeWhere((_) => true), 0);
    });
  });

  group('the Found tab shape', () {
    test('the album id is read from the nested event', () async {
      // Found rows wrap the event: {event: {...}, photos: [...]}. The matcher
      // in DeletedContent reaches through that, and a flat `row['id']` test
      // would silently match nothing and leave the dead album on screen.
      final cache = cacheFor('found');
      await cache.save([
        {
          'event': {'id': 'gone', 'eventName': 'Deleted Album'},
          'photos': const [],
        },
        {
          'event': {'id': 'keep', 'eventName': 'Live Album'},
          'photos': const [],
        },
      ], page: 1, hasMore: false);

      final removed = await cache.removeWhere((row) {
        final event = row['event'];
        return event is Map && event['id']?.toString() == 'gone';
      });

      expect(removed, 1);
      final left = cache.restore().rows;
      expect(left, hasLength(1));
      expect((left.first['event'] as Map)['id'], 'keep');
    });
  });
}

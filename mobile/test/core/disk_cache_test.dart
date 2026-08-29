import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/cache/disk_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The store behind the Following and Found tabs opening to something without
/// a connection.
///
/// The photo bytes were always on disk — [JpergImageCache] keeps them for
/// sixty days. What was missing was the list saying which photos to draw, so
/// both tabs fetched from scratch and showed a spinner then an error offline,
/// while the feed, which had a cache of exactly this kind, did not.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  DiskCache cacheFor(String key, {int maxEntries = 30}) =>
      DiskCache(prefs, key: key, maxEntries: maxEntries);

  group('a round trip', () {
    test('rows come back as they went in', () async {
      final cache = cacheFor('k');
      await cache.save([
        {'id': 'a', 'url': 'https://x/a.jpg', 'price': 1.5},
        {'id': 'b', 'url': 'https://x/b.jpg', 'price': 0},
      ]);

      final restored = cache.restore();
      expect(restored, hasLength(2));
      expect(restored.first['id'], 'a');
      // Raw rows, so the same parser reads the cache and the network — and a
      // price does not quietly change type on the way through.
      expect(restored.first['price'], 1.5);
    });

    test('restore is empty when nothing was saved', () {
      expect(cacheFor('never-written').restore(), isEmpty);
    });

    test('two caches do not see each other', () async {
      await cacheFor('one').save([
        {'id': 'a'}
      ]);
      expect(cacheFor('two').restore(), isEmpty);
    });
  });

  group('it never brings a screen down', () {
    test('a corrupt payload reads as a miss, not a crash', () async {
      await prefs.setString('k', 'not json at all');
      expect(cacheFor('k').restore(), isEmpty);
    });

    test('a payload of the wrong shape reads as a miss', () async {
      await prefs.setString('k', jsonEncode({'not': 'a list'}));
      expect(cacheFor('k').restore(), isEmpty);
    });

    test('non-map entries are dropped rather than thrown on', () async {
      await prefs.setString('k', jsonEncode([{'id': 'a'}, 'rubbish', 7]));
      final restored = cacheFor('k').restore();
      expect(restored, hasLength(1));
      expect(restored.first['id'], 'a');
    });
  });

  group('what it refuses to do', () {
    test('an empty response does not erase a good cache', () async {
      final cache = cacheFor('k');
      await cache.save([
        {'id': 'a'}
      ]);

      // A blip, or a filter that matched nothing. Writing it would take the
      // tab offline-blank until the next successful fetch.
      await cache.save([]);

      expect(cache.restore(), hasLength(1));
    });

    test('it writes no more than maxEntries', () async {
      final cache = cacheFor('k', maxEntries: 3);
      await cache.save([for (var i = 0; i < 20; i++) {'id': '$i'}]);

      final restored = cache.restore();
      expect(restored, hasLength(3));
      expect(restored.last['id'], '2', reason: 'it keeps the first, not the last');
    });
  });

  group('sign-out', () {
    test('clear leaves nothing for the next account', () async {
      final cache = cacheFor('k');
      await cache.save([
        // The reason this matters: these flags are one person's answers.
        {'id': 'a', 'isLikedByUser': true, 'isPurchased': true}
      ]);
      expect(cache.restore(), isNotEmpty);

      await cache.clear();

      expect(cache.restore(), isEmpty,
          reason: "someone else's likes and purchases must not be restored "
              'under a new account');
    });
  });
}

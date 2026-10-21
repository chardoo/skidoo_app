import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jperg_app/core/cache/block_sync.dart';
import 'package:jperg_app/core/cache/deleted_content.dart';
import 'package:jperg_app/core/cache/disk_cache.dart';
import 'package:jperg_app/core/cache/session_cache.dart';
import 'package:jperg_app/core/di/service_locator.dart';

/// Blocked content leaving the phone.
///
/// Blocking on the server takes content out of every answer it gives. It does
/// not take it off a device that already has it: [DiskCache] and the feed
/// cache restore synchronously at launch, *before* any request goes out, so
/// blocked content is on screen on a cold start and stays there until
/// something replaces the whole entry. For a takedown that is the surface that
/// matters most — the copy in somebody's hand.
///
/// So the server names blocked ids on requests the app is already making, and
/// this is the half that acts on them: prune the disk, remember how far we
/// got, and tell the on-screen lists.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    if (sl.isRegistered<SharedPreferences>()) sl.unregister<SharedPreferences>();
    sl.registerSingleton<SharedPreferences>(prefs);

    for (final name in [kFollowingFeedCache, kFoundAlbumsCache]) {
      if (sl.isRegistered<DiskCache>(instanceName: name)) {
        sl.unregister<DiskCache>(instanceName: name);
      }
      sl.registerSingleton<DiskCache>(
        DiskCache(prefs, key: 'jperg.$name.v1'),
        instanceName: name,
      );
    }
    DeletedContent.reset();
  });

  tearDown(() async {
    await sl.reset();
    DeletedContent.reset();
  });

  DiskCache following() => sl<DiskCache>(instanceName: kFollowingFeedCache);
  DiskCache found() => sl<DiskCache>(instanceName: kFoundAlbumsCache);

  group('the watermark', () {
    test('is empty until something has been applied', () {
      expect(BlockSync.watermark, isNull);
    });

    test('is stored from the payload, so the next ask is narrow', () async {
      await BlockSync.apply({
        'events': <String>[],
        'pictures': <String>[],
        'syncedAt': '2026-10-21T09:00:00Z',
      });

      expect(BlockSync.watermark, '2026-10-21T09:00:00Z');
    });

    test('survives a relaunch — a block that happened while the app was '
        'closed is the one a cold start would keep showing', () async {
      await BlockSync.apply({'syncedAt': '2026-10-21T09:00:00Z'});

      // A fresh read of prefs is what the next launch does.
      final reread = await SharedPreferences.getInstance();
      expect(reread.getString('jperg.block_sync.watermark'),
          '2026-10-21T09:00:00Z');
    });

    test('does not move when the server capped its answer', () async {
      await BlockSync.apply({'syncedAt': '2026-10-21T09:00:00Z'});
      await BlockSync.apply({
        'events': ['e1'],
        'syncedAt': '2026-10-21T10:00:00Z',
        'more': true,
      });

      // Advancing past a truncated answer would skip whatever did not fit.
      expect(BlockSync.watermark, '2026-10-21T09:00:00Z');
    });

    test('is handed to the fetcher on a pull', () async {
      await BlockSync.apply({'syncedAt': '2026-10-21T09:00:00Z'});

      String? seen;
      await BlockSync.pull((since) async {
        seen = since;
        return {'data': {'events': <String>[], 'pictures': <String>[]}};
      });

      expect(seen, '2026-10-21T09:00:00Z');
    });
  });

  group('applying a payload', () {
    test('drops a blocked album from the Following cache', () async {
      await following().save([
        {'id': 'keep', 'eventName': 'Fine'},
        {'id': 'blocked', 'eventName': 'Taken down'},
      ], page: 1, hasMore: false);

      await BlockSync.apply({
        'events': ['blocked'],
        'pictures': <String>[],
        'syncedAt': '2026-10-21T09:00:00Z',
      });

      final ids = following().restore().rows.map((r) => r['id']).toList();
      expect(ids, ['keep']);
    });

    test('lifts a blocked photo out of the album that holds it', () async {
      // The album is not gone because one frame in it was taken down —
      // dropping the row would make the album vanish from the tab until the
      // next fetch, which reads as the platform having lost it.
      await following().save([
        {
          'id': 'album',
          'eventName': 'Fine',
          'pictures': [
            {'id': 'p1'},
            {'id': 'blocked'},
          ],
        },
      ], page: 1, hasMore: false);

      await BlockSync.apply({
        'events': <String>[],
        'pictures': ['blocked'],
        'syncedAt': '2026-10-21T09:00:00Z',
      });

      final rows = following().restore().rows;
      expect(rows.length, 1, reason: 'the album itself should survive');
      expect((rows.first['pictures'] as List).map((p) => p['id']), ['p1']);
    });

    test('reaches photos nested under a Found row', () async {
      await found().save([
        {
          'event': {
            'id': 'album',
            'photos': [
              {'id': 'p1'},
              {'id': 'blocked'},
            ],
          },
        },
      ], page: 1, hasMore: false);

      await BlockSync.apply({
        'pictures': ['blocked'],
        'syncedAt': '2026-10-21T09:00:00Z',
      });

      final event = found().restore().rows.first['event'] as Map;
      expect((event['photos'] as List).map((p) => p['id']), ['p1']);
    });

    test('tells on-screen lists, which no disk prune reaches', () async {
      var bumps = 0;
      void listener() => bumps++;
      AppCacheSignals.content.addListener(listener);
      addTearDown(() => AppCacheSignals.content.removeListener(listener));

      await BlockSync.apply({
        'events': ['gone'],
        'syncedAt': '2026-10-21T09:00:00Z',
      });

      expect(bumps, 1);
    });

    test('one bump for a whole batch, not one per id', () async {
      var bumps = 0;
      void listener() => bumps++;
      AppCacheSignals.content.addListener(listener);
      addTearDown(() => AppCacheSignals.content.removeListener(listener));

      await BlockSync.apply({
        'events': ['e1', 'e2', 'e3'],
        'pictures': ['p1', 'p2'],
        'syncedAt': '2026-10-21T09:00:00Z',
      });

      // A moderator blocking an album of two hundred photos must not cost the
      // phone two hundred rebuilds.
      expect(bumps, 1);
    });

    test('the same id arriving twice is free', () async {
      await BlockSync.apply({'events': ['e1'], 'syncedAt': '2026-10-21T09:00:00Z'});

      var bumps = 0;
      void listener() => bumps++;
      AppCacheSignals.content.addListener(listener);
      addTearDown(() => AppCacheSignals.content.removeListener(listener));

      // The sync re-sends an id until the watermark moves past it.
      await BlockSync.apply({'events': ['e1'], 'syncedAt': '2026-10-21T09:05:00Z'});

      expect(bumps, 0);
      expect(BlockSync.watermark, '2026-10-21T09:05:00Z',
          reason: 'the watermark still advances');
    });
  });

  group('a payload that is not what we expected', () {
    test('a missing block does nothing', () async {
      await BlockSync.apply(null);
      await BlockSync.apply('not a map');
      await BlockSync.apply(<String>[]);

      expect(BlockSync.watermark, isNull);
    });

    test('ids that are not strings are skipped rather than crashing', () async {
      await following().save([
        {'id': 'keep'},
      ], page: 1, hasMore: false);

      await BlockSync.apply({
        'events': [null, 42, '', 'keep'],
        'syncedAt': '2026-10-21T09:00:00Z',
      });

      // `42` stringifies to a harmless id that matches nothing; the empty one
      // and the null are dropped. What matters is that the real id landed.
      expect(following().restore().rows, isEmpty);
    });

    test('a fetch that throws leaves the watermark where it was', () async {
      await BlockSync.apply({'syncedAt': '2026-10-21T09:00:00Z'});

      await BlockSync.pull((_) async => throw Exception('offline'));

      // Losing this costs a delayed purge. Advancing the watermark past
      // blocks we never saw would cost them permanently.
      expect(BlockSync.watermark, '2026-10-21T09:00:00Z');
    });
  });
}

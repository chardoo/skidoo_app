import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_rest_data_source.dart';

/// The bug these lock down: the app asked GET /chat/rooms for page 1 of 25 and
/// treated the answer as the whole list. Anything past it was invisible — and
/// worse, RoomSyncReconciler counts a locally-known room missing from the
/// server's list as a miss and deletes it from SQLite after two in a row. So an
/// account with more than 25 private rooms had the tail of its chat list
/// quietly erased on every couple of refreshes, and a group invite that sorted
/// outside the page could never be accepted into view.
void main() {
  Map<String, dynamic> room(String id) => {
        'id': id,
        'type': 'group',
        'created_at': '2026-08-14T10:00:00Z',
        'participants': <dynamic>[],
      };

  Map<String, dynamic> page(List<String> ids, {required int totalPages}) => {
        'data': [for (final id in ids) room(id)],
        'pagination': {'totalPages': totalPages},
      };

  /// Serves [pages] in order and records the requests made.
  ({Future<dynamic> Function(int, int) fetch, List<int> requested}) server(
    List<dynamic> pages,
  ) {
    final requested = <int>[];
    return (
      requested: requested,
      fetch: (int p, int limit) async {
        requested.add(p);
        return p <= pages.length ? pages[p - 1] : page([], totalPages: 1);
      },
    );
  }

  test('a single short page is one request', () {
    final s = server([page(['a', 'b'], totalPages: 1)]);

    return collectRoomPages(s.fetch, pageSize: 100).then((rooms) {
      expect(rooms.map((r) => r.id), ['a', 'b']);
      expect(s.requested, [1],
          reason: 'most accounts fit in one page — do not pay for a second');
    });
  });

  test('a full page is followed until the list runs out', () async {
    final s = server([
      page(['a', 'b'], totalPages: 3),
      page(['c', 'd'], totalPages: 3),
      page(['e'], totalPages: 3),
    ]);

    final rooms = await collectRoomPages(s.fetch, pageSize: 2);

    expect(rooms.map((r) => r.id), ['a', 'b', 'c', 'd', 'e'],
        reason: 'the rooms past page 1 are the ones that used to disappear');
    expect(s.requested, [1, 2, 3]);
  });

  test('totalPages stops the loop even when the last page is full', () async {
    final s = server([
      page(['a', 'b'], totalPages: 2),
      page(['c', 'd'], totalPages: 2),
    ]);

    final rooms = await collectRoomPages(s.fetch, pageSize: 2);

    expect(rooms, hasLength(4));
    expect(s.requested, [1, 2], reason: 'no speculative request past the end');
  });

  test('a room returned on two pages is kept once', () async {
    // Ordering is by last activity, so a message arriving mid-paging can push
    // a room from page 2 to page 1 — and the other way round.
    final s = server([
      page(['a', 'b'], totalPages: 2),
      page(['b', 'c'], totalPages: 2),
    ]);

    final rooms = await collectRoomPages(s.fetch, pageSize: 2);

    expect(rooms.map((r) => r.id), ['a', 'b', 'c']);
  });

  test('the page cap holds', () async {
    // Every page full and totalPages lying about there always being more.
    final s = server([
      for (var i = 0; i < 10; i++) page(['r$i', 'x$i'], totalPages: 999),
    ]);

    final rooms = await collectRoomPages(s.fetch, pageSize: 2, maxPages: 3);

    expect(s.requested, [1, 2, 3], reason: 'a bad totalPages must not loop');
    expect(rooms, hasLength(6));
  });

  test('a bare list with no pagination block is read as the whole list', () {
    final s = server([
      [room('a'), room('b')],
    ]);

    return collectRoomPages(s.fetch, pageSize: 100).then((rooms) {
      expect(rooms.map((r) => r.id), ['a', 'b']);
      expect(s.requested, [1]);
    });
  });

  test('an unexpected body is empty rather than a crash', () async {
    final s = server(['not a list or a map']);

    expect(await collectRoomPages(s.fetch, pageSize: 100), isEmpty);
  });

  test('a malformed row is skipped, the rest of the page survives', () async {
    final s = server([
      {
        'data': [room('a'), 'garbage', room('b')],
        'pagination': {'totalPages': 1},
      },
    ]);

    final rooms = await collectRoomPages(s.fetch, pageSize: 100);

    expect(rooms.map((r) => r.id), ['a', 'b']);
  });

  test('no rooms at all is an empty list, not an error', () async {
    final s = server([page([], totalPages: 0)]);

    expect(await collectRoomPages(s.fetch, pageSize: 100), isEmpty);
  });
}

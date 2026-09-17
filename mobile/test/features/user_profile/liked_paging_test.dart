import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/user_profile/data/repositories/profile_overview_repository.dart';

/// The Liked grid has to show every like, not the first page of them.
///
/// Two faults, one on each side, and either alone was enough to cap the grid:
///
///  1. `type=all` clipped each section to ten whatever limit was asked for, and
///     said nothing about it — `counts` carried the real totals beside a list
///     that did not match them.
///  2. The grid was a single fetch. Even uncapped it would have shown one page
///     and no amount of scrolling could reach the rest.
///
/// These cover the client half: that a page is read correctly, and that
/// "is there more" comes from the server rather than from the length of what
/// arrived — the grid merges two independently-counted sections, so a short
/// list does not mean the end.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body);

  final Map<String, dynamic> body;
  final queries = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? _,
      Future<void>? __) async {
    queries.add(options.queryParameters);
    return ResponseBody.fromString(
      _encode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _encode(Object? v) {
  if (v is Map) {
    return '{${v.entries.map((e) => '"${e.key}":${_encode(e.value)}').join(',')}}';
  }
  if (v is List) return '[${v.map(_encode).join(',')}]';
  if (v is String) return '"$v"';
  if (v == null) return 'null';
  return '$v';
}

void main() {
  ProfileOverviewRepository repoWith(_FakeAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    return ProfileOverviewRepository.forTest(dio);
  }

  Map<String, dynamic> response({
    List<Map<String, dynamic>> events = const [],
    List<Map<String, dynamic>> pictures = const [],
    bool moreEvents = false,
    bool morePictures = false,
  }) =>
      {
        'type': 'all',
        'events': events,
        'pictures': pictures,
        'hasMore': {'events': moreEvents, 'pictures': morePictures},
      };

  Map<String, dynamic> event(String id, String likedAt) => {
        'id': id,
        'eventName': 'Event $id',
        'coverUrl': 'https://x/$id.jpg',
        'likedAt': likedAt,
      };

  test('it asks for the page it was given', () async {
    final adapter = _FakeAdapter(response());
    await repoWith(adapter).getLikedPhotos(page: 3);

    expect(adapter.queries.single['page'], 3);
    expect(adapter.queries.single['type'], 'all');
  });

  test('both sections land in one list', () async {
    final adapter = _FakeAdapter(response(
      events: [event('e1', '2026-09-17T10:00:00Z')],
      pictures: [
        {'id': 'p1', 'url': 'https://x/p1.jpg', 'likedAt': '2026-09-17T11:00:00Z'},
      ],
    ));

    final page = await repoWith(adapter).getLikedPhotos();

    // Newest first, across both — one grid means one order, and the only one
    // that makes sense is when it was liked.
    expect(page.photos.map((p) => p.id), ['p1', 'e1']);
  });

  group('whether there is more', () {
    test('comes from the server, not the length', () async {
      // The trap: one short section does not mean the page is the last.
      final adapter = _FakeAdapter(response(
        events: [event('e1', '2026-09-17T10:00:00Z')],
        moreEvents: true,
      ));

      expect((await repoWith(adapter).getLikedPhotos()).hasMore, isTrue);
    });

    test('either section having more is enough', () async {
      final adapter = _FakeAdapter(response(morePictures: true));

      expect((await repoWith(adapter).getLikedPhotos()).hasMore, isTrue);
    });

    test('neither having more ends it', () async {
      final adapter = _FakeAdapter(response(
        events: [event('e1', '2026-09-17T10:00:00Z')],
      ));

      expect((await repoWith(adapter).getLikedPhotos()).hasMore, isFalse);
    });

    test('an older server that says nothing is treated as the end', () async {
      // No hasMore key at all. Better to stop than to page forever against a
      // service that cannot tell us when to.
      final adapter = _FakeAdapter({'type': 'all', 'events': [], 'pictures': []});

      expect((await repoWith(adapter).getLikedPhotos()).hasMore, isFalse);
    });
  });
}

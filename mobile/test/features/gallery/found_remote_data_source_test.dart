import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/features/gallery/data/datasources/found_remote_data_source.dart';

/// The `groupBy=none` photo object documented in FRONTEND_MY_PHOTOS.md.
Map<String, dynamic> photoJson({String id = 'pic-1'}) => {
      'id': id,
      'url': 'https://cdn/$id.jpg',
      'imageId': 'img-$id',
      'price': 25.0,
      'public': false,
      'facesCount': 3,
      'mediaType': 'image',
      'likeCount': 0,
      'commentCount': 0,
      'comments_enabled': true,
      'width': 4000,
      'height': 6000,
      'durationSeconds': null,
      'isPurchased': false,
      'identifiedAt': '2026-07-28T19:04:11+00:00',
      'photoDate': '2026-07-12',
      'event': {
        'id': 'evt-1',
        'eventName': 'Praise Reloaded 2026',
        'eventDate': '2026-07-10',
        'photographer': {
          'id': 'ph-1',
          'name': 'Kofi Mensah',
          'profile_url': 'https://cdn/kofi.jpg',
        },
      },
    };

Map<String, dynamic> pagination({
  int page = 1,
  int total = 4,
  int totalPages = 1,
  bool hasNext = false,
}) =>
    {
      'page': page,
      'limit': 25,
      'total': total,
      'totalPages': totalPages,
      'hasNext': hasNext,
      'hasPrev': page > 1,
    };

void main() {
  group('groupBy=event envelope', () {
    // The response documented in FRONTEND_MY_PHOTOS.md.
    final body = {
      'data': [
        {
          'event': {
            'id': 'evt-1',
            'eventName': 'Praise Reloaded 2026',
            'eventDate': '2026-07-12',
            'photographer': {'id': 'ph-1', 'name': 'Kofi Mensah'},
          },
          'photoCount': 21,
          'photos': [photoJson(id: 'a'), photoJson(id: 'b')],
          'moreCount': 15,
          'lastIdentifiedAt': '2026-07-28T19:04:11+00:00',
        }
      ],
      'pagination': pagination(),
      'totals': {'photos': 48, 'events': 4},
    };

    test('headline totals come from `totals`, not from `pagination.total`',
        () {
      final page = FoundRemoteDataSourceImpl.parseAlbumsPage(body);
      // pagination.total counts EVENTS under groupBy=event — using it for the
      // "N found" headline would show 4 instead of 48.
      expect(page.totalPhotos, 48);
      expect(page.totalEvents, 4);
      expect(page.pagination.total, 4);
    });

    test('albums parse with the server counts intact', () {
      final album = FoundRemoteDataSourceImpl.parseAlbumsPage(body).albums.single;
      expect(album.title, 'Praise Reloaded 2026');
      expect(album.photoCount, 21);
      expect(album.moreCount, 15);
      expect(album.photos, hasLength(2));
    });

    test('hasNext drives paging', () {
      expect(
        FoundRemoteDataSourceImpl.parseAlbumsPage(body).pagination.hasNext,
        isFalse,
      );
      final more = {
        ...body,
        'pagination': pagination(page: 1, totalPages: 3, hasNext: true),
      };
      expect(
        FoundRemoteDataSourceImpl.parseAlbumsPage(more).pagination.hasNext,
        isTrue,
      );
    });

    test('a missing hasNext is derived from page/totalPages', () {
      final body2 = {
        'data': const [],
        'pagination': {'page': 1, 'limit': 25, 'total': 9, 'totalPages': 3},
      };
      expect(
        FoundRemoteDataSourceImpl.parseAlbumsPage(body2).pagination.hasNext,
        isTrue,
      );
    });

    test('groups with no usable photos are dropped', () {
      final body2 = {
        'data': [
          {'event': {'id': 'e'}, 'photos': const [], 'photoCount': 0},
        ],
        'pagination': pagination(),
        'totals': {'photos': 0, 'events': 0},
      };
      expect(FoundRemoteDataSourceImpl.parseAlbumsPage(body2).albums, isEmpty);
    });

    test('an unexpected body yields an empty page instead of throwing', () {
      for (final raw in <dynamic>['nope', null, {'detail': 'Unauthorized'}]) {
        final page = FoundRemoteDataSourceImpl.parseAlbumsPage(raw);
        expect(page.albums, isEmpty);
        expect(page.totalPhotos, isNull);
        expect(page.pagination.hasNext, isFalse);
      }
    });

    test('a missing `totals` leaves the headline unknown, not summed', () {
      // Summing this page's albums was the old fallback. With 4 events spread
      // over 2 pages it would headline "21" on page 1 and then *drop* as later
      // pages replaced it — a number that is wrong and that moves.
      final page = FoundRemoteDataSourceImpl.parseAlbumsPage({
        'data': body['data'],
        'pagination': pagination(total: 4, totalPages: 2, hasNext: true),
      });
      expect(page.totalPhotos, isNull);
      // Events stay exact: they're the paged unit, so pagination.total is the
      // same number `totals.events` would have carried.
      expect(page.totalEvents, 4);
    });
  });

  group('groupBy=none envelope', () {
    final body = {
      'data': [photoJson()],
      'pagination': pagination(total: 21, totalPages: 1),
    };

    test('the photo object parses in full', () {
      final photo = FoundRemoteDataSourceImpl.parsePhotosPage(body).photos.single;

      expect(photo.id, 'pic-1');
      expect(photo.imageId, 'img-pic-1');
      expect(photo.url, 'https://cdn/pic-1.jpg');
      expect(photo.price, 25.0);
      expect(photo.isPublic, isFalse);
      expect(photo.isPurchased, isFalse);
      expect(photo.width, 4000);
      expect(photo.height, 6000);
      expect(photo.identifiedAt, DateTime.parse('2026-07-28T19:04:11+00:00'));
      expect(photo.eventId, 'evt-1');
      expect(photo.eventName, 'Praise Reloaded 2026');
      expect(photo.photographerName, 'Kofi Mensah');
      expect(photo.photographerAvatarUrl, 'https://cdn/kofi.jpg');
      expect(photo.userId, 'ph-1');
    });

    test('photoDate wins over the event date — it is what dateRange filters on',
        () {
      final photo = FoundRemoteDataSourceImpl.parsePhotosPage(body).photos.single;
      expect(photo.eventDate, '2026-07-12');
      expect(photo.eventDateTime, DateTime.parse('2026-07-12'));
    });

    test('foundDate falls back to identifiedAt when there is no photoDate', () {
      final json = photoJson()..remove('photoDate');
      (json['event'] as Map).remove('eventDate');
      final photo =
          FoundRemoteDataSourceImpl.parsePhotosPage({'data': [json]}).photos.single;

      expect(photo.eventDateTime, isNull);
      expect(photo.foundDate, DateTime.parse('2026-07-28T19:04:11+00:00'));
    });

    test('pagination.total counts photos here', () {
      expect(
        FoundRemoteDataSourceImpl.parsePhotosPage(body).pagination.total,
        21,
      );
    });

    test('items with no url are dropped rather than rendered as blanks', () {
      final page = FoundRemoteDataSourceImpl.parsePhotosPage({
        'data': [photoJson(), {'id': 'broken'}],
      });
      expect(page.photos.map((p) => p.id), ['pic-1']);
    });

    test('a bare array still parses', () {
      expect(
        FoundRemoteDataSourceImpl.parsePhotosPage([photoJson()]).photos,
        hasLength(1),
      );
    });
  });
}

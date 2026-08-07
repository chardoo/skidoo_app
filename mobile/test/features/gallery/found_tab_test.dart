import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_album.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_filter_options.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_filters.dart';

/// The group object documented in FRONTEND_MY_PHOTOS.md, verbatim.
Map<String, dynamic> groupJson({int photoCount = 21, int previewPhotos = 6}) => {
      'event': {
        'id': 'evt-1',
        'eventName': 'Praise Reloaded 2026',
        'description': '',
        'content_tags': [],
        'eventDate': '2026-07-12',
        'photographer': {
          'id': 'ph-1',
          'name': 'Kofi Mensah',
          'profile_url': 'https://cdn/kofi.jpg',
        },
      },
      'photoCount': photoCount,
      'photos': [
        for (var i = 0; i < previewPhotos; i++)
          {'id': 'p$i', 'url': 'https://cdn/p$i.jpg', 'public': true},
      ],
      'moreCount': photoCount - previewPhotos,
      'lastIdentifiedAt': '2026-07-28T19:04:11+00:00',
    };

void main() {
  group('FoundFilters → query parameters', () {
    test('defaults send nothing at all', () {
      expect(FoundFilters.none.toQueryParameters(), isEmpty);
      expect(FoundFilters.none.isActive, isFalse);
    });

    test('date buckets use the API values', () {
      expect(
        const FoundFilters(dateRange: FoundDateRange.thisMonth)
            .toQueryParameters(),
        {'dateRange': 'this_month'},
      );
      expect(
        const FoundFilters(dateRange: FoundDateRange.lastThreeMonths)
            .toQueryParameters(),
        {'dateRange': 'last_3_months'},
      );
    });

    test('a custom range sends zero-padded YYYY-MM-DD bounds', () {
      final q = FoundFilters(
        dateRange: FoundDateRange.custom,
        customRange: DateTimeRange(
          start: DateTime(2026, 3, 7),
          end: DateTime(2026, 11, 30),
        ),
      ).toQueryParameters();

      expect(q['dateRange'], 'custom');
      expect(q['startDate'], '2026-03-07');
      expect(q['endDate'], '2026-11-30');
    });

    test('custom with no range picked yet omits the bounds', () {
      const q = FoundFilters(dateRange: FoundDateRange.custom);
      expect(q.toQueryParameters(), {'dateRange': 'custom'});
    });

    test('visibility is omitted when "all"', () {
      expect(
        const FoundFilters(visibility: FoundVisibility.private)
            .toQueryParameters(),
        {'visibility': 'private'},
      );
      expect(
        const FoundFilters(visibility: FoundVisibility.all).toQueryParameters(),
        isEmpty,
      );
    });

    test('photographer and event ids go out as repeatable lists', () {
      final q = const FoundFilters(
        photographerIds: {'a', 'b'},
        eventIds: {'e1'},
      ).toQueryParameters();

      expect(q['photographerId'], isA<List<String>>());
      expect((q['photographerId'] as List).toSet(), {'a', 'b'});
      expect(q['eventId'], ['e1']);
    });
  });

  group('FoundFilters badge count', () {
    test('each sheet group contributes exactly one', () {
      const filters = FoundFilters(
        dateRange: FoundDateRange.thisMonth,
        visibility: FoundVisibility.private,
        photographerIds: {'a', 'b'},
      );
      expect(filters.activeCount, 3);
    });

    test('an event constraint is navigation, not a user filter', () {
      const filters = FoundFilters(eventIds: {'evt-1'});
      expect(filters.activeCount, 0);
      expect(filters.isActive, isFalse);
    });
  });

  group('FoundFilters toggles', () {
    test('tapping the active date chip clears it', () {
      const filters = FoundFilters(dateRange: FoundDateRange.thisMonth);
      expect(filters.toggleDate(FoundDateRange.thisMonth).dateRange,
          FoundDateRange.all);
      expect(filters.toggleDate(FoundDateRange.lastThreeMonths).dateRange,
          FoundDateRange.lastThreeMonths);
    });

    test('togglePhotographer adds then removes by id', () {
      final added = FoundFilters.none.togglePhotographer('ph-1');
      expect(added.photographerIds, {'ph-1'});
      expect(added.togglePhotographer('ph-1').photographerIds, isEmpty);
    });

    test('equality ignores set ordering', () {
      const a = FoundFilters(photographerIds: {'a', 'b'});
      const b = FoundFilters(photographerIds: {'b', 'a'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('FoundAlbum.fromJson', () {
    test('takes the counts from the server, not from the preview length', () {
      final album = FoundAlbum.fromJson(groupJson());

      expect(album.id, 'evt-1');
      expect(album.title, 'Praise Reloaded 2026');
      expect(album.photos, hasLength(6));
      expect(album.photoCount, 21);
      expect(album.moreCount, 15);
      expect(album.hasMore, isTrue);
      expect(album.photographerId, 'ph-1');
      expect(album.photographerName, 'Kofi Mensah');
      expect(album.photographerAvatarUrl, 'https://cdn/kofi.jpg');
      expect(album.eventDate, '2026-07-12');
    });

    test('the +N tile sits on the last preview photo', () {
      final album = FoundAlbum.fromJson(groupJson());
      expect(album.overflowCover?.id, 'p5');
    });

    test('an event that fits in the preview has no +N', () {
      final album =
          FoundAlbum.fromJson(groupJson(photoCount: 4, previewPhotos: 4));
      expect(album.moreCount, 0);
      expect(album.hasMore, isFalse);
    });

    test('a missing moreCount falls back to photoCount - preview', () {
      final json = groupJson()..remove('moreCount');
      expect(FoundAlbum.fromJson(json).moreCount, 15);
    });

    test('a partial group degrades instead of throwing', () {
      final album = FoundAlbum.fromJson(const {'photos': []});
      expect(album.id, isEmpty);
      expect(album.photoCount, 0);
      expect(album.moreCount, 0);
      expect(album.overflowCover, isNull);
    });
  });

  group('FoundFilterOptions.fromJson', () {
    // The response documented in FRONTEND_MY_PHOTOS.md.
    final json = {
      'matchingCount': 12,
      'totalCount': 48,
      'dateRanges': [
        {'value': 'all', 'count': 48},
        {'value': 'this_month', 'count': 12},
        {'value': 'last_3_months', 'count': 31},
      ],
      'visibility': [
        {'value': 'all', 'count': 48},
        {'value': 'public', 'count': 30},
        {'value': 'private', 'count': 18},
      ],
      'photographers': [
        {
          'id': 'ph-1',
          'name': 'Daniella Daniels',
          'profile_url': 'https://cdn/d.jpg',
          'count': 19,
        }
      ],
      'events': [
        {'id': 'evt-1', 'eventName': 'Praise Reloaded 2026', 'count': 21}
      ],
    };

    test('counts drive the CTA and the headline', () {
      final options = FoundFilterOptions.fromJson(json);
      expect(options.matchingCount, 12);
      expect(options.totalCount, 48);
    });

    test('date/visibility chips get their labels from the enum', () {
      final options = FoundFilterOptions.fromJson(json);
      expect(options.dateRanges.map((o) => o.label),
          ['Any time', 'This month', 'Last 3 months']);
      expect(options.visibility.map((o) => o.label),
          ['All', 'Public', 'Private']);
    });

    test('photographer chips carry id, name, avatar and count', () {
      final photographer =
          FoundFilterOptions.fromJson(json).photographers.single;
      expect(photographer.id, 'ph-1');
      expect(photographer.label, 'Daniella Daniels');
      expect(photographer.avatarUrl, 'https://cdn/d.jpg');
      expect(photographer.count, 19);
    });

    test('events are exposed for the drill-down', () {
      final event = FoundFilterOptions.fromJson(json).events.single;
      expect(event.id, 'evt-1');
      expect(event.label, 'Praise Reloaded 2026');
    });

    test('an empty body yields empty lists, not nulls', () {
      final options = FoundFilterOptions.fromJson(const {});
      expect(options.matchingCount, 0);
      expect(options.photographers, isEmpty);
      expect(options.dateRanges, isEmpty);
    });

    test('entries missing an id or label are dropped', () {
      final options = FoundFilterOptions.fromJson(const {
        'photographers': [
          {'id': '', 'name': 'Nameless', 'count': 1},
          {'id': 'ph-2', 'name': '', 'count': 1},
          {'id': 'ph-3', 'name': 'Kept', 'count': 1},
        ],
      });
      expect(options.photographers.map((o) => o.label), ['Kept']);
    });
  });
}

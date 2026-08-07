import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/search/domain/entities/search_models.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/models/photographer/photographer_event.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// The API sends an event cover's pixel dimensions alongside its url
/// (`coverWidth` / `coverHeight`), and a clip's length as `durationSeconds`.
/// Anything the models drop here is a shape or a duration the UI has to guess.
void main() {
  group('SearchEventRow cover', () {
    test('reads camelCase cover dimensions', () {
      final row = SearchEventRow.fromJson(const {
        'id': 'evt-1',
        'eventName': 'Graduation',
        'coverUrl': 'https://cdn/cover.jpg',
        'coverWidth': 1600,
        'coverHeight': 900,
      });

      expect(row.coverWidth, 1600);
      expect(row.coverHeight, 900);
      expect(row.coverAspectRatio, closeTo(16 / 9, 0.001));
    });

    test('accepts snake_case and bare width/height', () {
      expect(
        SearchEventRow.fromJson(const {
          'id': 'a',
          'cover_width': 800,
          'cover_height': 600,
        }).coverAspectRatio,
        closeTo(4 / 3, 0.001),
      );
      expect(
        SearchEventRow.fromJson(const {'id': 'b', 'width': 100, 'height': 200})
            .coverAspectRatio,
        closeTo(0.5, 0.001),
      );
    });

    test('a legacy cover has no ratio rather than a wrong one', () {
      final row = SearchEventRow.fromJson(const {
        'id': 'evt-2',
        'coverUrl': 'https://cdn/old.jpg',
      });

      expect(row.coverWidth, isNull);
      expect(row.coverAspectRatio, isNull);
    });

    test('a zero height cannot divide by zero', () {
      final row = SearchEventRow.fromJson(
          const {'id': 'evt-3', 'coverWidth': 100, 'coverHeight': 0});

      expect(row.coverAspectRatio, isNull);
    });

    test('dimensions are part of equality', () {
      Map<String, dynamic> json(int h) =>
          {'id': 'evt-4', 'coverWidth': 100, 'coverHeight': h};

      expect(SearchEventRow.fromJson(json(100)),
          isNot(SearchEventRow.fromJson(json(200))));
    });
  });

  group('PhotographerEvent cover', () {
    test('reads the cover dimensions the event list sends', () {
      final event = PhotographerEvent.fromJson(const {
        'id': 'evt-1',
        'eventName': 'Wedding',
        'url': 'https://cdn/cover.jpg',
        'coverWidth': 2000,
        'coverHeight': 1000,
      });

      expect(event.coverAspectRatio, closeTo(2.0, 0.001));
    });

    test('string-encoded numbers still parse', () {
      final event = PhotographerEvent.fromJson(const {
        'id': 'evt-2',
        'width': '1200',
        'height': '800',
      });

      expect(event.coverAspectRatio, closeTo(1.5, 0.001));
    });

    test('no dimensions means no ratio', () {
      expect(
        PhotographerEvent.fromJson(const {'id': 'evt-3'}).coverAspectRatio,
        isNull,
      );
    });
  });

  group('durationSeconds', () {
    test('EventPicture accepts both spellings', () {
      expect(
        EventPicture.fromMap(const {'id': 'p1', 'durationSeconds': 12.5})
            .durationSeconds,
        12.5,
      );
      expect(
        EventPicture.fromMap(const {'id': 'p2', 'duration_seconds': 8})
            .durationSeconds,
        8.0,
      );
    });

    test('Photo.fromMap2 accepts both spellings', () {
      Map<String, dynamic> json(Map<String, dynamic> extra) => {
            'id': 'p1',
            'imageId': 'img-1',
            'url': 'https://cdn/clip.mp4',
            'event': const {'id': 'e1', 'eventName': 'Party', 'userId': 'u1'},
            ...extra,
          };

      expect(Photo.fromMap2(json({'durationSeconds': 30})).durationSeconds, 30);
      expect(
          Photo.fromMap2(json({'duration_seconds': 45})).durationSeconds, 45);
    });
  });
}

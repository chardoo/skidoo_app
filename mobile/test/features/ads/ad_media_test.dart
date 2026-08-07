import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/ads/models/ad_media.dart';

void main() {
  group('AdMedia getters', () {
    test('isVideo reflects mediaType', () {
      expect(const AdMedia(id: '1', url: 'u', mediaType: 'video').isVideo, isTrue);
      expect(const AdMedia(id: '1', url: 'u', mediaType: 'image').isVideo, isFalse);
    });

    test('aspectRatio computes width/height when both present', () {
      const m = AdMedia(id: '1', url: 'u', mediaType: 'image', width: 1280, height: 720);
      expect(m.aspectRatio, closeTo(1280 / 720, 1e-9));
    });

    test('aspectRatio is null when dimensions missing or height is zero', () {
      expect(const AdMedia(id: '1', url: 'u', mediaType: 'image').aspectRatio, isNull);
      expect(
        const AdMedia(id: '1', url: 'u', mediaType: 'image', width: 100, height: 0).aspectRatio,
        isNull,
      );
    });
  });

  group('AdMedia.fromJson', () {
    test('parses canonical fields', () {
      final m = AdMedia.fromJson({
        'id': 'a1',
        'url': 'https://x/img.jpg',
        'media_type': 'image',
        'sort_order': 2,
        'width': 800,
        'height': 600,
        'duration_seconds': null,
      });
      expect(m.id, 'a1');
      expect(m.url, 'https://x/img.jpg');
      expect(m.mediaType, 'image');
      expect(m.position, 2);
      expect(m.width, 800);
      expect(m.height, 600);
    });

    test('falls back across url and type key aliases', () {
      final m = AdMedia.fromJson({
        'media_url': 'https://x/clip.mp4',
        'type': 'video',
        'position': 5,
        'duration_seconds': 12.5,
      });
      expect(m.url, 'https://x/clip.mp4');
      expect(m.mediaType, 'video');
      expect(m.position, 5);
      expect(m.durationSeconds, 12.5);
      expect(m.isVideo, isTrue);
    });

    test('uses safe defaults when fields are absent', () {
      final m = AdMedia.fromJson({});
      expect(m.id, '');
      expect(m.url, '');
      expect(m.mediaType, 'image');
      expect(m.position, 0);
      expect(m.width, isNull);
    });
  });
}

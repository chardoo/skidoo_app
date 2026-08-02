import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/utils/cloudinary_transform.dart';

/// The bug these lock down: a video in a thumbnail grid was handed to the
/// image loader as an `.mp4`, which can only fail — every clip rendered as a
/// broken-image icon behind its play badge. Thumbnails now show the video's
/// own poster frame, which Cloudinary renders from the same asset.
void main() {
  const videoUrl =
      'https://res.cloudinary.com/skidoo/video/upload/v1712345678/events/clip.mp4';
  const imageUrl =
      'https://res.cloudinary.com/skidoo/image/upload/v1712345678/events/shot.jpg';

  group('isVideoUrl', () {
    test('Cloudinary video delivery urls', () {
      expect(CloudinaryTransform.isVideoUrl(videoUrl), isTrue);
    });

    test('bare video files on any host', () {
      expect(CloudinaryTransform.isVideoUrl('https://cdn.example.com/a.mov'),
          isTrue);
      expect(
          CloudinaryTransform.isVideoUrl('https://cdn.example.com/a.mp4?sig=1'),
          isTrue);
    });

    test('images are not videos', () {
      expect(CloudinaryTransform.isVideoUrl(imageUrl), isFalse);
      expect(CloudinaryTransform.isVideoUrl('https://cdn.example.com/a.png'),
          isFalse);
    });
  });

  group('videoPoster', () {
    test('asks for a still frame of the video asset', () {
      final poster = CloudinaryTransform.videoPoster(videoUrl,
          displayWidth: 150, devicePixelRatio: 3.0)!;

      // Still extension, video resource type kept, frame at t=0.
      expect(poster, endsWith('/events/clip.jpg'));
      expect(poster, contains('/video/upload/'));
      expect(poster, contains('so_0'));
      expect(poster, isNot(contains('.mp4')));
      // `f_auto` on a video resource hands back a video container again.
      expect(poster, isNot(contains('f_auto')));
    });

    test('sizes to the slot, in stepped widths', () {
      final poster = CloudinaryTransform.videoPoster(videoUrl,
          displayWidth: 150, devicePixelRatio: 3.0)!;
      expect(poster, contains('w_480')); // 150 × 3 = 450 → next 160-step
      expect(poster, contains('dpr_3.0'));
    });

    test('keeps a query string', () {
      final poster = CloudinaryTransform.videoPoster('$videoUrl?token=abc',
          displayWidth: 100, devicePixelRatio: 1.0)!;
      expect(poster, endsWith('clip.jpg?token=abc'));
    });

    test('null for videos we cannot render a frame from', () {
      expect(
        CloudinaryTransform.videoPoster('https://cdn.example.com/clip.mp4',
            displayWidth: 100, devicePixelRatio: 1.0),
        isNull,
      );
    });

    test('null for images — callers should use image()', () {
      expect(
        CloudinaryTransform.videoPoster(imageUrl,
            displayWidth: 100, devicePixelRatio: 1.0),
        isNull,
      );
    });

    test('does not double-inject an already-derived poster', () {
      final once = CloudinaryTransform.videoPoster(videoUrl,
          displayWidth: 100, devicePixelRatio: 1.0)!;
      final twice = CloudinaryTransform.videoPoster(once,
          displayWidth: 100, devicePixelRatio: 1.0)!;
      expect(twice, once);
    });
  });
}

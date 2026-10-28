import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/utils/media_transform.dart';

/// Two separate things are locked down here.
///
/// **Posters.** A video in a thumbnail grid was handed to the image loader as
/// an `.mp4`, which can only fail — every clip rendered as a broken-image icon
/// behind its play badge. Thumbnails show the video's own poster frame instead.
///
/// **Rungs.** R2 serves back exactly the bytes it was given, so a photo is
/// pre-rendered at a ladder of widths at upload and the app asks for the
/// narrowest one that covers the slot. Picking the wrong rung is not a slow
/// image, it is a 404 and an empty slot, so the two reasons to decline a rung
/// are tested as carefully as the happy path.
void main() {
  const videoUrl =
      'https://res.cloudinary.com/jperg/video/upload/v1712345678/events/clip.mp4';
  const imageUrl =
      'https://res.cloudinary.com/jperg/image/upload/v1712345678/events/shot.jpg';
  const r2Url = 'https://cdn.example.com/newImages/9f3ca1b2.jpg';

  group('isVideoUrl', () {
    test('Cloudinary video delivery urls', () {
      expect(MediaTransform.isVideoUrl(videoUrl), isTrue);
    });

    test('bare video files on any host', () {
      expect(
          MediaTransform.isVideoUrl('https://cdn.example.com/a.mov'), isTrue);
      expect(MediaTransform.isVideoUrl('https://cdn.example.com/a.mp4?sig=1'),
          isTrue);
    });

    test('images are not videos', () {
      expect(MediaTransform.isVideoUrl(imageUrl), isFalse);
      expect(
          MediaTransform.isVideoUrl('https://cdn.example.com/a.png'), isFalse);
    });
  });

  group('videoPoster', () {
    test('asks for a still frame of the video asset', () {
      final poster = MediaTransform.videoPoster(videoUrl,
          displayWidth: 150, devicePixelRatio: 3.0)!;

      // Still extension, video resource type kept, frame at t=0.
      expect(poster, endsWith('/events/clip.jpg'));
      expect(poster, contains('/video/upload/'));
      expect(poster, contains('so_0'));
      expect(poster, isNot(contains('.mp4')));
      // `f_auto` on a video resource hands back a video container again.
      expect(poster, isNot(contains('f_auto')));
    });

    test('sizes to the slot, in stepped widths, with no dpr multiplier', () {
      final poster = MediaTransform.videoPoster(videoUrl,
          displayWidth: 150, devicePixelRatio: 3.0)!;
      expect(poster, contains('w_480')); // 150 × 3 = 450 → next 160-step
      // `dpr_` multiplies `w_` at Cloudinary's edge, so emitting both asked
      // for three times the pixels. The width already carries the DPR.
      expect(poster, isNot(contains('dpr_')));
    });

    test('keeps a query string', () {
      final poster = MediaTransform.videoPoster('$videoUrl?token=abc',
          displayWidth: 100, devicePixelRatio: 1.0)!;
      expect(poster, endsWith('clip.jpg?token=abc'));
    });

    test('null for videos we cannot render a frame from', () {
      // No ladder: an R2 clip from before posters were generated, or a video
      // on somebody else's host. Nothing stored, nothing derivable.
      expect(
        MediaTransform.videoPoster('https://cdn.example.com/clip.mp4',
            displayWidth: 100, devicePixelRatio: 1.0),
        isNull,
      );
    });

    test('an R2 clip takes a rung of its stored poster', () {
      // ffmpeg pulled frame zero out at upload and stored *its* rungs under a
      // parallel key, so this resolves exactly like a photo's rung would.
      final poster = MediaTransform.videoPoster(
        'https://cdn.example.com/newImages/clip.mp4',
        displayWidth: 393,
        devicePixelRatio: 3.0,
        ladder: const ImageLadder(version: 1, sourceWidth: 1920),
      );

      expect(poster, 'https://cdn.example.com/newImages/clip_poster_1600.webp');
      expect(poster, isNot(contains('.mp4')));
    });

    test('a poster rung above the frame width was never rendered', () {
      // The frame is only as wide as the clip, so a 1280-wide video has no
      // 1600 poster rung — asking for one would 404 behind the play badge.
      final poster = MediaTransform.videoPoster(
        'https://cdn.example.com/newImages/clip.mp4',
        displayWidth: 393,
        devicePixelRatio: 3.0,
        ladder: const ImageLadder(version: 1, sourceWidth: 1280),
      );
      expect(poster, isNull);
    });

    test('null for images — callers should use image()', () {
      expect(
        MediaTransform.videoPoster(imageUrl,
            displayWidth: 100, devicePixelRatio: 1.0),
        isNull,
      );
    });

    test('does not double-inject an already-derived poster', () {
      final once = MediaTransform.videoPoster(videoUrl,
          displayWidth: 100, devicePixelRatio: 1.0)!;
      final twice = MediaTransform.videoPoster(once,
          displayWidth: 100, devicePixelRatio: 1.0)!;
      expect(twice, once);
    });
  });

  group('image() on Cloudinary', () {
    test('asks the edge for physical pixels, once', () {
      final url = MediaTransform.image(imageUrl,
          displayWidth: 393, devicePixelRatio: 3.0);

      // 393 × 3 = 1179 → next 160-step. Crucially *not* w_1280,dpr_3.0, which
      // Cloudinary would have delivered at 3840px — ten times the pixel area
      // of the 1179 the card actually draws.
      expect(url, contains('w_1280'));
      expect(url, isNot(contains('dpr_')));
      expect(url, contains('f_auto'));
      expect(url, contains('c_limit'));
    });

    test('q_auto:good, not :best', () {
      final url = MediaTransform.image(imageUrl,
          displayWidth: 393, devicePixelRatio: 3.0);
      expect(url, contains('q_auto:good'));
      expect(url, isNot(contains('q_auto:best')));
    });

    test('sharpen is opt-out, for blur backdrops', () {
      expect(
        MediaTransform.image(imageUrl,
            displayWidth: 80, devicePixelRatio: 1.0, sharpen: false),
        isNot(contains('e_sharpen')),
      );
    });

    test('ignores a ladder — the edge sizes these, not a rung', () {
      final url = MediaTransform.image(
        imageUrl,
        displayWidth: 393,
        devicePixelRatio: 3.0,
        ladder: const ImageLadder(version: 1, sourceWidth: 5000),
      );
      expect(url, isNot(contains('.webp')));
      expect(url, contains('w_1280'));
    });
  });

  group('image() on R2 picks a rung', () {
    test('the narrowest rung that covers the slot', () {
      // A feed card on a 3x phone wants 1179 physical pixels.
      final url = MediaTransform.image(
        r2Url,
        displayWidth: 393,
        devicePixelRatio: 3.0,
        ladder: const ImageLadder(version: 1, sourceWidth: 5000),
      );
      expect(url, 'https://cdn.example.com/newImages/9f3ca1b2_1600.webp');
    });

    test('a grid thumbnail takes a small rung', () {
      final url = MediaTransform.image(
        r2Url,
        displayWidth: 100,
        devicePixelRatio: 3.0,
        ladder: const ImageLadder(version: 1, sourceWidth: 5000),
      );
      expect(url, endsWith('_320.webp'));
    });

    test('keeps a query string', () {
      final url = MediaTransform.image(
        '$r2Url?token=abc',
        displayWidth: 100,
        devicePixelRatio: 1.0,
        ladder: const ImageLadder(version: 1, sourceWidth: 5000),
      );
      expect(url, endsWith('_320.webp?token=abc'));
    });

    test('no rung is wide enough — the original is the right answer', () {
      // A viewer zoomed to 4x wants more pixels than the top rung holds.
      final url = MediaTransform.image(
        r2Url,
        displayWidth: 393 * 4,
        devicePixelRatio: 3.0,
        ladder: const ImageLadder(version: 1, sourceWidth: 6000),
      );
      expect(url, r2Url);
    });

    test('never asks for a rung at or above the source width', () {
      // A 1500px source has rungs up to 1080 and nothing above — anything
      // wider would have been an upscale and was never rendered. Asking for
      // _1600.webp here would 404.
      final url = MediaTransform.image(
        r2Url,
        displayWidth: 393,
        devicePixelRatio: 3.0,
        ladder: const ImageLadder(version: 1, sourceWidth: 1500),
      );
      expect(url, r2Url);
    });

    test('a source smaller than every rung has no ladder at all', () {
      final url = MediaTransform.image(
        r2Url,
        displayWidth: 100,
        devicePixelRatio: 1.0,
        ladder: const ImageLadder(version: 1, sourceWidth: 200),
      );
      expect(url, r2Url);
    });

    test('no version means no ladder was rendered', () {
      final url = MediaTransform.image(
        r2Url,
        displayWidth: 393,
        devicePixelRatio: 3.0,
        ladder: const ImageLadder(sourceWidth: 5000),
      );
      expect(url, r2Url);
    });

    test('no source width means the rungs cannot be reasoned about', () {
      final url = MediaTransform.image(
        r2Url,
        displayWidth: 393,
        devicePixelRatio: 3.0,
        ladder: const ImageLadder(version: 1),
      );
      expect(url, r2Url);
    });

    test('an unknown host with no ladder is returned untouched', () {
      const foreign = 'https://photos.example.org/a/b/c.jpg';
      expect(
        MediaTransform.image(foreign,
            displayWidth: 393, devicePixelRatio: 3.0),
        foreign,
      );
    });

    test('rung keys match the server, which derives them arithmetically', () {
      // Mirrors derivatives.rung_key: stem + _<width> + .webp.
      for (final width in MediaTransform.rungs) {
        final url = MediaTransform.image(
          r2Url,
          displayWidth: width.toDouble(),
          devicePixelRatio: 1.0,
          ladder: const ImageLadder(version: 1, sourceWidth: 6000),
        );
        expect(url, endsWith('_$width.webp'));
      }
    });
  });

  group('ImageLadder', () {
    test('reads the pair out of a picture payload', () {
      final ladder = ImageLadder.fromJson(
        const {'derivativesVersion': 1, 'width': 4000, 'height': 3000},
      );
      expect(ladder.version, 1);
      expect(ladder.sourceWidth, 4000);
      expect(ladder.exists, isTrue);
    });

    test('reads the event cover, which spells both keys differently', () {
      final ladder = ImageLadder.fromJson(
        const {'coverDerivativesVersion': 1, 'coverWidth': 2400},
        versionKey: 'coverDerivativesVersion',
        widthKey: 'coverWidth',
      );
      expect(ladder.version, 1);
      expect(ladder.sourceWidth, 2400);
    });

    test('a payload with neither field is simply no ladder', () {
      final ladder = ImageLadder.fromJson(const {'url': 'x'});
      expect(ladder.exists, isFalse);
      expect(ladder, ImageLadder.none);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/widgets/short_photo_lift.dart';

/// A wide photo on a tall phone, and how much of the screen it is allowed to
/// take back.
///
/// The numbers below are a real stage: a 390-point-wide phone with the app bar
/// and the thumbnail strip taken off, which is where the complaint came from —
/// a 3:2 photo drawn 260 points tall in the middle of 557.
void main() {
  const w = 390.0;
  const h = 557.0;

  double liftedHeight(double aspect) =>
      w / liftedAspect(photoAspect: aspect, availableWidth: w, availableHeight: h);

  group('what gets lifted', () {
    test('a 3:2 photo, which is the case this came from', () {
      // 260 points before. Taller after, and by a strip of width rather than
      // by magic.
      expect(w / 1.5, closeTo(260, 1));
      expect(liftedHeight(1.5), greaterThan(260));
    });

    test('16:9, which is shorter still', () {
      expect(liftedHeight(16 / 9), greaterThan(w / (16 / 9)));
    });

    test('4:3 is left exactly alone — it is not short', () {
      // The line is drawn so the commonest shape people shoot keeps every
      // pixel of its width.
      expect(liftedAspect(photoAspect: 4 / 3, availableWidth: w, availableHeight: h),
          4 / 3);
    });

    test('a portrait photo is left alone', () {
      expect(liftedAspect(photoAspect: 0.75, availableWidth: w, availableHeight: h),
          0.75);
    });

    test('a square is left alone', () {
      expect(liftedAspect(photoAspect: 1, availableWidth: w, availableHeight: h), 1);
    });
  });

  group('what it costs', () {
    test('never more than a tenth or so of the width', () {
      for (final aspect in [1.5, 16 / 9, 2.0, 3.0, 5.0]) {
        final box = liftedAspect(
            photoAspect: aspect, availableWidth: w, availableHeight: h);
        // How much of the frame's width is outside the box, as a fraction.
        final cropped = 1 - (box / aspect);
        expect(cropped, lessThanOrEqualTo(0.13),
            reason: 'a $aspect photo lost ${(cropped * 100).round()}% of its width');
      }
    });

    test('a panorama is lifted but not turned into a different picture', () {
      // 5:1 is the shape that would tempt a rule with no ceiling into cropping
      // most of the photograph away to fill a phone.
      final box =
          liftedAspect(photoAspect: 5, availableWidth: w, availableHeight: h);
      expect(box, greaterThan(4.3), reason: 'still recognisably a panorama');
    });

    test('it never grows past half the stage', () {
      for (final aspect in [1.5, 16 / 9, 2.0, 5.0]) {
        expect(liftedHeight(aspect), lessThanOrEqualTo(h * 0.5 + 1));
      }
    });

    test('it only ever grows', () {
      for (final aspect in [0.5, 1.0, 4 / 3, 1.5, 16 / 9, 3.0]) {
        expect(liftedHeight(aspect), greaterThanOrEqualTo(w / aspect - 0.01),
            reason: 'a $aspect photo got shorter');
      }
    });
  });

  group('nonsense in, nothing out', () {
    test('an unmeasured stage changes nothing', () {
      expect(liftedAspect(photoAspect: 1.5, availableWidth: 0, availableHeight: h),
          1.5);
      expect(liftedAspect(photoAspect: 1.5, availableWidth: w, availableHeight: 0),
          1.5);
    });

    test('an impossible aspect changes nothing', () {
      expect(liftedAspect(photoAspect: 0, availableWidth: w, availableHeight: h), 0);
    });

    test('a stage shorter than the photo changes nothing', () {
      // Already height-bound: there is no black to reclaim.
      expect(
        liftedAspect(photoAspect: 1.5, availableWidth: w, availableHeight: 100),
        1.5,
      );
    });
  });

  test('liftsPhoto agrees with liftedAspect', () {
    expect(
      liftsPhoto(photoAspect: 1.5, availableWidth: w, availableHeight: h),
      isTrue,
    );
    expect(
      liftsPhoto(photoAspect: 4 / 3, availableWidth: w, availableHeight: h),
      isFalse,
    );
  });
}

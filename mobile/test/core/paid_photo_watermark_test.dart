import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/purchase/paid_photo_watermark.dart';

/// The logo over a photo that has not been paid for.
///
/// The counterpart to the price badge, and it has to follow the same rule: the
/// badge says what a photo costs, the mark says it has not been bought. A
/// priced photo showing neither reads as free.
///
/// The rule is a static so every surface asks the same question. The
/// alternative — each screen writing its own "is this paid for" test — is how
/// one of them ends up disagreeing, and the screen that disagrees is the one
/// giving photographs away.
void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(body: SizedBox(width: 200, height: 200, child: child)),
      );

  final mark = find.byType(SvgPicture);

  group('who gets marked', () {
    test('a priced photo that has not been bought', () {
      expect(
        PaidPhotoWatermark.shouldMark(price: 20, isPurchased: false),
        isTrue,
      );
    });

    test('not once it has been bought', () {
      // The whole point of buying it.
      expect(
        PaidPhotoWatermark.shouldMark(price: 20, isPurchased: true),
        isFalse,
      );
    });

    test('not a free photo', () {
      expect(
        PaidPhotoWatermark.shouldMark(price: 0, isPurchased: false),
        isFalse,
      );
    });

    test('not a photo priced at a fraction of nothing', () {
      // `price` is a double on a money path. Anything above zero is for sale.
      expect(
        PaidPhotoWatermark.shouldMark(price: 0.5, isPurchased: false),
        isTrue,
      );
    });

    test('not the photographer looking at their own work', () {
      // They are not being sold anything, and marking their own photographs
      // back at them is noise.
      expect(
        PaidPhotoWatermark.shouldMark(
          price: 20,
          isPurchased: false,
          viewerIsPhotographer: true,
        ),
        isFalse,
      );
    });
  });

  group('drawing it', () {
    testWidgets('an unpaid priced photo carries the mark', (t) async {
      await t.pumpWidget(host(const PaidPhotoWatermark(
        price: 20,
        isPurchased: false,
        child: ColoredBox(color: Colors.blue),
      )));
      await t.pumpAndSettle();

      expect(mark, findsOneWidget);
    });

    testWidgets('a bought photo is left alone', (t) async {
      await t.pumpWidget(host(const PaidPhotoWatermark(
        price: 20,
        isPurchased: true,
        child: ColoredBox(color: Colors.blue),
      )));
      await t.pumpAndSettle();

      expect(mark, findsNothing);
    });

    testWidgets('a free photo is left alone', (t) async {
      await t.pumpWidget(host(const PaidPhotoWatermark(
        price: 0,
        isPurchased: false,
        child: ColoredBox(color: Colors.blue),
      )));
      await t.pumpAndSettle();

      expect(mark, findsNothing);
    });

    testWidgets('the photo underneath is always drawn', (t) async {
      // Marked or not, the widget is a wrapper — losing the photograph would
      // be a considerably worse bug than missing the logo.
      for (final purchased in [true, false]) {
        await t.pumpWidget(host(PaidPhotoWatermark(
          price: 20,
          isPurchased: purchased,
          child: const ColoredBox(color: Colors.blue),
        )));
        await t.pumpAndSettle();

        expect(find.byType(ColoredBox), findsWidgets);
      }
    });

    testWidgets('it does not eat gestures meant for the photo', (t) async {
      // Tapping through to the viewer, pinching, swiping the carousel — all of
      // it has to keep working under the mark.
      var taps = 0;
      await t.pumpWidget(host(GestureDetector(
        onTap: () => taps++,
        child: const PaidPhotoWatermark(
          price: 20,
          isPurchased: false,
          child: ColoredBox(color: Colors.blue),
        ),
      )));
      await t.pumpAndSettle();

      await t.tap(find.byType(PaidPhotoWatermark));

      expect(taps, 1);
    });

    testWidgets('the mark scales with the photo it is over', (t) async {
      // The same widget draws a 64px filmstrip thumbnail and a full-screen
      // viewer. Keyed to the shorter edge, so it lands the same on a portrait
      // crop and a landscape one rather than going tiny on a tall photo.
      Future<double> widthIn(Size box) async {
        await t.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: box.width,
              height: box.height,
              child: const PaidPhotoWatermark(
                price: 20,
                isPurchased: false,
                child: ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        ));
        await t.pumpAndSettle();
        return t.widget<SvgPicture>(mark).width!;
      }

      final thumbnail = await widthIn(const Size(64, 64));
      final viewer = await widthIn(const Size(390, 390));
      final tall = await widthIn(const Size(200, 600));

      expect(viewer, greaterThan(thumbnail));
      // A tall photo is measured on its width, not its height.
      expect(tall, closeTo(await widthIn(const Size(200, 200)), 0.01));
    });
  });

  group('growing with the zoom', () {
    // Pinning the mark outside the transform stopped it being panned
    // off-screen, and was still beatable: the window holds a quarter as much
    // photograph at 4×, so a mark held at its resting size covered a quarter
    // as much of it — zoom in on a face and it arrives clean beside a logo
    // that stayed where it was. The mark takes the scale for that reason.
    Future<double> widthAt(WidgetTester t, double scale) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 390,
            child: PaidPhotoWatermark(
              price: 20,
              isPurchased: false,
              scale: scale,
              child: const ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();
      return t.widget<SvgPicture>(mark).width!;
    }

    testWidgets('a zoomed photo gets a bigger mark', (t) async {
      final rest = await widthAt(t, 1);
      final zoomed = await widthAt(t, 1.5);

      expect(zoomed, greaterThan(rest));
      expect(zoomed, closeTo(rest * 1.5, 0.01));
    });

    testWidgets('it stops growing before it outgrows the window', (t) async {
      // Past the cap the logo is clipped to a fragment, and a fragment of a
      // logo does not read as a watermark — which is the one thing it is for.
      final far = await widthAt(t, 6);

      expect(far, lessThanOrEqualTo(390));
      expect(far, closeTo(390 * 0.95, 0.01));
    });

    testWidgets('it never shrinks below its resting size', (t) async {
      // A scale under 1 only comes from a pinch already easing back to rest,
      // and a mark that shrank with it would flicker.
      final rest = await widthAt(t, 1);

      expect(await widthAt(t, 0.4), rest);
    });
  });
}

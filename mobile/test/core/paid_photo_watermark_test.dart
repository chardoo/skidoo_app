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
}

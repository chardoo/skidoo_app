import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/widgets/zoomable_photo.dart';

/// The slot a watermark sits in over a photo being zoomed.
///
/// Two properties, and a paid photo leaks without either one:
///
///  * the overlay is **outside** the transform, so panning a magnified photo
///    cannot carry the mark off the visible window;
///  * the overlay is handed the **scale**, so it can grow back the coverage
///    that magnifying the photograph takes away.
void main() {
  /// Stands in for the watermark. Recorded rather than measured, because what
  /// the slot owes its occupant is the number.
  const overlayKey = Key('overlay');
  const photoKey = Key('photo');

  Future<double?> pumpAndZoom(WidgetTester t, {required bool zoom}) async {
    double? seen;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: ZoomableArea(
              overlayBuilder: (_, scale) {
                seen = scale;
                return const SizedBox.expand(key: overlayKey);
              },
              child: const ColoredBox(key: photoKey, color: Colors.blue),
            ),
          ),
        ),
      ),
    ));
    await t.pump();

    if (zoom) {
      // Double-tap: the gesture ZoomableArea offers when the host has not
      // taken the single tap for its own chrome.
      final photo = find.byKey(photoKey);
      await t.tap(photo);
      await t.pump(kDoubleTapMinTime);
      await t.tap(photo);
      await t.pumpAndSettle();
    }
    return seen;
  }

  testWidgets('at rest the overlay is told 1×', (t) async {
    expect(await pumpAndZoom(t, zoom: false), 1.0);
  });

  testWidgets('a zoomed photo tells the overlay how far', (t) async {
    final scale = await pumpAndZoom(t, zoom: true);

    expect(scale, isNotNull);
    expect(scale, greaterThan(1.0),
        reason: 'a mark that is never told about the zoom cannot grow with it',
    );
  });

  testWidgets('the overlay is never inside the transform', (t) async {
    await pumpAndZoom(t, zoom: false);

    expect(find.byKey(overlayKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(InteractiveViewer),
        matching: find.byKey(overlayKey),
      ),
      findsNothing,
      reason: 'inside, the mark pans with the photo and at 4× in a corner it '
          'is off the visible window — pinch, pan, screenshot, clean photo',
    );
  });

  testWidgets('a viewer with no overlay is left as it was', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 300,
          child: ZoomableArea(child: ColoredBox(color: Colors.blue)),
        ),
      ),
    ));
    await t.pump();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byKey(overlayKey), findsNothing);
  });
}

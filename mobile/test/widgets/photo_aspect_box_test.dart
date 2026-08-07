import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/widgets/photo_aspect_box.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/models/photos/Photo.dart';

const _child = SizedBox.shrink();

Widget host(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(width: 200, child: child)));

void main() {
  group('PhotoAspectBox', () {
    testWidgets('sizes from the served dimensions', (t) async {
      // 4000 × 6000 — the shape in the my-photos contract.
      await t.pumpWidget(host(const PhotoAspectBox(
        aspectRatio: 4000 / 6000,
        child: _child,
      )));

      // 200 wide at 2:3 → 300 tall, reserved before anything decodes.
      expect(t.getSize(find.byType(AspectRatio)), const Size(200, 300));
    });

    testWidgets('clamps a panorama so one tile cannot eat the grid', (t) async {
      await t.pumpWidget(host(const PhotoAspectBox(
        aspectRatio: 8, // 8:1
        child: _child,
      )));

      // Clamped to 2:1 → 100 tall, not 25.
      expect(t.getSize(find.byType(AspectRatio)), const Size(200, 100));
    });

    testWidgets('clamps a tower at the other end', (t) async {
      await t.pumpWidget(host(const PhotoAspectBox(
        aspectRatio: 0.1, // 1:10
        child: _child,
      )));

      // Clamped to 1:2 → 400 tall, not 2000.
      expect(t.getSize(find.byType(AspectRatio)), const Size(200, 400));
    });

    testWidgets('falls back to the given height when dimensions are missing',
        (t) async {
      await t.pumpWidget(host(const PhotoAspectBox(
        aspectRatio: null,
        fallbackHeight: 150,
        child: _child,
      )));

      expect(find.byType(AspectRatio), findsNothing);
      expect(t.getSize(find.byType(SizedBox).last).height, 150);
    });

    testWidgets('leaves the child alone with neither dimensions nor fallback',
        (t) async {
      await t.pumpWidget(host(const PhotoAspectBox(
        aspectRatio: null,
        child: Text('media'),
      )));

      // Intrinsic sizing — the behaviour legacy records already had.
      expect(find.byType(AspectRatio), findsNothing);
      expect(find.text('media'), findsOneWidget);
    });

    testWidgets('treats a zero/garbage ratio as missing', (t) async {
      await t.pumpWidget(host(const PhotoAspectBox(
        aspectRatio: 0,
        fallbackHeight: 150,
        child: _child,
      )));

      expect(find.byType(AspectRatio), findsNothing);
    });
  });

  group('the models actually carry the dimensions', () {
    test('EventPicture reads width/height off the wire', () {
      final pic = EventPicture.fromMap(const {
        'id': 'p1',
        'url': 'https://example.invalid/p1.jpg',
        'imageId': 'i1',
        'price': 0,
        'width': 4000,
        'height': 6000,
      });

      expect(pic.width, 4000);
      expect(pic.height, 6000);
      expect(pic.aspectRatio, closeTo(2 / 3, 1e-9));
    });

    test('Photo reads them too, and reports null when absent', () {
      final withDims = Photo.fromMap(const {
        'id': 'p1',
        'url': 'https://example.invalid/p1.jpg',
        'imageId': 'i1',
        'price': 0,
        'width': 1920,
        'height': 1080,
      });
      expect(withDims.aspectRatio, closeTo(16 / 9, 1e-9));

      // Legacy record — callers must be able to tell "unknown" from a guess.
      final noDims = Photo.fromMap(const {
        'id': 'p2',
        'url': 'https://example.invalid/p2.jpg',
        'imageId': 'i2',
        'price': 0,
      });
      expect(noDims.aspectRatio, isNull);
    });

    test('a zero height never yields a divide-by-zero ratio', () {
      final pic = EventPicture.fromMap(const {
        'id': 'p1',
        'url': 'https://example.invalid/p1.jpg',
        'imageId': 'i1',
        'price': 0,
        'width': 100,
        'height': 0,
      });
      expect(pic.aspectRatio, isNull);
    });
  });
}

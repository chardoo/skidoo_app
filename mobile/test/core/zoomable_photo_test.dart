import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/image_aspect.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/core/widgets/zoomable_photo.dart';

/// A full-screen viewer used to hand a screen-sized slot to `BoxFit.contain`,
/// so the loading state was a spinner marooned in the middle of a black screen
/// and the photo appeared somewhere else entirely. Boxing the page to the
/// server's `width`/`height` means the placeholder already occupies the
/// footprint the image is about to fill.
/// The viewer's slot in these tests — a portrait phone rather than the default
/// 800 × 600 test surface, which is landscape and would clip the box under
/// test instead of letting it choose its own shape.
const _viewport = Size(400, 800);

void main() {
  setUp(() {
    ImageAspectCache.clear();
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = _viewport;
    view.devicePixelRatio = 1;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  Widget host(Widget child) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(backgroundColor: Colors.black, body: child),
      );

  testWidgets('boxes the photo to its recorded shape', (t) async {
    await t.pumpWidget(host(const ZoomablePhoto(
      imageUrl: 'https://cdn.example.com/wide.jpg',
      knownAspect: 3 / 2, // 3000 × 2000
    )));

    final size = t.getSize(find.byType(JpergImage));
    expect(size.width, 400);
    expect(size.height, moreOrLessEquals(400 / (3 / 2), epsilon: 0.5));
  });

  testWidgets('a tall shot is bounded by the screen, not overflowed',
      (t) async {
    // 1:4 — taller than the 400 × 800 viewport can show at full width, so the
    // box has to give up width rather than run off the bottom.
    await t.pumpWidget(host(const ZoomablePhoto(
      imageUrl: 'https://cdn.example.com/tall.jpg',
      knownAspect: 1 / 4,
    )));

    final size = t.getSize(find.byType(JpergImage));
    expect(size.height, 800);
    expect(size.width, moreOrLessEquals(800 * (1 / 4), epsilon: 0.5));
  });

  testWidgets('the loading state occupies the photo footprint, not the screen',
      (t) async {
    await t.pumpWidget(host(const ZoomablePhoto(
      imageUrl: 'https://cdn.example.com/wide.jpg',
      knownAspect: 3 / 2,
    )));

    // The placeholder is inside the box, so it is the photo's size — this is
    // what stops the image jumping when it lands.
    final placeholder = t.getSize(find.byType(JpergImagePlaceholder).first);
    expect(placeholder.height, moreOrLessEquals(400 / (3 / 2), epsilon: 0.5));
  });

  testWidgets('a record with no dimensions still renders', (t) async {
    await t.pumpWidget(host(const ZoomablePhoto(
      imageUrl: 'https://cdn.example.com/legacy.jpg',
    )));
    await t.pump();

    // Falls back to ResolvedAspect's default shape rather than collapsing.
    expect(find.byType(JpergImage), findsOneWidget);
    expect(t.getSize(find.byType(JpergImage)).height, greaterThan(0));
  });

  testWidgets('zoom resets when the page is recycled onto another photo',
      (t) async {
    await t.pumpWidget(host(const ZoomablePhoto(
      imageUrl: 'https://cdn.example.com/a.jpg',
      knownAspect: 1,
    )));

    final viewer = find.byType(InteractiveViewer);
    final controller = t.widget<InteractiveViewer>(viewer);
    controller.transformationController!.value = Matrix4.identity()
      ..scaleByDouble(2.5, 2.5, 2.5, 1);
    await t.pump();

    await t.pumpWidget(host(const ZoomablePhoto(
      imageUrl: 'https://cdn.example.com/b.jpg',
      knownAspect: 1,
    )));

    expect(
      t
          .widget<InteractiveViewer>(viewer)
          .transformationController!
          .value
          .isIdentity(),
      isTrue,
    );
  });

  testWidgets('double-tap magnifies the photo, and again puts it back',
      (t) async {
    await t.pumpWidget(host(const ZoomablePhoto(
      imageUrl: 'https://cdn.example.com/a.jpg',
      knownAspect: 1,
    )));

    final viewer = find.byType(InteractiveViewer);
    double scale() => t
        .widget<InteractiveViewer>(viewer)
        .transformationController!
        .value
        .getMaxScaleOnAxis();

    Future<void> doubleTap() async {
      await t.tap(viewer);
      await t.pump(kDoubleTapMinTime);
      await t.tap(viewer);
      // Not pumpAndSettle: the loading placeholder spins forever, so the tree
      // never settles. One frame to start the zoom, one long enough to finish
      // it — the first tick a ticker gets is its zero point.
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
    }

    await doubleTap();
    expect(scale(), greaterThan(1.5), reason: 'zoomed in on the tapped point');

    await doubleTap();
    expect(scale(), moreOrLessEquals(1, epsilon: 0.01));
  });

  testWidgets('a photo swiped away from does not keep its zoom', (t) async {
    // The pager keeps its neighbours alive, so a page left magnified would
    // still be magnified when it is swiped back to.
    await t.pumpWidget(host(const ZoomablePhoto(
      imageUrl: 'https://cdn.example.com/a.jpg',
      knownAspect: 1,
    )));

    final viewer = find.byType(InteractiveViewer);
    t.widget<InteractiveViewer>(viewer).transformationController!.value =
        Matrix4.identity()..scaleByDouble(2.5, 2.5, 2.5, 1);
    await t.pump();

    await t.pumpWidget(host(const ZoomablePhoto(
      imageUrl: 'https://cdn.example.com/a.jpg',
      knownAspect: 1,
      isActive: false,
    )));

    expect(
      t
          .widget<InteractiveViewer>(viewer)
          .transformationController!
          .value
          .isIdentity(),
      isTrue,
    );
  });

  testWidgets('the host is told when the photo leaves 1x and when it returns',
      (t) async {
    final reported = <bool>[];

    await t.pumpWidget(host(ZoomablePhoto(
      imageUrl: 'https://cdn.example.com/a.jpg',
      knownAspect: 1,
      onZoomChanged: reported.add,
    )));

    final controller = t
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;

    controller.value = Matrix4.identity()..scaleByDouble(2.5, 2.5, 2.5, 1);
    await t.pump();
    expect(reported, [true]);

    // The threshold sits a little above 1, so a pinch that ends fractionally
    // off rest counts as back at rest rather than leaving the pager frozen.
    controller.value = Matrix4.identity()..scaleByDouble(1.02, 1.02, 1.02, 1);
    await t.pump();
    expect(reported, [true, false]);

    controller.value = Matrix4.identity();
    await t.pump();
    expect(reported, [true, false], reason: 'still at rest, nothing to say');
  });
}

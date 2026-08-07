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
}

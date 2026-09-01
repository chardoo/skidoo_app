import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/image_aspect.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// A photo opened in full is a photo someone is inspecting — usually to decide
/// whether the face in a crowd shot is theirs — and at screen size that is
/// often not decidable. These pin that the viewer every entry point opens can
/// be zoomed, and that the zoom is usable once it is on: a magnified photo has
/// to pan under the finger rather than page to the next one.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: child,
      ),
    );

Photo photo({String id = 'pic-1'}) => Photo.fromMap({
      'id': id,
      'url': 'https://cdn/$id.jpg',
      'width': 3000,
      'height': 2000,
      'event': const {'id': 'evt-1', 'eventName': 'University Graduation 2024'},
    });

TransformationController zoomOf(WidgetTester t) =>
    t.widget<InteractiveViewer>(find.byType(InteractiveViewer).first)
        .transformationController!;

ScrollPhysics? pagerPhysics(WidgetTester t) =>
    t.widget<PageView>(find.byType(PageView)).physics;

void main() {
  setUp(() {
    ImageAspectCache.clear();
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  testWidgets('the photo on show can be zoomed', (t) async {
    await t.pumpWidget(host(FoundPhotoViewerPage(photos: [photo()])));
    await t.pump();

    expect(find.byType(InteractiveViewer), findsWidgets);
  });

  testWidgets('the pager is frozen while the photo is zoomed', (t) async {
    final settled = <int>[];

    await t.pumpWidget(host(FoundPhotoViewerPage(
      photos: [photo(id: 'a'), photo(id: 'b')],
      onIndexChanged: settled.add,
    )));
    await t.pump();

    expect(pagerPhysics(t), isNot(isA<NeverScrollableScrollPhysics>()));

    zoomOf(t).value = Matrix4.identity()..scaleByDouble(2.5, 2.5, 2.5, 1);
    await t.pump();

    expect(pagerPhysics(t), isA<NeverScrollableScrollPhysics>());

    // The drag that would have paged now belongs to the photo.
    await t.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await t.pump(const Duration(seconds: 1));

    expect(settled, isEmpty, reason: 'it stayed on the photo being inspected');
  });

  testWidgets('swiping is given back once the photo is at rest', (t) async {
    await t.pumpWidget(host(FoundPhotoViewerPage(
      photos: [photo(id: 'a'), photo(id: 'b')],
    )));
    await t.pump();

    final zoom = zoomOf(t);
    zoom.value = Matrix4.identity()..scaleByDouble(2.5, 2.5, 2.5, 1);
    await t.pump();
    zoom.value = Matrix4.identity();
    await t.pump();

    expect(pagerPhysics(t), isNot(isA<NeverScrollableScrollPhysics>()));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/widgets/image_aspect.dart';
import 'package:skidoo_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: [AppThemeExtension.dark]),
        home: child,
      ),
    );

Photo photo({
  String id = 'pic-1',
  int? width,
  int? height,
}) =>
    Photo.fromMap({
      'id': id,
      'url': 'https://cdn/$id.jpg',
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      'event': const {'id': 'evt-1', 'eventName': 'University Graduation 2024'},
    });

/// The height the pager actually got — the thing that used to be "everything
/// left over" regardless of the photo.
double pagerHeight(WidgetTester t) =>
    t.getSize(find.byType(PageView)).height;

double photoWidth(WidgetTester t) => t.getSize(find.byType(PageView)).width;

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

  testWidgets('a landscape photo gets its own height, not the leftover space',
      (t) async {
    // 3:2 — the shape that exposed the bug: the pager filled the screen and
    // left a fifth of it empty above the photo and another fifth below.
    await t.pumpWidget(host(FoundPhotoViewerPage(
      photos: [photo(width: 3000, height: 2000)],
    )));
    await t.pump();

    final expected = photoWidth(t) / (3000 / 2000);
    expect(pagerHeight(t), moreOrLessEquals(expected, epsilon: 1));

    // And that is genuinely shorter than the space it used to take.
    expect(pagerHeight(t), lessThan(t.getSize(find.byType(Scaffold)).height / 2));
  });

  testWidgets('the media is centred between the top bar and the filmstrip',
      (t) async {
    await t.pumpWidget(host(FoundPhotoViewerPage(
      photos: [
        photo(id: 'a', width: 3000, height: 2000),
        photo(id: 'b', width: 3000, height: 2000),
      ],
    )));
    await t.pump();

    // Sizing the pager to the photo must not park it against the top bar —
    // the design centres the media, and a wide shot and a tall one have to
    // read as the same screen.
    final area = t.getRect(find
        .ancestor(of: find.byType(PageView), matching: find.byType(Center))
        .last);
    final pager = t.getRect(find.byType(PageView));

    final gapAbove = pager.top - area.top;
    final gapBelow = area.bottom - pager.bottom;

    expect(gapAbove, moreOrLessEquals(gapBelow, epsilon: 1));
    expect(gapAbove, greaterThan(0), reason: 'it is not flush with the top bar');
  });

  testWidgets('a tall photo is capped at the space available', (t) async {
    // 1:4 wants a height far past the screen; it has to fill what is left
    // rather than overflow the column. (A layout overflow fails the test on
    // its own — flutter_test rethrows it at the end of the pump.)
    await t.pumpWidget(host(FoundPhotoViewerPage(
      photos: [photo(width: 1000, height: 4000)],
    )));
    await t.pump();

    final natural = photoWidth(t) / (1000 / 4000);
    final available = t.getSize(find.byType(Scaffold)).height;

    expect(natural, greaterThan(available), reason: 'the fixture is tall');
    expect(pagerHeight(t), lessThan(natural));
    expect(pagerHeight(t), lessThanOrEqualTo(available));
  });

  testWidgets('the pager height tracks the photo the user swipes to',
      (t) async {
    await t.pumpWidget(host(FoundPhotoViewerPage(
      photos: [
        photo(id: 'wide', width: 3000, height: 1000),
        photo(id: 'tall', width: 1000, height: 2000),
      ],
    )));
    await t.pump();

    final wide = pagerHeight(t);

    await t.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await t.pumpAndSettle();

    expect(pagerHeight(t), greaterThan(wide),
        reason: 'the tall photo needs more height than the wide one');
  });

  testWidgets('a record with no dimensions still renders', (t) async {
    // The fallback shape only has to hold until the image is measured; with no
    // network in a test it never is, so this pins that the page copes.
    await t.pumpWidget(host(FoundPhotoViewerPage(photos: [photo()])));
    await t.pump();

    expect(find.byType(PageView), findsOneWidget);
    expect(pagerHeight(t), greaterThan(0));
  });
}

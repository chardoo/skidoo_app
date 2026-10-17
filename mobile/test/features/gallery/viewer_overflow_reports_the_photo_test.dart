import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_icons.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/image_aspect.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// The photo viewer's top bar carries a back button, the album's name, and a
/// three-dot menu whose one entry reports the photo.
///
/// The slot has been all three things. It held an `onPressed: null` button
/// drawn at 35% opacity — three dots on every photo that could not be pressed
/// — which was removed, because everything such a menu would have offered
/// (share, send, save, download) is already on the rail down the photo's right
/// edge and the bar across its bottom.
///
/// Report is the exception, and the reason the slot is back: a photo is the
/// app's primary piece of user content, the server has accepted
/// `assetType: "picture"` the whole time, and every other route to Report was
/// on an event or an ad. A photo that cannot be flagged is the App Review
/// guideline 1.2 exposure, not a missing convenience.
///
/// Both halves are tested: that the menu opens and offers the report, and that
/// the title still sits on the centre of the screen — an IconButton occupies
/// exactly `kMinInteractiveDimension`, the same width the back button takes on
/// the other side, which is what keeps it there.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: child,
      ),
    );

Photo photo() => Photo.fromMap({
      'id': 'pic-1',
      'url': 'https://cdn/pic-1.jpg',
      'price': 0,
      'width': 1600,
      'height': 900,
      'event': const {'id': 'evt-1', 'eventName': 'Praise Reloaded 2026'},
    });

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

  testWidgets('the overflow is there and can be pressed', (t) async {
    await t.pumpWidget(host(FoundPhotoViewerPage(
      photos: [photo()],
      title: 'Praise Reloaded 2026',
    )));
    await t.pump();

    final overflow = find.byWidgetPredicate(
        (w) => w is AppSvgIcon && w.asset == AppIcons.moreVertical);
    expect(overflow, findsOneWidget);

    // Not drawn dead. The whole point of the slot is that pressing it does
    // something.
    expect(
      find.byWidgetPredicate((w) => w is IconButton && w.onPressed == null),
      findsNothing,
    );
  });

  testWidgets('it opens a menu that reports the photo', (t) async {
    await t.pumpWidget(host(FoundPhotoViewerPage(
      photos: [photo()],
      title: 'Praise Reloaded 2026',
    )));
    await t.pump();

    await t.tap(find.byWidgetPredicate(
        (w) => w is AppSvgIcon && w.asset == AppIcons.moreVertical));
    await t.pumpAndSettle();

    expect(find.text('Report photo'), findsOneWidget);

    // Through to the reason picker, which is where the report is actually
    // filed from. The sheet talks to the API only on submit, so opening it
    // needs nothing registered.
    await t.tap(find.text('Report photo'));
    await t.pumpAndSettle();

    expect(find.text('Why are you reporting this?'), findsOneWidget);
    // The reason the published child safety standards commit to. It is on this
    // list or the standards describe something the app does not have.
    expect(find.text('Child safety or exploitation'), findsOneWidget);
  });

  testWidgets('the album name still sits on the centre of the screen',
      (t) async {
    await t.pumpWidget(host(FoundPhotoViewerPage(
      photos: [photo()],
      title: 'Praise',
    )));
    await t.pump();

    final title = find.text('Praise');
    expect(title, findsOneWidget);

    final screen = t.getSize(find.byType(MaterialApp)).width;
    // Within a point: the menu button and the back button have to cost the
    // same width, or the title sits half a tap target off centre.
    expect(t.getCenter(title).dx, moreOrLessEquals(screen / 2, epsilon: 1.0));
  });
}

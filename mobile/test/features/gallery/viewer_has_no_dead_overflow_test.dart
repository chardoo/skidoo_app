import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_icons.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/image_aspect.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// The photo viewer's top bar carries a back button and the album's name, and
/// nothing else.
///
/// It used to end in a three-dot overflow button that was `onPressed: null` —
/// drawn at 35% opacity, holding the place the design gives a menu, wired to
/// nothing. So every photo in the app had three dots on it that could not be
/// pressed, which reads as a feature that broke rather than as one that was
/// never built. Everything such a menu would have offered — share, send,
/// download, save — is already on the rail down the right edge and the bar
/// across the bottom of the photo.
///
/// The width it occupied is kept, because that is the other half of what it
/// was doing: it balanced the back button so the title sat on the centre of
/// the screen rather than half a button to the right of it.
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

  testWidgets('no overflow button, pressable or otherwise', (t) async {
    await t.pumpWidget(host(FoundPhotoViewerPage(
      photos: [photo()],
      title: 'Praise Reloaded 2026',
    )));
    await t.pump();

    expect(
      find.byWidgetPredicate(
          (w) => w is AppSvgIcon && w.asset == AppIcons.moreVertical),
      findsNothing,
    );
    // Nor a disabled IconButton of any other kind: a control that cannot be
    // pressed has no business on a photo.
    expect(
      find.byWidgetPredicate((w) => w is IconButton && w.onPressed == null),
      findsNothing,
    );
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
    // Within a point: removing the button without keeping its width would push
    // the title half a tap target to the right.
    expect(t.getCenter(title).dx, moreOrLessEquals(screen / 2, epsilon: 1.0));
  });
}

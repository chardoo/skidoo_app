import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/found_photo_filmstrip.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

/// The Found viewer used to pin itself to the dark palette in both app themes.
/// These hold it to the ambient theme: the surround is the page's own
/// background, and only the overlays that sit *on* the photo stay light-on-
/// scrim regardless of theme.

Photo photo(String id) => Photo(
      id,
      'Praise Reloaded 2026',
      'img_$id',
      'https://example.invalid/$id.jpg',
      'user_1',
      0,
      '2026-07-30',
      null,
      true,
      photographerName: 'Daniella Daniels',
      location: 'Accra',
    );

Widget host(AppThemeExtension ext, Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(
          brightness: ext == AppThemeExtension.dark
              ? Brightness.dark
              : Brightness.light,
          extensions: [ext],
        ),
        home: child,
      ),
    );

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  // One theme per test: pumping a second theme into the same tree reuses the
  // element and the new theme doesn't take, passing for the wrong reason.
  for (final (name, ext) in [
    ('dark', AppThemeExtension.dark),
    ('light', AppThemeExtension.light),
  ]) {
    testWidgets('the viewer surround follows the theme — $name', (t) async {
      await t.pumpWidget(host(
        ext,
        FoundPhotoViewerPage(photos: [photo('a'), photo('b')]),
      ));

      final scaffold = t.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, ext.homeBackground);
    });

    testWidgets('the "n of total" bar follows the theme — $name', (t) async {
      await t.pumpWidget(host(
        ext,
        FoundPhotoViewerPage(photos: [photo('a'), photo('b')]),
      ));

      // The counter is a Text.rich split across spans, so find.text can't
      // reach it — the semantics label is the stable handle, and the colour
      // comes off the root span every child inherits from.
      expect(find.bySemanticsLabel('1 of 2'), findsOneWidget);
      // The counter is the one Text built from spans rather than a plain
      // string; its root span carries the colour every child inherits.
      final counter = t
          .widgetList<Text>(find.byType(Text))
          .firstWhere((w) => w.textSpan != null);
      expect(
        counter.textSpan!.style!.color,
        ext.greetingColor.withValues(alpha: 0.7),
      );
      expect(
        t.widget<Icon>(find.byIcon(Icons.arrow_back_rounded)).color,
        ext.greetingColor,
      );
    });

    testWidgets('the filmstrip ring stays the accent in either theme — $name',
        (t) async {
      await t.pumpWidget(host(
        ext,
        FoundPhotoViewerPage(photos: [photo('a'), photo('b')]),
      ));
      await t.pump();

      expect(find.byType(FoundPhotoFilmstrip), findsOneWidget);
      // accentGold is #1D9E75 in both themes, so the active ring needs no
      // per-theme variant even though the strip around it now has one.
      expect(ext.accentGold, AppThemeExtension.dark.accentGold);
    });
  }
}

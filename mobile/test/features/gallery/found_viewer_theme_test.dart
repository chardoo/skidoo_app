import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_photo_filmstrip.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// The viewer is dark in both app themes — the photo is the point of the
/// screen and the surround's job is to disappear behind it, so viewing
/// photographs is the one place the reader's theme preference loses.
///
/// This flipped once before, from pinned-dark to theme-following, and back. The
/// tests below assert the *current* rule against both themes, so whichever way
/// it goes next, the loop shows it rather than only half of it.

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
    testWidgets('the viewer surround is dark whatever the app theme — $name',
        (t) async {
      await t.pumpWidget(host(
        ext,
        FoundPhotoViewerPage(photos: [photo('a'), photo('b')]),
      ));

      final scaffold = t.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppThemeExtension.dark.homeBackground);
    });

    testWidgets('the "n of total" bar reads against that dark ground — $name',
        (t) async {
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
      // The chrome resolves the dark palette too, because the surface under it
      // is dark — the light theme's near-black text would all but vanish on it.
      expect(
        counter.textSpan!.style!.color,
        AppThemeExtension.dark.greetingColor.withValues(alpha: 0.7),
      );
      expect(
        t.widget<Icon>(find.byIcon(Icons.arrow_back_rounded)).color,
        AppThemeExtension.dark.greetingColor,
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

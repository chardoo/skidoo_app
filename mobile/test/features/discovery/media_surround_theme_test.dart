import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/card_photo_preview.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// The Feed / Following feeds letterbox almost every card, so the area
/// *around* the media is most of what is on screen. These guard the regression
/// that made those two tabs read as dark in light mode: the surround was
/// hard-coded black while the rest of the app followed the theme.

Widget host(AppThemeExtension ext, Widget child) => MaterialApp(
      theme: ThemeData(
        brightness:
            ext == AppThemeExtension.dark ? Brightness.dark : Brightness.light,
        extensions: [ext],
      ),
      home: Scaffold(body: child),
    );

EventPicture photo(String id) => EventPicture(
      id: id,
      url: 'https://example.invalid/$id.jpg',
      imageId: id,
      price: 0,
    );

/// The veil is the only [ColoredBox] the carousel paints itself — the blurred
/// backdrop and the sharp image are both [JpergImage]s.
Color veilColour(WidgetTester t) {
  final boxes = t
      .widgetList<ColoredBox>(find.byType(ColoredBox))
      .map((b) => b.color)
      .toList();
  return boxes.firstWhere((c) => c.a > 0 && c.a < 1);
}

void main() {
  for (final (name, ext) in [
    ('dark', AppThemeExtension.dark),
    ('light', AppThemeExtension.light),
  ]) {
    testWidgets('the blur veil follows the theme — $name', (t) async {
      await t.pumpWidget(host(
        ext,
        PostPhotoCarousel(
          pics: [photo('a')],
          pageController: PageController(),
          showBlur: false,
          onDoubleTap: () {},
          onTap: () {},
        ),
      ));

      expect(veilColour(t), ext.mediaBackdropVeil);
    });
  }

  test('light mode veils toward the page background, not toward black', () {
    const light = AppThemeExtension.light;
    // The whole point: composited over any photo, the surround lands nearer the
    // light page than the dark one.
    expect(light.mediaBackdropVeil.r, greaterThan(0.5));
    expect(light.mediaLetterbox, light.homeBackground);

    const dark = AppThemeExtension.dark;
    expect(dark.mediaBackdropVeil.r, lessThan(0.5));
  });

  test('the media surround is not the same token as the legibility scrim', () {
    // cardOverlayEnd stays dark in both themes on purpose — it backs white text
    // over an arbitrary photo. If someone ever "fixes" it to match the theme,
    // captions go unreadable, so the two must stay distinct.
    expect(AppThemeExtension.light.cardOverlayEnd,
        AppThemeExtension.dark.cardOverlayEnd);
    expect(AppThemeExtension.light.mediaBackdropVeil,
        isNot(AppThemeExtension.dark.mediaBackdropVeil));
  });
}

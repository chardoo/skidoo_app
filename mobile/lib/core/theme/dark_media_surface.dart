import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/theme/customThemeData.dart';

/// Forces the dark palette on [child], whatever theme the app is in.
///
/// For the full-bleed media feeds. Almost every post is letterboxed — a photo
/// keeps its own shape, so the area *around* it is most of the screen — and
/// that surround has one job: to disappear, so the eye goes to the photograph.
/// A light surround can't. It competes with the image, every bright photo
/// bleeds into it, and the overlays that sit on the media (white captions and
/// counts, each with a drop shadow) are drawn for a dark ground and lose their
/// contrast against a pale one.
///
/// So the feeds are a dark island in a light app: viewing photographs is the
/// one place the reader's theme preference loses. This is deliberately not done
/// by darkening the theme's own media tokens — [AppThemeExtension.mediaLetterbox]
/// and friends still follow the theme, because media is letterboxed in themed
/// contexts too (a grid tile, a sheet preview). Only the feed opts out, and it
/// does it by changing what "the theme" is for everything inside it, so a card
/// deep in the tree needs to know nothing about this.
///
/// The Found tab is *not* wrapped: it is a grid of albums on the page's own
/// background, not a photo filling the screen, so it belongs to the theme.
class DarkMediaSurface extends StatelessWidget {
  const DarkMediaSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The feed is full-bleed: it runs under the status bar, so the clock and
    // battery are drawn on this surface too. Nothing else in the app sets an
    // overlay style, which left them at the platform default — dark glyphs in
    // light mode, and those vanish against a dark feed.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      // The app's own dark theme rather than a hand-patched copy of the light
      // one, so the fonts, component themes and colour scheme inside stay
      // coherent — a Material default resolved off a light scheme would come
      // out dark-on-dark.
      child: Theme(
        data: Styles.dark,
        child: ColoredBox(
          color: AppThemeExtension.dark.homeBackground,
          child: child,
        ),
      ),
    );
  }
}

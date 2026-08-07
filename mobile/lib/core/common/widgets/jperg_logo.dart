import 'package:flutter/material.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The jperg wordmark — the mark and the name, as one piece of artwork.
///
/// Replaces the hand-built lockup this app used to draw everywhere: a rounded
/// square holding a letter "S" (from a previous name), followed by the text
/// "JPERG" in whatever weight and letter-spacing each screen happened to
/// choose. Three screens each drew their own version, so the brand was three
/// slightly different shapes and none of them was the real logo.
///
/// The asset is a silhouette — alpha only, no colour of its own — so it takes
/// [color], defaulting to the theme's accent. That is what lets one file serve
/// both themes: the artwork ships on a white background, which would show as a
/// white slab in dark mode.
class JpergLogo extends StatelessWidget {
  const JpergLogo({super.key, this.height = 28, this.color});

  static const _asset = 'assets/logo/jperg_wordmark_alpha.png';

  /// The artwork's own proportions, so a caller only ever sets a height and
  /// the width follows. Measured from the trimmed asset (354 × 114).
  static const aspectRatio = 354 / 114;

  /// Rendered height in logical pixels. Width is derived from it.
  final double height;

  /// Defaults to the theme's accent green — the colour the logo is drawn in.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    final tint = color ?? ext?.accentGold ?? const Color(0xFF1D9E75);

    return Semantics(
      image: true,
      label: 'jperg',
      child: Image.asset(
        _asset,
        height: height,
        width: height * aspectRatio,
        // The asset carries coverage, not colour: every visible pixel is
        // white at some alpha, so srcIn paints [tint] through that shape.
        color: tint,
        colorBlendMode: BlendMode.srcIn,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      ),
    );
  }
}

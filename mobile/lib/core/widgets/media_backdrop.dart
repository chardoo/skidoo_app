import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';

/// Fills a full-bleed slot with the media's own colours, so a photo that does
/// not match the screen's shape never sits in empty bands.
///
/// The media is drawn twice: once blown up to cover the whole slot and blurred
/// past recognition, and once — by the caller, as [child] — at its true size
/// and aspect ratio on top. Nothing about the real image changes; only what is
/// behind it.
///
/// A video URL works as [url] without any extra handling: [JpergImage] derives
/// a poster frame from it, so the backdrop is a still and there is never a
/// second decoder running for something nobody can make out anyway.
///
/// The cost is one extra fetch at 80 px wide, capped at 120 on decode (see
/// [JpergImage.isBlurBackground]) — the blur destroys the detail, so there is
/// no reason to pay for any more of it.
class MediaBackdrop extends StatelessWidget {
  const MediaBackdrop({
    super.key,
    required this.url,
    required this.child,
  });

  /// The image or video the backdrop is made from — the same one [child] draws.
  final String url;

  /// The real media, at its own size. Painted over the backdrop.
  final Widget child;

  /// Enough to leave shape and colour with no legible detail.
  ///
  /// A backdrop that can still be read as a photo competes with the real one
  /// in front of it, which is the failure this is meant to avoid: the bands
  /// should register as the picture's own light, not as a second picture.
  static const double blurSigma = 40;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>() ??
        AppThemeExtension.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: JpergImage(
            imageUrl: url,
            fit: BoxFit.cover,
            isBlurBackground: true,
            // No spinner on either state: the backdrop is scenery, and a
            // spinner behind the real media's own spinner reads as a fault.
            placeholder: (_, __) => const JpergImagePlaceholder(),
            errorWidget: (_, __, ___) => const JpergImagePlaceholder(),
          ),
        ),
        // Knocks the backdrop back so it cannot compete with the media in
        // front. Themed, because this fills most of the screen on a card that
        // does not match its shape — a fixed black veil made the whole feed
        // read as dark in light mode.
        ColoredBox(color: ext.mediaBackdropVeil),
        child,
      ],
    );
  }
}

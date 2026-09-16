import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The logo laid over a photo that has not been paid for.
///
/// The counterpart to [PhotoPriceBadge], and it follows the same rule: the
/// badge says what a photo costs, this says it has not been bought yet. A
/// priced photo showing neither reads as free.
///
/// **This is a visual treatment, not protection.** The bytes behind it are the
/// same bytes, and anyone reading the URL out of a network response still gets
/// the clean file. Making it protection means the server serving watermarked
/// bytes and only releasing the clean URL after purchase — a per-viewer URL,
/// which is a different piece of work. Nothing here should be described as
/// securing a photo.
///
/// Deliberately separate from the photographer's attribution badge (logo +
/// `@handle`, burned bottom-right server-side by `app/utils/watermark.py`).
/// That one is a photographer's choice about credit and can appear alongside
/// this; they answer different questions and are drawn by different layers.
class PaidPhotoWatermark extends StatelessWidget {
  const PaidPhotoWatermark({
    super.key,
    required this.child,
    required this.price,
    required this.isPurchased,
    this.viewerIsPhotographer = false,
    this.opacity = _defaultOpacity,
    this.widthFactor = _defaultWidthFactor,
  });

  /// Faint enough to leave the photograph readable, strong enough to be
  /// unmistakably there. A watermark nobody notices is not doing its job, and
  /// one that dominates makes the thing somebody is deciding whether to buy
  /// look worse than it is.
  static const _defaultOpacity = 0.20;

  /// Share of the shorter edge the mark spans. Keyed to the *shorter* edge so
  /// it lands the same on a portrait crop and a landscape one — a factor of
  /// the width alone makes it tiny on a tall photo.
  static const _defaultWidthFactor = 0.55;

  final Widget child;
  final double price;
  final bool isPurchased;

  /// The photographer looking at their own work. They are not being sold
  /// anything, and marking their own photographs back at them is noise.
  final bool viewerIsPhotographer;

  final double opacity;
  final double widthFactor;

  /// Whether a photo in this state should carry the mark.
  ///
  /// Static and exhaustive so every surface asks the same question — the
  /// alternative is each screen inventing its own "is this paid for" test and
  /// one of them getting it wrong.
  static bool shouldMark({
    required double price,
    required bool isPurchased,
    bool viewerIsPhotographer = false,
  }) =>
      price > 0 && !isPurchased && !viewerIsPhotographer;

  @override
  Widget build(BuildContext context) {
    if (!shouldMark(
      price: price,
      isPurchased: isPurchased,
      viewerIsPhotographer: viewerIsPhotographer,
    )) {
      return child;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        // Ignores pointers so the photo underneath keeps every gesture it had
        // — tapping through to the viewer, pinching, swiping the carousel.
        Positioned.fill(
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final shortest = constraints.biggest.shortestSide;
                // Unbounded happens inside a FittedBox or an intrinsic pass;
                // there is no size to scale to, so draw nothing rather than
                // throw or guess.
                if (!shortest.isFinite || shortest <= 0) {
                  return const SizedBox.shrink();
                }
                return Center(
                  child: Opacity(
                    opacity: opacity,
                    child: SvgPicture.asset(
                      'assets/logo/jperg_icon_white.svg',
                      width: shortest * widthFactor,
                      // Vector, so it stays crisp from a 60px thumbnail to a
                      // full-screen viewer. A raster mark scaled up to a
                      // detail view is visibly soft at exactly the moment
                      // somebody is looking closely enough to decide to buy.
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

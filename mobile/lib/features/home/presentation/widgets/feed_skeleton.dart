import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:shimmer/shimmer.dart';

/// The feed, before the feed arrives.
///
/// What was here was a spinner in the middle of an empty screen — the app
/// saying it is busy, which the reader already knows, and saying nothing about
/// what is coming. A skeleton says the other thing: a post is coming, it will
/// fill the screen, the caption sits down here and the reactions run up the
/// right. By the time the photograph lands the eye is already in the right
/// place, so the arrival reads as the picture appearing rather than as one
/// screen being swapped for another.
///
/// **The geometry is copied from [FullBleedEventCard], not invented.** Every
/// inset here — the 16/88 caption box, the 12 dp rail, the 96 dp navigation
/// band, the 0.4 rail anchor — is the number the real card uses. A skeleton
/// whose blocks land somewhere other than the content replaces one jolt with
/// two, which is worse than the spinner it was brought in to replace.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});

  /// Matches `FullBleedEventCard._navBand`: the strip the floating navigation
  /// bar occupies along the bottom.
  static const double _navBand = 96;

  /// Matches `FullBleedEventCard._railAnchor`.
  static const Alignment _railAnchor = Alignment(0, 0.4);

  /// Slower than the package's default second. A sweep that hurries reads as
  /// impatience — this is a hold, and it should feel like one.
  static const Duration _period = Duration(milliseconds: 1600);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    // The feed is a dark island whatever the app theme is — a photograph is
    // what normally fills this, so the ground it waits on has to be the ground
    // the photograph will sit on, not the page behind it.
    final ground = dark ? const Color(0xFF191918) : const Color(0xFF232321);

    // The placeholder shapes, a clear step lighter than the ground.
    //
    // They were the same colour as it to begin with, which rendered a flat
    // rectangle: the caption and the rail were there, painted in the ground's
    // own tone, and invisible. A skeleton has to *show* the shapes or it is
    // just a dark screen with a sheen moving across it.
    final block = dark ? const Color(0xFF343431) : const Color(0xFF3E3E3A);
    final highlight = dark ? const Color(0xFF4A4A46) : const Color(0xFF55554F);

    return ColoredBox(
      // The photograph's ground, and deliberately *outside* the shimmer below.
      //
      // [Shimmer] paints its gradient over everything it wraps with a srcIn
      // blend, so every opaque pixel inside it becomes the same sweep. Wrapping
      // the whole screen therefore rendered one flat rectangle: the caption and
      // the rail were there, and indistinguishable from the ground they stood
      // on. Only the placeholder shapes go inside.
      color: ground,
      child: Stack(
        children: [
          // ── The caption block ───────────────────────────────────────────
          // Same box the real one gets: 16 in from the left, 88 from the right
          // so it clears the rail, and standing on the navigation band.
          Positioned(
            left: 16.w,
            right: 88.w,
            bottom: _navBand + 24.h,
            child: Shimmer.fromColors(
              baseColor: block,
              highlightColor: highlight,
              period: _period,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The event's name and who shot it — one line, wide.
                  _Block(width: 210.w, height: 15.h, color: block),
                  SizedBox(height: AppSpacing.sm.h),
                  // The caption, clamped to two lines on the real card. The
                  // second is short, the way a wrapped sentence ends.
                  _Block(width: double.infinity, height: 11.h, color: block),
                  SizedBox(height: 6.h),
                  _Block(width: 160.w, height: 11.h, color: block),
                ],
              ),
            ),
          ),

          // ── The reaction rail ───────────────────────────────────────────
          // Five actions down the right edge, each a disc with its count
          // beneath — anchored 0.4 down the card, as the real one is.
          Positioned(
            right: 12.w,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: _railAnchor,
              child: Shimmer.fromColors(
                baseColor: block,
                highlightColor: highlight,
                period: _period,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 5; i++) ...[
                      _Block(
                        width: 26.w,
                        height: 26.w,
                        color: block,
                        radius: 13.w,
                      ),
                      SizedBox(height: 5.h),
                      _Block(width: 18.w, height: 8.h, color: block),
                      if (i < 4) SizedBox(height: AppSpacing.lg.h),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One muted block of the skeleton.
///
/// Painted in the shimmer's own base colour: [Shimmer] sweeps a gradient
/// across whatever it is given, so the children only have to supply the shape.
class _Block extends StatelessWidget {
  const _Block({
    required this.width,
    required this.height,
    required this.color,
    this.radius,
  });

  final double width;
  final double height;
  final Color color;
  final double? radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius ?? 4.r),
        ),
      );
}

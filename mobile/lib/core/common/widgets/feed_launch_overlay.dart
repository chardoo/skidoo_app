import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

/// Branded launch overlay that plays once per app session.
///
/// Wraps any child widget. On the very first build it renders a full-screen
/// brand reveal on top of the child (which is already rendering with cached
/// feed data beneath it). After ~1.6 s the overlay lifts upward off screen,
/// exposing the populated feed with no blank-screen moment.
class FeedLaunchOverlay extends StatefulWidget {
  const FeedLaunchOverlay({super.key, required this.child});
  final Widget child;

  @override
  State<FeedLaunchOverlay> createState() => _FeedLaunchOverlayState();
}

class _FeedLaunchOverlayState extends State<FeedLaunchOverlay>
    with SingleTickerProviderStateMixin {
  // Ensure the animation fires at most once per process lifetime.
  static bool _done = false;

  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );

    if (_done) {
      _ctrl.value = 1.0;
    } else {
      _done = true;
      // Let the first frame (cached feed content) paint before the animation
      // starts so the reveal lands on real content, not a white screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            if (_ctrl.isCompleted) return const SizedBox.shrink();
            return _OverlaySheet(progress: _ctrl.value);
          },
        ),
      ],
    );
  }
}

// ── Animated overlay sheet ────────────────────────────────────────────────────

class _OverlaySheet extends StatelessWidget {
  const _OverlaySheet({required this.progress});

  /// 0.0 = overlay fully visible, 1.0 = overlay has lifted off screen.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final size = MediaQuery.sizeOf(context);

    // ── Shimmer sweeps left→right during [0, 0.55] ──────────────────────────
    final shimmerProgress = Curves.easeInOut
        .transform((progress / 0.55).clamp(0.0, 1.0));
    // pos goes from -0.4 (before text) → 1.4 (after text)
    final shimmerPos = -0.4 + shimmerProgress * 1.8;

    // ── Logo breathes in during [0, 0.28] ───────────────────────────────────
    final logoScale = Tween<double>(begin: 0.82, end: 1.0).transform(
      Curves.easeOut.transform((progress / 0.28).clamp(0.0, 1.0)),
    );

    // ── Tagline fades in during [0.15, 0.45] ────────────────────────────────
    final taglineOpacity =
        Curves.easeOut.transform(((progress - 0.15) / 0.30).clamp(0.0, 1.0));

    // ── Overlay lifts upward during [0.55, 1.0] ─────────────────────────────
    final liftProgress = Curves.easeInCubic
        .transform(((progress - 0.55) / 0.45).clamp(0.0, 1.0));
    final liftY = -size.height * liftProgress;

    // ── Overlay fades at the very end [0.88, 1.0] ───────────────────────────
    final overlayAlpha = 1.0 -
        Curves.easeOut
            .transform(((progress - 0.88) / 0.12).clamp(0.0, 1.0));

    return Opacity(
      opacity: overlayAlpha.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, liftY),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: DecoratedBox(
            decoration: BoxDecoration(color: ext.homeBackground),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── SKIIDO wordmark + smile ──────────────────────────────────
                Transform.scale(
                  scale: logoScale,
                  child: _ShimmerImage(
                    assetPath: 'assets/logo/skiido_wordmark.png',
                    shimmerPos: shimmerPos,
                    shimmerColor: ext.accentGold,
                    width: 260.w,
                  ),
                ),

                SizedBox(height: 14.h),

                // ── Tagline ──────────────────────────────────────────────────
                Opacity(
                  opacity: taglineOpacity,
                  child: Text(
                    'capture every moment',
                    style: TextStyle(
                      color: ext.searchHintColor.withValues(alpha: 0.65),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shimmer image — gold highlight sweeps over the wordmark PNG ──────────────

class _ShimmerImage extends StatelessWidget {
  const _ShimmerImage({
    required this.assetPath,
    required this.shimmerPos,
    required this.shimmerColor,
    required this.width,
  });

  final String assetPath;

  /// Ranges from -0.4 (before left edge) to 1.4 (after right edge).
  final double shimmerPos;
  final Color shimmerColor;
  final double width;

  @override
  Widget build(BuildContext context) {
    // Map shimmerPos → [0,1] for the gradient space.
    final p = ((shimmerPos + 0.4) / 1.8).clamp(0.0, 1.0);
    const half = 0.14;
    final s0 = (p - half).clamp(0.0, 1.0);
    final s2 = (p + half).clamp(0.0, 1.0);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Base image
        Image.asset(assetPath, width: width, fit: BoxFit.contain),
        // Gold shimmer beam — blended on top with softLight so the
        // image colours show through and the highlight feels organic.
        Positioned.fill(
          child: ShaderMask(
            blendMode: BlendMode.softLight,
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Colors.transparent,
                Colors.transparent,
                shimmerColor.withValues(alpha: 0.85),
                Colors.transparent,
                Colors.transparent,
              ],
              stops: [0.0, s0, p, s2, 1.0],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds),
            child: const DecoratedBox(
              decoration: BoxDecoration(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

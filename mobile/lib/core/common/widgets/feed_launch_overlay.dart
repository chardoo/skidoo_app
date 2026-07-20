import 'package:flutter/material.dart';

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
    final size = MediaQuery.sizeOf(context);

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
          // Same full-bleed gif treatment as SplashPage, so the two
          // branded moments (cold-start splash, then this feed reveal)
          // match instead of showing two different animations back to back.
          child: Image.asset(
            'assets/splash/splash.gif',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

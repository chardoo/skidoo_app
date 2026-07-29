import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The "swipe up for more" nudge shown once, over the first card of the feed.
///
/// The feed is a vertical [PageView] with no scrollbar and no partially-visible
/// next card, so nothing on screen says the content continues — a first-time
/// visitor can read the first event as the whole app. This is the affordance
/// from the guest designs: a pair of chevrons rising and fading at the bottom
/// of the card.
///
/// Two chevrons rather than one, offset in time: a single mark can read as a
/// static icon, whereas the trailing chevron makes the direction unambiguous
/// at a glance.
///
/// It is deliberately passive — [IgnorePointer] means it never intercepts the
/// swipe it is asking for, and the caller dismisses it on the first page
/// change.
class SwipeUpHint extends StatefulWidget {
  const SwipeUpHint({super.key, this.label = 'Swipe up for more'});

  /// Set to an empty string for chevrons alone, as the design shows them over
  /// a busy photo where the extra text would compete.
  final String label;

  @override
  State<SwipeUpHint> createState() => _SwipeUpHintState();
}

class _SwipeUpHintState extends State<SwipeUpHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  @override
  void initState() {
    super.initState();
    // Started in didChangeDependencies — MediaQuery isn't available here, and
    // looping forever would defeat the OS's reduce-motion setting.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_reduceMotion) _ctrl.repeat();
    });
  }

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Announced once as a hint rather than as a live region: it's guidance,
    // not a status change, and screen-reader users navigate the feed by
    // element rather than by swipe.
    return IgnorePointer(
      child: Semantics(
        label: widget.label.isEmpty ? 'Swipe up for more' : widget.label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 34.h,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _Chevron(ctrl: _ctrl, delay: 0.0, still: _reduceMotion),
                  _Chevron(ctrl: _ctrl, delay: 0.18, still: _reduceMotion),
                ],
              ),
            ),
            if (widget.label.isNotEmpty) ...[
              SizedBox(height: 2.h),
              Text(
                widget.label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                  shadows: const [
                    Shadow(blurRadius: 8, color: Colors.black54),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One chevron of the pair: rises ~10dp while fading out, then restarts.
class _Chevron extends StatelessWidget {
  const _Chevron({
    required this.ctrl,
    required this.delay,
    required this.still,
  });

  final AnimationController ctrl;

  /// Fraction of the cycle this chevron trails the first one by.
  final double delay;

  /// Reduce-motion: both chevrons hold their resting position, stacked, so the
  /// direction still reads without anything moving.
  final bool still;

  @override
  Widget build(BuildContext context) {
    if (still) {
      return Padding(
        padding: EdgeInsets.only(bottom: delay > 0 ? 0 : 10.h),
        child: _mark(delay > 0 ? 0.45 : 0.9),
      );
    }

    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        // Each chevron runs the same 0→1 ramp, offset by `delay`; the modulo
        // makes the trailing one wrap around rather than clamp at the end.
        final t = (ctrl.value + delay) % 1.0;
        // Ease-out on the rise so it decelerates as it fades, which reads as a
        // gesture completing rather than a marquee looping.
        final eased = Curves.easeOut.transform(t);
        // Fade in over the first fifth, hold, then fade out — a chevron that
        // simply appeared at full opacity would flicker on each repeat.
        final opacity = t < 0.2
            ? t / 0.2
            : (1.0 - ((t - 0.2) / 0.8)).clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(0, (1 - eased) * 10.h),
          child: _mark(opacity * 0.9),
        );
      },
    );
  }

  Widget _mark(double opacity) => Icon(
        Icons.keyboard_arrow_up_rounded,
        size: 30.sp,
        color: Colors.white.withValues(alpha: opacity),
        // The feed is full-bleed photography; without a shadow the mark
        // disappears entirely over a light image.
        shadows: const [Shadow(blurRadius: 10, color: Colors.black87)],
      );
}

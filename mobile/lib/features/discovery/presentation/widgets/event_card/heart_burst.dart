import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Double-tap-to-like heart animation — scales up then fades out, driven by
/// an externally-owned [AnimationController] so the parent card controls
/// when it plays.
class HeartBurst extends StatelessWidget {
  const HeartBurst({super.key, required this.ctrl});
  final AnimationController ctrl;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = ctrl.value;
        // Scale: 0→1.4 in first half, 1.4→1.2 in second half
        final scale = t < 0.4 ? (t / 0.4) * 1.4 : 1.4 - ((t - 0.4) / 0.6) * 0.2;
        // Opacity: full until 0.6, then fade out
        final opacity = t < 0.6 ? 1.0 : 1.0 - ((t - 0.6) / 0.4);

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale.clamp(0.0, 2.0),
            child: Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 90.sp,
              shadows: const [
                Shadow(blurRadius: 20, color: Colors.black54),
              ],
            ),
          ),
        );
      },
    );
  }
}

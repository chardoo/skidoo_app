import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The heart that bursts over a photo somebody just double-tapped.
///
/// Driven by an externally-owned [AnimationController] so the card decides
/// when it plays and can re-play it on a second double-tap.
///
/// ## The shape of it
///
/// Three things happen at once and the timing between them is the effect:
///
/// * **Scale** springs past its resting size and comes back — up to about
///   1.25 by 120 ms, settled by 300. (The first tween names 1.15 and
///   `easeOutBack` carries it past that; the peak is the curve's, not the
///   number's.) The overshoot is what reads as a *pop*. This used to be a
///   straight line from 0 to 1.4 and then a slow drift down to 1.2, which
///   arrives at the size it wants and keeps going: a zoom rather than a snap.
/// * **Opacity** is full almost immediately and holds, then goes quickly.
///   A heart that fades *in* is a heart you notice after it has already
///   happened.
/// * **It leaves early.** The whole thing is 600 ms with the last 180 spent
///   fading. Anything longer and it is still on screen while the thumb is
///   moving to the next post, which reads as something stuck rather than
///   something acknowledged.
///
/// Drawn white with a shadow rather than in the accent green: it sits on a
/// photograph whose colours are unknown, and white with a drop shadow is the
/// one treatment that holds on all of them. The rail's heart, on a known
/// surface, is the one that takes the brand colour.
class HeartBurst extends StatelessWidget {
  const HeartBurst({super.key, required this.ctrl});

  final AnimationController ctrl;

  /// How long [ctrl] should run for. The curves below are laid out against
  /// this, so a controller driving it with a different duration will play the
  /// same shape faster or slower rather than a different shape.
  static const Duration duration = Duration(milliseconds: 600);

  static final Animatable<double> _scale = TweenSequence<double>([
    // In, past the target.
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 1.15)
          .chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 28,
    ),
    // Back to it, and hold there while the eye catches up.
    TweenSequenceItem(
      tween: Tween(begin: 1.15, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 17,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 25),
    // And a last drift out as it goes, so the fade has movement under it.
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.25)
          .chain(CurveTween(curve: Curves.easeIn)),
      weight: 30,
    ),
  ]);

  static final Animatable<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.0)
          .chain(CurveTween(curve: Curves.easeIn)),
      weight: 30,
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: ctrl,
        builder: (_, child) => Opacity(
          opacity: _opacity.evaluate(ctrl).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: _scale.evaluate(ctrl),
            child: child,
          ),
        ),
        // Built once and scaled, rather than rebuilt every frame: the glyph
        // does not change, only its transform.
        child: Icon(
          Icons.favorite_rounded,
          color: Colors.white,
          size: 110.sp,
          shadows: const [
            Shadow(color: Color(0x73000000), blurRadius: 24),
          ],
        ),
      ),
    );
  }
}

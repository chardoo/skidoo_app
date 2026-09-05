import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Confetti and a line of text, for the moment somebody's comment lands on a
/// round number.
///
/// Hand-rolled rather than a package. What this needs is forty coloured
/// rectangles falling for two seconds; the confetti packages on pub bring a
/// physics model, a controller lifecycle and a dependency to keep current, and
/// the app would use one screen of what they offer. The whole effect is one
/// [CustomPainter] driven by one [AnimationController].
///
/// It is drawn in an [OverlayEntry] so it floats above the comment sheet rather
/// than inside its scroll view — a celebration that scrolls away with the list
/// is a celebration nobody sees.
///
/// Nothing here is interactive: the overlay ignores pointers throughout, so a
/// reader who wants to keep typing while it plays is never blocked by it.
class CelebrationOverlay {
  const CelebrationOverlay._();

  static const Duration _duration = Duration(milliseconds: 2600);

  /// Plays [message] over whatever [context] is inside.
  ///
  /// Safe to call when nothing is mounted — a comment can be posted and the
  /// sheet dismissed in the same breath, and that must not throw on the way to
  /// a piece of decoration.
  static void show(BuildContext context, String message) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Celebration(
        message: message,
        duration: _duration,
        onDone: () {
          // Guarded: the overlay may already be gone if the route was popped
          // while this was playing.
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _Celebration extends StatefulWidget {
  const _Celebration({
    required this.message,
    required this.duration,
    required this.onDone,
  });

  final String message;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final List<_Fleck> _flecks;

  @override
  void initState() {
    super.initState();
    // Seeded from the clock rather than fixed, so two milestones in a row do
    // not fall in identical paths.
    _flecks = _Fleck.scatter(math.Random());
    _controller
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ConfettiPainter(flecks: _flecks, progress: t),
                  ),
                ),
                Positioned(
                  top: safeTop + 12.h,
                  left: 16.w,
                  right: 16.w,
                  child: _Banner(message: widget.message, progress: t),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The card the message sits in — in and out under its own curve, so it is
/// readable for most of the time the confetti is falling.
class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.progress});

  final String message;
  final double progress;

  @override
  Widget build(BuildContext context) {
    // Up quickly, hold, then away. The hold is the part that matters: a banner
    // that fades the moment it arrives is a flicker, not a message.
    const inEnd = 0.16;
    const outStart = 0.80;
    final double opacity;
    if (progress < inEnd) {
      opacity = Curves.easeOut.transform(progress / inEnd);
    } else if (progress > outStart) {
      opacity =
          1 - Curves.easeIn.transform((progress - outStart) / (1 - outStart));
    } else {
      opacity = 1;
    }

    // Drops in past its resting place and settles back, rather than sliding to
    // a stop. [Curves.easeOutBack] overshoots by design, which is what gives it
    // weight — a banner that decelerates smoothly to zero reads as a panel
    // being positioned, not as something arriving.
    final entry = Curves.easeOutBack.transform(
      math.min(1.0, progress / inEnd).clamp(0.0, 1.0),
    );
    final slide = (1 - entry) * -28;
    // The same curve on the scale, so it grows into place as it falls. Starting
    // at 0.94 rather than something smaller keeps the text legible throughout —
    // the message has to be readable for every frame it is on screen.
    final scale = 0.94 + 0.06 * entry;

    // On its way out it lifts slightly, the reverse of how it came in.
    final exit = progress > outStart
        ? Curves.easeIn.transform((progress - outStart) / (1 - outStart))
        : 0.0;

    return Opacity(
      opacity: opacity.clamp(0, 1),
      child: Transform.translate(
        offset: Offset(0, slide - exit * 10),
        child: Transform.scale(
          scale: scale,
          child: Semantics(
            liveRegion: true,
            label: message,
            // A [Material], not a decorated [Container].
            //
            // This is inserted into an Overlay, which has no Material ancestor
            // of its own. Text with no Material above it falls back to
            // Flutter's unstyled default — and that default is drawn with a
            // double yellow underline, on purpose, to make exactly this mistake
            // visible. It was doing its job: the banner shipped with a yellow
            // line struck under the message.
            child: Material(
              color: Colors.white,
              elevation: 10,
              shadowColor: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16.r),
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF14171A),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    // Belt and braces. The Material above already supplies a
                    // sane default; saying it here means the banner cannot
                    // regress into that yellow underline if it is ever moved
                    // somewhere without one.
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One piece of paper: where it starts, where it drifts, how fast it spins.
@immutable
class _Fleck {
  const _Fleck({
    required this.x,
    required this.drift,
    required this.delay,
    required this.fall,
    required this.spin,
    required this.tumble,
    required this.width,
    required this.height,
    required this.color,
  });

  /// Fraction of the width it starts at.
  final double x;

  /// Fraction of the width it wanders sideways over its life.
  final double drift;

  /// Fraction of the animation before it starts falling — the stagger that
  /// stops forty rectangles arriving as one line.
  final double delay;

  /// Fraction of the height it covers, past 1 so it leaves the screen.
  final double fall;
  final double spin;

  /// How fast it turns edge-on and back — the flip that makes a falling
  /// rectangle read as a piece of paper rather than a sliding tile. Separate
  /// from [spin], which turns it in the plane of the screen; this one turns it
  /// *through* the screen, and the two together are what stops forty rectangles
  /// looking like forty rectangles.
  final double tumble;

  final double width;
  final double height;
  final Color color;

  /// The palette is not the app's: confetti that matches the brand reads as
  /// part of the interface rather than as something thrown in the air.
  static const _colors = [
    Color(0xFFE84D68),
    Color(0xFFF2C14E),
    Color(0xFF4DA1E8),
    Color(0xFF3FBF7F),
    Color(0xFFB06BE8),
    Color(0xFFFFFFFF),
  ];

  static List<_Fleck> scatter(math.Random random, {int count = 56}) {
    return List.generate(count, (i) {
      return _Fleck(
        x: random.nextDouble(),
        // Wider wander than a straight drop. Paper does not fall in a line.
        drift: (random.nextDouble() - 0.5) * 0.5,
        // A longer stagger, so the fall keeps arriving instead of coming as
        // one wave and leaving the rest of the animation empty.
        delay: random.nextDouble() * 0.45,
        fall: 1.1 + random.nextDouble() * 0.4,
        spin: (random.nextDouble() - 0.5) * 10,
        tumble: 5 + random.nextDouble() * 9,
        width: 5 + random.nextDouble() * 7,
        height: 8 + random.nextDouble() * 10,
        color: _colors[i % _colors.length],
      );
    });
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.flecks, required this.progress});

  final List<_Fleck> flecks;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (final fleck in flecks) {
      // Each one runs its own clock, started late by its delay and finishing
      // with the whole.
      final span = 1 - fleck.delay;
      final local = (progress - fleck.delay) / span;
      if (local <= 0) continue;

      final t = local.clamp(0.0, 1.0);
      // Gravity, roughly: falls slowly at first and gathers pace.
      final fallen = t * t * 0.6 + t * 0.4;

      // Two sine waves rather than one, at different rates, so the sideways
      // wander does not settle into a single visible arc repeated forty times.
      final sway = math.sin(t * math.pi) * 0.7 + math.sin(t * math.pi * 2.7) * 0.3;
      final dx = (fleck.x + fleck.drift * sway) * size.width;
      final dy = fallen * fleck.fall * size.height - fleck.height;

      // Fades over the last third rather than vanishing at the bottom edge,
      // which reads as the animation being cut off.
      paint.color = fleck.color.withValues(
        alpha: t > 0.66 ? (1 - (t - 0.66) / 0.34).clamp(0.0, 1.0) : 1.0,
      );

      // The flip. Scaling the width by a cosine turns the rectangle edge-on and
      // back as it falls, which is what a scrap of paper actually does — and it
      // costs one multiply, where a real 3D transform would cost a matrix per
      // fleck per frame. `abs` because a negative width would mirror it rather
      // than continue the turn, and at these sizes the difference is invisible.
      final flip = math.cos(fleck.tumble * t).abs().clamp(0.12, 1.0);

      canvas
        ..save()
        ..translate(dx, dy)
        ..rotate(fleck.spin * t)
        ..drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: fleck.width * flip,
            height: fleck.height,
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

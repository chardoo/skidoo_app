import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The globe that turns while an event's photos are being searched for a face.
///
/// Meridians drawn as ellipses whose width oscillates, which is what a
/// rotating wireframe sphere looks like in two dimensions — cheaper and
/// steadier than rotating real geometry, and it never needs an asset. The
/// filled lens in the middle is the meridian nearest the viewer.
///
/// Deliberately a painter rather than a Lottie or a GIF: it has to sit over
/// the app background in either theme, and it is on screen for a couple of
/// seconds at most.
class FoundScanningOrb extends StatefulWidget {
  const FoundScanningOrb({
    super.key,
    required this.color,
    this.size = 260,
  });

  final Color color;
  final double size;

  @override
  State<FoundScanningOrb> createState() => _FoundScanningOrbState();
}

class _FoundScanningOrbState extends State<FoundScanningOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (_, __) => CustomPaint(
          painter: _OrbPainter(phase: _spin.value, color: widget.color),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  const _OrbPainter({required this.phase, required this.color});

  /// 0..1, one full turn.
  final double phase;
  final Color color;

  static const _meridians = 5;

  /// Where the drifting specks sit, as (meridian fraction, latitude). Fixed
  /// rather than random so the animation is identical every time it runs —
  /// a loading state that differs run to run reads as a glitch.
  static const _motes = <(double, double)>[
    (0.15, -0.55),
    (0.62, -0.18),
    (0.35, 0.30),
    (0.88, 0.52),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final turn = phase * 2 * math.pi;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: 0.55);

    // The sphere's silhouette.
    canvas.drawCircle(centre, radius, stroke);

    for (var i = 0; i < _meridians; i++) {
      // Each meridian is a quarter-turn further round than the last.
      final angle = turn + (i * math.pi / _meridians);
      // cos gives the ellipse's apparent width: 1 edge-on becomes 0 when the
      // meridian is facing the viewer flat-on.
      final squash = math.cos(angle);
      final rect = Rect.fromCenter(
        center: centre,
        width: (radius * 2 * squash).abs(),
        height: radius * 2,
      );

      // The one nearest the viewer is filled, which is what gives the shape
      // its sense of depth rather than reading as flat rings.
      if (squash.abs() > 0.86) {
        canvas.drawOval(
          rect,
          Paint()
            ..style = PaintingStyle.fill
            ..color = color.withValues(alpha: 0.12),
        );
      }
      canvas.drawOval(rect, stroke);
    }

    // Specks travelling the meridians.
    for (final (offset, latitude) in _motes) {
      final angle = turn + (offset * 2 * math.pi);
      final x = centre.dx +
          radius * math.cos(angle) * math.sqrt(1 - latitude * latitude);
      final y = centre.dy + radius * latitude;
      // Behind the sphere: dimmer, so they read as going round rather than
      // sliding across.
      final front = math.cos(angle) > 0;
      canvas.drawCircle(
        Offset(x, y),
        front ? 3.0 : 2.0,
        Paint()..color = color.withValues(alpha: front ? 0.9 : 0.35),
      );
    }

    // The lens at the centre.
    canvas.drawCircle(
      centre,
      radius * 0.22,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.phase != phase || old.color != color;
}

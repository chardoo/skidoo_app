import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// One button in an action rail over media: an icon with its count underneath,
/// both shadowed so they stay legible on any photo, and a press-scale so the
/// tap has some weight to it.
///
/// The single button primitive for every reaction surface drawn over media —
/// the home feed's full-bleed card, the Found tab's photo viewer, and the
/// gallery viewer's bottom bar. Assemble a rail out of [MediaReactionRail]
/// rather than reaching for this directly: the rail owns which glyph a
/// reaction uses and what it looks like once active, which is the part that
/// used to drift between screens.
class MediaRailAction extends StatefulWidget {
  const MediaRailAction({
    super.key,
    required this.icon,
    this.iconColor = Colors.white,
    this.label,
    required this.onTap,
    this.busy = false,
    this.semanticLabel,
    this.iconSize,
    this.tapTargetSize,
  });

  final IconData icon;
  final Color iconColor;

  /// Count shown under the icon. Null renders the icon alone — used where
  /// there is genuinely no count rather than showing a hardcoded zero.
  final String? label;

  final VoidCallback onTap;

  /// Shows a small spinner in place of the icon while an async action (e.g.
  /// the external share round trip) is in flight.
  final bool busy;

  final String? semanticLabel;

  /// Glyph size. Defaults to the rail's 28sp.
  final double? iconSize;

  /// Pads the glyph out to a fixed square so a row of these keeps a finger-
  /// sized tap target even where the icons themselves are small. Null leaves
  /// the target the size of the glyph, which is what a vertical rail wants.
  final double? tapTargetSize;

  @override
  State<MediaRailAction> createState() => _MediaRailActionState();
}

class _MediaRailActionState extends State<MediaRailAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    lowerBound: 0.85,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.iconSize ?? 28.sp;
    final glyph = widget.busy
        ? SizedBox(
            width: size * 0.8,
            height: size * 0.8,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: widget.iconColor),
          )
        : Icon(widget.icon, color: widget.iconColor, size: size, shadows: const [
            Shadow(color: Colors.black45, blurRadius: 4),
          ]);

    return Semantics(
      button: true,
      label: widget.semanticLabel ?? widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.busy ? null : (_) => _ctrl.reverse(),
        onTapUp: widget.busy
            ? null
            : (_) {
                _ctrl.forward();
                widget.onTap();
              },
        onTapCancel: () => _ctrl.forward(),
        child: ScaleTransition(
          scale: _ctrl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.tapTargetSize != null)
                SizedBox(
                  width: widget.tapTargetSize,
                  height: widget.tapTargetSize,
                  child: Center(child: glyph),
                )
              else
                glyph,
              if (widget.label != null) ...[
                SizedBox(height: 3.h),
                Text(
                  widget.label!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    shadows: const [
                      Shadow(color: Colors.black45, blurRadius: 4)
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

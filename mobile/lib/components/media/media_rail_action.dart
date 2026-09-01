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
    this.enabled = true,
    this.labelColor,
    this.semanticLabel,
    this.iconSize,
    this.tapTargetSize,
  });

  final IconData icon;
  final Color iconColor;

  /// Count shown under the icon. Null renders the icon alone — used where
  /// there is genuinely no count rather than showing a hardcoded zero.
  final String? label;

  /// Colour of that count. Defaults to white, which is what every live action
  /// wants over media. An action drawn as unavailable passes its own so the
  /// count dims along with the glyph rather than staying bright above it.
  final Color? labelColor;

  /// False draws the action but takes the interaction away: no press-scale,
  /// and the tap does nothing at all. It still occupies its place in the rail
  /// and still absorbs the tap, so a press near it doesn't fall through to
  /// whatever is behind — an unavailable action is stated, not hidden.
  final bool enabled;

  final VoidCallback onTap;

  /// Shows a small spinner in place of the icon while an async action (e.g.
  /// the external share round trip) is in flight.
  final bool busy;

  final String? semanticLabel;

  /// Glyph size, before rounding. Defaults to 24 — see [_MediaRailActionState].
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

  /// A tight drop shadow, offset, rather than a halo.
  ///
  /// This used to be a 4 px blur at 45 % black with no offset: a blurred copy
  /// of the glyph in every direction at once, which thickens the stroke and
  /// reads as an icon slightly out of focus. A shadow that falls *somewhere*
  /// is what every native rail uses — one pixel down and two of blur separates
  /// a white glyph from a bright photo without softening its edges.
  static const _shadows = [
    Shadow(color: Color(0x99000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// The glyph, at a whole number of logical pixels.
  ///
  /// Rounded deliberately. `.sp` lands on a fraction for most devices — 24 sp
  /// is 26.46 on a 430 pt phone — and an icon font rasterised at a fractional
  /// size sits between the pixel grid and comes out soft. Rounding is the
  /// difference between a crisp glyph and a faintly smeared one, and costs at
  /// most half a pixel of size.
  ///
  /// 24 rather than the 28 it was: the rail sits over somebody's photograph,
  /// and at 28 the five glyphs were the loudest thing on the screen.
  double get _size => (widget.iconSize ?? 24.sp).roundToDouble();

  @override
  Widget build(BuildContext context) {
    final size = _size;
    final glyph = widget.busy
        ? SizedBox(
            width: size * 0.8,
            height: size * 0.8,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: widget.iconColor),
          )
        : Icon(widget.icon,
            color: widget.iconColor, size: size, shadows: _shadows);

    final inert = widget.busy || !widget.enabled;

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel ?? widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: inert ? null : (_) => _ctrl.reverse(),
        onTapUp: inert
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
                    color: widget.labelColor ?? Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    // Same treatment as the glyph above it, so the pair reads
                    // as one control rather than a sharp number under a soft
                    // icon.
                    shadows: _shadows,
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

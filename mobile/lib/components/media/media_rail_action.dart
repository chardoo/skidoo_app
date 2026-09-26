import 'package:flutter/material.dart';
import 'package:jperg_app/core/theme/app_icons.dart';
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
    this.assetIcon,
    this.tapTargetSize,
    this.active = false,
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

  /// A supplied glyph to draw instead of [icon].
  ///
  /// Design's own engagement set — see [EngagementIcons]. The icon-font glyph
  /// is still required and is what an *active* reaction falls back to, since
  /// the supplied set has rest states only.
  final String? assetIcon;

  /// Pads the glyph out to a fixed square so a row of these keeps a finger-
  /// sized tap target even where the icons themselves are small. Null leaves
  /// the target the size of the glyph, which is what a vertical rail wants.
  final double? tapTargetSize;

  /// Whether the reaction is on — liked, saved.
  ///
  /// Drives the pop: the glyph overshoots and settles the moment this turns
  /// true. Not a style flag — the caller already colours and fills the glyph
  /// itself — but the *transition*, which is the part a tap needs
  /// acknowledging. Without it a like was a silent colour swap on a glyph
  /// under the thumb that had just hidden it.
  final bool active;

  @override
  State<MediaRailAction> createState() => _MediaRailActionState();
}

class _MediaRailActionState extends State<MediaRailAction>
    with TickerProviderStateMixin {
  /// The press: a small dip under the finger, released on tap-up. Says the
  /// touch landed, and says nothing about what it did.
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    lowerBound: 0.85,
    upperBound: 1.0,
    value: 1.0,
  );

  /// The pop: what the reaction turning on looks like.
  ///
  /// A separate controller from the press because they are separate events and
  /// they overlap — the finger is still down, holding the dip, when the state
  /// flips. Driving both from one value made the pop start from wherever the
  /// press happened to be and land wrong.
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  /// Overshoot and settle, rather than a swell.
  ///
  /// 1 → ~1.38 → 1: up in about 120 ms, settled by 320. (The tween names
  /// 1.35 and `easeOutBack` carries it a little past; the peak is the curve's,
  /// not the number's.) That overshoot is the whole effect — a scale that only
  /// approaches its target reads as a slow zoom, and at this duration as
  /// nothing much at all.
  late final Animation<double> _popScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.35)
          .chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 45,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.35, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 55,
    ),
  ]).animate(_pop);

  @override
  void didUpdateWidget(MediaRailAction old) {
    super.didUpdateWidget(old);
    // On the way in only. Turning a reaction *off* is not an achievement and
    // a heart that pops as it empties reads as a second like.
    if (widget.active && !old.active) {
      _pop
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _pop.dispose();
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
        : widget.assetIcon != null
            ? AppSvgIcon(
                widget.assetIcon!,
                size: size,
                color: widget.iconColor,
                shadows: _shadows,
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
        onTapDown: inert ? null : (_) => _press.reverse(),
        onTapUp: inert
            ? null
            : (_) {
                _press.forward();
                widget.onTap();
              },
        onTapCancel: () => _press.forward(),
        // Two scales, multiplied by nesting: the press dip belongs to the
        // whole control, the pop to the glyph alone — a count that leapt
        // 35% and back would pull the eye off the thing that changed.
        child: ScaleTransition(
          scale: _press,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.tapTargetSize != null)
                SizedBox(
                  width: widget.tapTargetSize,
                  height: widget.tapTargetSize,
                  child: Center(
                      child: ScaleTransition(scale: _popScale, child: glyph)),
                )
              else
                ScaleTransition(scale: _popScale, child: glyph),
              if (widget.label != null) ...[
                SizedBox(height: 3.h),
                Text(
                  widget.label!,
                  style: TextStyle(
                    color: widget.labelColor ?? Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
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

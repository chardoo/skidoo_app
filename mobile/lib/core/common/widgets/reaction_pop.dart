import 'package:flutter/material.dart';
import 'package:jperg_app/core/common/reaction_feedback.dart';

/// The pop a reaction makes when it turns on, and the tap and click that go
/// with it.
///
/// Wrap the glyph that changes — the heart, the bookmark — and hand it the
/// reaction's own state:
///
/// ```dart
/// ReactionPop(active: liked, child: Icon(liked ? filled : outline))
/// ```
///
/// Every heart in the app goes through this: the feed rail's
/// ([MediaRailAction]), the event card's bar ([CardInteractionBar]) and a
/// comment row's. They each used to answer a tap differently — the rail popped,
/// the bar only dipped under the finger, and a comment's heart just changed
/// colour — which is the drift this exists to stop.
///
/// ## The shape of it
///
/// 1 → 1.8 → 0.94 → 1: up hard in about 110 ms, back down *past* resting size
/// by 250, settled by 340.
///
/// Two things make this read as a pop rather than a zoom, and the first one
/// alone was not enough:
///
/// * **It overshoots on the way up.** Obvious, and what the first version did.
/// * **It undershoots on the way back.** The glyph passes resting size, dips
///   a little under, and comes back. That is the squash after the stretch, and
///   it is what the eye reads as something having *landed*. Without it the
///   curve is symmetrical — the glyph swells and un-swells, which at any peak
///   looks like a zoom. A 1.35 peak and then a 1.55 peak were both reported as
///   not popping, and the number was never the problem.
///
/// Measured end to end, as the net scale arriving at the glyph, in
/// `test/widgets/like_pop_visibility_test.dart` — because a pop can be
/// cancelled by something else scaling the same glyph the other way, which is
/// exactly what the bar's `AnimatedSwitcher` was doing to it.
///
/// ## On the way in only
///
/// Turning a reaction off does not pop. A heart that pops as it empties reads
/// as a second like, and the gesture it is answering is an undo.
///
/// ## Scaling, not rebuilding
///
/// [child] is built once and transformed. The glyph itself is swapped by
/// whoever owns it — this widget knows only that a reaction changed, which is
/// why it takes [active] rather than two icons.
class ReactionPop extends StatefulWidget {
  const ReactionPop({
    super.key,
    required this.active,
    required this.child,
    this.feedback = true,
  });

  /// Whether the reaction is on. The pop plays when this turns true.
  final bool active;

  final Widget child;

  /// Whether the transition also taps and clicks — see [ReactionFeedback].
  ///
  /// False draws the pop silently. For a surface that fires its own feedback,
  /// or one where the state can change without the viewer having touched
  /// anything.
  final bool feedback;

  /// How long the whole thing takes. The curves are laid out against this, so
  /// a different duration plays the same shape faster or slower rather than a
  /// different shape.
  static const Duration duration = Duration(milliseconds: 340);

  /// How big the glyph gets at the top of the pop.
  ///
  /// 1.8 on the rail's 24 px heart is about 9 px of travel, against the 3 px
  /// that 1.35 bought. Wrap the glyph alone and never its count: at this size
  /// a number scaling with it is both distracting and wide enough to collide
  /// with whatever sits next to it.
  static const double peak = 1.8;

  /// How far under resting size it settles back through — the squash that
  /// makes the stretch read. Small on purpose: this should be felt, not seen
  /// as a second animation.
  static const double undershoot = 0.94;

  @override
  State<ReactionPop> createState() => _ReactionPopState();
}

class _ReactionPopState extends State<ReactionPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: ReactionPop.duration,
  );

  late final Animation<double> _scale = TweenSequence<double>([
    // Up, hard. `easeOutCubic` spends its speed at the start, so the glyph is
    // most of the way there in the first few frames — that initial velocity is
    // what the eye catches.
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: ReactionPop.peak)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 32,
    ),
    // Down through resting size, to just under it.
    TweenSequenceItem(
      tween: Tween(begin: ReactionPop.peak, end: ReactionPop.undershoot)
          .chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 40,
    ),
    // And back up to rest. The squash resolving is the end of the gesture.
    TweenSequenceItem(
      tween: Tween(begin: ReactionPop.undershoot, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 28,
    ),
  ]).animate(_ctrl);

  @override
  void didUpdateWidget(ReactionPop old) {
    super.didUpdateWidget(old);
    if (widget.active == old.active) return;

    if (widget.active) {
      // reset() first: a second like landing before the first has settled
      // should start over, not continue from halfway up.
      _ctrl
        ..reset()
        ..forward();
      if (widget.feedback) ReactionFeedback.turnedOn();
    } else if (widget.feedback) {
      ReactionFeedback.turnedOff();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

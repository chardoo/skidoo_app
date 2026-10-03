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
/// 1 → ~1.55 → 1, up in about 150 ms and settled by 340. The tween names
/// [peak] and `easeOutBack` carries it a little past; the peak is the curve's,
/// not the number's.
///
/// The overshoot is the entire effect. A scale that merely *approaches* its
/// target reads as a slow zoom, and at this duration as nothing much at all —
/// which is what the bar's heart did when all it had was a press dip to 0.85:
/// the glyph got smaller under a thumb that was already covering it, and by the
/// time the thumb lifted everything was over.
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

  /// The size the glyph aims for on the way up, before `easeOutBack` carries it
  /// past. Raised from the 1.35 the rail used alone: at 1.35 on a 24 px glyph
  /// the pop was about three pixels of travel, which is not enough to see on a
  /// screen the thumb is still moving across.
  static const double peak = 1.5;

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
    // Up, past the target.
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: ReactionPop.peak)
          .chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 45,
    ),
    // And back down to it, settling rather than snapping.
    TweenSequenceItem(
      tween: Tween(begin: ReactionPop.peak, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 55,
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

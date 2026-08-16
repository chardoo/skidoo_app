import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// App-wide motion language.
///
/// Inspired by the restrained, premium feel of apple.com / bibellogik.de:
/// content eases in with a soft fade + short upward slide, items stagger
/// subtly, and page transitions glide rather than snap. Works on every
/// platform (mobile + web) and honours the OS "reduce motion" setting.
class AppMotion {
  AppMotion._();

  /// Soft decelerate — the signature "ease-out" used for almost everything.
  static const Curve ease = Cubic(0.22, 1, 0.36, 1); // easeOutQuint-ish
  static const Curve easeInOut = Cubic(0.65, 0, 0.35, 1);

  static const Duration fast = Duration(milliseconds: 260);
  static const Duration medium = Duration(milliseconds: 420);
  static const Duration slow = Duration(milliseconds: 620);

  /// Per-item delay used when staggering a list/column of [Reveal]s.
  static const Duration stagger = Duration(milliseconds: 70);
}

/// Fades + slides its [child] in once, the first time it is built.
///
/// Drop it around any widget to give it a premium entrance. Use [delay] (or
/// [RevealStagger]) to cascade a group. Respects `MediaQuery.disableAnimations`
/// (OS reduce-motion / accessibility) by showing the final state immediately.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.medium,
    this.offset = const Offset(0, 24),
    this.curve = AppMotion.ease,
    this.scaleFrom = 1.0,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Starting translation (logical px) the child slides in from. Default is a
  /// 24px upward slide (it starts 24px below its resting place).
  final Offset offset;
  final Curve curve;

  /// Optional starting scale (e.g. 0.98 for a faint "lift"). 1.0 disables it.
  final double scaleFrom;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: widget.curve);

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Honour OS reduce-motion: skip straight to the resting state.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _c.value = 1.0;
      return;
    }
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        final v = _t.value;
        final dx = widget.offset.dx * (1 - v);
        final dy = widget.offset.dy * (1 - v);
        final scale = widget.scaleFrom + (1.0 - widget.scaleFrom) * v;
        Widget out = Opacity(opacity: v.clamp(0.0, 1.0), child: child);
        if (widget.scaleFrom != 1.0) {
          out = Transform.scale(scale: scale, child: out);
        }
        return Transform.translate(offset: Offset(dx, dy), child: out);
      },
      child: widget.child,
    );
  }
}

/// The page transition on touch platforms: the incoming page slides in from
/// the trailing edge, and can be dragged back off from the leading edge.
///
/// This is Flutter's Cupertino transition, installed for Android as well as
/// iOS, and that is the whole point of the class. The interactive back gesture
/// lives *inside* [CupertinoPageTransitionsBuilder] — not inside the route —
/// so the app's previous setup, which gave every platform the fade-and-lift
/// [AppFadePageTransitionsBuilder], silently removed swipe-back from every
/// `MaterialPageRoute` in the app. The only screens that could be swiped back
/// were the handful pushed with an explicit `CupertinoPageRoute` — chat rooms,
/// mostly — which build their own transition and bypass the theme. Going back
/// was a button on one screen and a button-or-a-swipe on the next.
///
/// Screens that shouldn't be swipeable opt out rather than being carved out
/// here: `NoSwipeBackPageRoute` for horizontal pagers, `fullscreenDialog: true`
/// for modals, `PopScope(canPop: false)` for flows that must confirm first.
/// All three already read as "not swipeable" to [PageRoute.popGestureEnabled].
class AppPageTransitionsBuilder extends CupertinoPageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Reduce Motion: no slide — and, because the gesture detector is built by
    // the transition we're skipping, no drag either. Unchanged from before;
    // these users navigate back by the button, which every screen has.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return child;
    }
    return super.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Smooth fade + short upward slide page transition.
///
/// Used on desktop and desktop web, where there is no touch back gesture to
/// preserve and a horizontal slide would read as a mobile affordance.
class AppFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const AppFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return child;
    }
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.ease,
      reverseCurve: AppMotion.easeInOut,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

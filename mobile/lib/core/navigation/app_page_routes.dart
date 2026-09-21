import 'package:flutter/material.dart';
import 'package:jperg_app/features/splash/presentation/pages/splash_page.dart';

/// A normal push that opts the destination out of the edge swipe-back gesture.
///
/// Every route in the app can be dragged back from the leading edge (see
/// `AppPageTransitionsBuilder`). That is right for a screen the user reads, and
/// wrong for a screen that is itself a horizontal pager: in a full-screen photo
/// viewer the leading 20 logical pixels would pop the whole viewer instead of
/// turning to the previous photo, so a thumb that lands slightly too far left
/// throws the user out of the gallery. iOS's own photo browser disables the
/// gesture for exactly this reason.
///
/// The route still animates like every other push, and still has its back
/// button and the system back gesture — only the drag is off.
class NoSwipeBackPageRoute<T> extends MaterialPageRoute<T> {
  NoSwipeBackPageRoute({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  });

  @override
  bool get popGestureEnabled => false;
}

/// Wraps [builder] in the route class this particular navigation calls for.
///
/// The app's route table decides *what* a name shows; this decides how it
/// arrives. They are separate because almost every route arrives the same way
/// — the app's Cupertino slide — and the exceptions are about the navigation
/// rather than about the screen: `/home` reached from the tab bar, a deep link
/// or sign-in is an ordinary push, and the same `/home` reached from the splash
/// dissolves.
///
/// Lives here, apart from `app.dart`, so the choice can be tested without
/// standing up the whole app: the table there closes over the session token and
/// the onboarding flag, and nothing in the suite builds it.
Route<void> appRouteFor(RouteSettings settings, WidgetBuilder builder) {
  // The brand screen. Still, in both directions: nothing pushes it, so it has
  // no entrance to play, and it must not answer the dissolve above it with the
  // Cupertino parallax slide.
  if (settings.name == SplashPage.routeName) {
    return StillPageRoute<void>(builder: builder, settings: settings);
  }
  // The one navigation that dissolves — see [SplashPage.handoff].
  if (identical(settings.arguments, SplashPage.handoff)) {
    return SplashHandoffRoute<void>(
      builder: builder,
      // Stripped, so nothing downstream sees the marker as its own argument:
      // it says how to arrive, not what to show.
      settings: RouteSettings(name: settings.name),
    );
  }
  return MaterialPageRoute<void>(builder: builder, settings: settings);
}

/// How long the splash takes to dissolve into the app behind it.
///
/// Slower than a page push (300 ms) on purpose. A push is a move between two
/// screens and wants to be brisk; this is one image becoming another in the
/// same place, and at push speed it reads as a cut with a soft edge rather
/// than as a dissolve.
const kSplashHandoffDuration = Duration(milliseconds: 520);

/// The route the splash hands over to: the destination fades up over it.
///
/// The app's own transition is [AppPageTransitionsBuilder] — Flutter's
/// Cupertino slide, on Android as well as iOS — which is right for every push
/// in the app and wrong for exactly one: the destination slid in from the
/// trailing edge as though the feed were a detail screen pushed on top of the
/// brand moment. Instagram, which this screen is modelled on, dissolves.
///
/// The splash underneath stays fully painted for the whole fade: an opaque
/// route only hides what is below it once its transition has *finished*, so
/// there is never a frame showing neither screen. That is deliberate and it is
/// tested — fading the splash out instead would put the scaffold's bare black
/// on screen in the middle of the handover, which is the seam this is about.
///
/// Pair with [StillPageRoute] beneath it. A route sitting below this one gets
/// its `secondaryAnimation` driven by this fade, and a [MaterialPageRoute]
/// answers that by sliding itself a third of the way off the leading edge —
/// so the splash would drift left while the app faded in over it, which is two
/// motions saying different things.
class SplashHandoffRoute<T> extends PageRouteBuilder<T> {
  SplashHandoffRoute({
    required WidgetBuilder builder,
    required RouteSettings super.settings,
  }) : super(
          pageBuilder: (context, _, __) => builder(context),
          transitionDuration: kSplashHandoffDuration,
          // Nothing pops back to a splash; this only exists so the route has a
          // sane reverse if one is ever run.
          reverseTransitionDuration: kSplashHandoffDuration,
          transitionsBuilder: (context, animation, _, child) {
            // Reduce Motion: the destination is simply there. Matching
            // [AppPageTransitionsBuilder], which does the same.
            if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
              return child;
            }
            return FadeTransition(
              // Eased out rather than linear: a linear cross-fade spends its
              // middle with both images half-visible, which on two pictures
              // that do not line up reads as a smear. This clears the splash
              // early and lets the app hold the rest of the fade.
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            );
          },
        );
}

/// A route that does not animate — in or out, and not when something is laid
/// over it either.
///
/// For the splash, which is the first route in the stack: nothing pushes it, so
/// it has no entrance to play, and what covers it is [SplashHandoffRoute],
/// which does the whole transition itself. Left as a [MaterialPageRoute] it
/// would answer that fade with the Cupertino parallax slide described above.
class StillPageRoute<T> extends MaterialPageRoute<T> {
  StillPageRoute({
    required super.builder,
    required RouteSettings super.settings,
  });

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}

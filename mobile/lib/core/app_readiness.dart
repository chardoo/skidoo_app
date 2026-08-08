import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Whether the app has finished deciding where it starts.
///
/// The splash is not just a brand beat — it owns the first navigation. It waits
/// (1.2s minimum, up to 6s while it warms the feed) and then calls
/// `pushReplacementNamed`, which replaces whatever is on top of the stack.
///
/// A deep link that arrives on a cold start opens its destination about a
/// tenth of a second after the first frame, so by the time the splash finishes
/// the thing on top is the link's screen — and the splash threw it away. The
/// person tapped a link to a photo and landed on the feed, which for a session
/// the splash considered signed-out is the *guest* feed. That is what looked
/// like being logged out.
///
/// So links wait for this instead of racing it. Once the splash has landed on
/// Home (or Discovery), the held link is followed and its screen is pushed on
/// top of a real destination — which also means Back goes somewhere sensible
/// rather than to a spent splash.
class AppReadiness {
  AppReadiness._();

  /// True once the first navigation has happened and it is safe to push on top.
  static final ValueNotifier<bool> isReady = ValueNotifier<bool>(false);

  /// Called by whichever screen performs the initial navigation.
  ///
  /// Safe to call more than once — a rebuild or a second cold-start path must
  /// not reset anything that is already waiting on it.
  ///
  /// The flip waits for the end of a frame, and both halves of that are
  /// load-bearing.
  ///
  /// Listeners navigate. A push marks the Navigator's Overlay dirty, so it must
  /// not happen while the tree is building — doing so throws
  /// `setState() or markNeedsBuild() called during build` on the Overlay, and
  /// the push that follows then trips `'!navigator._debugLocked': is not true`
  /// when its transition completes. A microtask is not far enough: microtasks
  /// drain inside the frame, so the listener can land in the middle of the
  /// destination's build. A post-frame callback runs after build, layout and
  /// paint, when the navigator is idle.
  ///
  /// `ensureVisualUpdate` is the other half: `addPostFrameCallback` only runs
  /// if a frame is actually scheduled, so on an idle tree the flip would never
  /// happen and a held link would silently never open — trading a crash for a
  /// dead link. This guarantees the frame that runs it.
  static void markReady() {
    if (isReady.value || _scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => isReady.value = true)
      ..ensureVisualUpdate();
  }

  static bool _scheduled = false;

  /// Test-only reset; production never goes back to not-ready.
  @visibleForTesting
  static void resetForTest() {
    _scheduled = false;
    isReady.value = false;
  }
}

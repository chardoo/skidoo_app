import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What a reaction feels and sounds like at the moment it lands.
///
/// One definition for every heart in the app — the feed's rail, the event
/// card's bar, a comment row — so a like feels the same wherever it is tapped.
/// Fired by [ReactionPop], which is also what draws the pop, because the
/// transition is the event: a reaction turning *on* is the thing being
/// acknowledged, and the two acknowledgements should not be able to drift
/// apart.
///
/// ## Why the tap is firmer than the rest of the UI
///
/// [HapticFeedback.lightImpact] is what the app uses for *a tap landed* — it
/// is on every button, and a like that feels like a button says nothing about
/// having liked anything. [HapticFeedback.mediumImpact] is the one that reads
/// as a thing happening rather than a control being operated, and it is what
/// Instagram's heart feels like on iOS.
///
/// ## About the sound
///
/// [SystemSoundType.click] is the platform's own touch click. Going through the
/// OS rather than playing an asset is deliberate:
///
/// * On **Android** it is the same click every system button makes, and it
///   honours *Settings → Sound → Touch sounds*. Someone who has turned touch
///   sounds off has already said they do not want this, and an asset would
///   talk over that decision.
/// * It cannot interrupt anything. The feed has its own music layer
///   (`FeedMusicController`); a click played through an audio player would
///   share that session and risk ducking or pausing it — and on iOS would play
///   through the ringer regardless of the mute switch.
///
/// The cost of that choice is that **iOS plays nothing**: Flutter's iOS engine
/// treats `SystemSoundType.click` as a no-op, because UIKit has no public
/// touch-click sound, and iOS apps feel their taps rather than hear them. On
/// iPhone the `mediumImpact` above *is* the feedback. Audible ticks on iOS
/// would mean bundling a sound asset and giving it its own ambient audio
/// session, which is a larger change than this one and a worse default.
class ReactionFeedback {
  const ReactionFeedback._();

  /// When a gesture last said it was about to change a reaction.
  static DateTime? _armedAt;

  /// How long an [arm] stays good for.
  ///
  /// A tap flips the glyph optimistically, so the change usually arrives in
  /// the same frame. The window covers the call sites that wait for the server
  /// before flipping, and is short enough that a background patch landing a
  /// second later is not mistaken for the tap.
  static const Duration _window = Duration(seconds: 1);

  /// A finger is about to turn a reaction on or off.
  ///
  /// Call this from the gesture, not from the state change. Nothing here
  /// fires without it.
  ///
  /// `active` flipping is not evidence that anybody did anything. It flips
  /// when the server's value arrives and disagrees with the optimistic one,
  /// when a list patches rows in underneath, and — the loud one — when a
  /// scrolling list recycles a row's widgets onto a different item whose
  /// reaction happens to differ. That last case can fire several at once, from
  /// photographs nobody has touched, which is what "patching or updating the
  /// events" sounded like.
  ///
  /// The one haptic in the app that is allowed to fire without a tap is none
  /// of them.
  static void arm() => _armedAt = DateTime.now();

  /// A reaction's tap handler, wrapped so the change it causes is
  /// acknowledged and every other change is not.
  ///
  /// ```dart
  /// onTap: ReactionFeedback.arming(onLike),
  /// ```
  ///
  /// Only on the handlers that actually toggle a reaction. Arming from a
  /// shared button wrapper would cover Comment and Share too, and a bookmark
  /// patched in within a second of somebody tapping Share would then sound
  /// like they had saved it.
  static VoidCallback arming(VoidCallback onTap) => () {
        arm();
        onTap();
      };

  /// [arming], for a handler that may be absent — a comment row hides its
  /// heart rather than disabling it, so the callback is nullable there.
  static VoidCallback? armingOrNull(VoidCallback? onTap) =>
      onTap == null ? null : arming(onTap);

  /// Whether the change now arriving belongs to a recent gesture, consuming
  /// the arm either way — one tap is one acknowledgement.
  static bool _takeArmed() {
    final armed = _armedAt;
    _armedAt = null;
    return armed != null && DateTime.now().difference(armed) <= _window;
  }

  /// Forgets any pending arm. For tests, and for a gesture that armed and then
  /// decided not to go through with it.
  @visibleForTesting
  static void disarm() => _armedAt = null;

  /// A reaction just turned on — liked, saved.
  ///
  /// Best-effort twice over: a device with no haptics or no touch sounds is a
  /// normal device, not an error, so neither call is allowed to surface.
  static void turnedOn() {
    if (!_takeArmed()) return;
    HapticFeedback.mediumImpact().catchError((Object _) {});
    SystemSound.play(SystemSoundType.click).catchError((Object _) {});
  }

  /// A reaction turned off.
  ///
  /// The light tap only: taking a like back is an undo, and giving it the same
  /// weight as the like itself reads as having liked something twice. No sound
  /// either — the click is the sound of a thing landing.
  static void turnedOff() {
    if (!_takeArmed()) return;
    HapticFeedback.lightImpact().catchError((Object _) {});
  }
}

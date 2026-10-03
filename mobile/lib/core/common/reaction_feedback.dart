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

  /// A reaction just turned on — liked, saved.
  ///
  /// Best-effort twice over: a device with no haptics or no touch sounds is a
  /// normal device, not an error, so neither call is allowed to surface.
  static void turnedOn() {
    HapticFeedback.mediumImpact().catchError((Object _) {});
    SystemSound.play(SystemSoundType.click).catchError((Object _) {});
  }

  /// A reaction turned off.
  ///
  /// The light tap only: taking a like back is an undo, and giving it the same
  /// weight as the like itself reads as having liked something twice. No sound
  /// either — the click is the sound of a thing landing.
  static void turnedOff() {
    HapticFeedback.lightImpact().catchError((Object _) {});
  }
}

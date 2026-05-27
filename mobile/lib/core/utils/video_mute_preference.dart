import 'package:flutter/foundation.dart';

/// Persists the user's mute preference across all [SkidooVideoPlayer] instances.
///
/// Initial value: muted on web (avoids autoplay policy blocks), unmuted on
/// native — matching the platform default. Once the user explicitly toggles
/// mute in any video, [muted] is updated and every subsequently created player
/// reads the new value at init time, so the choice "sticks" for the session.
class VideoMutePreference {
  VideoMutePreference._();

  /// The current global mute state. `true` = muted.
  static final ValueNotifier<bool> _notifier =
      ValueNotifier<bool>(kIsWeb); // muted on web, unmuted on native

  /// Read the current mute preference.
  static bool get muted => _notifier.value;

  /// Update the preference (called by [SkidooVideoPlayer] on user toggle).
  static set muted(bool value) => _notifier.value = value;

  /// Listen for changes — e.g. to sync a mute indicator in a parent widget.
  static ValueNotifier<bool> get notifier => _notifier;
}

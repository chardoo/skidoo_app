import 'notification_sound_stub.dart'
    if (dart.library.js_interop) 'notification_sound_web.dart'
    if (dart.library.io) 'notification_sound_io.dart' as impl;

/// Plays a short notification tone for an incoming direct message that arrives
/// while the user is not viewing that conversation.
///
/// Best-effort and fire-and-forget. On web it synthesizes a soft two-note chime
/// with the Web Audio API — no bundled asset and no `<audio>` element that the
/// browser's autoplay policy would silently block. On iOS/Android it plays the
/// platform's standard alert sound. The caller is responsible for honoring the
/// in-app mute preference before invoking this.
class NotificationSoundService {
  const NotificationSoundService();

  /// Fire the new-message tone. Swallows any platform error — a notification
  /// sound must never interfere with chat message processing.
  void playMessageTone() {
    try {
      impl.playNotificationTone();
    } catch (_) {}
  }
}

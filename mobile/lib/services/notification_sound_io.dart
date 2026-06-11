import 'package:flutter/services.dart';

/// Native (iOS/Android): play the platform's standard alert sound. This routes
/// through the OS so it respects the device ringer/volume. Best-effort.
void playNotificationTone() {
  SystemSound.play(SystemSoundType.alert);
}

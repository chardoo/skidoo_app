import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';

/// Blocks screenshots and screen recording across the whole app.
///
/// - **Android:** sets `FLAG_SECURE`, which blocks screenshots, screen
///   recording, and the recents / app-switcher thumbnail.
/// - **iOS:** renders a secure overlay so screenshots and screen recordings
///   capture a blank frame, plus a blurred placeholder while the app is in the
///   background (app switcher).
///
/// Failures never propagate: a protection error must not crash startup.
Future<void> enableScreenshotProtection() async {
  try {
    await ScreenProtector.preventScreenshotOn();
    // App-switcher / background privacy — iOS only (Android is already covered
    // by FLAG_SECURE, which also blanks the recents thumbnail).
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await ScreenProtector.protectDataLeakageWithBlur();
    }
  } catch (_) {/* non-fatal */}
}

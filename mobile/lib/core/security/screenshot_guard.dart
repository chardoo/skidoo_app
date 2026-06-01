import 'package:flutter/foundation.dart';
// Needed only by the (currently disabled) web BrowserContextMenu protection:
// import 'package:flutter/services.dart';
import 'package:screen_protector/screen_protector.dart';

/// Blocks screenshots and screen recording across the whole app.
///
/// - **Android:** sets `FLAG_SECURE`, which blocks screenshots, screen
///   recording, and the recents / app-switcher thumbnail.
/// - **iOS:** renders a secure overlay so screenshots and screen recordings
///   capture a blank frame, plus a blurred placeholder while the app is in the
///   background (app switcher).
/// - **Web:** browsers expose **no API** to block OS-level screenshots — the
///   best we can do is disable the right-click context menu ("Save image as").
///   Additional DOM-level deterrents (no image drag / text selection) live in
///   `web/index.html`.
///
/// Failures never propagate: a protection error must not crash startup.
Future<void> enableScreenshotProtection() async {
  if (kIsWeb) {
    // Web protection is disabled for now so testers can right-click to inspect
    // elements. Re-enable to block the right-click "Save image as…" menu.
    // try {
    //   await BrowserContextMenu.disableContextMenu();
    // } catch (_) {/* non-fatal */}
    return;
  }

  try {
    await ScreenProtector.preventScreenshotOn();
    // App-switcher / background privacy — iOS only (Android is already covered
    // by FLAG_SECURE, which also blanks the recents thumbnail).
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await ScreenProtector.protectDataLeakageWithBlur();
    }
  } catch (_) {/* non-fatal */}
}

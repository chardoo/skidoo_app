import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// "Is there a face in this photo?", answered by the OS.
///
/// This used to be `google_mlkit_face_detection`, which bundles its own
/// detector and TFLite models: ~26 MB of the iOS download, and ~16 MB of the
/// Android one, for a single yes/no on the selfie screen. Both platforms
/// already ship a face detector — iOS in the Vision framework, Android in Play
/// Services — so this asks theirs instead, over a method channel implemented
/// in `ios/Runner/FaceCheckPlugin.swift` and
/// `android/.../FaceCheckPlugin.kt`.
///
/// The check is an early hint, not a gate: the selfie goes to the recognition
/// backend either way, and the capture screen lets the user proceed regardless.
/// So an *undeterminable* answer counts as a pass — see [hasFace].
class FaceCheck {
  const FaceCheck._();

  static const MethodChannel _channel = MethodChannel('skidoo/face_check');

  /// True when the image at [imagePath] contains at least one face.
  ///
  /// Also true when no answer is available — on web, where there is no native
  /// detector; on a device whose detector failed or is still downloading its
  /// model; or if the platform side isn't registered. A detector that can't
  /// run must never be the reason a real user can't submit their selfie.
  static Future<bool> hasFace(String imagePath) async {
    if (kIsWeb) return true;
    try {
      final result =
          await _channel.invokeMethod<bool>('hasFace', {'path': imagePath});
      return result ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return true;
    }
  }
}

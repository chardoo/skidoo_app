import Flutter
import UIKit
import Vision

/// Answers the Dart side's `skidoo/face_check` channel: "does this photo
/// contain a face?"
///
/// Vision ships with iOS, so this costs nothing in the app download. It
/// replaced ML Kit's bundled face detector, which linked ~16 MB of static code
/// into the binary and shipped a further 10 MB of TFLite models for the same
/// yes/no.
///
/// Returning `nil` means "couldn't tell" — the Dart side treats that as a pass
/// rather than blocking the user (see `FaceCheck.hasFace`).
enum FaceCheckPlugin {
  static let channelName = "skidoo/face_check"

  static func register(with registry: FlutterPluginRegistry) {
    // Any registrar's messenger reaches the same engine; this plugin has no
    // platform views or assets, so the name is only an identity.
    let registrar = registry.registrar(forPlugin: "FaceCheckPlugin")!
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { call, result in
      guard call.method == "hasFace" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      else {
        result(nil)
        return
      }

      // Decoding and detection are both slow enough to matter on the platform
      // thread; the reply hops back to main because the Flutter messenger
      // expects it there.
      DispatchQueue.global(qos: .userInitiated).async {
        let answer = detectFace(atPath: path)
        DispatchQueue.main.async { result(answer) }
      }
    }
  }

  private static func detectFace(atPath path: String) -> Bool? {
    guard
      let image = UIImage(contentsOfFile: path),
      let cgImage = image.cgImage
    else { return nil }

    let request = VNDetectFaceRectanglesRequest()
    let handler = VNImageRequestHandler(
      cgImage: cgImage,
      // A selfie is usually stored rotated, with the upright direction only in
      // the EXIF orientation. Vision detects on the raw buffer, so without
      // this a portrait capture arrives sideways and finds no face.
      orientation: cgOrientation(of: image.imageOrientation),
      options: [:]
    )

    do {
      try handler.perform([request])
      return !(request.results ?? []).isEmpty
    } catch {
      return nil
    }
  }

  private static func cgOrientation(
    of orientation: UIImage.Orientation
  ) -> CGImagePropertyOrientation {
    switch orientation {
    case .up: return .up
    case .down: return .down
    case .left: return .left
    case .right: return .right
    case .upMirrored: return .upMirrored
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
  }
}

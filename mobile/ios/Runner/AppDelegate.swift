import Flutter
import UIKit
import AVFoundation
import CoreImage

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Allow video audio to play through the speaker even when the silent
    // switch is on and to mix/duck with other audio properly.
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback,
        mode: .moviePlayback,
        options: [.mixWithOthers]
      )
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("[AppDelegate] AVAudioSession setup failed: \(error)")
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Enable wide color (P3) rendering on the Flutter Metal layer so photos
    // and videos display the full DCI-P3 colour gamut on supported iPhones.
    // This is a no-op on devices that don't support wide colour.
    if let flutterVC = engineBridge.flutterViewController,
       let metalLayer = flutterVC.view.layer as? CAMetalLayer {
      if #available(iOS 16.0, *) {
        metalLayer.pixelFormat = .bgra10_xr_srgb   // 10-bit wide colour
      } else {
        metalLayer.pixelFormat = .bgra8Unorm        // 8-bit fallback
      }
      if let p3 = CGColorSpace(name: CGColorSpace.displayP3) {
        metalLayer.colorspace = p3
      }
      metalLayer.wantsExtendedDynamicRangeContent = true
      metalLayer.contentsScale = UIScreen.main.scale  // always full native DPI
    }
  }
}

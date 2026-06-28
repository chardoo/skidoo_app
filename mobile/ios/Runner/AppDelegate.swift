import Flutter
import UIKit
import AVFoundation
import Metal

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
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // Enable wide colour (P3) on the Flutter Metal layer after the engine
    // has finished launching and the root view controller is available.
    _applyWideColorIfSupported()
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // ── Wide colour / P3 rendering ────────────────────────────────────────────

  private func _applyWideColorIfSupported() {
    guard let flutterVC = window?.rootViewController as? FlutterViewController,
          let metalLayer = flutterVC.view.layer as? CAMetalLayer else { return }

    if #available(iOS 16.0, *) {
      metalLayer.pixelFormat = MTLPixelFormat.bgra10_xr_srgb
      metalLayer.wantsExtendedDynamicRangeContent = true
    } else {
      metalLayer.pixelFormat = MTLPixelFormat.bgra8Unorm
    }
    if let p3 = CGColorSpace(name: CGColorSpace.displayP3) {
      metalLayer.colorspace = p3
    }
    metalLayer.contentsScale = UIScreen.main.scale
  }
}

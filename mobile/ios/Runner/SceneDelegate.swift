import Flutter
import Metal
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    guard let windowScene = scene as? UIWindowScene,
          let window = windowScene.windows.first,
          let flutterVC = window.rootViewController as? FlutterViewController,
          let metalLayer = flutterVC.view.layer as? CAMetalLayer else { return }

    if #available(iOS 16.0, *) {
      metalLayer.pixelFormat = .bgra10_xr_srgb
      metalLayer.wantsExtendedDynamicRangeContent = true
    } else {
      metalLayer.pixelFormat = .bgra8Unorm
    }
    if let p3 = CGColorSpace(name: CGColorSpace.displayP3) {
      metalLayer.colorspace = p3
    }
    metalLayer.contentsScale = UIScreen.main.scale
  }
}

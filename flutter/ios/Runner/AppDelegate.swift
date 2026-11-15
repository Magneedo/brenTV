import Flutter
import UIKit

// Observe the presenting controller, never subclass AVPlayerViewController.
@objc(BrenTVViewController)
class BrenTVViewController: FlutterViewController {
  var onReappear: (() -> Void)?
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    onReappear?()
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var iosPlayer: IosPlayerBridge?
  private var mediaConverter: IosMediaConverter?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "BrenTVPlayer") {
      let player = IosPlayerBridge(messenger: registrar.messenger(), parent: window?.rootViewController)
      iosPlayer = player
      mediaConverter = IosMediaConverter(messenger: registrar.messenger())
      (window?.rootViewController as? BrenTVViewController)?.onReappear = { [weak player] in
        player?.reconcilePresentation()
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Diese Methode ist für iOS 9+ und verarbeitet Deep-Links
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    print("Received URL: \(url.absoluteString)")
    return super.application(app, open: url, options: options)
  }
  
  // Diese Methode ist für Universal Links (iOS 13+)
  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if let url = userActivity.webpageURL {
      print("Received Universal Link: \(url.absoluteString)")
    }
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }
}

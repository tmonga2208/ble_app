import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Request background execution time for BLE
    if #available(iOS 13.0, *) {
      // iOS 13+ uses new background task API
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle app waking from background due to BLE events
  override func applicationDidEnterBackground(_ application: UIApplication) {
    // App entered background - BLE connection should be maintained
    super.applicationDidEnterBackground(application)
  }

  override func applicationWillEnterForeground(_ application: UIApplication) {
    // App coming to foreground
    super.applicationWillEnterForeground(application)
  }
}

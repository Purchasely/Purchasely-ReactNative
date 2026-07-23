import UIKit
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider

@main
class AppDelegate: RCTAppDelegate {
  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    self.moduleName = "example"
    self.dependencyProvider = RCTAppDependencyProvider()

    // E2E mode: launched via `xcrun simctl launch <udid> <bundle> E2E_MODE true`
    // (launch argument) or with the E2E_MODE=true environment variable. When set,
    // index.js routes the root component to E2ETestRunner (mirrors Android
    // MainActivity reading the E2E_MODE intent extra).
    let args = ProcessInfo.processInfo.arguments
    let env = ProcessInfo.processInfo.environment
    let e2eMode = args.contains("E2E_MODE") || env["E2E_MODE"] == "true"

    // You can add your custom initial props in the dictionary below.
    // They will be passed down to the ViewController used by React Native.
    self.initialProps = e2eMode ? ["e2eMode": true] : [:]

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func sourceURL(for bridge: RCTBridge) -> URL? {
    self.bundleURL()
  }

  override func bundleURL() -> URL? {
#if DEBUG
    RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
#else
    Bundle.main.url(forResource: "main", withExtension: "jsbundle")
#endif
  }
}

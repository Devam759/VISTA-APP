import Flutter
import UIKit
import FirebaseAppCheck

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let providerFactory = AppCheckDebugProviderFactory()
    AppCheck.setAppCheckProviderFactory(providerFactory)

    // Force generate the debug token if it doesn't exist so we can guarantee we know it
    if UserDefaults.standard.string(forKey: "GACAppCheckDebugToken") == nil {
        let newToken = UUID().uuidString
        UserDefaults.standard.set(newToken, forKey: "GACAppCheckDebugToken")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    
    let channel = FlutterMethodChannel(
      name: "com.ashish.vista.jklu/debug_token",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "getDebugToken" {
        let token = UserDefaults.standard.string(forKey: "GACAppCheckDebugToken") ?? "NOT_FOUND"
        result(token)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
  }
}

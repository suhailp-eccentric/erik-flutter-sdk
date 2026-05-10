import Flutter
import UIKit

public class ErikFlutterSdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "erik_flutter_sdk", binaryMessenger: registrar.messenger())
    let instance = ErikFlutterSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.register(
      ErikPlatformViewFactory(
        messenger: registrar.messenger(),
        assetResolver: ErikAssetResolver(registrar: registrar)
      ),
      withId: "erik_flutter_sdk/erik_fragment_view"
    )
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "isEmulator":
      #if targetEnvironment(simulator)
      result(true)
      #else
      result(false)
      #endif
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

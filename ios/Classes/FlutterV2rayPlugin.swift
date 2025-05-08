import Flutter
import UIKit

public class FlutterV2rayPlugin: NSObject, FlutterPlugin {
    private let v2rayManager = V2RayManager()
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_v2ray", binaryMessenger: registrar.messenger())
        let instance = FlutterV2rayPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            do {
                try v2rayManager.extractV2RayBinary()
                result(true)
            } catch {
                result(FlutterError(code: "INIT_ERROR", 
                                    message: "Failed to initialize V2Ray", 
                                    details: error.localizedDescription))
            }
            
        case "connect":
            guard let args = call.arguments as? [String: Any],
                  let config = args["config"] as? String else {
                result(FlutterError(code: "ARGS_ERROR", 
                                   message: "Invalid arguments", 
                                   details: "Config is required"))
                return
            }
            
            do {
                try v2rayManager.saveConfig(config: config)
                result(true)
            } catch {
                result(FlutterError(code: "CONFIG_ERROR", 
                                   message: "Failed to save configuration", 
                                   details: error.localizedDescription))
            }
            
        case "start":
            do {
                try v2rayManager.start()
                result(true)
            } catch {
                result(FlutterError(code: "START_ERROR", 
                                   message: "Failed to start V2Ray service", 
                                   details: error.localizedDescription))
            }
            
        case "stop":
            do {
                try v2rayManager.stop()
                result(true)
            } catch {
                result(FlutterError(code: "STOP_ERROR", 
                                   message: "Failed to stop V2Ray service", 
                                   details: error.localizedDescription))
            }
            
        case "isConnected":
            result(v2rayManager.isRunning())
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

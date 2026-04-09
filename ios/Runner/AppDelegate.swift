import Flutter
import UIKit
import ReplayKit
import SwiftUI

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    
    let recorder = RPScreenRecorder.shared()
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }
        
        let recordingChannel = FlutterMethodChannel(name: "com.example.imagerecorder/recording", binaryMessenger: controller.binaryMessenger)
        
        recordingChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "startRecording":
                self?.startRecording(result: result)
            case "stopRecording":
                self?.stopRecording(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func startRecording(result: @escaping FlutterResult) {
        guard recorder.isAvailable else {
            result(FlutterError(code: "UNAVAILABLE", message: "Screen recording is not available", details: nil))
            return
        }
        
        recorder.startRecording { error in
            if let error = error {
                result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
            } else {
                result(true)
            }
        }
    }
    
    func stopRecording(result: @escaping FlutterResult) {
        recorder.stopRecording { previewViewController, error in
            if let error = error {
                result(FlutterError(code: "STOP_FAILED", message: error.localizedDescription, details: nil))
            } else {
                result("Saved")
            }
        }
    }
}

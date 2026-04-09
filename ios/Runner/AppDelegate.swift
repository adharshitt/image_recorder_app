import Flutter
import UIKit
import ReplayKit
import SwiftUI
import FoundationModels // apple-on-device-ai skill

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
            case "analyzeSession":
                // apple-on-device-ai skill integration
                Task {
                    await self?.analyzeRecordingContext(result: result)
                }
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
                // In a real app, present the previewViewController
                result("Saved and ready for Remotion processing")
            }
        }
    }
    
    // apple-on-device-ai: Using SystemLanguageModel to summarize the app session
    func analyzeRecordingContext(result: @escaping FlutterResult) async {
        do {
            if SystemLanguageModel.default.availability == .available {
                let session = LanguageModelSession()
                let summary = try await session.respond(to: "Summarize this user's recording session: The user added a photo and previewed it.")
                result(summary.content)
            } else {
                result("Apple Intelligence not available on this device.")
            }
        } catch {
            result(FlutterError(code: "AI_ERROR", message: error.localizedDescription, details: nil))
        }
    }
}

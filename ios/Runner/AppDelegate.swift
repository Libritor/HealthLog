Cimport Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  
  // Channel Names
  private let COMMAND_CHANNEL = "com.museheadband/muse_commands"
  private let SCAN_CHANNEL = "com.museheadband/scan_stream"
  private let EEG_CHANNEL = "com.museheadband/eeg_stream"
  private let BAND_POWER_CHANNEL = "com.museheadband/bandpower_stream"
  private let IMU_CHANNEL = "com.museheadband/imu_stream"
  private let FNIRS_CHANNEL = "com.museheadband/fnirs_stream"
  private let HSI_CHANNEL = "com.museheadband/hsi_stream"
  private let BATTERY_CHANNEL = "com.museheadband/battery_stream"
    
  private let museManager = MuseManager()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    
    // 1. Command Channel (Methods)
    let methodChannel = FlutterMethodChannel(name: COMMAND_CHANNEL,
                                              binaryMessenger: controller.binaryMessenger)
    methodChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else { return }
        
      switch call.method {
      case "scan":
        self.museManager.startScan()
        result(nil)
      case "stopScan":
        self.museManager.stopScan()
        result(nil)
      case "connect":
        if let args = call.arguments as? [String: Any],
           let deviceId = args["deviceId"] as? String {
            self.museManager.connect(deviceId: deviceId)
            result(nil)
        } else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "deviceId required", details: nil))
        }
      case "disconnect":
        if let args = call.arguments as? [String: Any],
           let deviceId = args["deviceId"] as? String {
            self.museManager.disconnect(deviceId: deviceId)
            result(nil)
        } else {
             result(FlutterError(code: "INVALID_ARGUMENT", message: "deviceId required", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    })

    // 2. Event Channels (Streams)
    registerStream(name: SCAN_CHANNEL, messenger: controller.binaryMessenger) { self.museManager.scanSink = $0 }
    registerStream(name: EEG_CHANNEL, messenger: controller.binaryMessenger) { self.museManager.eegSink = $0 }
    registerStream(name: BAND_POWER_CHANNEL, messenger: controller.binaryMessenger) { self.museManager.bandPowerSink = $0 }
    registerStream(name: IMU_CHANNEL, messenger: controller.binaryMessenger) { self.museManager.imuSink = $0 }
    registerStream(name: FNIRS_CHANNEL, messenger: controller.binaryMessenger) { self.museManager.fnirsSink = $0 }
    registerStream(name: HSI_CHANNEL, messenger: controller.binaryMessenger) { self.museManager.hsiSink = $0 }
    registerStream(name: BATTERY_CHANNEL, messenger: controller.binaryMessenger) { self.museManager.batterySink = $0 }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func registerStream(name: String, messenger: FlutterBinaryMessenger, setter: @escaping (FlutterEventSink?) -> Void) {
    let channel = FlutterEventChannel(name: name, binaryMessenger: messenger)
    channel.setStreamHandler(StreamHandler(setter: setter))
  }
}

class StreamHandler: NSObject, FlutterStreamHandler {
    let setter: (FlutterEventSink?) -> Void
    
    init(setter: @escaping (FlutterEventSink?) -> Void) {
        self.setter = setter
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        setter(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        setter(nil)
        return nil
    }
}

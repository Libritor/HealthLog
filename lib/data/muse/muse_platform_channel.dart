import 'package:flutter/services.dart';

// Platform channel bridge for talking to native LibMuse SDK.
// Uses MethodChannel for commands, EventChannel for streaming sensor data.
//
// Setup for iOS (Swift - AppDelegate.swift):
//   - Add LibMuse.framework to ios/Frameworks
//   - Create method channel "com.museheadband/muse_commands"
//   - Create event channels for each data type
//   - Call museManager.startListening(), muse.connect(), etc.
//
// Setup for Android (Kotlin - MainActivity.kt):
//   - Add libmuse_android.aar to android/app/libs
//   - Same channel setup as iOS
//   - Use MuseManagerAndroid.getInstance()
class MusePlatformChannel {
  static const MethodChannel _methodChannel =
      MethodChannel('com.museheadband/muse_commands');

  static const EventChannel _scanEventChannel =
      EventChannel('com.museheadband/scan_stream');

  static const EventChannel _eegEventChannel =
      EventChannel('com.museheadband/eeg_stream');

  static const EventChannel _bandPowerEventChannel =
      EventChannel('com.museheadband/bandpower_stream');

  static const EventChannel _fnirsEventChannel =
      EventChannel('com.museheadband/fnirs_stream');

  static const EventChannel _imuEventChannel =
      EventChannel('com.museheadband/imu_stream');

  static const EventChannel _batteryEventChannel =
      EventChannel('com.museheadband/battery_stream');

  static const EventChannel _hsiEventChannel =
      EventChannel('com.museheadband/hsi_stream');

  Future<void> startScanning() async {
    await _methodChannel.invokeMethod('scan');
  }

  Future<void> stopScanning() async {
    await _methodChannel.invokeMethod('stopScan');
  }

  Future<void> connect(String deviceId) async {
    await _methodChannel.invokeMethod('connect', {'deviceId': deviceId});
  }

  Future<void> disconnect(String deviceId) async {
    await _methodChannel.invokeMethod('disconnect', {'deviceId': deviceId});
  }

  // Scan results: { "id": "...", "name": "...", "battery": 85 }
  Stream<Map<String, dynamic>> get scanStream {
    return _scanEventChannel.receiveBroadcastStream().map((event) {
      return Map<String, dynamic>.from(event as Map);
    });
  }

  // EEG data: { "deviceId": "...", "timestamp": 123456789, "tp9": 0.5, ... }
  Stream<Map<String, dynamic>> getEegStream(String deviceId) {
    return _eegEventChannel.receiveBroadcastStream(deviceId).map((event) {
      return Map<String, dynamic>.from(event as Map);
    });
  }

  Stream<Map<String, dynamic>> getBandPowerStream(String deviceId) {
    return _bandPowerEventChannel
        .receiveBroadcastStream(deviceId)
        .map((event) {
      return Map<String, dynamic>.from(event as Map);
    });
  }

  Stream<Map<String, dynamic>> getFnirsStream(String deviceId) {
    return _fnirsEventChannel.receiveBroadcastStream(deviceId).map((event) {
      return Map<String, dynamic>.from(event as Map);
    });
  }

  Stream<Map<String, dynamic>> getImuStream(String deviceId) {
    return _imuEventChannel.receiveBroadcastStream(deviceId).map((event) {
      return Map<String, dynamic>.from(event as Map);
    });
  }

  Stream<dynamic> getBatteryStream(String deviceId) {
    return _batteryEventChannel.receiveBroadcastStream(deviceId);
  }

  Stream<Map<String, dynamic>> getHsiStream(String deviceId) {
    return _hsiEventChannel.receiveBroadcastStream(deviceId).map((event) {
      return Map<String, dynamic>.from(event as Map);
    });
  }
}

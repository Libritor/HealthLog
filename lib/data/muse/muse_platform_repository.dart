import 'dart:async';
import '../../domain/models/muse_device.dart';
import '../../domain/models/eeg_sample.dart';
import '../../domain/models/band_power_sample.dart';
import '../../domain/models/fnirs_sample.dart';
import '../../domain/models/imu_sample.dart';
import 'muse_service.dart';
import 'muse_platform_channel.dart';

/// Real implementation of MuseService using platform channels
/// This connects to actual Muse headbands via the native Android/iOS SDK
class MusePlatformRepository implements MuseService {
  final MusePlatformChannel _platformChannel = MusePlatformChannel();
  
  final Map<String, StreamController<EegSample>> _eegControllers = {};
  final Map<String, StreamController<BandPowerSample>> _bandPowerControllers = {};
  final Map<String, StreamController<FnirsSample>> _fnirsControllers = {};
  final Map<String, StreamController<ImuSample>> _imuControllers = {};
  final Map<String, StreamController<int>> _batteryControllers = {};
  final Map<String, StreamController<Map<String, HsiValue>>> _hsiControllers = {};
  final Map<String, ImuSample> _lastImuSamples = {};

  StreamController<List<MuseDevice>>? _scanController;
  final List<MuseDevice> _discoveredDevices = [];

  @override
  Stream<List<MuseDevice>> scanForDevices() {
    _scanController = StreamController<List<MuseDevice>>.broadcast();
    _discoveredDevices.clear();

    // Listen to the platform channel scan stream
    _platformChannel.scanStream.listen((deviceData) {
      final device = MuseDevice(
        id: deviceData['id'] as String,
        name: deviceData['name'] as String,
        isConnected: false,
        batteryPercent: (deviceData['battery'] as num?)?.toInt() ?? 0,
      );
      
      // Check if device already exists
      final existingIndex = _discoveredDevices.indexWhere((d) => d.id == device.id);
      if (existingIndex == -1) {
        _discoveredDevices.add(device);
      } else {
        _discoveredDevices[existingIndex] = device;
      }
      
      _scanController?.add(List.from(_discoveredDevices));
    });

    // Start scanning via platform channel
    _platformChannel.startScanning();

    return _scanController!.stream;
  }

  // Single global subscriptions to platform channels
  StreamSubscription? _globalEegSubscription;
  StreamSubscription? _globalBandPowerSubscription;
  StreamSubscription? _globalFnirsSubscription;
  StreamSubscription? _globalImuSubscription;
  StreamSubscription? _globalBatterySubscription;
  StreamSubscription? _globalHsiSubscription;

  // ... (scan methods remain unchanged)

  @override
  Future<void> stopScanning() async {
    await _platformChannel.stopScanning();
    await _scanController?.close();
    _scanController = null;
  }

  @override
  Future<void> connectToDevice(String deviceId) async {
    await _platformChannel.connect(deviceId);
    
    // Update device connection state
    final index = _discoveredDevices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      _discoveredDevices[index] = _discoveredDevices[index].copyWith(isConnected: true);
    }
  }

  @override
  Future<void> disconnectDevice(String deviceId) async {
    await _platformChannel.disconnect(deviceId);
    
    // Clean up stream controllers for this device
    await _eegControllers[deviceId]?.close();
    _eegControllers.remove(deviceId);

    await _bandPowerControllers[deviceId]?.close();
    _bandPowerControllers.remove(deviceId);

    await _fnirsControllers[deviceId]?.close();
    _fnirsControllers.remove(deviceId);

    await _imuControllers[deviceId]?.close();
    _imuControllers.remove(deviceId);

    await _batteryControllers[deviceId]?.close();
    _batteryControllers.remove(deviceId);

    await _hsiControllers[deviceId]?.close();
    _hsiControllers.remove(deviceId);

    // Update device connection state
    final index = _discoveredDevices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      _discoveredDevices[index] = _discoveredDevices[index].copyWith(isConnected: false);
    }
  }

  // --- Global Stream Listeners ---

  void _ensureGlobalEegListener() {
    if (_globalEegSubscription != null) return;

    // Listen to platform channel EEG stream ONCE
    _globalEegSubscription = _platformChannel.getEegStream('global').listen((data) {
      final receivedDeviceId = data['deviceId'] as String?;
      
      // Debug: Log received device IDs and registered controllers
      // print('DEBUG EEG: Received from deviceId=$receivedDeviceId, registered controllers: ${_eegControllers.keys.toList()}');
      
      // Route data to the correct controller
      final controller = _eegControllers[receivedDeviceId];
      if (controller != null && !controller.isClosed) {
        final sample = EegSample(
          timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int),
          tp9: data['tp9'] as double,
          af7: data['af7'] as double,
          af8: data['af8'] as double,
          tp10: data['tp10'] as double,
          drl: data['drl'] as double,
          ref: data['ref'] as double,
        );
        controller.add(sample);
      } else if (receivedDeviceId != null) {
        // Auto-create controller for devices we receive data from but haven't subscribed to yet
        print('DEBUG EEG: Creating controller on-the-fly for $receivedDeviceId');
        _eegControllers[receivedDeviceId] = StreamController<EegSample>.broadcast();
        final sample = EegSample(
          timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int),
          tp9: data['tp9'] as double,
          af7: data['af7'] as double,
          af8: data['af8'] as double,
          tp10: data['tp10'] as double,
          drl: data['drl'] as double,
          ref: data['ref'] as double,
        );
        _eegControllers[receivedDeviceId]!.add(sample);
      }
    });
  }

  void _ensureGlobalBandPowerListener() {
    if (_globalBandPowerSubscription != null) return;

    _globalBandPowerSubscription = _platformChannel.getBandPowerStream('global').listen((data) {
      final receivedDeviceId = data['deviceId'] as String?;
      
      var controller = _bandPowerControllers[receivedDeviceId];
      
      // Auto-create controller if it doesn't exist
      if (controller == null && receivedDeviceId != null) {
        print('DEBUG BandPower: Creating controller on-the-fly for $receivedDeviceId');
        _bandPowerControllers[receivedDeviceId] = StreamController<BandPowerSample>.broadcast();
        controller = _bandPowerControllers[receivedDeviceId];
      }
      
      if (controller != null && !controller.isClosed) {
        final sample = BandPowerSample(
          timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int),
          tp9: ChannelBandPower(
            deltaAbsolute: data['tp9_delta_absolute'] as double? ?? 0.0,
            thetaAbsolute: data['tp9_theta_absolute'] as double? ?? 0.0,
            alphaAbsolute: data['tp9_alpha_absolute'] as double? ?? 0.0,
            betaAbsolute: data['tp9_beta_absolute'] as double? ?? 0.0,
            gammaAbsolute: data['tp9_gamma_absolute'] as double? ?? 0.0,
            deltaRelative: data['tp9_delta_relative'] as double? ?? 0.0,
            thetaRelative: data['tp9_theta_relative'] as double? ?? 0.0,
            alphaRelative: data['tp9_alpha_relative'] as double? ?? 0.0,
            betaRelative: data['tp9_beta_relative'] as double? ?? 0.0,
            gammaRelative: data['tp9_gamma_relative'] as double? ?? 0.0,
          ),
          af7: ChannelBandPower(
            deltaAbsolute: data['af7_delta_absolute'] as double? ?? 0.0,
            thetaAbsolute: data['af7_theta_absolute'] as double? ?? 0.0,
            alphaAbsolute: data['af7_alpha_absolute'] as double? ?? 0.0,
            betaAbsolute: data['af7_beta_absolute'] as double? ?? 0.0,
            gammaAbsolute: data['af7_gamma_absolute'] as double? ?? 0.0,
            deltaRelative: data['af7_delta_relative'] as double? ?? 0.0,
            thetaRelative: data['af7_theta_relative'] as double? ?? 0.0,
            alphaRelative: data['af7_alpha_relative'] as double? ?? 0.0,
            betaRelative: data['af7_beta_relative'] as double? ?? 0.0,
            gammaRelative: data['af7_gamma_relative'] as double? ?? 0.0,
          ),
          af8: ChannelBandPower(
            deltaAbsolute: data['af8_delta_absolute'] as double? ?? 0.0,
            thetaAbsolute: data['af8_theta_absolute'] as double? ?? 0.0,
            alphaAbsolute: data['af8_alpha_absolute'] as double? ?? 0.0,
            betaAbsolute: data['af8_beta_absolute'] as double? ?? 0.0,
            gammaAbsolute: data['af8_gamma_absolute'] as double? ?? 0.0,
            deltaRelative: data['af8_delta_relative'] as double? ?? 0.0,
            thetaRelative: data['af8_theta_relative'] as double? ?? 0.0,
            alphaRelative: data['af8_alpha_relative'] as double? ?? 0.0,
            betaRelative: data['af8_beta_relative'] as double? ?? 0.0,
            gammaRelative: data['af8_gamma_relative'] as double? ?? 0.0,
          ),
          tp10: ChannelBandPower(
            deltaAbsolute: data['tp10_delta_absolute'] as double? ?? 0.0,
            thetaAbsolute: data['tp10_theta_absolute'] as double? ?? 0.0,
            alphaAbsolute: data['tp10_alpha_absolute'] as double? ?? 0.0,
            betaAbsolute: data['tp10_beta_absolute'] as double? ?? 0.0,
            gammaAbsolute: data['tp10_gamma_absolute'] as double? ?? 0.0,
            deltaRelative: data['tp10_delta_relative'] as double? ?? 0.0,
            thetaRelative: data['tp10_theta_relative'] as double? ?? 0.0,
            alphaRelative: data['tp10_alpha_relative'] as double? ?? 0.0,
            betaRelative: data['tp10_beta_relative'] as double? ?? 0.0,
            gammaRelative: data['tp10_gamma_relative'] as double? ?? 0.0,
          ),
        );
        controller.add(sample);
      }
    });
  }

  void _ensureGlobalFnirsListener() {
    if (_globalFnirsSubscription != null) return;

    _globalFnirsSubscription = _platformChannel.getFnirsStream('global').listen((data) {
      final receivedDeviceId = data['deviceId'] as String?;
      
      var controller = _fnirsControllers[receivedDeviceId];
      
      // Auto-create controller if it doesn't exist
      if (controller == null && receivedDeviceId != null) {
        _fnirsControllers[receivedDeviceId] = StreamController<FnirsSample>.broadcast();
        controller = _fnirsControllers[receivedDeviceId];
      }
      
      if (controller != null && !controller.isClosed) {
        final timestamp = data['timestamp'] as int;
        final ppg0 = data['ppg0'] as double? ?? 0.0;
        final ppg1 = data['ppg1'] as double? ?? 0.0;
        final ppg2 = data['ppg2'] as double? ?? 0.0;
        final ppg3 = data['ppg3'] as double? ?? 0.0;
        final ppg4 = data['ppg4'] as double? ?? 0.0;
        final ppg5 = data['ppg5'] as double? ?? 0.0;
        
        final sample = FnirsSample(
          timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
          nm730LeftOuter: ppg0,
          nm730RightOuter: ppg1,
          nm730LeftInner: ppg0,
          nm730RightInner: ppg1,
          nm850LeftOuter: ppg2,
          nm850RightOuter: ppg3,
          nm850LeftInner: ppg2,
          nm850RightInner: ppg3,
          redLeftOuter: ppg4,
          redRightOuter: ppg5,
          redLeftInner: ppg4,
          redRightInner: ppg5,
          ambientLeftOuter: ppg0,
          ambientRightOuter: ppg1,
          ambientLeftInner: ppg0,
          ambientRightInner: ppg1,
        );
        controller.add(sample);
      }
    });
  }

  void _ensureGlobalImuListener() {
    if (_globalImuSubscription != null) return;

    _globalImuSubscription = _platformChannel.getImuStream('global').listen((data) {
      final receivedDeviceId = data['deviceId'] as String?;
      if (receivedDeviceId == null) return;
      
      var controller = _imuControllers[receivedDeviceId];
      
      // Auto-create controller if it doesn't exist
      if (controller == null) {
        _imuControllers[receivedDeviceId] = StreamController<ImuSample>.broadcast();
        controller = _imuControllers[receivedDeviceId];
      }
      
      if (controller != null && !controller.isClosed) {
        // Get last sample or create zeroed one
        var lastSample = _lastImuSamples[receivedDeviceId] ?? 
            ImuSample(
              timestamp: DateTime.now(), 
              gyroX: 0, gyroY: 0, gyroZ: 0, 
              accelX: 0, accelY: 0, accelZ: 0
            );

        // Merge new data
        double accelX = lastSample.accelX;
        double accelY = lastSample.accelY;
        double accelZ = lastSample.accelZ;
        double gyroX = lastSample.gyroX;
        double gyroY = lastSample.gyroY;
        double gyroZ = lastSample.gyroZ;

        if (data.containsKey('accel_x')) {
          accelX = data['accel_x'] as double? ?? 0.0;
          accelY = data['accel_y'] as double? ?? 0.0;
          accelZ = data['accel_z'] as double? ?? 0.0;
        }

        if (data.containsKey('gyro_x')) {
          gyroX = data['gyro_x'] as double? ?? 0.0;
          gyroY = data['gyro_y'] as double? ?? 0.0;
          gyroZ = data['gyro_z'] as double? ?? 0.0;
        }

        final sample = ImuSample(
          timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int),
          gyroX: gyroX,
          gyroY: gyroY,
          gyroZ: gyroZ,
          accelX: accelX,
          accelY: accelY,
          accelZ: accelZ,
        );
        
        // Update state and emit
        _lastImuSamples[receivedDeviceId] = sample;
        controller.add(sample);
      }
    });
  }



  void _ensureGlobalHsiListener() {
    if (_globalHsiSubscription != null) return;

    _globalHsiSubscription = _platformChannel.getHsiStream('global').listen((data) {
      // HSI data from native: { "deviceId": "...", "TP9": {...}, ... }
      // We need to ensure native sends deviceId in HSI packet.
      // Looking at previous logs, EEG/BandPower/IMU/fNIRS all have deviceId.
      // Assuming HSI does too.
      final receivedDeviceId = data['deviceId'] as String?;
      
      var controller = _hsiControllers[receivedDeviceId];
      
      // Auto-create controller if it doesn't exist
      if (controller == null && receivedDeviceId != null) {
        _hsiControllers[receivedDeviceId] = StreamController<Map<String, HsiValue>>.broadcast();
        controller = _hsiControllers[receivedDeviceId];
      }
      
      if (controller != null && !controller.isClosed) {
        final hsiMap = <String, HsiValue>{};
        for (final channel in ['TP9', 'AF7', 'AF8', 'TP10']) {
          if (data.containsKey(channel)) {
            final channelData = Map<String, dynamic>.from(data[channel] as Map);
            hsiMap[channel] = HsiValue(
              value: channelData['value'] as int? ?? 4,
              isArtifactFree: channelData['artifact_free'] as bool? ?? false,
            );
          }
        }
        controller.add(hsiMap);
      }
    });
  }

  @override
  Stream<EegSample> subscribeToEeg(String deviceId) {
    _ensureGlobalEegListener();
    if (!_eegControllers.containsKey(deviceId)) {
      _eegControllers[deviceId] = StreamController<EegSample>.broadcast();
    }
    return _eegControllers[deviceId]!.stream;
  }

  @override
  Stream<BandPowerSample> subscribeToBandPowers(String deviceId) {
    _ensureGlobalBandPowerListener();
    if (!_bandPowerControllers.containsKey(deviceId)) {
      _bandPowerControllers[deviceId] = StreamController<BandPowerSample>.broadcast();
    }
    return _bandPowerControllers[deviceId]!.stream;
  }

  @override
  Stream<FnirsSample> subscribeToFnirs(String deviceId) {
    _ensureGlobalFnirsListener();
    if (!_fnirsControllers.containsKey(deviceId)) {
      _fnirsControllers[deviceId] = StreamController<FnirsSample>.broadcast();
    }
    return _fnirsControllers[deviceId]!.stream;
  }

  @override
  Stream<ImuSample> subscribeToImu(String deviceId) {
    _ensureGlobalImuListener();
    if (!_imuControllers.containsKey(deviceId)) {
      _imuControllers[deviceId] = StreamController<ImuSample>.broadcast();
    }
    return _imuControllers[deviceId]!.stream;
  }

  @override
  Stream<int> subscribeToBattery(String deviceId) {
    _ensureGlobalBatteryListener();
    if (!_batteryControllers.containsKey(deviceId)) {
      _batteryControllers[deviceId] = StreamController<int>.broadcast();
    }
    return _batteryControllers[deviceId]!.stream;
  }

  void _ensureGlobalBatteryListener() {
    if (_globalBatterySubscription != null) return;

    _globalBatterySubscription = _platformChannel.getBatteryStream('global').listen((data) {
      // Battery data from native: { "deviceId": "...", "level": 85 }
      if (data is Map) {
         final receivedDeviceId = data['deviceId'] as String?;
         final level = data['level'] as int?;
         
         if (receivedDeviceId != null && level != null) {
           var controller = _batteryControllers[receivedDeviceId];
           
           // Auto-create controller if it doesn't exist
           if (controller == null) {
             _batteryControllers[receivedDeviceId] = StreamController<int>.broadcast();
             controller = _batteryControllers[receivedDeviceId];
           }
           
           if (controller != null && !controller.isClosed) {
             controller.add(level);
           }
         }
      }
    });
  }

  @override
  Stream<Map<String, HsiValue>> subscribeToHsi(String deviceId) {
    _ensureGlobalHsiListener();
    if (!_hsiControllers.containsKey(deviceId)) {
      _hsiControllers[deviceId] = StreamController<Map<String, HsiValue>>.broadcast();
    }
    return _hsiControllers[deviceId]!.stream;
  }

  @override
  Future<void> dispose() async {
    await stopScanning();

    // Cancel global subscriptions
    await _globalEegSubscription?.cancel();
    await _globalBandPowerSubscription?.cancel();
    await _globalFnirsSubscription?.cancel();
    await _globalImuSubscription?.cancel();
    await _globalBatterySubscription?.cancel();
    await _globalHsiSubscription?.cancel();

    // Clean up all controllers
    for (var controller in _eegControllers.values) await controller.close();
    _eegControllers.clear();

    for (var controller in _bandPowerControllers.values) await controller.close();
    _bandPowerControllers.clear();

    for (var controller in _fnirsControllers.values) await controller.close();
    _fnirsControllers.clear();

    for (var controller in _imuControllers.values) await controller.close();
    _imuControllers.clear();

    for (var controller in _batteryControllers.values) await controller.close();
    _batteryControllers.clear();

    for (var controller in _hsiControllers.values) await controller.close();
    _hsiControllers.clear();
  }
}

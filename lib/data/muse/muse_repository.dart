import 'dart:async';
import 'dart:math';
import '../../domain/models/muse_device.dart';
import '../../domain/models/eeg_sample.dart';
import '../../domain/models/band_power_sample.dart';
import '../../domain/models/fnirs_sample.dart';
import '../../domain/models/imu_sample.dart';
import 'muse_service.dart';

// Mock implementation - generates fake data for testing without a real headband.
// Replace calls here with platform channel calls to the native Muse SDK.
class MuseRepository implements MuseService {
  final _random = Random();
  final Map<String, StreamController<EegSample>> _eegControllers = {};
  final Map<String, StreamController<BandPowerSample>> _bandPowerControllers =
      {};
  final Map<String, StreamController<FnirsSample>> _fnirsControllers = {};
  final Map<String, StreamController<ImuSample>> _imuControllers = {};
  final Map<String, StreamController<int>> _batteryControllers = {};
  final Map<String, StreamController<Map<String, HsiValue>>> _hsiControllers =
      {};

  StreamController<List<MuseDevice>>? _scanController;
  final List<MuseDevice> _discoveredDevices = [];
  Timer? _scanTimer;

  @override
  Stream<List<MuseDevice>> scanForDevices() {
    // Replace with IXNMuseManager.startListening() (iOS) or MuseManager.getMuseList() (Android)
    _scanController = StreamController<List<MuseDevice>>.broadcast();

    // Fake discovery - add 2 devices over 2 seconds
    _discoveredDevices.clear();
    _scanTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_discoveredDevices.length < 2) {
        final device = MuseDevice(
          id: 'MUSE-${_discoveredDevices.length + 1}',
          name: 'Muse S ${_discoveredDevices.length == 0 ? "Athena" : "Gen 2"}',
          isConnected: false,
          batteryPercent: 75 + _random.nextInt(20),
        );
        _discoveredDevices.add(device);
        _scanController?.add(List.from(_discoveredDevices));
      } else {
        timer.cancel();
      }
    });

    return _scanController!.stream;
  }

  @override
  Future<void> stopScanning() async {
    _scanTimer?.cancel();
    await _scanController?.close();
    _scanController = null;
  }

  @override
  Future<void> connectToDevice(String deviceId) async {
    // Real impl: get Muse by ID and call muse.connect()
    print('Connecting to device: $deviceId');
    await Future.delayed(const Duration(seconds: 1));

    final index = _discoveredDevices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      _discoveredDevices[index] =
          _discoveredDevices[index].copyWith(isConnected: true);
    }
    print('Connected to device: $deviceId');
  }

  @override
  Future<void> disconnectDevice(String deviceId) async {
    print('Disconnecting from device: $deviceId');

    // Tear down streams
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

    final index = _discoveredDevices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      _discoveredDevices[index] =
          _discoveredDevices[index].copyWith(isConnected: false);
    }
  }

  @override
  Stream<EegSample> subscribeToEeg(String deviceId) {
    // Real impl: muse.register(listener, dataType: .EEG) at 256 Hz
    if (!_eegControllers.containsKey(deviceId)) {
      _eegControllers[deviceId] = StreamController<EegSample>.broadcast();

      // Fake 256 Hz EEG
      Timer.periodic(const Duration(milliseconds: 4), (timer) {
        if (!_eegControllers.containsKey(deviceId)) {
          timer.cancel();
          return;
        }

        final sample = EegSample(
          timestamp: DateTime.now(),
          tp9: _generateEegValue(),
          af7: _generateEegValue(),
          af8: _generateEegValue(),
          tp10: _generateEegValue(),
          drl: _generateEegValue() * 0.5,
          ref: _generateEegValue() * 0.5,
        );

        _eegControllers[deviceId]?.add(sample);
      });
    }

    return _eegControllers[deviceId]!.stream;
  }

  @override
  Stream<BandPowerSample> subscribeToBandPowers(String deviceId) {
    // Real impl: register for ALPHA_ABSOLUTE, ALPHA_RELATIVE, etc. (~10 Hz)
    if (!_bandPowerControllers.containsKey(deviceId)) {
      _bandPowerControllers[deviceId] =
          StreamController<BandPowerSample>.broadcast();

      Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!_bandPowerControllers.containsKey(deviceId)) {
          timer.cancel();
          return;
        }

        final sample = BandPowerSample(
          timestamp: DateTime.now(),
          tp9: _generateChannelBandPower(),
          af7: _generateChannelBandPower(),
          af8: _generateChannelBandPower(),
          tp10: _generateChannelBandPower(),
        );

        _bandPowerControllers[deviceId]?.add(sample);
      });
    }

    return _bandPowerControllers[deviceId]!.stream;
  }

  @override
  Stream<FnirsSample> subscribeToFnirs(String deviceId) {
    // Athena only - register for fNIRS packets (~64 Hz)
    if (!_fnirsControllers.containsKey(deviceId)) {
      _fnirsControllers[deviceId] = StreamController<FnirsSample>.broadcast();

      Timer.periodic(const Duration(milliseconds: 16), (timer) {
        if (!_fnirsControllers.containsKey(deviceId)) {
          timer.cancel();
          return;
        }

        final sample = FnirsSample(
          timestamp: DateTime.now(),
          nm730LeftOuter: _generateFnirsValue(),
          nm730RightOuter: _generateFnirsValue(),
          nm730LeftInner: _generateFnirsValue(),
          nm730RightInner: _generateFnirsValue(),
          nm850LeftOuter: _generateFnirsValue() * 1.2,
          nm850RightOuter: _generateFnirsValue() * 1.2,
          nm850LeftInner: _generateFnirsValue() * 1.2,
          nm850RightInner: _generateFnirsValue() * 1.2,
          redLeftOuter: _generateFnirsValue() * 0.8,
          redRightOuter: _generateFnirsValue() * 0.8,
          redLeftInner: _generateFnirsValue() * 0.8,
          redRightInner: _generateFnirsValue() * 0.8,
          ambientLeftOuter: _generateFnirsValue() * 0.3,
          ambientRightOuter: _generateFnirsValue() * 0.3,
          ambientLeftInner: _generateFnirsValue() * 0.3,
          ambientRightInner: _generateFnirsValue() * 0.3,
        );

        _fnirsControllers[deviceId]?.add(sample);
      });
    }

    return _fnirsControllers[deviceId]!.stream;
  }

  @override
  Stream<ImuSample> subscribeToImu(String deviceId) {
    // Real impl: register for ACCELEROMETER + GYRO (~52 Hz)
    if (!_imuControllers.containsKey(deviceId)) {
      _imuControllers[deviceId] = StreamController<ImuSample>.broadcast();

      Timer.periodic(const Duration(milliseconds: 19), (timer) {
        if (!_imuControllers.containsKey(deviceId)) {
          timer.cancel();
          return;
        }

        final sample = ImuSample(
          timestamp: DateTime.now(),
          gyroX: (_random.nextDouble() - 0.5) * 20,
          gyroY: (_random.nextDouble() - 0.5) * 20,
          gyroZ: (_random.nextDouble() - 0.5) * 20,
          accelX: (_random.nextDouble() - 0.5) * 2,
          accelY: (_random.nextDouble() - 0.5) * 2,
          accelZ: 1.0 + (_random.nextDouble() - 0.5) * 0.2,
        );

        _imuControllers[deviceId]?.add(sample);
      });
    }

    return _imuControllers[deviceId]!.stream;
  }

  @override
  Stream<int> subscribeToBattery(String deviceId) {
    // Real impl: register for BATTERY updates (1 Hz)
    if (!_batteryControllers.containsKey(deviceId)) {
      _batteryControllers[deviceId] = StreamController<int>.broadcast();

      var battery = 85;
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!_batteryControllers.containsKey(deviceId)) {
          timer.cancel();
          return;
        }

        battery = (battery - 0.1).clamp(0, 100).toInt();
        _batteryControllers[deviceId]?.add(battery);
      });
    }

    return _batteryControllers[deviceId]!.stream;
  }

  @override
  Stream<Map<String, HsiValue>> subscribeToHsi(String deviceId) {
    // Real impl: register for HSI (quality indicator) at ~2 Hz
    // Values: 1 = good, 2 = medium, 4 = bad
    if (!_hsiControllers.containsKey(deviceId)) {
      _hsiControllers[deviceId] =
          StreamController<Map<String, HsiValue>>.broadcast();

      Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (!_hsiControllers.containsKey(deviceId)) {
          timer.cancel();
          return;
        }

        final hsiMap = {
          'TP9': HsiValue(
            value: [1, 1, 1, 2][_random.nextInt(4)],
            isArtifactFree: _random.nextDouble() > 0.2,
          ),
          'AF7': HsiValue(
            value: [1, 1, 2, 2][_random.nextInt(4)],
            isArtifactFree: _random.nextDouble() > 0.2,
          ),
          'AF8': HsiValue(
            value: [1, 1, 2, 4][_random.nextInt(4)],
            isArtifactFree: _random.nextDouble() > 0.15,
          ),
          'TP10': HsiValue(
            value: [1, 1, 1, 1][_random.nextInt(4)],
            isArtifactFree: _random.nextDouble() > 0.1,
          ),
        };

        _hsiControllers[deviceId]?.add(hsiMap);
      });
    }

    return _hsiControllers[deviceId]!.stream;
  }

  @override
  Future<void> dispose() async {
    await stopScanning();

    for (var controller in _eegControllers.values) {
      await controller.close();
    }
    _eegControllers.clear();

    for (var controller in _bandPowerControllers.values) {
      await controller.close();
    }
    _bandPowerControllers.clear();

    for (var controller in _fnirsControllers.values) {
      await controller.close();
    }
    _fnirsControllers.clear();

    for (var controller in _imuControllers.values) {
      await controller.close();
    }
    _imuControllers.clear();

    for (var controller in _batteryControllers.values) {
      await controller.close();
    }
    _batteryControllers.clear();

    for (var controller in _hsiControllers.values) {
      await controller.close();
    }
    _hsiControllers.clear();
  }

  // --- Mock data helpers ---
  
  double _generateEegValue() {
    return (_random.nextDouble() - 0.5) * 100; // ±100 µV typical
  }

  ChannelBandPower _generateChannelBandPower() {
    final totalPower = 10.0 + _random.nextDouble() * 20;
    final delta = _random.nextDouble() * totalPower * 0.3;
    final theta = _random.nextDouble() * totalPower * 0.2;
    final alpha = _random.nextDouble() * totalPower * 0.3;
    final beta = _random.nextDouble() * totalPower * 0.15;
    final gamma = _random.nextDouble() * totalPower * 0.05;

    final sum = delta + theta + alpha + beta + gamma;

    return ChannelBandPower(
      deltaAbsolute: delta,
      thetaAbsolute: theta,
      alphaAbsolute: alpha,
      betaAbsolute: beta,
      gammaAbsolute: gamma,
      deltaRelative: delta / sum,
      thetaRelative: theta / sum,
      alphaRelative: alpha / sum,
      betaRelative: beta / sum,
      gammaRelative: gamma / sum,
    );
  }

  double _generateFnirsValue() {
    return 1000 + _random.nextDouble() * 500;
  }
}

import '../../domain/models/muse_device.dart';
import '../../domain/models/eeg_sample.dart';
import '../../domain/models/band_power_sample.dart';
import '../../domain/models/fnirs_sample.dart';
import '../../domain/models/imu_sample.dart';

// Interface for Muse SDK - implement this for real hardware
abstract class MuseService {
  Stream<List<MuseDevice>> scanForDevices();
  Future<void> stopScanning();
  Future<void> connectToDevice(String deviceId);
  Future<void> disconnectDevice(String deviceId);

  // Raw EEG at 256 Hz
  Stream<EegSample> subscribeToEeg(String deviceId);

  // Band powers (delta/theta/alpha/beta/gamma) at ~10 Hz
  Stream<BandPowerSample> subscribeToBandPowers(String deviceId);

  // fNIRS at ~64 Hz (Athena models only)
  Stream<FnirsSample> subscribeToFnirs(String deviceId);

  // Gyro + accel at ~52 Hz
  Stream<ImuSample> subscribeToImu(String deviceId);

  // Battery updates at ~1 Hz
  Stream<int> subscribeToBattery(String deviceId);

  // Contact quality: TP9/AF7/AF8/TP10, values 1=good/2=ok/4=bad
  Stream<Map<String, HsiValue>> subscribeToHsi(String deviceId);

  Future<void> dispose();
}

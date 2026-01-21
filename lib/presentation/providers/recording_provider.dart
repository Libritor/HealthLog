import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/session_config.dart';
import '../../domain/models/band_power_sample.dart';
import '../../domain/models/fnirs_sample.dart';
import '../../domain/models/imu_sample.dart';
import '../../data/storage/csv_writer.dart';
import '../../data/storage/file_storage_helper.dart';
import '../../core/constants.dart';
import 'device_provider.dart';

final sessionConfigProvider =
    StateNotifierProvider<SessionConfigNotifier, SessionConfig?>((ref) {
  return SessionConfigNotifier();
});

class SessionConfigNotifier extends StateNotifier<SessionConfig?> {
  SessionConfigNotifier() : super(null);

  void createConfig({
    required List<String> selectedDeviceIds,
    required Set<String> selectedColumns,
    required String sessionName,
    String notes = '',
  }) {
    state = SessionConfig(
      selectedDeviceIds: selectedDeviceIds,
      selectedColumns: selectedColumns,
      sessionName: sessionName,
      notes: notes,
      startTime: DateTime.now(),
    );
  }

  void clearConfig() {
    state = null;
  }
}

final recordingStateProvider =
    StateNotifierProvider<RecordingStateNotifier, RecordingState>((ref) {
  return RecordingStateNotifier();
});

class RecordingStateNotifier extends StateNotifier<RecordingState> {
  RecordingStateNotifier() : super(RecordingState.idle);

  void startRecording() => state = RecordingState.recording;
  void pauseRecording() => state = RecordingState.paused;
  void resumeRecording() => state = RecordingState.recording;
  void stopRecording() => state = RecordingState.stopped;
  void reset() => state = RecordingState.idle;
}

// Column selection for CSV export
final selectedColumnsProvider =
    StateNotifierProvider<SelectedColumnsNotifier, Set<String>>((ref) {
  return SelectedColumnsNotifier();
});

class SelectedColumnsNotifier extends StateNotifier<Set<String>> {
  SelectedColumnsNotifier() : super(Set.from(AppConstants.csvColumns));

  void toggleColumn(String column) {
    if (state.contains(column)) {
      state = Set.from(state)..remove(column);
    } else {
      state = Set.from(state)..add(column);
    }
  }

  void toggleGroup(String groupName, bool selected) {
    final groupColumns = AppConstants.columnGroups[groupName] ?? [];
    if (selected) {
      state = Set.from(state)..addAll(groupColumns);
    } else {
      state = Set.from(state)..removeAll(groupColumns);
    }
  }

  void selectAll() {
    state = Set.from(AppConstants.csvColumns);
  }

  void clearAll() {
    state = {};
  }
}

// One CSV writer per device
final csvWritersProvider =
    StateNotifierProvider<CsvWritersNotifier, Map<String, CsvWriter>>((ref) {
  return CsvWritersNotifier();
});

class CsvWritersNotifier extends StateNotifier<Map<String, CsvWriter>> {
  CsvWritersNotifier() : super({});

  Future<void> createWriter(String deviceId, String deviceName, List<String> selectedColumns,
      {DateTime? sessionStartTime}) async {
    final file = await FileStorageHelper.generateCsvFilePath(
      deviceId,
      deviceName: deviceName,
      sessionStartTime: sessionStartTime,
    );
    final writer = await CsvWriter.create(file, selectedColumns);
    await writer.writeHeader();
    state = {...state, deviceId: writer};
  }

  CsvWriter? getWriter(String deviceId) => state[deviceId];

  Future<void> closeAll() async {
    for (var writer in state.values) {
      await writer.close();
    }
    state = {};
  }

  Future<void> closeWriter(String deviceId) async {
    final writer = state[deviceId];
    if (writer != null) {
      await writer.close();
      final newState = Map<String, CsvWriter>.from(state);
      newState.remove(deviceId);
      state = newState;
    }
  }
}

final recordingManagerProvider = Provider<RecordingManager>((ref) {
  return RecordingManager(ref);
});

// Coordinates recording across all connected devices.
class RecordingManager {
  final Ref ref;
  final Map<String, StreamSubscription> _subscriptions = {};
  Timer? _recordingTimer;
  DateTime? _sessionStartTime;
  int _elapsedSeconds = 0;

  // Buffer latest data from slower streams to merge with EEG
  final Map<String, BandPowerSample> _latestBandPower = {};
  final Map<String, FnirsSample> _latestFnirs = {};
  final Map<String, ImuSample> _latestImu = {};

  RecordingManager(this.ref);

  Future<void> startRecording() async {
    final config = ref.read(sessionConfigProvider);
    if (config == null) {
      throw Exception('Session config not set');
    }

    _sessionStartTime = DateTime.now();
    _elapsedSeconds = 0;

    _latestBandPower.clear();
    _latestFnirs.clear();
    _latestImu.clear();

    final csvWritersNotifier = ref.read(csvWritersProvider.notifier);
    final deviceNamesNotifier = ref.read(deviceNamesProvider.notifier);
    
    for (var deviceId in config.selectedDeviceIds) {
      final deviceName = deviceNamesNotifier.assignName(deviceId);
      
      await csvWritersNotifier.createWriter(
        deviceId,
        deviceName,
        config.selectedColumns.toList(),
        sessionStartTime: _sessionStartTime,
      );
    }

    for (var deviceId in config.selectedDeviceIds) {
      _subscribeToDeviceStreams(deviceId);
    }

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
    });

    ref.read(recordingStateProvider.notifier).startRecording();
  }

  // EEG drives CSV writes, other streams just buffer their latest values.
  void _subscribeToDeviceStreams(String deviceId) {
    final csvWriters = ref.read(csvWritersProvider);
    final writer = csvWriters[deviceId];
    if (writer == null) return;

    final connectedDevices = ref.read(connectedDevicesProvider);
    final device = connectedDevices[deviceId];
    if (device == null) return;

    final deviceName = ref.read(deviceNamesProvider)[deviceId] ?? 'Unknown';

    // EEG at 256 Hz - main driver
    final eegSub = ref.read(eegStreamProvider(deviceId).stream).listen(
      (eegSample) {
        writer.writeRow(
          packetType: 'EEG',
          deviceName: deviceName,
          timestamp: eegSample.timestamp,
          device: device,
          eegSample: eegSample,
          bandPowerSample: _latestBandPower[deviceId],
          fnirsSample: _latestFnirs[deviceId],
          imuSample: _latestImu[deviceId],
        );
      },
      onError: (error) => print('EEG stream error for $deviceId: $error'),
    );
    _subscriptions['${deviceId}_eeg'] = eegSub;

    // Band powers at ~10 Hz
    final bandPowerSub =
        ref.read(bandPowerStreamProvider(deviceId).stream).listen(
      (bandPowerSample) {
        _latestBandPower[deviceId] = bandPowerSample;
      },
      onError: (error) =>
          print('Band power stream error for $deviceId: $error'),
    );
    _subscriptions['${deviceId}_bandpower'] = bandPowerSub;

    // fNIRS at ~64 Hz
    final fnirsSub = ref.read(fnirsStreamProvider(deviceId).stream).listen(
      (fnirsSample) {
        print('fNIRS data received for $deviceId: 730nm_LO=${fnirsSample.nm730LeftOuter}, 850nm_LO=${fnirsSample.nm850LeftOuter}');
        _latestFnirs[deviceId] = fnirsSample;
      },
      onError: (error) => print('fNIRS stream error for $deviceId: $error'),
    );
    _subscriptions['${deviceId}_fnirs'] = fnirsSub;

    // IMU at ~52 Hz
    final imuSub = ref.read(imuStreamProvider(deviceId).stream).listen(
      (imuSample) {
        _latestImu[deviceId] = imuSample;
      },
      onError: (error) => print('IMU stream error for $deviceId: $error'),
    );
    _subscriptions['${deviceId}_imu'] = imuSub;
  }

  Future<void> stopRecording() async {
    for (var sub in _subscriptions.values) {
      await sub.cancel();
    }
    _subscriptions.clear();

    _recordingTimer?.cancel();
    _recordingTimer = null;

    await ref.read(csvWritersProvider.notifier).closeAll();

    ref.read(recordingStateProvider.notifier).stopRecording();
  }

  void addTrigger() {
    final csvWriters = ref.read(csvWritersProvider);
    for (var writer in csvWriters.values) {
      writer.incrementTrigger();
    }
  }

  int get elapsedSeconds => _elapsedSeconds;
  DateTime? get sessionStartTime => _sessionStartTime;

  void dispose() {
    for (var sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    _recordingTimer?.cancel();
  }
}

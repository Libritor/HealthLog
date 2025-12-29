import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/device_provider.dart';
import '../providers/recording_provider.dart';
import '../../domain/models/session_config.dart';
import '../widgets/hsi_indicator.dart';
import '../widgets/eeg_chart.dart';
import '../widgets/fnirs_chart.dart';
import '../widgets/imu_chart.dart';
import '../widgets/band_power_chart.dart';
import '../../data/muse/osc_service.dart';
import '../providers/osc_streaming_provider.dart';
import 'post_session_screen.dart';

// Main recording screen with live data visualization.
class LiveSessionScreen extends ConsumerStatefulWidget {
  const LiveSessionScreen({super.key});

  @override
  ConsumerState<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends ConsumerState<LiveSessionScreen> {
  @override
  void initState() {
    super.initState();
    // Start recording when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRecording();
    });
  }

  Future<void> _startRecording() async {
    final recordingManager = ref.read(recordingManagerProvider);
    try {
      await recordingManager.startRecording();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordingState = ref.watch(recordingStateProvider);
    final connectedDevices = ref.watch(connectedDevicesProvider);
    final config = ref.watch(sessionConfigProvider);
    
    // Initialize OSC Manager
    ref.watch(oscStreamingManagerProvider);
    final isOscStreaming = ref.watch(isOscStreamingProvider);

    if (config == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session')),
        body: const Center(child: Text('No session configured')),
      );
    }

    final deviceIds = config.selectedDeviceIds;

    return WillPopScope(
      onWillPop: () async {
        final shouldPop = await _showStopConfirmation();
        return shouldPop ?? false;
      },
      child: DefaultTabController(
        length: deviceIds.length,
        child: Scaffold(
          appBar: AppBar(
            title: Text(config.sessionName),
            bottom: deviceIds.length > 1
                ? TabBar(
                    tabs: deviceIds.asMap().entries.map((entry) {
                      final index = entry.key;
                      final id = entry.value;
                      final device = connectedDevices[id];
                      final personLabel = index == 0 ? 'Person 1' : index == 1 ? 'Person 2' : 'Person ${index + 1}';
                      return Tab(text: '${device?.name ?? id}\n($personLabel)');
                    }).toList(),
                  )
                : null,
            actions: [
              IconButton(
                icon: Icon(
                  isOscStreaming ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                  color: isOscStreaming ? Colors.greenAccent : null,
                ),
                onPressed: () => _showOscSettings(context),
                tooltip: 'OSC Streaming Settings',
              ),
            ],
          ),
          body: Column(
            children: [
              // Recording status bar
              Container(
                padding: const EdgeInsets.all(12),
                color: recordingState == RecordingState.recording
                    ? Colors.red.shade700
                    : Colors.grey,
                child: Row(
                  children: [
                    Icon(
                      recordingState == RecordingState.recording
                          ? Icons.fiber_manual_record
                          : Icons.pause,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      recordingState == RecordingState.recording
                          ? 'RECORDING'
                          : 'PAUSED',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.timer, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    _buildTimer(),
                  ],
                ),
              ),

              // TabBarView is lazy, so we need hidden widgets to keep all streams alive.
              ...deviceIds.map((deviceId) => _StreamKeeper(deviceId: deviceId)),

              // Device tabs
              Expanded(
                child: deviceIds.length > 1
                    ? TabBarView(
                        children: deviceIds
                            .map((deviceId) => _buildDeviceView(deviceId))
                            .toList(),
                      )
                    : _buildDeviceView(deviceIds.first),
              ),

              // Bottom controls
              _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimer() {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final recordingManager = ref.read(recordingManagerProvider);
        final elapsed = recordingManager.elapsedSeconds;
        final minutes = elapsed ~/ 60;
        final seconds = elapsed % 60;
        return Text(
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        );
      },
    );
  }

  Widget _buildDeviceView(String deviceId) {
    final connectedDevices = ref.watch(connectedDevicesProvider);
    final device = connectedDevices[deviceId];

    if (device == null) {
      return const Center(child: Text('Device not connected'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HSI and battery
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              HsiIndicator(
                tp9: device.tp9Hsi,
                af7: device.af7Hsi,
                af8: device.af8Hsi,
                tp10: device.tp10Hsi,
              ),
              Column(
                children: [
                  const Icon(Icons.battery_std, size: 48),
                  Text(
                    '${device.batteryPercent}%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // EEG Chart
          Text(
            'EEG Raw Data',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: ref.watch(eegStreamProvider(deviceId)).when(
                  data: (eegSample) => EegChart(
                    dataStream: ref.read(eegStreamProvider(deviceId).stream),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error: $e')),
                ),
          ),

          const SizedBox(height: 24),

          // Band Powers
          Text(
            'Band Powers',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: ref.watch(bandPowerStreamProvider(deviceId)).when(
                  data: (sample) => BandPowerChart(
                    dataStream: ref.read(bandPowerStreamProvider(deviceId).stream),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error: $e')),
                ),
          ),

          const SizedBox(height: 24),

          // fNIRS (Oxygenation) - Only for Muse S
          if (device.name.contains('Muse S')) ...[
            Text(
              'fNIRS (Oxygenation)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ref.watch(fnirsStreamProvider(deviceId)).when(
                    data: (sample) => FnirsChart(
                      dataStream: ref.read(fnirsStreamProvider(deviceId).stream),
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text('Error: $e')),
                  ),
            ),
            const SizedBox(height: 24),
          ],

          const SizedBox(height: 24),

          // IMU
          Text(
            'IMU (Motion)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ref.watch(imuStreamProvider(deviceId)).when(
                data: (sample) => ImuChart(
                  dataStream: ref.read(imuStreamProvider(deviceId).stream),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error: $e')),
              ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _addTrigger,
              icon: const Icon(Icons.flag),
              label: const Text('Add Marker'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _stopRecording,
              icon: const Icon(Icons.stop),
              label: const Text('Stop & Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addTrigger() {
    final recordingManager = ref.read(recordingManagerProvider);
    recordingManager.addTrigger();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Marker added'),
        duration: Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> _stopRecording() async {
    final recordingManager = ref.read(recordingManagerProvider);
    await recordingManager.stopRecording();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const PostSessionScreen(),
        ),
      );
    }
  }

  Future<bool?> _showStopConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Recording?'),
        content: const Text(
          'Are you sure you want to stop recording? This will save the session data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Recording'),
          ),
          TextButton(
            onPressed: () async {
              await _stopRecording();
              if (mounted) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Stop & Save'),
          ),
        ],
      ),
    );
  }

  void _showOscSettings(BuildContext context) {
    final ipController = TextEditingController(text: ref.read(oscTargetIpProvider));
    final ports = ref.read(oscTargetPortsProvider);
    final portController = TextEditingController(text: ports.join(', '));
    final config = ref.read(sessionConfigProvider);

    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final isStreaming = ref.watch(isOscStreamingProvider);
          final connectedDevices = ref.read(connectedDevicesProvider);
          final deviceIds = config?.selectedDeviceIds ?? [];
          
          return AlertDialog(
            title: const Text('OSC Streaming Settings'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stream Band Powers to VR Headset via Wi-Fi.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  
                  // Device mapping info
                  if (deviceIds.length >= 2) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Device Mapping:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          for (int i = 0; i < deviceIds.length && i < 2; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '• ${connectedDevices[deviceIds[i]]?.name ?? deviceIds[i]} → Person ${i + 1} (Port ${5000 + i}, /person${i + 1}/eeg)',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  TextField(
                    controller: ipController,
                    decoration: const InputDecoration(
                      labelText: 'Target IP Address',
                      hintText: 'e.g. 192.168.1.100',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !isStreaming,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: portController,
                    decoration: const InputDecoration(
                      labelText: 'Target Ports (comma separated)',
                      hintText: '5000, 5001',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text, // Changed to text to allow commas
                    enabled: !isStreaming,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (isStreaming) {
                    ref.read(isOscStreamingProvider.notifier).state = false;
                  } else {
                    // Save settings and start
                    ref.read(oscTargetIpProvider.notifier).state = ipController.text;
                    
                    // Parse ports
                    final portString = portController.text;
                    final portList = portString
                        .split(',')
                        .map((s) => int.tryParse(s.trim()))
                        .where((p) => p != null)
                        .cast<int>()
                        .toList();
                        
                    if (portList.isEmpty) {
                       // Fallback if parsing fails
                       portList.add(5000);
                    }

                    ref.read(oscTargetPortsProvider.notifier).state = portList;
                    ref.read(isOscStreamingProvider.notifier).state = true;
                    // Trigger refresh to ensure subscriptions pick up new state
                    ref.read(oscStreamingManagerProvider).refreshSubscriptions();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('OSC Streaming Started')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isStreaming ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(isStreaming ? Icons.stop : Icons.play_arrow),
                label: Text(isStreaming ? 'Stop Streaming' : 'Start Streaming'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Keeps streams alive for tabs that aren't visible. Also syncs battery/HSI to device state.
class _StreamKeeper extends ConsumerStatefulWidget {
  final String deviceId;

  const _StreamKeeper({required this.deviceId});

  @override
  ConsumerState<_StreamKeeper> createState() => _StreamKeeperState();
}

class _StreamKeeperState extends ConsumerState<_StreamKeeper> {
  @override
  Widget build(BuildContext context) {
    // Watch all streams to keep them alive
    ref.watch(eegStreamProvider(widget.deviceId));
    ref.watch(bandPowerStreamProvider(widget.deviceId));
    ref.watch(fnirsStreamProvider(widget.deviceId));
    ref.watch(imuStreamProvider(widget.deviceId));
    
    // Battery stream - update device state when data arrives
    ref.watch(batteryStreamProvider(widget.deviceId)).whenData((battery) {
      ref.read(connectedDevicesProvider.notifier).updateBattery(widget.deviceId, battery);
    });
    
    // HSI stream -  update device state when data arrives
    ref.watch(hsiStreamProvider(widget.deviceId)).whenData((hsiMap) {
      ref.read(connectedDevicesProvider.notifier).updateHsi(widget.deviceId, hsiMap);
    });
    
    // Return invisible widget
    return const SizedBox.shrink();
  }
}

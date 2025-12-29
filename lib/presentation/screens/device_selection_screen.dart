import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/device_provider.dart';
import '../providers/recording_provider.dart';
import 'recording_config_screen.dart';

/// Device selection and scanning screen
class DeviceSelectionScreen extends ConsumerStatefulWidget {
  const DeviceSelectionScreen({super.key});

  @override
  ConsumerState<DeviceSelectionScreen> createState() =>
      _DeviceSelectionScreenState();
}

class _DeviceSelectionScreenState
    extends ConsumerState<DeviceSelectionScreen> {
  bool _isScanning = false;

  @override
  Widget build(BuildContext context) {
    final deviceScanAsync = ref.watch(deviceScanProvider);
    final selectedDevices = ref.watch(selectedDevicesProvider);
    final connectedDevices = ref.watch(connectedDevicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Muse Devices'),
        elevation: 2,
      ),
      body: Column(
        children: [
          // Scan control
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _startScan,
                    icon: Icon(_isScanning ? Icons.bluetooth_searching : Icons.bluetooth),
                    label: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
                  ),
                ),
                if (_isScanning) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _stopScan,
                    icon: const Icon(Icons.stop),
                    tooltip: 'Stop Scan',
                  ),
                ],
              ],
            ),
          ),

          // Device list
          Expanded(
            child: deviceScanAsync.when(
              data: (devices) {
                if (devices.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No devices found'),
                        SizedBox(height: 8),
                        Text('Tap "Scan for Devices" to start'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: devices.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    final isSelected = selectedDevices.contains(device.id);
                    final isConnected = connectedDevices.containsKey(device.id);

                    final displayDevice = connectedDevices[device.id] ?? device;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (checked) {
                          ref.read(selectedDevicesProvider.notifier).toggleDevice(device.id);
                        },
                        title: Text(
                          device.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${device.id}'),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  isConnected ? Icons.link : Icons.link_off,
                                  size: 16,
                                  color: isConnected ? Colors.green : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isConnected ? 'Connected' : 'Disconnected',
                                  style: TextStyle(
                                    color: isConnected ? Colors.green : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        secondary: (isConnected && displayDevice.batteryPercent > 0)
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.battery_std),
                                  Text('${displayDevice.batteryPercent}%'),
                                ],
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                  ],
                ),
              ),
            ),
          ),

          // Bottom action buttons
          Container(
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
            child: Column(
              children: [
                if (selectedDevices.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${selectedDevices.length} device(s) selected',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: selectedDevices.isEmpty ? null : _connectSelected,
                        child: const Text('Connect Selected'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedDevices.isEmpty ? null : _startSession,
                        child: const Text('Start Session'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startScan() async {
    // Request permissions first
    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
      }
    });

    if (!allGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth and Location permissions are required to scan.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isScanning = true;
    });
    
    // Force a refresh of the scan provider to restart the scanning process
    // This ensures that if the previous scan failed due to missing permissions,
    // a new scan is started now that permissions are granted.
    ref.invalidate(deviceScanProvider);
  }

  void _stopScan() async {
    await ref.read(museServiceProvider).stopScanning();
    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _connectSelected() async {
    final selectedDeviceIds = ref.read(selectedDevicesProvider);
    final museService = ref.read(museServiceProvider);
    final connectedNotifier = ref.read(connectedDevicesProvider.notifier);
    final deviceList = ref.read(deviceScanProvider).value ?? [];

    for (var deviceId in selectedDeviceIds) {
      try {
        await museService.connectToDevice(deviceId);
        final device = deviceList.firstWhere((d) => d.id == deviceId);
        connectedNotifier.addDevice(device.copyWith(isConnected: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connected to ${device.name}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to connect: $e')),
          );
        }
      }
    }
  }

  void _startSession() {
    final selectedDeviceIds = ref.read(selectedDevicesProvider);
    if (selectedDeviceIds.isEmpty) return;

    // Check if all selected devices are connected
    final connectedDevices = ref.read(connectedDevicesProvider);
    final notConnected = selectedDeviceIds.where((id) => !connectedDevices.containsKey(id));

    if (notConnected.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please connect all selected devices before starting.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Navigate to recording configuration
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecordingConfigScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _stopScan();
    super.dispose();
  }
}

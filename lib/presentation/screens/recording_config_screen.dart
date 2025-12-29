import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/device_provider.dart';
import '../providers/recording_provider.dart';
import '../../core/constants.dart';
import 'live_session_screen.dart';

/// Recording configuration screen
/// Allows user to select columns and configure session metadata
class RecordingConfigScreen extends ConsumerStatefulWidget {
  const RecordingConfigScreen({super.key});

  @override
  ConsumerState<RecordingConfigScreen> createState() =>
      _RecordingConfigScreenState();
}

class _RecordingConfigScreenState
    extends ConsumerState<RecordingConfigScreen> {
  final _sessionNameController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sessionNameController.text = 'Session ${DateTime.now().toIso8601String().substring(0, 10)}';
  }

  @override
  Widget build(BuildContext context) {
    final selectedDevices = ref.watch(selectedDevicesProvider);
    final selectedColumns = ref.watch(selectedColumnsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Recording'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Session metadata
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session Info',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _sessionNameController,
                          decoration: const InputDecoration(
                            labelText: 'Session Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes (optional)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Recording ${selectedDevices.length} device(s)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Column selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Select Data Columns',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${selectedColumns.length}/${AppConstants.csvColumns.length}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                ref.read(selectedColumnsProvider.notifier).selectAll();
                              },
                              child: const Text('Select All'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () {
                                ref.read(selectedColumnsProvider.notifier).clearAll();
                              },
                              child: const Text('Clear All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Column groups
                        ...AppConstants.columnGroups.entries.map((entry) {
                          final groupName = entry.key;
                          final groupColumns = entry.value;
                          final allSelected = groupColumns.every(selectedColumns.contains);
                          final someSelected = groupColumns.any(selectedColumns.contains);

                          return CheckboxListTile(
                            title: Text(groupName),
                            subtitle: Text('${groupColumns.length} columns'),
                            value: allSelected,
                            tristate: true,
                            onChanged: (checked) {
                              ref.read(selectedColumnsProvider.notifier).toggleGroup(
                                    groupName,
                                    checked ?? !allSelected,
                                  );
                            },
                            secondary: someSelected && !allSelected
                                ? const Icon(Icons.indeterminate_check_box)
                                : null,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Start recording button
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
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: selectedColumns.isEmpty ? null : _startRecording,
                icon: const Icon(Icons.fiber_manual_record),
                label: const Text('Start Recording'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startRecording() {
    final selectedDeviceIds = ref.read(selectedDevicesProvider).toList();
    final selectedColumns = ref.read(selectedColumnsProvider);

    // Create session config
    ref.read(sessionConfigProvider.notifier).createConfig(
          selectedDeviceIds: selectedDeviceIds,
          selectedColumns: selectedColumns,
          sessionName: _sessionNameController.text,
          notes: _notesController.text,
        );

    // Navigate to live session screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LiveSessionScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

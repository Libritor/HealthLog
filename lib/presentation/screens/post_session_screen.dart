import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/storage/file_storage_helper.dart';
import '../providers/recording_provider.dart';
import 'device_selection_screen.dart';

/// Post-session summary screen
/// Shows recording summary and allows sharing CSV files
class PostSessionScreen extends ConsumerStatefulWidget {
  const PostSessionScreen({super.key});

  @override
  ConsumerState<PostSessionScreen> createState() => _PostSessionScreenState();
}

class _PostSessionScreenState extends ConsumerState<PostSessionScreen> {
  List<File>? _sessionFiles;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessionFiles();
  }

  Future<void> _loadSessionFiles() async {
    final files = await FileStorageHelper.listSessionFiles();
    setState(() {
      // Get the most recent files (last recording)
      _sessionFiles = files.take(10).toList(); // Show last 10 files
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(sessionConfigProvider);
    final recordingManager = ref.read(recordingManagerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Complete'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Success icon
                  const Center(
                    child: Icon(
                      Icons.check_circle,
                      size: 80,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Session summary
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session Summary',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Divider(),
                          _buildSummaryRow('Session Name', config?.sessionName ?? 'Unknown'),
                          _buildSummaryRow(
                            'Duration',
                            _formatDuration(recordingManager.elapsedSeconds),
                          ),
                          _buildSummaryRow(
                            'Devices',
                            '${config?.selectedDeviceIds.length ?? 0}',
                          ),
                          _buildSummaryRow(
                            'Columns Recorded',
                            '${config?.selectedColumns.length ?? 0}',
                          ),
                          if (config?.notes.isNotEmpty ?? false) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Notes:',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(config!.notes),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // CSV files
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recorded Files',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Divider(),
                          if (_sessionFiles == null || _sessionFiles!.isEmpty)
                            const Text('No files found')
                          else
                            ..._sessionFiles!.map((file) => _buildFileRow(file)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Share all button
                  if (_sessionFiles != null && _sessionFiles!.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _shareAllFiles,
                        icon: const Icon(Icons.share),
                        label: const Text('Share All CSV Files'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // New session button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _startNewSession,
                      icon: const Icon(Icons.add),
                      label: const Text('Start New Session'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildFileRow(File file) {
    final fileName = file.uri.pathSegments.last;
    final fileSize = FileStorageHelper.formatFileSize(file.lengthSync());

    return ListTile(
      leading: const Icon(Icons.insert_drive_file),
      title: Text(
        fileName,
        style: const TextStyle(fontSize: 12),
      ),
      subtitle: Text(fileSize),
      trailing: IconButton(
        icon: const Icon(Icons.share),
        onPressed: () => _shareFile(file),
      ),
      onTap: () => _showFileInfo(file),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes min $secs sec';
  }

  Future<void> _shareFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Muse Session Data',
      text: 'Muse brain-sensing headband recording data (CSV)',
    );
  }

  Future<void> _shareAllFiles() async {
    if (_sessionFiles == null || _sessionFiles!.isEmpty) return;

    await Share.shareXFiles(
      _sessionFiles!.map((f) => XFile(f.path)).toList(),
      subject: 'Muse Session Data',
      text: 'Muse brain-sensing headband recording data (CSV)',
    );
  }

  void _showFileInfo(File file) {
    final path = FileStorageHelper.getDisplayPath(file);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Location'),
        content: SelectableText(path),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _startNewSession() {
    // Reset session config
    ref.read(sessionConfigProvider.notifier).clearConfig();
    ref.read(recordingStateProvider.notifier).reset();
    ref.read(selectedColumnsProvider.notifier).selectAll();

    // Navigate back to device selection
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const DeviceSelectionScreen(),
      ),
      (route) => false,
    );
  }
}

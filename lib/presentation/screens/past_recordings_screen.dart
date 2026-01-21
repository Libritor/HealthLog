import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../data/storage/file_storage_helper.dart';

/// Screen to browse and share past recording files
class PastRecordingsScreen extends ConsumerStatefulWidget {
  const PastRecordingsScreen({super.key});

  @override
  ConsumerState<PastRecordingsScreen> createState() => _PastRecordingsScreenState();
}

class _PastRecordingsScreenState extends ConsumerState<PastRecordingsScreen> {
  List<File>? _allFiles;
  bool _isLoading = true;
  final Set<File> _selectedFiles = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadAllFiles();
  }

  Future<void> _loadAllFiles() async {
    setState(() => _isLoading = true);
    final files = await FileStorageHelper.listSessionFiles();
    setState(() {
      _allFiles = files;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode 
            ? '${_selectedFiles.length} selected' 
            : 'Past Recordings'),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Select All',
              onPressed: _selectAll,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel Selection',
              onPressed: _cancelSelection,
            ),
          ] else if (_allFiles != null && _allFiles!.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: 'Select Files',
              onPressed: () => setState(() => _isSelectionMode = true),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadAllFiles,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allFiles == null || _allFiles!.isEmpty
              ? _buildEmptyState()
              : _buildFileList(),
      bottomNavigationBar: _isSelectionMode && _selectedFiles.isNotEmpty
          ? SafeArea(
              child: Container(
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
                        onPressed: _deleteSelected,
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: Text(
                          'Delete (${_selectedFiles.length})',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _shareSelected,
                        icon: const Icon(Icons.share),
                        label: Text('Share (${_selectedFiles.length})'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Recordings Found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new session to create recordings',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    // Group files by date
    final groupedFiles = <String, List<File>>{};
    final dateFormat = DateFormat('MMMM d, yyyy');

    for (final file in _allFiles!) {
      final stat = file.statSync();
      final dateKey = dateFormat.format(stat.modified);
      groupedFiles.putIfAbsent(dateKey, () => []).add(file);
    }

    final sortedDates = groupedFiles.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final files = groupedFiles[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                date,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            ...files.map((file) => _buildFileItem(file)),
            if (index < sortedDates.length - 1) const Divider(),
          ],
        );
      },
    );
  }

  Widget _buildFileItem(File file) {
    final fileName = file.uri.pathSegments.last;
    final fileSize = FileStorageHelper.formatFileSize(file.lengthSync());
    final stat = file.statSync();
    final timeFormat = DateFormat('h:mm a');
    final timeStr = timeFormat.format(stat.modified);
    final isSelected = _selectedFiles.contains(file);

    return ListTile(
      leading: _isSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (checked) => _toggleFileSelection(file),
            )
          : const Icon(Icons.insert_drive_file, color: Colors.blue),
      title: Text(
        fileName,
        style: const TextStyle(fontSize: 13),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('$fileSize • $timeStr'),
      trailing: _isSelectionMode
          ? null
          : IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _shareFile(file),
            ),
      onTap: _isSelectionMode
          ? () => _toggleFileSelection(file)
          : () => _showFileOptions(file),
      onLongPress: () {
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedFiles.add(file);
          });
        }
      },
    );
  }

  void _toggleFileSelection(File file) {
    setState(() {
      if (_selectedFiles.contains(file)) {
        _selectedFiles.remove(file);
        if (_selectedFiles.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedFiles.add(file);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedFiles.clear();
      _selectedFiles.addAll(_allFiles!);
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedFiles.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _shareFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Muse Session Data',
      text: 'Muse brain-sensing headband recording data (CSV)',
    );
  }

  Future<void> _shareSelected() async {
    if (_selectedFiles.isEmpty) return;

    await Share.shareXFiles(
      _selectedFiles.map((f) => XFile(f.path)).toList(),
      subject: 'Muse Session Data',
      text: 'Muse brain-sensing headband recording data (CSV)',
    );
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Files?'),
        content: Text(
          'Are you sure you want to delete ${_selectedFiles.length} file(s)? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final file in _selectedFiles) {
        try {
          await file.delete();
        } catch (e) {
          // Ignore deletion errors
        }
      }
      _cancelSelection();
      await _loadAllFiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Files deleted')),
        );
      }
    }
  }

  void _showFileOptions(File file) {
    final fileName = file.uri.pathSegments.last;
    final path = FileStorageHelper.getDisplayPath(file);

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                fileName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                path,
                style: const TextStyle(fontSize: 11),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                _shareFile(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete File?'),
                    content: Text('Are you sure you want to delete "$fileName"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await file.delete();
                  await _loadAllFiles();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('File deleted')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

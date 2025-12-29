import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

// Cross-platform file paths for session recordings.
class FileStorageHelper {
  // Sessions go to external storage on Android (survives uninstall),
  // Documents folder on iOS (backed up to iCloud).
  static Future<Directory> getSessionsDirectory() async {
    Directory baseDir;

    if (Platform.isAndroid) {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        baseDir = Directory('${externalDir.path}/muse_sessions');
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        baseDir = Directory('${appDir.path}/muse_sessions');
      }
    } else if (Platform.isIOS) {
      final appDir = await getApplicationDocumentsDirectory();
      baseDir = Directory('${appDir.path}/muse_sessions');
    } else {
      // macOS or other desktop
      final appDir = await getApplicationDocumentsDirectory();
      baseDir = Directory('${appDir.path}/muse_sessions');
    }

    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    return baseDir;
  }

  // File naming: muse_session_YYYYMMDD_HHMMSS_DeviceName.csv
  static Future<File> generateCsvFilePath(
    String deviceId, {
    String? deviceName,
    DateTime? sessionStartTime,
  }) async {
    final timestamp = sessionStartTime ?? DateTime.now();
    final dateFormat = DateFormat('yyyyMMdd_HHmmss');
    final dateStr = dateFormat.format(timestamp);

    final String fileIdentifier;
    if (deviceName != null && deviceName.isNotEmpty) {
      fileIdentifier = deviceName.replaceAll(RegExp(r'[^\w\-]'), '_');
    } else {
      fileIdentifier = deviceId.replaceAll(RegExp(r'[^\w\-]'), '_');
    }

    final filename = 'muse_session_${dateStr}_$fileIdentifier.csv';
    final sessionsDir = await getSessionsDirectory();
    return File('${sessionsDir.path}/$filename');
  }

  static Future<List<File>> listSessionFiles() async {
    final sessionsDir = await getSessionsDirectory();

    if (!await sessionsDir.exists()) {
      return [];
    }

    final entities = await sessionsDir.list().toList();
    final csvFiles = entities
        .whereType<File>()
        .where((file) => file.path.endsWith('.csv'))
        .toList();

    // Newest first
    csvFiles.sort((a, b) =>
        b.statSync().modified.compareTo(a.statSync().modified));

    return csvFiles;
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static Future<void> deleteSessionFile(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  static String getDisplayPath(File file) {
    return file.path;
  }
}

import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Native-only helper for writing log entries to a local file.
class LogFileStorage {
  static const String _fileName = 'app_logs.txt';
  static const int _maxLogLines = 1000;

  static Future<File> _logFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$_fileName');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  static Future<void> appendLogEntry(String logEntry) async {
    try {
      final file = await _logFile();
      await file.writeAsString('$logEntry\n', mode: FileMode.append, flush: true);

      final lines = await file.readAsLines();
      if (lines.length > _maxLogLines) {
        final trimmedLines = lines.sublist(lines.length - _maxLogLines);
        await file.writeAsString('${trimmedLines.join('\n')}\n', flush: true);
      }
    } catch (_) {
      // Swallow file logging errors to avoid breaking the app.
    }
  }

  static Future<List<String>> readLogLines() async {
    try {
      final file = await _logFile();
      if (!await file.exists()) {
        return [];
      }
      return await file.readAsLines();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearLogFile() async {
    try {
      final file = await _logFile();
      if (await file.exists()) {
        await file.writeAsString('');
      }
    } catch (_) {
      // ignore
    }
  }

  static Future<String?> getLogFilePath() async {
    try {
      final file = await _logFile();
      return file.path;
    } catch (_) {
      return null;
    }
  }
}

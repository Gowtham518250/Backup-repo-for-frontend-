/// Web-compatible stub for file-backed logging.
class LogFileStorage {
  static Future<void> appendLogEntry(String logEntry) async {}
  static Future<List<String>> readLogLines() async => [];
  static Future<void> clearLogFile() async {}
  static Future<String?> getLogFilePath() async => null;
}

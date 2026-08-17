import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'secure_token_storage.dart';
import 'log_file_storage_stub.dart'
    if (dart.library.io) 'log_file_storage.dart';

/// Comprehensive logging service for debug, API, user analytics, and error logging
/// Supports local file storage (web-compatible) and remote backend API integration
class ComprehensiveLogger {
  // Log levels
  static const String DEBUG = 'DEBUG';
  static const String INFO = 'INFO';
  static const String WARNING = 'WARNING';
  static const String ERROR = 'ERROR';
  static const String CRITICAL = 'CRITICAL';

  // Configuration
  static const String _defaultLogLevel = DEBUG;
  static const String _defaultLogIngestUrl = '/api/logs/ingest';
  static const bool _defaultEnableRemoteLogging = true;
  static const int _maxLocalLogs = 1000; // Prevent storage overflow
  static const int _batchSize = 10; // Send logs in batches
  static const Duration _batchInterval = Duration(seconds: 30); // Send batch every 30s

  // State
  static String? _sessionId;
  static String? _userId;
  static String _logLevel = _defaultLogLevel;
  static String _logIngestUrl = _defaultLogIngestUrl;
  static bool _enableRemoteLogging = _defaultEnableRemoteLogging;
  static final List<String> _logBuffer = [];
  static Timer? _batchTimer;
  static bool _isInitialized = false;

  // Get configuration from environment variables
  static String get _configuredLogLevel =>
      const String.fromEnvironment('LOG_LEVEL', defaultValue: _defaultLogLevel);
  
  static String get _configuredLogIngestUrl =>
      const String.fromEnvironment('LOG_INGEST_URL', defaultValue: _defaultLogIngestUrl);
  
  static bool get _configuredEnableRemoteLogging =>
      const String.fromEnvironment('ENABLE_REMOTE_LOGGING', defaultValue: 'true') == 'true';

  /// Initialize the logging service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load configuration from environment variables
      _logLevel = _configuredLogLevel;
      _logIngestUrl = _configuredLogIngestUrl;
      _enableRemoteLogging = _configuredEnableRemoteLogging;

      // Generate session ID
      _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

      // Load user ID if available
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getInt('user_id')?.toString() ?? prefs.getInt('userId')?.toString();

      // Start batch timer for remote logging
      if (_enableRemoteLogging) {
        _startBatchTimer();
      }

      _isInitialized = true;
      logInfo('ComprehensiveLogger', 'Logging service initialized', {
        'session_id': _sessionId,
        'user_id': _userId,
        'log_level': _logLevel,
        'remote_logging': _enableRemoteLogging,
        'platform': kIsWeb ? 'web' : 'native',
      });
    } catch (e) {
      // Fallback to basic logging if initialization fails
      debugPrint('🚨 ComprehensiveLogger initialization failed: $e');
      _isInitialized = true; // Still mark as initialized to prevent retries
    }
  }

  /// Start batch timer for remote log sending
  static void _startBatchTimer() {
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(_batchInterval, (_) {
      _sendBatchedLogs();
    });
  }

  /// Stop batch timer
  static void stopBatchTimer() {
    _batchTimer?.cancel();
    _batchTimer = null;
  }

  /// Check if log level should be captured
  static bool _shouldLog(String level) {
    final levels = [DEBUG, INFO, WARNING, ERROR, CRITICAL];
    final currentLevelIndex = levels.indexOf(_logLevel);
    final messageLevelIndex = levels.indexOf(level);
    return messageLevelIndex >= currentLevelIndex;
  }

  /// Format log entry with timestamp
  static String _formatLogEntry({
    required String level,
    required String location,
    required String message,
    Map<String, dynamic>? data,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final timestampFormatted = timestamp.substring(0, 19).replaceFirst('T', ' ');
    
    final buffer = StringBuffer();
    buffer.write('[$timestampFormatted] [$level] [$location] $message');
    
    if (data != null && data.isNotEmpty) {
      try {
        final sanitizedData = _sanitizeData(data);
        buffer.write(' | ${jsonEncode(sanitizedData)}');
      } catch (e) {
        buffer.write(' | data: <encoding error>');
      }
    }
    
    return buffer.toString();
  }

  /// Sanitize sensitive data from logs
  static Map<String, dynamic> _sanitizeData(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);
    final sensitiveKeys = [
      'password', 'token', 'secret', 'key', 'auth', 'credential',
      'Authorization', 'Bearer', 'access_token', 'refresh_token'
    ];
    
    for (final key in sanitized.keys) {
      for (final sensitive in sensitiveKeys) {
        if (key.toLowerCase().contains(sensitive.toLowerCase())) {
          sanitized[key] = '***REDACTED***';
          break;
        }
      }
    }
    
    return sanitized;
  }

  /// Core logging method
  static void _log({
    required String level,
    required String location,
    required String message,
    Map<String, dynamic>? data,
  }) {
    if (!_isInitialized) {
      initialize(); // Auto-initialize if not already done
    }

    if (!_shouldLog(level)) return;

    final formattedEntry = _formatLogEntry(
      level: level,
      location: location,
      message: message,
      data: data,
    );

    // Print to console
    if (kDebugMode) {
      debugPrint(formattedEntry);
    }

    // Add to buffer for local storage and remote sending
    _logBuffer.add(formattedEntry);

    // Maintain buffer size limit
    if (_logBuffer.length > _maxLocalLogs) {
      _logBuffer.removeAt(0);
    }

    // Save to local storage
    _saveToLocalStorage(formattedEntry);

    // Send immediately for critical errors
    if (level == CRITICAL && _enableRemoteLogging) {
      _sendBatchedLogs();
    }
  }

  /// Save log entry to local storage and file storage.
  static Future<void> _saveToLocalStorage(String logEntry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getStringList('app_logs') ?? [];

      logs.add(logEntry);

      // Maintain size limit
      if (logs.length > _maxLocalLogs) {
        logs.removeRange(0, logs.length - _maxLocalLogs);
      }

      await prefs.setStringList('app_logs', logs);
      await LogFileStorage.appendLogEntry(logEntry);
    } catch (e) {
      debugPrint('⚠️ Failed to save log to local storage: $e');
    }
  }

  /// Send batched logs to remote API
  static Future<void> _sendBatchedLogs() async {
    if (!_enableRemoteLogging || _logBuffer.isEmpty) return;

    try {
      // Get batch to send
      final batch = _logBuffer.take(_batchSize).toList();
      if (batch.isEmpty) return;

      // Prepare payload
      final payload = {
        'session_id': _sessionId,
        'user_id': _userId,
        'app_version': '1.0.0',
        'platform': kIsWeb ? 'web' : 'native',
        'logs': batch,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Get auth token if available
      final token = await SecureTokenStorage.getToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      // Determine full URL
      final baseUrl = ApiClient.baseUrl;
      final fullUrl = _logIngestUrl.startsWith('http')
          ? _logIngestUrl
          : '$baseUrl$_logIngestUrl';

      // Send to backend
      final response = await http.post(
        Uri.parse(fullUrl),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Remove sent logs from buffer
        _logBuffer.removeRange(0, batch.length);
        if (kDebugMode) {
          debugPrint('✅ Sent ${batch.length} logs to remote API');
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ Failed to send logs: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Error sending logs to remote API: $e');
      }
      // Keep logs in buffer for retry
    }
  }

  /// Get all local logs from file storage when available, otherwise fallback to preferences.
  static Future<List<String>> getLocalLogs() async {
    try {
      final fileLines = await LogFileStorage.readLogLines();
      if (fileLines.isNotEmpty) {
        return fileLines;
      }

      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('app_logs') ?? [];
    } catch (e) {
      debugPrint('⚠️ Failed to get local logs: $e');
      return [];
    }
  }

  /// Return the path to the local log file when available.
  static Future<String?> getLocalLogFilePath() async {
    try {
      return await LogFileStorage.getLogFilePath();
    } catch (e) {
      debugPrint('⚠️ Failed to get log file path: $e');
      return null;
    }
  }

  /// Clear all local logs and file-backed logs.
  static Future<void> clearLocalLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('app_logs');
      await LogFileStorage.clearLogFile();
      _logBuffer.clear();
      if (kDebugMode) {
        debugPrint('🗑️ Local logs cleared');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to clear local logs: $e');
    }
  }

  /// Export logs as downloadable string
  static Future<String> exportLogs() async {
    final logs = await getLocalLogs();
    return logs.join('\n');
  }

  /// Download logs as .txt file (web-compatible)
  static void downloadLogsAsTxt() {
    exportLogs().then((logs) {
      if (kIsWeb) {
        // For web, print logs to console with clear markers for easy copying
        debugPrint('╔══════════════════════════════════════════════════════════════════════════════╗');
        debugPrint('║                    APPLICATION LOGS EXPORT                                        ║');
        debugPrint('║                    Copy from here to bottom                                     ║');
        debugPrint('╚══════════════════════════════════════════════════════════════════════════════╝');
        debugPrint(logs);
        debugPrint('╔══════════════════════════════════════════════════════════════════════════════╗');
        debugPrint('║                    END OF LOGS                                                  ║');
        debugPrint('╚══════════════════════════════════════════════════════════════════════════════╝');
        debugPrint('');
        debugPrint('💡 To save logs: Select the text above, copy (Ctrl+C), and paste into a .txt file');
      } else {
        // Native: Just log the export
        debugPrint('Log export: ${logs.length} characters');
        debugPrint('First 500 chars: ${logs.substring(0, logs.length > 500 ? 500 : logs.length)}');
      }
    });
  }

  // Public logging methods

  static void logDebug(String location, String message, [Map<String, dynamic>? data]) {
    _log(level: DEBUG, location: location, message: message, data: data);
  }

  static void logInfo(String location, String message, [Map<String, dynamic>? data]) {
    _log(level: INFO, location: location, message: message, data: data);
  }

  static void logWarning(String location, String message, [Map<String, dynamic>? data]) {
    _log(level: WARNING, location: location, message: message, data: data);
  }

  static void logError({required String location, required String message, Map<String, dynamic>? data}) {
    _log(level: ERROR, location: location, message: message, data: data);
  }

  static void logCritical(String location, String message, [Map<String, dynamic>? data]) {
    _log(level: CRITICAL, location: location, message: message, data: data);
  }

  // API logging methods

  static void logApiRequest({
    required String method,
    required String url,
    Map<String, String>? headers,
    dynamic body,
  }) {
    _log(
      level: DEBUG,
      location: 'API_REQUEST',
      message: '$method $url',
      data: {
        'method': method,
        'url': url,
        'headers': _sanitizeData(headers ?? {}),
        if (body != null) 'body': _sanitizeData(body is Map ? Map<String, dynamic>.from(body) : {'data': body.toString()}),
      },
    );
  }

  static void logApiResponse({
    required String method,
    required String url,
    required int statusCode,
    Map<String, String>? headers,
    dynamic body,
    required Duration duration,
  }) {
    final level = statusCode >= 400 ? WARNING : DEBUG;
    _log(
      level: level,
      location: 'API_RESPONSE',
      message: '$method $url - $statusCode (${duration.inMilliseconds}ms)',
      data: {
        'method': method,
        'url': url,
        'status_code': statusCode,
        'duration_ms': duration.inMilliseconds,
        'headers': _sanitizeData(headers ?? {}),
        if (body != null) 'body': _sanitizeData(body is Map ? Map<String, dynamic>.from(body) : {'data': body.toString()}),
      },
    );
  }

  static void logApiError({
    required String method,
    required String url,
    required String error,
    StackTrace? stackTrace,
    required Duration duration,
  }) {
    _log(
      level: ERROR,
      location: 'API_ERROR',
      message: '$method $url - $error (${duration.inMilliseconds}ms)',
      data: {
        'method': method,
        'url': url,
        'error': error,
        'duration_ms': duration.inMilliseconds,
        if (stackTrace != null) 'stack_trace': stackTrace.toString(),
      },
    );
  }

  // User action logging methods

  static void logUserAction({
    required String action,
    required String screen,
    Map<String, dynamic>? details,
  }) {
    _log(
      level: INFO,
      location: 'USER_ACTION',
      message: '$action on $screen',
      data: {
        'action': action,
        'screen': screen,
        if (details != null) 'details': _sanitizeData(details),
        'user_id': _userId,
      },
    );
  }

  static void logRouteChange({
    required String from,
    required String to,
    Map<String, dynamic>? arguments,
  }) {
    _log(
      level: INFO,
      location: 'ROUTE_CHANGE',
      message: 'Navigation: $from -> $to',
      data: {
        'from': from,
        'to': to,
        if (arguments != null) 'arguments': _sanitizeData(arguments),
        'user_id': _userId,
      },
    );
  }

  static void logButtonClick({
    required String buttonLabel,
    required String screen,
    Map<String, dynamic>? context,
  }) {
    _log(
      level: INFO,
      location: 'BUTTON_CLICK',
      message: 'Clicked: $buttonLabel on $screen',
      data: {
        'button_label': buttonLabel,
        'screen': screen,
        if (context != null) 'context': _sanitizeData(context),
        'user_id': _userId,
      },
    );
  }

  static void logFormSubmission({
    required String formName,
    required String screen,
    required bool success,
    Map<String, dynamic>? formData,
    String? error,
  }) {
    _log(
      level: success ? INFO : WARNING,
      location: 'FORM_SUBMISSION',
      message: 'Form $formName ${success ? "submitted" : "failed"} on $screen',
      data: {
        'form_name': formName,
        'screen': screen,
        'success': success,
        if (formData != null) 'form_data': _sanitizeData(formData),
        if (error != null) 'error': error,
        'user_id': _userId,
      },
    );
  }

  // Error and crash logging methods

  static void logErrorWithStack({
    required String location,
    required String error,
    required StackTrace stackTrace,
    Map<String, dynamic>? context,
  }) {
    _log(
      level: ERROR,
      location: location,
      message: error,
      data: {
        'error': error,
        'stack_trace': stackTrace.toString(),
        if (context != null) 'context': _sanitizeData(context),
        'user_id': _userId,
      },
    );
  }

  static void logCrash({
    required String error,
    required StackTrace stackTrace,
    Map<String, dynamic>? context,
  }) {
    _log(
      level: CRITICAL,
      location: 'CRASH',
      message: error,
      data: {
        'error': error,
        'stack_trace': stackTrace.toString(),
        if (context != null) 'context': _sanitizeData(context),
        'user_id': _userId,
        'app_state': {
          'session_id': _sessionId,
          'platform': kIsWeb ? 'web' : 'native',
        },
      },
    );
  }

  /// Update user ID (call after login/logout)
  static void updateUserId(String? userId) {
    _userId = userId;
    logInfo('ComprehensiveLogger', 'User ID updated', {'user_id': _userId});
  }

  /// Cleanup resources
  static Future<void> dispose() async {
    stopBatchTimer();
    // Send any remaining logs
    if (_enableRemoteLogging && _logBuffer.isNotEmpty) {
      await _sendBatchedLogs();
    }
    _isInitialized = false;
  }
}

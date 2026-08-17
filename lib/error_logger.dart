import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'local_storage_service.dart';

/// Comprehensive Error Logger - Logs all app errors for debugging
class ErrorLogger {
  static const String _tag = '🚨 ERROR_LOGGER';
  static const String _logsKey = 'app_error_logs_v1';
  static const String _crashesKey = 'app_crashes_v1';
  static const int maxLogsPerType = 100;  // Prevent storage bloat
  
  final LocalStorageService _storage = LocalStorageService();
  
  /// Log an error
  Future<void> logError({
    required String message,
    required String source,  // e.g., 'PaymentDetection', 'ApiClient'
    String? stackTrace,
    Map<String, dynamic>? context,
    String severity = 'ERROR',  // ERROR, WARNING, INFO
  }) async {
    try {
      final errorEntry = {
        'timestamp': DateTime.now().toIso8601String(),
        'message': message,
        'source': source,
        'severity': severity,
        'stackTrace': stackTrace,
        'context': context,
      };
      
      final logsJson = await _storage.getString(_logsKey) ?? '[]';
      final List<dynamic> logs = jsonDecode(logsJson);
      
      logs.add(errorEntry);
      
      // Keep only recent logs
      if (logs.length > maxLogsPerType) {
        logs.removeRange(0, logs.length - maxLogsPerType);
      }
      
      await _storage.setString(_logsKey, jsonEncode(logs));
      
      if (kDebugMode) {
        print('$_tag [$severity] $source: $message');
        if (stackTrace != null) print(stackTrace);
      }
    } catch (e) {
      if (kDebugMode) print('$_tag ❌ Failed to log error: $e');
    }
  }
  
  /// Log API error
  Future<void> logApiError({
    required String endpoint,
    required int statusCode,
    required String responseBody,
    String? requestBody,
    Duration? responseTime,
  }) async {
    await logError(
      message: 'API Error: $endpoint returned $statusCode',
      source: 'ApiClient',
      severity: statusCode >= 500 ? 'ERROR' : 'WARNING',
      context: {
        'endpoint': endpoint,
        'statusCode': statusCode,
        'responseLength': responseBody.length,
        'responseTimeMs': responseTime?.inMilliseconds,
        'preview': responseBody.substring(0, 200.clamp(0, responseBody.length)),
      },
    );
  }
  
  /// Log network error
  Future<void> logNetworkError({
    required String endpoint,
    required String errorType,  // 'Timeout', 'SocketException', 'ConnectionRefused'
    String? errorMessage,
  }) async {
    await logError(
      message: 'Network Error: $errorType on $endpoint',
      source: 'Network',
      severity: 'WARNING',
      context: {
        'endpoint': endpoint,
        'errorType': errorType,
        'errorMessage': errorMessage,
      },
    );
  }
  
  /// Log payment detection error
  Future<void> logPaymentError({
    required String detectionSource,
    required String errorReason,
    Map<String, dynamic>? paymentDetails,
  }) async {
    await logError(
      message: 'Payment Detection Error: $errorReason',
      source: 'PaymentDetection',
      severity: 'ERROR',
      context: {
        'detectionSource': detectionSource,
        'paymentDetails': paymentDetails,
      },
    );
  }
  
  /// Log crash
  Future<void> logCrash({
    required String message,
    required String stackTrace,
    String? source,
  }) async {
    try {
      final crash = {
        'timestamp': DateTime.now().toIso8601String(),
        'message': message,
        'stackTrace': stackTrace,
        'source': source ?? 'UNKNOWN',
      };
      
      final crashesJson = await _storage.getString(_crashesKey) ?? '[]';
      final List<dynamic> crashes = jsonDecode(crashesJson);
      crashes.add(crash);
      
      if (crashes.length > maxLogsPerType) {
        crashes.removeRange(0, crashes.length - maxLogsPerType);
      }
      
      await _storage.setString(_crashesKey, jsonEncode(crashes));
      
      if (kDebugMode) {
        print('$_tag 💥 CRASH: $message');
        print(stackTrace);
      }
    } catch (e) {
      if (kDebugMode) print('$_tag ❌ Failed to log crash: $e');
    }
  }
  
  /// Get all logs
  Future<List<Map<String, dynamic>>> getAllLogs() async {
    try {
      final logsJson = await _storage.getString(_logsKey) ?? '[]';
      return List<Map<String, dynamic>>.from(jsonDecode(logsJson));
    } catch (e) {
      return [];
    }
  }
  
  /// Get all crashes
  Future<List<Map<String, dynamic>>> getAllCrashes() async {
    try {
      final crashesJson = await _storage.getString(_crashesKey) ?? '[]';
      return List<Map<String, dynamic>>.from(jsonDecode(crashesJson));
    } catch (e) {
      return [];
    }
  }
  
  /// Export logs as JSON for debugging
  Future<String> exportLogsAsJson() async {
    try {
      final logs = await getAllLogs();
      final crashes = await getAllCrashes();
      
      final export = {
        'exportedAt': DateTime.now().toIso8601String(),
        'logs': logs,
        'crashes': crashes,
        'summary': {
          'totalLogs': logs.length,
          'totalCrashes': crashes.length,
          'errorCount': logs.where((l) => l['severity'] == 'ERROR').length,
          'warningCount': logs.where((l) => l['severity'] == 'WARNING').length,
        },
      };
      
      return jsonEncode(export);
    } catch (e) {
      return '{"error": "$e"}';
    }
  }
  
  /// Clear old logs (keep only last N hours)
  Future<void> clearOldLogs({int olderThanHours = 48}) async {
    try {
      final logsJson = await _storage.getString(_logsKey) ?? '[]';
      final List<dynamic> logs = jsonDecode(logsJson);
      
      final cutoffTime = DateTime.now().subtract(Duration(hours: olderThanHours));
      
      final recent = logs.where((log) {
        try {
          final timestamp = DateTime.parse(log['timestamp']);
          return timestamp.isAfter(cutoffTime);
        } catch (_) {
          return false;
        }
      }).toList();
      
      await _storage.setString(_logsKey, jsonEncode(recent));
      if (kDebugMode) print('$_tag ✅ Logs cleaned: ${logs.length} → ${recent.length}');
    } catch (e) {
      if (kDebugMode) print('$_tag ❌ Failed to clean logs: $e');
    }
  }
}

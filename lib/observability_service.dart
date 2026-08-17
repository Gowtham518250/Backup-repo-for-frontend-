import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'secure_token_storage.dart';

/// 
/// OBSERVABILITY SERVICE - Backend Monitoring and Diagnostics
/// ==============================================================
/// 
/// Integrates with backend observability endpoints for:
/// - Health checks
/// - Metrics collection
/// - Performance monitoring
/// - Error logging
/// - Business analytics
/// 
class ObservabilityService {
  
  /// Check backend health status
  static Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await ApiClient.getJson(
        ApiClient.observabilityHealth,
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'status': data['status'],
          'version': data['version'],
          'timestamp': data['timestamp'],
        };
      } else {
        return {'success': false, 'error': 'BACKEND_ERROR'};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Health check failed: $e');
      return {'success': false, 'error': 'NETWORK_ERROR'};
    }
  }
  
  /// Check backend readiness status
  static Future<Map<String, dynamic>> checkReadiness() async {
    try {
      final response = await ApiClient.getJson(
        ApiClient.observabilityReady,
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'ready': data['ready'],
          'checks': data['checks'],
          'timestamp': data['timestamp'],
        };
      } else {
        return {'success': false, 'error': 'BACKEND_ERROR'};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Readiness check failed: $e');
      return {'success': false, 'error': 'NETWORK_ERROR'};
    }
  }
  
  /// Get backend metrics
  static Future<Map<String, dynamic>> getMetrics() async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        return {'success': false, 'error': 'NOT_AUTHENTICATED'};
      }
      
      final response = await ApiClient.getJson(
        ApiClient.observabilityMetrics,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'metrics': data['metrics'],
          'timestamp': data['timestamp'],
        };
      } else {
        return {'success': false, 'error': 'BACKEND_ERROR'};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Metrics fetch failed: $e');
      return {'success': false, 'error': 'NETWORK_ERROR'};
    }
  }
  
  /// Log event to backend
  static Future<Map<String, dynamic>> logEvent({
    required String event,
    Map<String, dynamic>? metadata,
    String? level,
  }) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        return {'success': false, 'error': 'NOT_AUTHENTICATED'};
      }
      
      final response = await ApiClient.postJson(
        ApiClient.observabilityLog,
        {
          'event': event,
          'metadata': metadata ?? {},
          'level': level ?? 'INFO',
          'timestamp': DateTime.now().toIso8601String(),
        },
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'logged': data['logged'],
          'event_id': data['event_id'],
        };
      } else {
        return {'success': false, 'error': 'BACKEND_ERROR'};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Event logging failed: $e');
      return {'success': false, 'error': 'NETWORK_ERROR'};
    }
  }
  
  /// Log error to backend
  static Future<Map<String, dynamic>> logError({
    required String error,
    String? stackTrace,
    Map<String, dynamic>? context,
    String? severity,
  }) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        return {'success': false, 'error': 'NOT_AUTHENTICATED'};
      }
      
      final response = await ApiClient.postJson(
        ApiClient.observabilityError,
        {
          'error': error,
          'stack_trace': stackTrace,
          'context': context ?? {},
          'severity': severity ?? 'ERROR',
          'timestamp': DateTime.now().toIso8601String(),
        },
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'logged': data['logged'],
          'error_id': data['error_id'],
        };
      } else {
        return {'success': false, 'error': 'BACKEND_ERROR'};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error logging failed: $e');
      return {'success': false, 'error': 'NETWORK_ERROR'};
    }
  }
  
  /// Get performance summary
  static Future<Map<String, dynamic>> getPerformanceSummary() async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        return {'success': false, 'error': 'NOT_AUTHENTICATED'};
      }
      
      final response = await ApiClient.getJson(
        ApiClient.observabilityPerformanceSummary,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'performance': data['performance'],
          'timestamp': data['timestamp'],
        };
      } else {
        return {'success': false, 'error': 'BACKEND_ERROR'};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Performance summary fetch failed: $e');
      return {'success': false, 'error': 'NETWORK_ERROR'};
    }
  }
  
  /// Get database performance metrics
  static Future<Map<String, dynamic>> getDatabasePerformance() async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        return {'success': false, 'error': 'NOT_AUTHENTICATED'};
      }
      
      final response = await ApiClient.getJson(
        ApiClient.observabilityPerformanceDatabase,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'database_performance': data['database_performance'],
          'timestamp': data['timestamp'],
        };
      } else {
        return {'success': false, 'error': 'BACKEND_ERROR'};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Database performance fetch failed: $e');
      return {'success': false, 'error': 'NETWORK_ERROR'};
    }
  }
  
  /// Get business overview metrics
  static Future<Map<String, dynamic>> getBusinessOverview() async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        return {'success': false, 'error': 'NOT_AUTHENTICATED'};
      }
      
      final response = await ApiClient.getJson(
        ApiClient.observabilityBusinessOverview,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'business_overview': data['business_overview'],
          'timestamp': data['timestamp'],
        };
      } else {
        return {'success': false, 'error': 'BACKEND_ERROR'};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Business overview fetch failed: $e');
      return {'success': false, 'error': 'NETWORK_ERROR'};
    }
  }
  
  /// Automatic error logging helper
  static Future<void> logErrorAuto(
    String error,
    StackTrace stackTrace, {
    Map<String, dynamic>? context,
  }) async {
    await logError(
      error: error,
      stackTrace: stackTrace.toString(),
      context: context,
      severity: 'ERROR',
    );
  }
  
  /// Automatic event logging helper
  static Future<void> logEventAuto(
    String event, {
    Map<String, dynamic>? metadata,
  }) async {
    await logEvent(
      event: event,
      metadata: metadata,
      level: 'INFO',
    );
  }
}

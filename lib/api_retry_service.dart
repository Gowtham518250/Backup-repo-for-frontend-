import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// API Retry Service - Handles exponential backoff and retry logic
class ApiRetryService {
  static const String _tag = '🔄 RETRY_SERVICE';
  
  // Retry configuration
  static const int maxRetries = 3;
  static const Duration initialDelay = Duration(milliseconds: 500);
  static const Duration maxDelay = Duration(seconds: 30);
  static const double backoffMultiplier = 2.0;
  
  /// Execute request with retry logic
  static Future<http.Response> executeWithRetry(
    Future<http.Response> Function() request, {
    int retries = maxRetries,
    Duration delay = initialDelay,
    String? endpoint,
  }) async {
    int attempt = 0;
    
    while (attempt <= retries) {
      try {
        if (kDebugMode) {
          print('$_tag Attempt ${attempt + 1}/${ retries + 1} for $endpoint');
        }
        
        final response = await request();
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          if (kDebugMode) print('✅ Success on attempt ${attempt + 1}');
          return response;
        } else if (response.statusCode >= 500) {
          // Server error - retry
          if (attempt < retries) {
            if (kDebugMode) {
              print('⚠️ Server error ${response.statusCode}, retrying...');
            }
            attempt++;
            await Future.delayed(delay);
            delay = Duration(
              milliseconds: (delay.inMilliseconds * backoffMultiplier).toInt()
                  .clamp(0, maxDelay.inMilliseconds),
            );
          } else {
            return response;
          }
        } else {
          // Client error - don't retry
          return response;
        }
      } on TimeoutException catch (e) {
        if (kDebugMode) print('⏱️ Timeout: $e');
        if (attempt < retries) {
          attempt++;
          await Future.delayed(delay);
          delay = Duration(
            milliseconds: (delay.inMilliseconds * backoffMultiplier).toInt()
                .clamp(0, maxDelay.inMilliseconds),
          );
        } else {
          rethrow;
        }
      } catch (e) {
        if (kDebugMode) print('❌ Error: $e');
        if (attempt < retries) {
          attempt++;
          await Future.delayed(delay);
          delay = Duration(
            milliseconds: (delay.inMilliseconds * backoffMultiplier).toInt()
                .clamp(0, maxDelay.inMilliseconds),
          );
        } else {
          rethrow;
        }
      }
    }
    
    throw Exception('Max retries exceeded for $endpoint');
  }
  
  /// Check if error is retryable
  static bool isRetryable(dynamic error) {
    if (error is http.ClientException) return true;
    if (error is TimeoutException) return true;
    if (error is SocketException) return true;
    return false;
  }
}

class SocketException implements Exception {
  final String message;
  SocketException(this.message);
  
  @override
  String toString() => message;
}

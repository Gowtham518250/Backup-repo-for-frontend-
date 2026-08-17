import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'api_client.dart';
import 'offline_payment_queue.dart';
import 'error_logger.dart';
import 'payment_detection_service.dart';
import 'payment_event.dart';

/// Payment Processing Manager - Orchestrates the complete payment flow with error handling,
/// offline support, and fallback options
class PaymentProcessingManager {
  static const String _tag = '💳 PAYMENT_MANAGER';
  
  final ErrorLogger _errorLogger = ErrorLogger();
  final OfflinePaymentQueue _offlineQueue = OfflinePaymentQueue();
  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;  // Initialize to true to prevent early offline triggers
  
  // Callbacks
  Function(PaymentEvent)? onPaymentDetected;
  Function(double, int)? onSyncProgress;  // (amount, count)
  Function()? onSyncComplete;
  
  PaymentProcessingManager() {
    _initializeConnectivity();
    _checkInitialConnection();
  }
  
  Future<void> _checkInitialConnection() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    if (kDebugMode) print('$_tag Initial connection: ${_isOnline ? "ONLINE" : "OFFLINE"}');
  }
  
  void _initializeConnectivity() {
    _connectivity.onConnectivityChanged.listen((result) {
      _isOnline = result != ConnectivityResult.none;
      if (kDebugMode) print('$_tag Connection: ${_isOnline ? "ONLINE" : "OFFLINE"}');
      
      if (_isOnline) {
        _syncQueuedPayments();
      }
    });
  }
  
  /// Main payment detection handler - runs with full error handling
  Future<void> handlePaymentDetected(PaymentEvent payment) async {
    try {
      if (kDebugMode) print('$_tag Detected: ₹${payment.amount} from ${payment.detectionSource}');
      
      if (_isOnline) {
        // Online: Process immediately
        await _processPaymentOnline(payment);
      } else {
        // Offline: Queue for later
        await _offlineQueue.queuePaymentOffline(payment);
        _showOfflineNotification(payment);
      }
      
      onPaymentDetected?.call(payment);
    } catch (e) {
      await _errorLogger.logPaymentError(
        detectionSource: payment.detectionSource,
        errorReason: 'Unhandled error in handlePaymentDetected',
        paymentDetails: {'amount': payment.amount, 'error': e.toString()},
      );
      
      // Queue as fallback
      await _offlineQueue.queuePaymentOffline(payment);
    }
  }
  
  /// Process payment with automatic retry
  Future<void> _processPaymentOnline(PaymentEvent payment) async {
    try {
      // Real API call via ApiClient with automatic retry and token injection
      final response = await ApiClient.postJson(
        ApiClient.invoicesPayments,
        {
          'amount': payment.amount,
          'reference_id': payment.referenceId,
          'payer_name': payment.payerName,
          'source': payment.detectionSource,
          'timestamp': payment.timestamp.toIso8601String(),
        },
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Server failed to record payment: ${response.statusCode}');
      }
      
      await _errorLogger.logError(
        message: 'Payment processed successfully: ₹${payment.amount}',
        source: 'PaymentProcessing',
        severity: 'INFO',
      );
    } catch (e) {
      // Fall back to offline queue
      await _offlineQueue.queuePaymentOffline(payment);
      
      await _errorLogger.logPaymentError(
        detectionSource: payment.detectionSource,
        errorReason: 'Failed to process online, queued for retry',
        paymentDetails: {'amount': payment.amount, 'error': e.toString()},
      );
    }
  }
  
  /// Sync queued payments when connection restored
  Future<void> _syncQueuedPayments() async {
    try {
      final queued = await _offlineQueue.getQueuedPayments();
      if (queued.isEmpty) return;
      
      if (kDebugMode) print('$_tag Syncing ${queued.length} queued payments...');
      
      int synced = 0;
      int failed = 0;
      
      for (final item in queued) {
        if (item['status'] != 'PENDING') continue;
        
        // FIX-6: Exponential backoff based on retry count
        // Prevents hammering backend on repeated failures
        final retryCount = item['retryCount'] as int? ?? 0;
        if (retryCount > 0) {
          final backoffMs = math.min(1000 * math.pow(2, retryCount).toInt(), 30000);
          if (kDebugMode) print('$_tag Waiting ${backoffMs}ms before retry (attempt ${retryCount + 1})');
          await Future.delayed(Duration(milliseconds: backoffMs));
        }
        
        try {
          // Real sync call to backend
          final response = await ApiClient.postJson(
            ApiClient.invoicesPayments,
            item,
          );

          if (response.statusCode != 200 && response.statusCode != 201) {
            throw Exception('Sync failed');
          }
          
          await _offlineQueue.markAsSynced(item['id']);
          synced++;
          
          onSyncProgress?.call(item['amount'], synced);
        } catch (e) {
          final canRetry = await _offlineQueue.incrementRetryCount(item['id']);
          if (!canRetry) {
            failed++;
            
            await _errorLogger.logPaymentError(
              detectionSource: 'OFFLINE_SYNC',
              errorReason: 'Max retries exceeded for queued payment',
              paymentDetails: {'paymentId': item['id'], 'amount': item['amount']},
            );
          }
        }
      }
      
      await _offlineQueue.updateSyncStatus(synced: synced, failed: failed);
      onSyncComplete?.call();
      
      if (kDebugMode) print('$_tag Sync complete: $synced synced, $failed failed');
    } catch (e) {
      await _errorLogger.logError(
        message: 'Error syncing queued payments: $e',
        source: 'PaymentSync',
        severity: 'ERROR',
      );
    }
  }
  
  /// Show offline notification to user
  void _showOfflineNotification(PaymentEvent payment) {
    // This would show a toast/snackbar in the UI
    print('$_tag 🔴 OFFLINE: Payment queued - ₹${payment.amount}');
  }
  
  /// Get offline queue status
  Future<Map<String, dynamic>> getOfflineStatus() async {
    final pending = await _offlineQueue.getPendingCount();
    final status = await _offlineQueue.getSyncStatus();
    
    return {
      'isOnline': _isOnline,
      'pendingPayments': pending,
      'syncStatus': status,
    };
  }
  
  /// Export logs for debugging
  Future<String> exportDebugLogs() async {
    return await _errorLogger.exportLogsAsJson();
  }
  
  /// Clear old logs (older than 48 hours)
  Future<void> cleanupOldLogs() async {
    await _errorLogger.clearOldLogs(olderThanHours: 48);
  }
}

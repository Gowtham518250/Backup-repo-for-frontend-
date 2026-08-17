import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' as foundation;
import 'local_storage_service.dart';
import 'payment_event.dart';

/// Offline Payment Queue - Handles pending payments when offline
class OfflinePaymentQueue {
  static const String _tag = '📋 OFFLINE_QUEUE';
  static const String _queueKey = 'offline_payments_queue_v1';
  static const String _syncStatusKey = 'offline_sync_status';
  
  final LocalStorageService _storage = LocalStorageService();
  
  // Future chain used to serialize all queue modification actions and prevent race conditions.
  Future<void> _writeLock = Future.value();

  Future<T> _synchronized<T>(Future<T> Function() action) async {
    final completer = Completer<void>();
    final previous = _writeLock;
    _writeLock = completer.future;
    await previous;
    try {
      return await action();
    } finally {
      completer.complete();
    }
  }
  
  /// Queue a payment when offline
  Future<void> queuePaymentOffline(PaymentEvent payment) {
    return _synchronized(() async {
      try {
        final queueJson = await _storage.getString(_queueKey) ?? '[]';
        final List<dynamic> queue = jsonDecode(queueJson);
        
        final paymentData = {
          'id': payment.id,
          'amount': payment.amount,
          'app': payment.app.toString(),
          'payerName': payment.payerName,
          'referenceId': payment.referenceId,
          'vpa': payment.vpa,
          'bankName': payment.bankName,
          'isFailed': payment.isFailed,
          'isDuplicate': payment.isDuplicate,
          'isPartialPayment': payment.isPartialPayment,
          'confidenceScore': payment.confidenceScore,
          'detectionSource': payment.detectionSource,
          'rawText': payment.rawText,
          'decision': payment.decision.toString(),
          'timestamp': payment.timestamp.toIso8601String(),
          'queuedAt': DateTime.now().toIso8601String(),
          'retryCount': 0,
          'status': 'PENDING',
        };
        
        queue.add(paymentData);
        await _storage.setString(_queueKey, jsonEncode(queue));
        
        if (foundation.kDebugMode) {
          print('$_tag ✅ Payment queued offline: ₹${payment.amount} | Total: ${queue.length}');
        }
      } catch (e) {
        if (foundation.kDebugMode) print('$_tag ❌ Failed to queue: $e');
      }
    });
  }
  
  /// Get all queued payments
  Future<List<Map<String, dynamic>>> getQueuedPayments() async {
    try {
      final queueJson = await _storage.getString(_queueKey) ?? '[]';
      return List<Map<String, dynamic>>.from(jsonDecode(queueJson));
    } catch (e) {
      if (foundation.kDebugMode) print('$_tag ❌ Failed to get queue: $e');
      return [];
    }
  }
  
  /// Get count of pending payments
  Future<int> getPendingCount() async {
    final queue = await getQueuedPayments();
    return queue.where((p) => p['status'] == 'PENDING').length;
  }
  
  /// Mark payment as synced
  Future<void> markAsSynced(String paymentId) {
    return _synchronized(() async {
      try {
        final queueJson = await _storage.getString(_queueKey) ?? '[]';
        final List<dynamic> queue = jsonDecode(queueJson);
        
        final index = queue.indexWhere((p) => p['id'] == paymentId);
        if (index != -1) {
          queue[index]['status'] = 'SYNCED';
          queue[index]['syncedAt'] = DateTime.now().toIso8601String();
          await _storage.setString(_queueKey, jsonEncode(queue));
          
          if (foundation.kDebugMode) print('$_tag ✅ Payment marked synced: $paymentId');
        }
      } catch (e) {
        if (foundation.kDebugMode) print('$_tag ❌ Failed to mark synced: $e');
      }
    });
  }
  
  /// Mark payment as failed (max retries exceeded)
  Future<void> markAsFailed(String paymentId) {
    return _synchronized(() async {
      try {
        final queueJson = await _storage.getString(_queueKey) ?? '[]';
        final List<dynamic> queue = jsonDecode(queueJson);
        
        final index = queue.indexWhere((p) => p['id'] == paymentId);
        if (index != -1) {
          queue[index]['status'] = 'FAILED';
          queue[index]['failedAt'] = DateTime.now().toIso8601String();
          await _storage.setString(_queueKey, jsonEncode(queue));
          
          if (foundation.kDebugMode) print('$_tag ⚠️ Payment marked failed: $paymentId');
        }
      } catch (e) {
        if (foundation.kDebugMode) print('$_tag ❌ Failed to mark as failed: $e');
      }
    });
  }
  
  /// Increment retry count
  Future<bool> incrementRetryCount(String paymentId) {
    return _synchronized(() async {
      try {
        const maxRetries = 5;
        final queueJson = await _storage.getString(_queueKey) ?? '[]';
        final List<dynamic> queue = jsonDecode(queueJson);
        
        final index = queue.indexWhere((p) => p['id'] == paymentId);
        if (index != -1) {
          queue[index]['retryCount']++;
          
          if (queue[index]['retryCount'] > maxRetries) {
            queue[index]['status'] = 'FAILED';
            queue[index]['failedAt'] = DateTime.now().toIso8601String();
            await _storage.setString(_queueKey, jsonEncode(queue));
            if (foundation.kDebugMode) print('$_tag ⚠️ Payment marked failed: $paymentId');
            return false;
          }
          
          await _storage.setString(_queueKey, jsonEncode(queue));
          return true;
        }
        return false;
      } catch (e) {
        if (foundation.kDebugMode) print('$_tag ❌ Failed to increment retry: $e');
        return false;
      }
    });
  }
  
  /// Get sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final statusJson = await _storage.getString(_syncStatusKey) ?? 
          jsonEncode({
            'lastSyncAt': null,
            'totalSynced': 0,
            'totalFailed': 0,
          });
      return jsonDecode(statusJson);
    } catch (e) {
      return {
        'lastSyncAt': null,
        'totalSynced': 0,
        'totalFailed': 0,
      };
    }
  }
  
  /// Update sync status
  Future<void> updateSyncStatus({
    int? synced,
    int? failed,
  }) async {
    try {
      final status = await getSyncStatus();
      if (synced != null) status['totalSynced'] = (status['totalSynced'] ?? 0) + synced;
      if (failed != null) status['totalFailed'] = (status['totalFailed'] ?? 0) + failed;
      status['lastSyncAt'] = DateTime.now().toIso8601String();
      
      await _storage.setString(_syncStatusKey, jsonEncode(status));
    } catch (e) {
      if (foundation.kDebugMode) print('$_tag ❌ Failed to update status: $e');
    }
  }
  
  /// FIX-5: Clear queue with audit trail — preserves failed payments for investigation
  /// Use preserveFailed=false only after manual audit/remediation
  Future<void> clearQueue({bool preserveFailed = true}) {
    return _synchronized(() async {
      try {
        if (preserveFailed) {
          final queueJson = await _storage.getString(_queueKey) ?? '[]';
          final List<dynamic> queue = jsonDecode(queueJson);
          // Keep FAILED payments for audit trail
          final failed = queue.where((p) => p['status'] == 'FAILED').toList();
          await _storage.setString(_queueKey, jsonEncode(failed));
          if (foundation.kDebugMode) print('$_tag ✅ Queue cleared. Preserved ${failed.length} failed payments for audit.');
        } else {
          await _storage.setString(_queueKey, '[]');
          if (foundation.kDebugMode) print('$_tag ✅ Queue cleared completely');
        }
      } catch (e) {
        if (foundation.kDebugMode) print('$_tag ❌ Failed to clear: $e');
      }
    });
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'api_client.dart';
import 'secure_token_storage.dart';

/// Enhanced Sync Queue with Overflow Handling
/// Manages offline operations with robust overflow protection and priority handling
class EnhancedSyncQueue {
  static EnhancedSyncQueue? _instance;
  static const String _queueKey = 'enhanced_sync_queue';
  static const String _overflowKey = 'sync_queue_overflow';
  static const int _maxQueueSize = 1000; // Maximum operations in main queue
  static const int _maxOverflowSize = 5000; // Maximum operations in overflow storage
  
  EnhancedSyncQueue._();
  
  static EnhancedSyncQueue get instance {
    _instance ??= EnhancedSyncQueue._();
    return _instance!;
  }
  
  /// Enqueue an operation with overflow protection
  Future<bool> enqueue(String action, Map<String, dynamic> data, {SyncPriority priority = SyncPriority.normal}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Create operation record
      final operation = {
        'action': action,
        'data': data,
        'priority': priority.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'operation_id': _generateOperationId(),
        'synced': false,
        'retry_count': 0,
        'max_retries': 5,
      };
      
      // Load current queue
      final queue = await _loadQueue();
      
      // Check if queue is full
      if (queue.length >= _maxQueueSize) {
        if (kDebugMode) debugPrint('⚠️ Main queue full, moving to overflow storage');
        await _moveToOverflow(operation);
        return true;
      }
      
      // Add to queue based on priority
      if (priority == SyncPriority.high) {
        // High priority goes to front
        queue.insert(0, operation);
      } else {
        // Normal priority goes to end
        queue.add(operation);
      }
      
      // Save queue
      await _saveQueue(queue);
      
      if (kDebugMode) debugPrint('📋 Enqueued operation: $action (Queue size: ${queue.length})');
      return true;
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error enqueuing operation: $e');
      return false;
    }
  }
  
  /// Process queue with overflow handling
  Future<SyncResult> processQueue() async {
    final result = SyncResult();
    
    try {
      final token = await SecureTokenStorage.getToken();
      if (token == null || token.isEmpty) {
        if (kDebugMode) debugPrint('🔒 No token available, skipping sync');
        return result;
      }
      
      // Process main queue first
      await _processMainQueue(result, token);
      
      // Process overflow queue if main queue is empty
      if (result.processedCount == 0) {
        await _processOverflowQueue(result, token);
      }
      
      if (kDebugMode) {
        debugPrint('📊 Sync completed: ${result.processedCount} processed, ${result.successCount} success, ${result.errorCount} errors');
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Queue processing error: $e');
    }
    
    return result;
  }
  
  /// Process main queue
  Future<void> _processMainQueue(SyncResult result, String token) async {
    final queue = await _loadQueue();
    final List<int> toRemove = [];
    
    for (int i = 0; i < queue.length; i++) {
      if (result.processedCount >= 50) break; // Safety limit
      
      final operation = queue[i];
      if (operation['synced'] == true) {
        toRemove.add(i);
        continue;
      }
      
      try {
        final success = await _syncOperation(operation, token);
        
        if (success) {
          operation['synced'] = true;
          toRemove.add(i);
          result.successCount++;
          if (kDebugMode) debugPrint('✅ Synced: ${operation['action']}');
        } else {
          operation['retry_count'] = (operation['retry_count'] as int) + 1;
          if (operation['retry_count'] >= operation['max_retries']) {
            // Max retries reached, move to overflow
            await _moveToOverflow(operation);
            toRemove.add(i);
            result.errorCount++;
            if (kDebugMode) debugPrint('⚠️ Max retries reached, moved to overflow: ${operation['action']}');
          }
        }
        
        result.processedCount++;
        
      } catch (e) {
        operation['retry_count'] = (operation['retry_count'] as int) + 1;
        if (kDebugMode) debugPrint('❌ Sync error: ${operation['action']} - $e');
      }
    }
    
    // Remove synced items
    for (final index in toRemove.reversed) {
      queue.removeAt(index);
    }
    
    await _saveQueue(queue);
  }
  
  /// Process overflow queue
  Future<void> _processOverflowQueue(SyncResult result, String token) async {
    final overflow = await _loadOverflow();
    final List<int> toRemove = [];
    
    for (int i = 0; i < overflow.length; i++) {
      if (result.processedCount >= 30) break; // Lower limit for overflow
      
      final operation = overflow[i];
      if (operation['synced'] == true) {
        toRemove.add(i);
        continue;
      }
      
      try {
        final success = await _syncOperation(operation, token);
        
        if (success) {
          operation['synced'] = true;
          toRemove.add(i);
          result.successCount++;
          if (kDebugMode) debugPrint('✅ Synced from overflow: ${operation['action']}');
        }
        
        result.processedCount++;
        
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Overflow sync error: ${operation['action']} - $e');
      }
    }
    
    // Remove synced items
    for (final index in toRemove.reversed) {
      overflow.removeAt(index);
    }
    
    await _saveOverflow(overflow);
  }
  
  /// Sync a single operation
  Future<bool> _syncOperation(Map<String, dynamic> operation, String token) async {
    try {
      final action = operation['action'] as String;
      final data = operation['data'] as Map<String, dynamic>;
      
      String endpoint;
      switch (action) {
        case 'save_customer':
          endpoint = ApiClient.customersPrefix;
          break;
        case 'save_sale':
          endpoint = '/api/invoices/sync';
          break;
        case 'save_product':
          endpoint = '/api/products';
          break;
        default:
          if (kDebugMode) debugPrint('⚠️ Unknown action: $action');
          return false;
      }
      
      final response = await ApiClient.postJson(
        endpoint,
        data,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      
      return response.statusCode == 200 || response.statusCode == 201;
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Operation sync error: $e');
      return false;
    }
  }
  
  /// Move operation to overflow storage
  Future<void> _moveToOverflow(Map<String, dynamic> operation) async {
    try {
      final overflow = await _loadOverflow();
      
      if (overflow.length >= _maxOverflowSize) {
        // Overflow is also full, remove oldest
        overflow.removeAt(0);
        if (kDebugMode) debugPrint('⚠️ Overflow full, removed oldest operation');
      }
      
      overflow.add(operation);
      await _saveOverflow(overflow);
      
      if (kDebugMode) debugPrint('📦 Moved operation to overflow (Size: ${overflow.length})');
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error moving to overflow: $e');
    }
  }
  
  /// Load main queue
  Future<List<Map<String, dynamic>>> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey) ?? '[]';
      final List<dynamic> decoded = json.decode(queueJson);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error loading queue: $e');
      return [];
    }
  }
  
  /// Save main queue
  Future<void> _saveQueue(List<Map<String, dynamic>> queue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_queueKey, json.encode(queue));
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error saving queue: $e');
    }
  }
  
  /// Load overflow storage
  Future<List<Map<String, dynamic>>> _loadOverflow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final overflowJson = prefs.getString(_overflowKey) ?? '[]';
      final List<dynamic> decoded = json.decode(overflowJson);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error loading overflow: $e');
      return [];
    }
  }
  
  /// Save overflow storage
  Future<void> _saveOverflow(List<Map<String, dynamic>> overflow) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_overflowKey, json.encode(overflow));
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error saving overflow: $e');
    }
  }
  
  /// Get queue statistics
  Future<QueueStats> getStats() async {
    final queue = await _loadQueue();
    final overflow = await _loadOverflow();
    
    int highPriority = 0;
    int normalPriority = 0;
    int synced = 0;
    
    for (final op in queue) {
      if (op['synced'] == true) synced++;
      if (op['priority'] == SyncPriority.high.toString()) highPriority++;
      else normalPriority++;
    }
    
    return QueueStats(
      mainQueueSize: queue.length,
      overflowSize: overflow.length,
      highPriorityPending: highPriority,
      normalPriorityPending: normalPriority,
      syncedCount: synced,
      totalPending: queue.length + overflow.length - synced,
    );
  }
  
  /// Clear all queues (use with caution)
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
      await prefs.remove(_overflowKey);
      if (kDebugMode) debugPrint('🗑️ All sync queues cleared');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error clearing queues: $e');
    }
  }
  
  /// Generate unique operation ID
  String _generateOperationId() {
    return 'OP_${DateTime.now().millisecondsSinceEpoch}_${_randomString(8)}';
  }
  
  /// Generate random string for ID
  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String result = '';
    for (int i = 0; i < length; i++) {
      result += chars[(random + i) % chars.length];
    }
    return result;
  }
}

/// Sync priority levels
enum SyncPriority {
  high,
  normal,
}

/// Sync result
class SyncResult {
  int processedCount = 0;
  int successCount = 0;
  int errorCount = 0;
  int overflowProcessed = 0;
}

/// Queue statistics
class QueueStats {
  final int mainQueueSize;
  final int overflowSize;
  final int highPriorityPending;
  final int normalPriorityPending;
  final int syncedCount;
  final int totalPending;
  
  QueueStats({
    required this.mainQueueSize,
    required this.overflowSize,
    required this.highPriorityPending,
    required this.normalPriorityPending,
    required this.syncedCount,
    required this.totalPending,
  });
  
  bool get isOverflowActive => overflowSize > 0;
  bool get needsAttention => totalPending > 100;
}
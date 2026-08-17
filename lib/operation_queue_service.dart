import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:synchronized/synchronized.dart';
import 'uuid_service.dart';
import 'session_management.dart';

/// Persistent Operation Queue Service
/// Stores sync operations in persistent storage to survive app restarts
/// Implements retry logic with exponential backoff
class OperationQueueService {
  static const String _operationsBox = 'sync_operations_v2';
  static const String _queueMetadataBox = 'sync_queue_metadata';
  
  static final Lock _lock = Lock();
  static OperationQueueService? _instance;
  
  OperationQueueService._();
  
  static OperationQueueService get instance {
    _instance ??= OperationQueueService._();
    return _instance!;
  }
  
  /// Initialize the operation queue
  static Future<void> initialize() async {
    await Hive.openBox(_operationsBox);
    await Hive.openBox(_queueMetadataBox);
    
    // Clean up any orphaned operations on startup
    await _cleanupOrphanedOperations();
  }
  
  /// Enqueue a new operation
  Future<String> enqueueOperation({
    required OperationType type,
    required Map<String, dynamic> payload,
    String? entityId,
    OperationPriority? priority,
  }) async {
    return await _lock.synchronized(() async {
      final operationId = UuidService.generateWithPrefix(type.toOperationString());
      
      final operation = Operation(
        operationId: operationId,
        type: type,
        payload: payload,
        entityId: entityId,
        status: OperationStatus.pending,
        retryCount: 0,
        createdTime: DateTime.now(),
        priority: priority ?? type.getPriority(),
        deviceId: await SessionManagementService.getDeviceId(),
        userId: (await SessionManagementService.getCurrentUserId()) ?? 0,
      );
      
      final box = Hive.box(_operationsBox);
      await box.put(operationId, operation.toJson());
      
      // Update queue metadata
      await _updateQueueMetadata();
      
      if (kDebugMode) {
        debugPrint('📝 Operation enqueued: $operationId (${type.toOperationString()})');
      }
      
      return operationId;
    });
  }
  
  /// Get next pending operation (high priority first)
  Future<Operation?> getNextOperation() async {
    return await _lock.synchronized(() async {
      final box = Hive.box(_operationsBox);
      
      // Get all pending operations
      final pendingOps = box.values
          .map((json) => Operation.fromJson(json as Map<String, dynamic>))
          .where((op) => op.status == OperationStatus.pending)
          .toList();
      
      if (pendingOps.isEmpty) return null;
      
      // Sort by priority (high first) and then by created time
      pendingOps.sort((a, b) {
        final priorityCompare = _priorityOrder(a.priority).compareTo(_priorityOrder(b.priority));
        if (priorityCompare != 0) return priorityCompare;
        return a.createdTime.compareTo(b.createdTime);
      });
      
      return pendingOps.first;
    });
  }
  
  /// Mark operation as in progress
  Future<void> markInProgress(String operationId) async {
    return await _lock.synchronized(() async {
      final box = Hive.box(_operationsBox);
      final json = box.get(operationId);
      
      if (json != null) {
        final operation = Operation.fromJson(json as Map<String, dynamic>);
        final updated = operation.copyWith(
          status: OperationStatus.inProgress,
        );
        await box.put(operationId, updated.toJson());
      }
    });
  }
  
  /// Mark operation as completed
  Future<void> markCompleted(String operationId) async {
    return await _lock.synchronized(() async {
      final box = Hive.box(_operationsBox);
      await box.delete(operationId);
      
      await _updateQueueMetadata();
      
      if (kDebugMode) {
        debugPrint('✅ Operation completed: $operationId');
      }
    });
  }
  
  /// Mark operation as failed (will retry)
  Future<void> markFailed(String operationId, {String? error}) async {
    return await _lock.synchronized(() async {
      final box = Hive.box(_operationsBox);
      final json = box.get(operationId);
      
      if (json != null) {
        final operation = Operation.fromJson(json as Map<String, dynamic>);
        
        // Check if max retries exceeded
        if (operation.retryCount >= _maxRetriesForPriority(operation.priority)) {
          // Cancel operation
          await markCancelled(operationId, error: 'Max retries exceeded');
          return;
        }
        
        final updated = operation.copyWith(
          status: OperationStatus.failed,
          retryCount: operation.retryCount + 1,
          lastError: error,
        );
        await box.put(operationId, updated.toJson());
        
        if (kDebugMode) {
          debugPrint('❌ Operation failed: $operationId (Retry ${updated.retryCount})');
        }
      }
    });
  }
  
  /// Mark operation as cancelled
  Future<void> markCancelled(String operationId, {String? error}) async {
    return await _lock.synchronized(() async {
      final box = Hive.box(_operationsBox);
      final json = box.get(operationId);
      
      if (json != null) {
        final operation = Operation.fromJson(json as Map<String, dynamic>);
        final updated = operation.copyWith(
          status: OperationStatus.cancelled,
          lastError: error,
        );
        await box.put(operationId, updated.toJson());
        
        if (kDebugMode) {
          debugPrint('🚫 Operation cancelled: $operationId');
        }
      }
    });
  }
  
  /// Get operation by ID
  Future<Operation?> getOperation(String operationId) async {
    final box = Hive.box(_operationsBox);
    final json = box.get(operationId);
    
    if (json == null) return null;
    
    return Operation.fromJson(json as Map<String, dynamic>);
  }
  
  /// Get all pending operations
  Future<List<Operation>> getPendingOperations() async {
    final box = Hive.box(_operationsBox);
    
    return box.values
        .map((json) => Operation.fromJson(json as Map<String, dynamic>))
        .where((op) => op.status == OperationStatus.pending)
        .toList();
  }
  
  /// Get queue statistics
  Future<QueueStats> getQueueStats() async {
    final box = Hive.box(_operationsBox);
    final metadataBox = Hive.box(_queueMetadataBox);
    
    final operations = box.values
        .map((json) => Operation.fromJson(json as Map<String, dynamic>))
        .toList();
    
    final pending = operations.where((op) => op.status == OperationStatus.pending).length;
    final inProgress = operations.where((op) => op.status == OperationStatus.inProgress).length;
    final failed = operations.where((op) => op.status == OperationStatus.failed).length;
    final cancelled = operations.where((op) => op.status == OperationStatus.cancelled).length;
    
    return QueueStats(
      totalOperations: operations.length,
      pendingOperations: pending,
      inProgressOperations: inProgress,
      failedOperations: failed,
      cancelledOperations: cancelled,
      highPriorityPending: operations.where((op) => 
          op.status == OperationStatus.pending && op.priority == OperationPriority.high).length,
      lastSyncTime: metadataBox.get('last_sync_time') != null
          ? DateTime.parse(metadataBox.get('last_sync_time') as String)
          : null,
    );
  }
  
  /// Clear all operations (use with caution)
  Future<void> clearAll() async {
    return await _lock.synchronized(() async {
      final box = Hive.box(_operationsBox);
      await box.clear();
      
      final metadataBox = Hive.box(_queueMetadataBox);
      await metadataBox.clear();
      
      if (kDebugMode) {
        debugPrint('🧹 Operation queue cleared');
      }
    });
  }
  
  /// Retry failed operations
  Future<void> retryFailedOperations() async {
    return await _lock.synchronized(() async {
      final box = Hive.box(_operationsBox);
      
      final failedOps = box.values
          .map((json) => Operation.fromJson(json as Map<String, dynamic>))
          .where((op) => op.status == OperationStatus.failed)
          .toList();
      
      for (final op in failedOps) {
        final updated = op.copyWith(
          status: OperationStatus.pending,
          retryCount: 0,
        );
        await box.put(op.operationId, updated.toJson());
      }
      
      if (kDebugMode) {
        debugPrint('🔄 Retried ${failedOps.length} failed operations');
      }
    });
  }
  
  /// Clean up old completed/cancelled operations
  Future<void> cleanupOldOperations({Duration maxAge = const Duration(days: 7)}) async {
    return await _lock.synchronized(() async {
      final box = Hive.box(_operationsBox);
      final cutoff = DateTime.now().subtract(maxAge);
      
      final keysToDelete = <String>[];
      
      for (final key in box.keys) {
        final json = box.get(key);
        if (json == null) continue;
        
        final operation = Operation.fromJson(json as Map<String, dynamic>);
        
        // Clean up completed/cancelled operations older than maxAge
        if ((operation.status == OperationStatus.completed || 
             operation.status == OperationStatus.cancelled) &&
            operation.createdTime.isBefore(cutoff)) {
          keysToDelete.add(key as String);
        }
      }
      
      for (final key in keysToDelete) {
        await box.delete(key);
      }
      
      if (kDebugMode && keysToDelete.isNotEmpty) {
        debugPrint('🧹 Cleaned up ${keysToDelete.length} old operations');
      }
    });
  }
  
  /// Clean up orphaned operations (stuck in in_progress)
  static Future<void> _cleanupOrphanedOperations() async {
    final box = Hive.box(_operationsBox);
    
    final orphanedOps = box.values
        .map((json) => Operation.fromJson(json as Map<String, dynamic>))
        .where((op) => op.status == OperationStatus.inProgress)
        .where((op) => DateTime.now().difference(op.createdTime) > const Duration(minutes: 5))
        .toList();
    
    for (final op in orphanedOps) {
      final updated = op.copyWith(status: OperationStatus.pending);
      await box.put(op.operationId, updated.toJson());
      
      if (kDebugMode) {
        debugPrint('🔄 Reset orphaned operation: ${op.operationId}');
      }
    }
  }
  
  /// Update queue metadata
  static Future<void> _updateQueueMetadata() async {
    final box = Hive.box(_queueMetadataBox);
    await box.put('last_sync_time', DateTime.now().toIso8601String());
  }
  
  /// Priority order for sorting (lower number = higher priority)
  static int _priorityOrder(OperationPriority priority) {
    switch (priority) {
      case OperationPriority.high:
        return 0;
      case OperationPriority.medium:
        return 1;
      case OperationPriority.low:
        return 2;
    }
  }
  
  /// Max retries based on priority
  static int _maxRetriesForPriority(OperationPriority priority) {
    switch (priority) {
      case OperationPriority.high:
        return 10; // More retries for critical operations
      case OperationPriority.medium:
        return 5;
      case OperationPriority.low:
        return 3;
    }
  }
}

/// Operation model
class Operation {
  final String operationId;      // Unique operation ID (with prefix)
  final OperationType type;      // Type of operation
  final Map<String, dynamic> payload;  // Operation data
  final String? entityId;        // Affected entity UUID
  final OperationStatus status;  // Current status
  final int retryCount;          // Number of retries attempted
  final DateTime createdTime;    // When operation was created
  final OperationPriority priority; // Priority level
  final String deviceId;         // Device that created the operation
  final int userId;              // User who created the operation
  final String? lastError;       // Last error message
  
  Operation({
    required this.operationId,
    required this.type,
    required this.payload,
    this.entityId,
    required this.status,
    required this.retryCount,
    required this.createdTime,
    required this.priority,
    required this.deviceId,
    required this.userId,
    this.lastError,
  });
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'operation_id': operationId,
      'type': type.toOperationString(),
      'payload': jsonEncode(payload),
      'entity_id': entityId,
      'status': status.toString(),
      'retry_count': retryCount,
      'created_time': createdTime.toIso8601String(),
      'priority': priority.toString(),
      'device_id': deviceId,
      'user_id': userId,
      'last_error': lastError,
    };
  }
  
  /// Create from JSON
  factory Operation.fromJson(Map<String, dynamic> json) {
    return Operation(
      operationId: json['operation_id'] as String,
      type: OperationTypeExtension.fromString(json['type'] as String),
      payload: jsonDecode(json['payload'] as String) as Map<String, dynamic>,
      entityId: json['entity_id'] as String?,
      status: _parseStatus(json['status'] as String?),
      retryCount: json['retry_count'] as int? ?? 0,
      createdTime: DateTime.parse(json['created_time'] as String),
      priority: _parsePriority(json['priority'] as String?),
      deviceId: json['device_id'] as String,
      userId: json['user_id'] as int,
      lastError: json['last_error'] as String?,
    );
  }
  
  /// Create a copy with updated fields
  Operation copyWith({
    OperationStatus? status,
    int? retryCount,
    String? lastError,
  }) {
    return Operation(
      operationId: operationId,
      type: type,
      payload: payload,
      entityId: entityId,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      createdTime: createdTime,
      priority: priority,
      deviceId: deviceId,
      userId: userId,
      lastError: lastError ?? this.lastError,
    );
  }
  
  static OperationStatus _parseStatus(String? status) {
    switch (status) {
      case 'OperationStatus.pending':
        return OperationStatus.pending;
      case 'OperationStatus.inProgress':
        return OperationStatus.inProgress;
      case 'OperationStatus.completed':
        return OperationStatus.completed;
      case 'OperationStatus.failed':
        return OperationStatus.failed;
      case 'OperationStatus.cancelled':
        return OperationStatus.cancelled;
      default:
        return OperationStatus.pending;
    }
  }
  
  static OperationPriority _parsePriority(String? priority) {
    switch (priority) {
      case 'OperationPriority.high':
        return OperationPriority.high;
      case 'OperationPriority.medium':
        return OperationPriority.medium;
      case 'OperationPriority.low':
        return OperationPriority.low;
      default:
        return OperationPriority.medium;
    }
  }
}

/// Queue statistics
class QueueStats {
  final int totalOperations;
  final int pendingOperations;
  final int inProgressOperations;
  final int failedOperations;
  final int cancelledOperations;
  final int highPriorityPending;
  final DateTime? lastSyncTime;
  
  QueueStats({
    required this.totalOperations,
    required this.pendingOperations,
    required this.inProgressOperations,
    required this.failedOperations,
    required this.cancelledOperations,
    required this.highPriorityPending,
    this.lastSyncTime,
  });
  
  /// Get queue health status
  QueueHealth get health {
    if (failedOperations > 10) return QueueHealth.critical;
    if (failedOperations > 5) return QueueHealth.warning;
    if (highPriorityPending > 20) return QueueHealth.warning;
    return QueueHealth.healthy;
  }
}

/// Queue health status
enum QueueHealth {
  healthy,
  warning,
  critical,
}
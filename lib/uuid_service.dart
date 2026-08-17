import 'package:uuid/uuid.dart';

/// UUID Service for generating globally unique identifiers
/// This service ensures no duplicate IDs across devices and time
class UuidService {
  static final Uuid _uuid = Uuid();
  
  /// Generate a new UUID v4
  static String generate() {
    return _uuid.v4();
  }
  
  /// Generate multiple UUIDs at once
  static List<String> generateBatch(int count) {
    return List.generate(count, (_) => generate());
  }
  
  /// Validate if a string is a valid UUID
  static bool isValid(String? uuid) {
    if (uuid == null || uuid.isEmpty) return false;
    
    try {
      final regex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
      );
      return regex.hasMatch(uuid);
    } catch (e) {
      return false;
    }
  }
  
  /// Generate a UUID with a specific prefix for operation IDs
  /// Example: "create_sale_abc123-def456-..."
  static String generateWithPrefix(String prefix) {
    return '${prefix}_${generate()}';
  }
  
  /// Extract the prefix from a prefixed UUID
  static String? extractPrefix(String prefixedUuid) {
    if (!prefixedUuid.contains('_')) return null;
    
    final parts = prefixedUuid.split('_');
    if (parts.length < 2) return null;
    
    return parts.sublist(0, parts.length - 1).join('_');
  }
  
  /// Get the base UUID from a prefixed UUID
  static String getBaseUuid(String prefixedUuid) {
    if (!prefixedUuid.contains('_')) return prefixedUuid;
    
    final parts = prefixedUuid.split('_');
    return parts.last;
  }
}

/// Sync Metadata for all database entities
/// This ensures proper synchronization and conflict resolution
class SyncMetadata {
  final String uuid;              // Global UUID (primary key)
  final int version;              // Version number for conflict resolution
  final DateTime updatedAt;       // Last update timestamp
  final DateTime createdAt;       // Creation timestamp
  final bool deleted;             // Soft delete flag
  final DateTime? deletedAt;      // Deletion timestamp
  final SyncStatus syncStatus;    // Current sync status
  final String deviceId;          // Device that created/modified
  final DateTime? lastSyncedAt;   // Last successful sync timestamp
  
  SyncMetadata({
    required this.uuid,
    this.version = 1,
    required this.updatedAt,
    required this.createdAt,
    this.deleted = false,
    this.deletedAt,
    this.syncStatus = SyncStatus.pending,
    required this.deviceId,
    this.lastSyncedAt,
  });
  
  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'version': version,
      'updated_at': updatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'deleted': deleted,
      'deleted_at': deletedAt?.toIso8601String(),
      'sync_status': syncStatus.toString(),
      'device_id': deviceId,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
    };
  }
  
  /// Create from JSON
  factory SyncMetadata.fromJson(Map<String, dynamic> json) {
    return SyncMetadata(
      uuid: json['uuid'] as String,
      version: json['version'] as int? ?? 1,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      deleted: json['deleted'] as bool? ?? false,
      deletedAt: json['deleted_at'] != null 
          ? DateTime.parse(json['deleted_at'] as String) 
          : null,
      syncStatus: _parseSyncStatus(json['sync_status'] as String?),
      deviceId: json['device_id'] as String,
      lastSyncedAt: json['last_synced_at'] != null
          ? DateTime.parse(json['last_synced_at'] as String)
          : null,
    );
  }
  
  static SyncStatus _parseSyncStatus(String? status) {
    switch (status) {
      case 'SyncStatus.synced':
        return SyncStatus.synced;
      case 'SyncStatus.pending':
        return SyncStatus.pending;
      case 'SyncStatus.conflict':
        return SyncStatus.conflict;
      case 'SyncStatus.error':
        return SyncStatus.error;
      default:
        return SyncStatus.pending;
    }
  }
  
  /// Create a copy with updated version
  SyncMetadata incrementVersion() {
    return SyncMetadata(
      uuid: uuid,
      version: version + 1,
      updatedAt: DateTime.now(),
      createdAt: createdAt,
      deleted: deleted,
      deletedAt: deletedAt,
      syncStatus: SyncStatus.pending,
      deviceId: deviceId,
      lastSyncedAt: lastSyncedAt,
    );
  }
  
  /// Mark as deleted
  SyncMetadata markDeleted() {
    return SyncMetadata(
      uuid: uuid,
      version: version + 1,
      updatedAt: DateTime.now(),
      createdAt: createdAt,
      deleted: true,
      deletedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
      deviceId: deviceId,
      lastSyncedAt: lastSyncedAt,
    );
  }
  
  /// Mark as synced
  SyncMetadata markSynced() {
    return SyncMetadata(
      uuid: uuid,
      version: version,
      updatedAt: updatedAt,
      createdAt: createdAt,
      deleted: deleted,
      deletedAt: deletedAt,
      syncStatus: SyncStatus.synced,
      deviceId: deviceId,
      lastSyncedAt: DateTime.now(),
    );
  }
}

/// Sync status enum
enum SyncStatus {
  synced,      // Successfully synced with cloud
  pending,     // Pending sync (local changes not yet uploaded)
  conflict,    // Conflict detected (requires resolution)
  error,       // Sync error (will retry)
}

/// Operation types for the operation queue
enum OperationType {
  createSale,
  updateSale,
  deleteSale,
  createCustomer,
  updateCustomer,
  deleteCustomer,
  createProduct,
  updateProduct,
  deleteProduct,
  updateStock,
  createInvoice,
  updateInvoice,
  deleteInvoice,
  createExpense,
  updateExpense,
  deleteExpense,
  createSupplier,
  updateSupplier,
  deleteSupplier,
  returnProduct,
  editInvoice,
}

/// Convert operation type to string
extension OperationTypeExtension on OperationType {
  String toOperationString() {
    switch (this) {
      case OperationType.createSale:
        return 'create_sale';
      case OperationType.updateSale:
        return 'update_sale';
      case OperationType.deleteSale:
        return 'delete_sale';
      case OperationType.createCustomer:
        return 'create_customer';
      case OperationType.updateCustomer:
        return 'update_customer';
      case OperationType.deleteCustomer:
        return 'delete_customer';
      case OperationType.createProduct:
        return 'create_product';
      case OperationType.updateProduct:
        return 'update_product';
      case OperationType.deleteProduct:
        return 'delete_product';
      case OperationType.updateStock:
        return 'update_stock';
      case OperationType.createInvoice:
        return 'create_invoice';
      case OperationType.updateInvoice:
        return 'update_invoice';
      case OperationType.deleteInvoice:
        return 'delete_invoice';
      case OperationType.createExpense:
        return 'create_expense';
      case OperationType.updateExpense:
        return 'update_expense';
      case OperationType.deleteExpense:
        return 'delete_expense';
      case OperationType.createSupplier:
        return 'create_supplier';
      case OperationType.updateSupplier:
        return 'update_supplier';
      case OperationType.deleteSupplier:
        return 'delete_supplier';
      case OperationType.returnProduct:
        return 'return_product';
      case OperationType.editInvoice:
        return 'edit_invoice';
    }
  }
  
  static OperationType fromString(String operationString) {
    switch (operationString) {
      case 'create_sale':
        return OperationType.createSale;
      case 'update_sale':
        return OperationType.updateSale;
      case 'delete_sale':
        return OperationType.deleteSale;
      case 'create_customer':
        return OperationType.createCustomer;
      case 'update_customer':
        return OperationType.updateCustomer;
      case 'delete_customer':
        return OperationType.deleteCustomer;
      case 'create_product':
        return OperationType.createProduct;
      case 'update_product':
        return OperationType.updateProduct;
      case 'delete_product':
        return OperationType.deleteProduct;
      case 'update_stock':
        return OperationType.updateStock;
      case 'create_invoice':
        return OperationType.createInvoice;
      case 'update_invoice':
        return OperationType.updateInvoice;
      case 'delete_invoice':
        return OperationType.deleteInvoice;
      case 'create_expense':
        return OperationType.createExpense;
      case 'update_expense':
        return OperationType.updateExpense;
      case 'delete_expense':
        return OperationType.deleteExpense;
      case 'create_supplier':
        return OperationType.createSupplier;
      case 'update_supplier':
        return OperationType.updateSupplier;
      case 'delete_supplier':
        return OperationType.deleteSupplier;
      case 'return_product':
        return OperationType.returnProduct;
      case 'edit_invoice':
        return OperationType.editInvoice;
      default:
        throw ArgumentError('Unknown operation type: $operationString');
    }
  }
  
  /// Get priority level for this operation type
  OperationPriority getPriority() {
    switch (this) {
      case OperationType.createSale:
      case OperationType.updateSale:
      case OperationType.deleteSale:
      case OperationType.updateStock:
      case OperationType.returnProduct:
        return OperationPriority.high;
      case OperationType.createCustomer:
      case OperationType.updateCustomer:
      case OperationType.deleteCustomer:
      case OperationType.createInvoice:
      case OperationType.updateInvoice:
      case OperationType.deleteInvoice:
      case OperationType.editInvoice:
      case OperationType.createExpense:
      case OperationType.updateExpense:
      case OperationType.deleteExpense:
      case OperationType.createSupplier:
      case OperationType.updateSupplier:
      case OperationType.deleteSupplier:
        return OperationPriority.medium;
      case OperationType.createProduct:
      case OperationType.updateProduct:
      case OperationType.deleteProduct:
        return OperationPriority.low;
    }
  }
}

/// Operation priority for sync queue
enum OperationPriority {
  high,    // Sync immediately (sales, stock, returns)
  medium,  // Sync within minutes (customers, invoices, expenses)
  low,     // Sync in background (products, suppliers)
}

/// Operation status
enum OperationStatus {
  pending,      // Waiting to be processed
  inProgress,   // Currently being processed
  completed,    // Successfully completed
  failed,       // Failed (will retry)
  cancelled,    // Cancelled by user
}
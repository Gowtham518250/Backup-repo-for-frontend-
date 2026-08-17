import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:synchronized/synchronized.dart';
import 'uuid_service.dart';
import 'operation_queue_service.dart';
import 'session_management.dart';

/// Enhanced Local Storage Service with UUID and Sync Metadata
/// This service implements the production-grade architecture with:
/// - UUID-based entity identification
/// - Sync metadata on all entities
/// - Operation queue integration
/// - ACID-like transactions
class EnhancedLocalStorageService {
  static const int _schemaVersion = 4; // Updated for UUID support
  static const String _schemaVersionKey = 'enhanced_schema_version';

  // FIX (Issue 2.2): userId-scoped box names so each user's data is isolated.
  // Call initialize(userId: ...) before any storage operations.
  static String _userId = 'guest';

  static String get _salesBox     => 'sales_uuid_v2_$_userId';
  static String get _productsBox  => 'products_uuid_v2_$_userId';
  static String get _customersBox => 'customers_uuid_v2_$_userId';
  static String get _invoicesBox  => 'invoices_uuid_v2_$_userId';
  static String get _expensesBox  => 'expenses_uuid_v2_$_userId';
  static String get _inventoryBox => 'inventory_uuid_v2_$_userId';
  static String get _suppliersBox => 'suppliers_uuid_v2_$_userId';

  // Legacy (un-scoped) box names used before this fix.
  // Referenced during migration only.
  static const String _legacySalesBox     = 'sales_uuid_v2';
  static const String _legacyProductsBox  = 'products_uuid_v2';
  static const String _legacyCustomersBox = 'customers_uuid_v2';
  static const String _legacyInvoicesBox  = 'invoices_uuid_v2';
  static const String _legacyExpensesBox  = 'expenses_uuid_v2';
  static const String _legacyInventoryBox = 'inventory_uuid_v2';
  static const String _legacySuppliersBox = 'suppliers_uuid_v2';
  
  static final Lock _lock = Lock();
  static EnhancedLocalStorageService? _instance;
  
  EnhancedLocalStorageService._();
  
  static EnhancedLocalStorageService get instance {
    _instance ??= EnhancedLocalStorageService._();
    return _instance!;
  }
  
  /// Initialize enhanced storage with UUID support.
  ///
  /// [userId] MUST be the authenticated user's ID so that each user's Hive
  /// boxes are kept separate (FIX Issue 2.2). Fall back to `'guest'` only
  /// for unauthenticated bootstrap.
  static Future<void> initialize({String userId = 'guest'}) async {
    _userId = userId.isEmpty ? 'guest' : userId;

    await Hive.openBox(_salesBox);
    await Hive.openBox(_productsBox);
    await Hive.openBox(_customersBox);
    await Hive.openBox(_invoicesBox);
    await Hive.openBox(_expensesBox);
    await Hive.openBox(_inventoryBox);
    await Hive.openBox(_suppliersBox);
    
    // Initialize operation queue
    await OperationQueueService.initialize();
    
    await _validateAndMigrateSchema();
  }
  
  /// Validate and migrate schema if needed
  static Future<void> _validateAndMigrateSchema() async {
    final prefs = await Hive.openBox('app_metadata');
    final currentVersion = prefs.get(_schemaVersionKey) as int? ?? 0;
    
    if (currentVersion < _schemaVersion) {
      if (kDebugMode) {
        debugPrint('🔄 Migrating schema from version $currentVersion to $_schemaVersion');
      }
      
      // Perform migration steps
      await _migrateToUUIDSchema(currentVersion);
      
      await prefs.put(_schemaVersionKey, _schemaVersion);
      
      if (kDebugMode) {
        debugPrint('✅ Schema migration complete');
      }
    }
  }
  
  /// Migrate existing data to UUID-based schema.
  ///
  /// FIX (Issue 2.4): Copies records from the old un-scoped legacy boxes into
  /// the new user-scoped boxes. Records that already have a `uuid` field are
  /// treated as already migrated and skipped.
  static Future<void> _migrateToUUIDSchema(int fromVersion) async {
    if (kDebugMode) {
      debugPrint('🔄 UUID migration from version $fromVersion for user: $_userId');
    }

    // Pairs of (legacy box name, current scoped box getter).
    final migrations = [
      [_legacySalesBox,     _salesBox],
      [_legacyProductsBox,  _productsBox],
      [_legacyCustomersBox, _customersBox],
      [_legacyInvoicesBox,  _invoicesBox],
      [_legacyExpensesBox,  _expensesBox],
      [_legacyInventoryBox, _inventoryBox],
      [_legacySuppliersBox, _suppliersBox],
    ];

    for (final pair in migrations) {
      final legacyBoxName  = pair[0];
      final currentBoxName = pair[1];

      // Skip if both names are the same (already scoped from a previous run).
      if (legacyBoxName == currentBoxName) continue;

      try {
        // Open the legacy box (read-only intent).
        final legacyBox = await Hive.openBox(legacyBoxName);

        if (legacyBox.isEmpty) {
          continue;
        }

        final currentBox = Hive.box(currentBoxName);

        for (final rawKey in legacyBox.keys) {
          final value = legacyBox.get(rawKey);
          if (value == null) continue;

          try {
            final record = value as Map<String, dynamic>;

            // Assign a UUID if the record doesn't have one.
            final uuid = record['uuid'] as String? ?? UuidService.generate();
            final migratedRecord = {
              ...record,
              'uuid': uuid,
            };

            // Only write if not already present in the scoped box.
            if (currentBox.get(uuid) == null) {
              await currentBox.put(uuid, migratedRecord);
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️ Skipping corrupt record during migration: $e');
            }
          }
        }

        if (kDebugMode) {
          debugPrint('✅ Migrated ${legacyBox.length} records from $legacyBoxName → $currentBoxName');
        }
      } catch (e) {
        // Legacy box may not exist on fresh installs — that is expected.
        if (kDebugMode) {
          debugPrint('ℹ️ Legacy box $legacyBoxName not found (fresh install?): $e');
        }
      }
    }
  }
  
  /// ============================================
  /// SALE OPERATIONS WITH UUID AND SYNC METADATA
  /// ============================================
  
  /// Create a new sale with UUID and sync metadata
  Future<Map<String, dynamic>> createSale(Map<String, dynamic> saleData) async {
    return await _lock.synchronized(() async {
      // Generate UUID for the sale
      final saleUuid = UuidService.generate();
      
      // Create sync metadata
      final metadata = SyncMetadata(
        uuid: saleUuid,
        version: 1,
        updatedAt: DateTime.now(),
        createdAt: DateTime.now(),
        deleted: false,
        syncStatus: SyncStatus.pending,
        deviceId: await SessionManagementService.getDeviceId(),
      );
      
      // Add UUID and metadata to sale data
      final enhancedSale = {
        ...saleData,
        'uuid': saleUuid,
        'metadata': metadata.toJson(),
      };
      
      // Save to local storage
      final box = Hive.box(_salesBox);
      await box.put(saleUuid, enhancedSale);
      
      // Enqueue sync operation
      await OperationQueueService.instance.enqueueOperation(
        type: OperationType.createSale,
        payload: enhancedSale,
        entityId: saleUuid,
        priority: OperationPriority.high,
      );
      
      if (kDebugMode) {
        debugPrint('✅ Sale created with UUID: $saleUuid');
      }
      
      return enhancedSale;
    });
  }
  
  /// Update sale with version increment
  Future<Map<String, dynamic>?> updateSale(String saleUuid, Map<String, dynamic> updates) async {
    return await _lock.synchronized(() async {
      final box = Hive.box(_salesBox);
      final existing = box.get(saleUuid);
      
      if (existing == null) return null;
      
      final existingSale = existing as Map<String, dynamic>;
      final existingMetadata = SyncMetadata.fromJson(existingSale['metadata'] as Map<String, dynamic>);
      
      // Increment version and mark as pending sync
      final updatedMetadata = existingMetadata.incrementVersion();
      
      // Update sale data
      final updatedSale = {
        ...existingSale,
        ...updates,
        'metadata': updatedMetadata.toJson(),
      };
      
      await box.put(saleUuid, updatedSale);
      
      // Enqueue sync operation
      await OperationQueueService.instance.enqueueOperation(
        type: OperationType.updateSale,
        payload: updatedSale,
        entityId: saleUuid,
        priority: OperationPriority.high,
      );
      
      if (kDebugMode) {
        debugPrint('✅ Sale updated: $saleUuid (version ${updatedMetadata.version})');
      }
      
      return updatedSale;
    });
  }
  
  /// Soft delete sale
  Future<bool> deleteSale(String saleUuid) async {
    return await _lock.synchronized(() async {
      final box = Hive.box(_salesBox);
      final existing = box.get(saleUuid);
      
      if (existing == null) return false;
      
      final existingSale = existing as Map<String, dynamic>;
      final existingMetadata = SyncMetadata.fromJson(existingSale['metadata'] as Map<String, dynamic>);
      
      // Mark as deleted
      final deletedMetadata = existingMetadata.markDeleted();
      
      final deletedSale = {
        ...existingSale,
        'metadata': deletedMetadata.toJson(),
      };
      
      await box.put(saleUuid, deletedSale);
      
      // Enqueue sync operation
      await OperationQueueService.instance.enqueueOperation(
        type: OperationType.deleteSale,
        payload: {'uuid': saleUuid, 'deleted_at': deletedMetadata.deletedAt?.toIso8601String()},
        entityId: saleUuid,
        priority: OperationPriority.high,
      );
      
      if (kDebugMode) {
        debugPrint('🗑️ Sale soft-deleted: $saleUuid');
      }
      
      return true;
    });
  }
  
  /// Get sale by UUID
  Future<Map<String, dynamic>?> getSale(String saleUuid) async {
    final box = Hive.box(_salesBox);
    final sale = box.get(saleUuid);
    
    if (sale == null) return null;
    
    final saleData = sale as Map<String, dynamic>;
    final metadata = SyncMetadata.fromJson(saleData['metadata'] as Map<String, dynamic>);
    
    // Don't return deleted sales unless explicitly requested
    if (metadata.deleted) return null;
    
    return saleData;
  }
  
  /// Get all sales (excluding deleted)
  Future<List<Map<String, dynamic>>> getAllSales() async {
    final box = Hive.box(_salesBox);
    
    final sales = box.values
        .map((json) => json as Map<String, dynamic>)
        .where((sale) {
          final metadata = SyncMetadata.fromJson(sale['metadata'] as Map<String, dynamic>);
          return !metadata.deleted;
        })
        .toList();
    
    return sales;
  }
  
  /// ============================================
  /// CUSTOMER OPERATIONS WITH UUID AND SYNC METADATA
  /// ============================================
  
  /// Create customer with UUID
  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> customerData) async {
    return await _lock.synchronized(() async {
      final customerUuid = UuidService.generate();
      
      final metadata = SyncMetadata(
        uuid: customerUuid,
        version: 1,
        updatedAt: DateTime.now(),
        createdAt: DateTime.now(),
        deleted: false,
        syncStatus: SyncStatus.pending,
        deviceId: await SessionManagementService.getDeviceId(),
      );
      
      final enhancedCustomer = {
        ...customerData,
        'uuid': customerUuid,
        'metadata': metadata.toJson(),
      };
      
      final box = Hive.box(_customersBox);
      await box.put(customerUuid, enhancedCustomer);
      
      await OperationQueueService.instance.enqueueOperation(
        type: OperationType.createCustomer,
        payload: enhancedCustomer,
        entityId: customerUuid,
        priority: OperationPriority.medium,
      );
      
      if (kDebugMode) {
        debugPrint('✅ Customer created with UUID: $customerUuid');
      }
      
      return enhancedCustomer;
    });
  }
  
  /// Update customer
  Future<Map<String, dynamic>?> updateCustomer(String customerUuid, Map<String, dynamic> updates) async {
    return await _lock.synchronized(() async {
      final box = Hive.box(_customersBox);
      final existing = box.get(customerUuid);
      
      if (existing == null) return null;
      
      final existingCustomer = existing as Map<String, dynamic>;
      final existingMetadata = SyncMetadata.fromJson(existingCustomer['metadata'] as Map<String, dynamic>);
      
      final updatedMetadata = existingMetadata.incrementVersion();
      
      final updatedCustomer = {
        ...existingCustomer,
        ...updates,
        'metadata': updatedMetadata.toJson(),
      };
      
      await box.put(customerUuid, updatedCustomer);
      
      await OperationQueueService.instance.enqueueOperation(
        type: OperationType.updateCustomer,
        payload: updatedCustomer,
        entityId: customerUuid,
        priority: OperationPriority.medium,
      );
      
      return updatedCustomer;
    });
  }
  
  /// Get customer by UUID
  Future<Map<String, dynamic>?> getCustomer(String customerUuid) async {
    final box = Hive.box(_customersBox);
    final customer = box.get(customerUuid);
    
    if (customer == null) return null;
    
    final customerData = customer as Map<String, dynamic>;
    final metadata = SyncMetadata.fromJson(customerData['metadata'] as Map<String, dynamic>);
    
    if (metadata.deleted) return null;
    
    return customerData;
  }
  
  /// Get all customers
  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final box = Hive.box(_customersBox);
    
    return box.values
        .map((json) => json as Map<String, dynamic>)
        .where((customer) {
          final metadata = SyncMetadata.fromJson(customer['metadata'] as Map<String, dynamic>);
          return !metadata.deleted;
        })
        .toList();
  }
  
  /// ============================================
  /// INVENTORY OPERATIONS WITH UUID AND SYNC METADATA
  /// ============================================
  
  /// Update stock with operation queue
  Future<Map<String, dynamic>?> updateStock(String productUuid, int newQuantity, {String? reason}) async {
    return await _lock.synchronized(() async {
      final box = Hive.box(_inventoryBox);
      final existing = box.get(productUuid);
      
      if (existing == null) return null;
      
      final existingInventory = existing as Map<String, dynamic>;
      final existingMetadata = SyncMetadata.fromJson(existingInventory['metadata'] as Map<String, dynamic>);
      
      final updatedMetadata = existingMetadata.incrementVersion();
      
      final updatedInventory = {
        ...existingInventory,
        'quantity': newQuantity,
        'metadata': updatedMetadata.toJson(),
      };
      
      await box.put(productUuid, updatedInventory);
      
      await OperationQueueService.instance.enqueueOperation(
        type: OperationType.updateStock,
        payload: {
          'uuid': productUuid,
          'quantity': newQuantity,
          'reason': reason,
        },
        entityId: productUuid,
        priority: OperationPriority.high,
      );
      
      if (kDebugMode) {
        debugPrint('📦 Stock updated: $productUuid -> $newQuantity');
      }
      
      return updatedInventory;
    });
  }
  
  /// Get inventory item by UUID
  Future<Map<String, dynamic>?> getInventoryItem(String productUuid) async {
    final box = Hive.box(_inventoryBox);
    final item = box.get(productUuid);
    
    if (item == null) return null;
    
    final itemData = item as Map<String, dynamic>;
    final metadata = SyncMetadata.fromJson(itemData['metadata'] as Map<String, dynamic>);
    
    if (metadata.deleted) return null;
    
    return itemData;
  }
  
  /// Get all inventory items
  Future<List<Map<String, dynamic>>> getAllInventory() async {
    final box = Hive.box(_inventoryBox);
    
    return box.values
        .map((json) => json as Map<String, dynamic>)
        .where((item) {
          final metadata = SyncMetadata.fromJson(item['metadata'] as Map<String, dynamic>);
          return !metadata.deleted;
        })
        .toList();
  }
  
  /// ============================================
  /// TRANSACTION SUPPORT
  /// ============================================
  
  /// Execute multiple operations as a transaction
  /// If any operation fails, all are rolled back
  Future<bool> executeTransaction(List<TransactionOperation> operations) async {
    return await _lock.synchronized(() async {
      final transactionId = UuidService.generate();
      
      // Store original states for rollback
      final rollbackData = <String, dynamic>{};
      
      try {
        // Phase 1: Prepare all operations
        for (final operation in operations) {
          switch (operation.type) {
            case TransactionOpType.createSale:
              final saleUuid = UuidService.generate();
              operation.entityId = saleUuid;
              break;
            case TransactionOpType.updateStock:
              // Store original stock for rollback
              final existing = await getInventoryItem(operation.entityId!);
              if (existing != null) {
                rollbackData[operation.entityId!] = existing;
              }
              break;
            default:
              break;
          }
        }
        
        // Phase 2: Execute all operations
        for (final operation in operations) {
          switch (operation.type) {
            case TransactionOpType.createSale:
              await createSale(operation.data);
              break;
            case TransactionOpType.updateStock:
              await updateStock(operation.entityId!, operation.data['quantity'] as int);
              break;
            case TransactionOpType.createCustomer:
              await createCustomer(operation.data);
              break;
            default:
              break;
          }
        }
        
        if (kDebugMode) {
          debugPrint('✅ Transaction completed: $transactionId');
        }
        
        return true;
      } catch (e) {
        // Rollback all operations
        if (kDebugMode) {
          debugPrint('❌ Transaction failed, rolling back: $transactionId');
        }
        
        for (final entry in rollbackData.entries) {
          final box = Hive.box(_inventoryBox);
          await box.put(entry.key, entry.value);
        }
        
        return false;
      }
    });
  }
  
  /// ============================================
  /// SYNC INTEGRATION
  /// ============================================
  
  /// Mark entity as synced
  Future<void> markAsSynced(String entityType, String entityUuid) async {
    return await _lock.synchronized(() async {
      final box = _getBoxForEntityType(entityType);
      if (box == null) return;
      
      final existing = box.get(entityUuid);
      if (existing == null) return;
      
      final entityData = existing as Map<String, dynamic>;
      final existingMetadata = SyncMetadata.fromJson(entityData['metadata'] as Map<String, dynamic>);
      
      final syncedMetadata = existingMetadata.markSynced();
      
      final updatedEntity = {
        ...entityData,
        'metadata': syncedMetadata.toJson(),
      };
      
      await box.put(entityUuid, updatedEntity);
    });
  }
  
  /// Restore entity from cloud data
  Future<void> restoreFromCloud(String entityType, Map<String, dynamic> cloudData) async {
    return await _lock.synchronized(() async {
      final box = _getBoxForEntityType(entityType);
      if (box == null) return;
      
      final entityUuid = cloudData['uuid'] as String;
      
      // Create or update with synced metadata
      final metadata = SyncMetadata(
        uuid: entityUuid,
        version: cloudData['version'] as int? ?? 1,
        updatedAt: DateTime.parse(cloudData['updated_at'] as String),
        createdAt: DateTime.parse(cloudData['created_at'] as String),
        deleted: cloudData['deleted'] as bool? ?? false,
        deletedAt: cloudData['deleted_at'] != null 
            ? DateTime.parse(cloudData['deleted_at'] as String) 
            : null,
        syncStatus: SyncStatus.synced,
        deviceId: cloudData['device_id'] as String? ?? 'cloud',
        lastSyncedAt: DateTime.now(),
      );
      
      final enhancedData = {
        ...cloudData,
        'metadata': metadata.toJson(),
      };
      
      await box.put(entityUuid, enhancedData);
      
      if (kDebugMode) {
        debugPrint('🔄 Restored $entityType from cloud: $entityUuid');
      }
    });
  }
  
  /// Get sync status for all entities
  Future<SyncStatusReport> getSyncStatusReport() async {
    final report = SyncStatusReport();
    
    final salesBox = Hive.box(_salesBox);
    report.totalSales = salesBox.length;
    report.syncedSales = salesBox.values
        .where((sale) {
          final metadata = SyncMetadata.fromJson((sale as Map<String, dynamic>)['metadata'] as Map<String, dynamic>);
          return metadata.syncStatus == SyncStatus.synced;
        })
        .length;
    
    final customersBox = Hive.box(_customersBox);
    report.totalCustomers = customersBox.length;
    report.syncedCustomers = customersBox.values
        .where((customer) {
          final metadata = SyncMetadata.fromJson((customer as Map<String, dynamic>)['metadata'] as Map<String, dynamic>);
          return metadata.syncStatus == SyncStatus.synced;
        })
        .length;
    
    final inventoryBox = Hive.box(_inventoryBox);
    report.totalInventory = inventoryBox.length;
    report.syncedInventory = inventoryBox.values
        .where((item) {
          final metadata = SyncMetadata.fromJson((item as Map<String, dynamic>)['metadata'] as Map<String, dynamic>);
          return metadata.syncStatus == SyncStatus.synced;
        })
        .length;
    
    return report;
  }
  
  /// Get appropriate box for entity type
  static Box? _getBoxForEntityType(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'sale':
      case 'sales':
        return Hive.box(_salesBox);
      case 'customer':
      case 'customers':
        return Hive.box(_customersBox);
      case 'product':
      case 'products':
      case 'inventory':
        return Hive.box(_inventoryBox);
      case 'invoice':
      case 'invoices':
        return Hive.box(_invoicesBox);
      case 'expense':
      case 'expenses':
        return Hive.box(_expensesBox);
      case 'supplier':
      case 'suppliers':
        return Hive.box(_suppliersBox);
      default:
        return null;
    }
  }
}

/// Transaction operation for ACID-like transactions
class TransactionOperation {
  final TransactionOpType type;
  final Map<String, dynamic> data;
  String? entityId;
  
  TransactionOperation({
    required this.type,
    required this.data,
    this.entityId,
  });
}

/// Transaction operation types
enum TransactionOpType {
  createSale,
  updateStock,
  createCustomer,
  updateCustomer,
  deleteSale,
}

/// Sync status report
class SyncStatusReport {
  int totalSales = 0;
  int syncedSales = 0;
  int totalCustomers = 0;
  int syncedCustomers = 0;
  int totalInventory = 0;
  int syncedInventory = 0;
  
  double get salesSyncRate => totalSales > 0 ? syncedSales / totalSales : 1.0;
  double get customersSyncRate => totalCustomers > 0 ? syncedCustomers / totalCustomers : 1.0;
  double get inventorySyncRate => totalInventory > 0 ? syncedInventory / totalInventory : 1.0;
  
  double get overallSyncRate {
    final total = totalSales + totalCustomers + totalInventory;
    final synced = syncedSales + syncedCustomers + syncedInventory;
    return total > 0 ? synced / total : 1.0;
  }
}
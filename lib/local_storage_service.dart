import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'inventory_stock_helper.dart';
import 'sales_dedup_helper.dart';
import 'stored_sale.dart';

/// SENIOR ENGINEER REFACTOR: Enterprise Local Storage Service
/// Features: User Isolation, Hive Performance, Auto-recovery, and Zero Data Leakage.
class LocalStorageService {
  
  // ✅ FIX: Schema versioning to prevent silent data corruption on app updates
  static const int _schemaVersion = 3;
  static const String _schemaVersionKey = 'schema_version';
  
  // Hive Box Names
  static const String _salesBoxBase = 'sales_v2';
  static const String _productsBoxBase = 'products_v2';
  static const String _customersBoxBase = 'customers_v2';
  static const String _invoicesBoxBase = 'invoices_v2';
  static const String _purchaseOrdersBoxBase = 'purchase_orders_v2';
  static const String _khataBoxBase = 'khata_v2';
  static const String _idempotencyBoxBase = 'deductions_idempotency_v2';
  static const String _expensesBoxBase = 'expenses_v2';
  static const String _inventoryBoxBase = 'inventory_v2';

  static Future<int?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final primary = prefs.getInt('user_id');
    final alternate = prefs.getInt('userId');
    final id = primary ?? alternate;
    
    // 🔒 VALIDATION: Ensure user ID is valid and positive
    if (id != null && id > 0) {
      // Normalize user ID storage
      if (primary == null) {
        await prefs.setInt('user_id', id);
      }
      if (alternate == null) {
        await prefs.setInt('userId', id);
      }
      return id;
    }
    
    // 🔒 SECURITY: Throw error instead of failing silently for critical operations
    // This prevents data leakage by ensuring operations fail when user is not authenticated
    if (kDebugMode) debugPrint('⚠️ Invalid user ID detected: primary=$primary, alternate=$alternate');
    
    return null; // Return null for non-critical operations that check with _hasValidUserId()
  }
  
  /// ✅ FIX: Call on app startup to check and migrate schema if needed with proper backup and rollback
  static Future<void> validateAndMigrateSchema() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentVersion = prefs.getInt(_schemaVersionKey) ?? 0;
      
      if (currentVersion < _schemaVersion) {
        if (kDebugMode) {
          debugPrint('📊 Schema migration needed: $currentVersion → $_schemaVersion');
        }
        
        // Create backup before migration
        String? backupPath;
        try {
          backupPath = await _createSchemaBackup(currentVersion);
          if (kDebugMode) debugPrint('📦 Schema backup created at: $backupPath');
        } catch (backupError) {
          if (kDebugMode) debugPrint('⚠️ Schema backup failed: $backupError');
          // Continue with migration but log the risk
        }
        
        // Migration logic for each schema version
        try {
          // Migration from version 0 to 1
          if (currentVersion < 1) {
            await _migrateFromV0ToV1();
            // Update version incrementally for rollback safety
            await prefs.setInt(_schemaVersionKey, 1);
          }
          
          // Migration from version 1 to 2
          if (currentVersion < 2) {
            await _migrateFromV1ToV2();
            await prefs.setInt(_schemaVersionKey, 2);
          }
          
          // Migration from version 2 to 3
          if (currentVersion < 3) {
            await _migrateFromV2ToV3();
            await prefs.setInt(_schemaVersionKey, 3);
          }
          
          // Final update to target schema version
          await prefs.setInt(_schemaVersionKey, _schemaVersion);
          
          if (kDebugMode) {
            debugPrint('✅ Schema updated to $_schemaVersion');
          }
          
          // Clean up backup after successful migration
          if (backupPath != null) {
            try {
              await _cleanupSchemaBackup(backupPath);
              if (kDebugMode) debugPrint('🧹 Schema backup cleaned up');
            } catch (cleanupError) {
              if (kDebugMode) debugPrint('⚠️ Schema backup cleanup failed: $cleanupError');
            }
          }
        } catch (migrationError) {
          if (kDebugMode) debugPrint('❌ Schema migration failed: $migrationError');
          
          // Attempt rollback from backup
          if (backupPath != null) {
            try {
              await _restoreSchemaBackup(backupPath, currentVersion);
              if (kDebugMode) debugPrint('✅ Schema rollback successful from backup');
            } catch (rollbackError) {
              if (kDebugMode) debugPrint('❌ Schema rollback failed: $rollbackError');
              // Store critical error for user notification
              await prefs.setBool('schema_migration_critical_failure', true);
              await prefs.setString('schema_migration_error', 'Migration failed and rollback failed. Manual intervention may be required.');
            }
          }
          
          // Revert to previous version on failure
          await prefs.setInt(_schemaVersionKey, currentVersion);
          rethrow;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Schema validation error: $e');
    }
  }
  
  /// Create a backup of all Hive boxes before schema migration
  static Future<String?> _createSchemaBackup(int currentVersion) async {
    try {
      if (kIsWeb) return null; // Skip backup on web
      
      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupDir = Directory('${appDir.path}/hive_schema_backup_v${currentVersion}_$timestamp');
      
      if (await backupDir.exists()) {
        await backupDir.delete(recursive: true);
      }
      await backupDir.create(recursive: true);
      
      final hiveDir = Directory('${appDir.path}/hive');
      if (await hiveDir.exists()) {
        // Copy all hive files to backup
        await for (final entity in hiveDir.list(recursive: true)) {
          if (entity is File) {
            final relativePath = entity.path.substring(hiveDir.path.length);
            final backupFile = File('${backupDir.path}$relativePath');
            await backupFile.parent.create(recursive: true);
            await entity.copy(backupFile.path);
          }
        }
      }
      
      return backupDir.path;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Schema backup creation failed: $e');
      return null;
    }
  }
  
  /// Restore from schema backup after failed migration
  static Future<void> _restoreSchemaBackup(String backupPath, int targetVersion) async {
    try {
      if (kIsWeb) return;
      
      final appDir = await getApplicationDocumentsDirectory();
      final hiveDir = Directory('${appDir.path}/hive');
      final backupDir = Directory(backupPath);
      
      if (!await backupDir.exists()) {
        throw Exception('Backup directory not found: $backupPath');
      }
      
      // Close all open boxes first
      await closeUserBoxes();
      
      // If hive directory exists, rename it as a precaution
      if (await hiveDir.exists()) {
        final failedMigrationDir = Directory('${appDir.path}/hive_failed_migration_${DateTime.now().millisecondsSinceEpoch}');
        await hiveDir.rename(failedMigrationDir.path);
      }
      
      // Recreate hive directory
      await hiveDir.create(recursive: true);
      
      // Restore files from backup
      await for (final entity in backupDir.list(recursive: true)) {
        if (entity is File) {
          final relativePath = entity.path.substring(backupDir.path.length);
          final restoreFile = File('${hiveDir.path}$relativePath');
          await restoreFile.parent.create(recursive: true);
          await entity.copy(restoreFile.path);
        }
      }
      
      // Reinitialize Hive
      await Hive.initFlutter();
      
      if (kDebugMode) debugPrint('✅ Schema restored from backup to version $targetVersion');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Schema restore failed: $e');
      rethrow;
    }
  }
  
  /// Clean up schema backup after successful migration
  static Future<void> _cleanupSchemaBackup(String backupPath) async {
    try {
      if (kIsWeb) return;
      
      final backupDir = Directory(backupPath);
      if (await backupDir.exists()) {
        await backupDir.delete(recursive: true);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Schema backup cleanup failed: $e');
    }
  }
  
  /// Migration from version 0 to 1: Convert from unscoped to user-scoped boxes
  static Future<void> _migrateFromV0ToV1() async {
    if (kDebugMode) debugPrint('🔄 Migrating from v0 to v1...');
    
    try {
      final userId = await _getUserId();
      if (userId == null || userId == 0) {
        if (kDebugMode) debugPrint('⚠️ No valid user ID for v0->v1 migration, skipping');
        return;
      }
      
      // List of boxes to migrate from unscoped to scoped
      final boxesToMigrate = [
        'sales_v2',
        'products_v2',
        'customers_v2',
        'invoices_v2',
        'purchase_orders_v2',
        'khata_v2',
        'deductions_idempotency_v2',
        'expenses_v2',
        'inventory_v2',
      ];
      
      for (final boxName in boxesToMigrate) {
        try {
          // Check if unscoped box exists
          if (Hive.isBoxOpen(boxName) || await _boxExists(boxName)) {
            final oldBox = await Hive.openBox(boxName);
            final scopedBoxName = '${boxName}_$userId';
            final newBox = await Hive.openBox(scopedBoxName);
            
            // Migrate all data
            for (final key in oldBox.keys) {
              final value = oldBox.get(key);
              await newBox.put(key, value);
            }
            
            await oldBox.close();
            await newBox.close();
            
            // Delete old unscoped box after successful migration
            await Hive.deleteBoxFromDisk(boxName);
            
            if (kDebugMode) debugPrint('✅ Migrated $boxName to $scopedBoxName');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Failed to migrate $boxName: $e');
          // Continue with other boxes even if one fails
        }
      }
      
      // Clean up legacy SharedPreferences
      await purgeLegacyPrefsSales();
      
      if (kDebugMode) debugPrint('✅ v0->v1 migration completed');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ v0->v1 migration failed: $e');
      rethrow;
    }
  }
  
  /// Migration from version 1 to 2: Add data validation and indexing improvements
  static Future<void> _migrateFromV1ToV2() async {
    if (kDebugMode) debugPrint('🔄 Migrating from v1 to v2...');
    
    try {
      final userId = await _getUserId();
      if (userId == null || userId == 0) {
        if (kDebugMode) debugPrint('⚠️ No valid user ID for v1->v2 migration, skipping');
        return;
      }
      
      // Add validation metadata to sales box
      try {
        final salesBoxName = '${_salesBoxBase}_$userId';
        if (await _boxExists(salesBoxName)) {
          final salesBox = await Hive.openBox(salesBoxName);
          
          // Add validation flag to existing sales records
          for (final key in salesBox.keys) {
            final saleData = salesBox.get(key);
            if (saleData is Map && !saleData.containsKey('validated')) {
              saleData['validated'] = true;
              saleData['validation_timestamp'] = DateTime.now().toIso8601String();
              await salesBox.put(key, saleData);
            }
          }
          
          await salesBox.close();
          if (kDebugMode) debugPrint('✅ Sales box validation metadata added');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Sales box migration failed: $e');
      }
      
      // Add timestamp metadata to products box
      try {
        final productsBoxName = '${_productsBoxBase}_$userId';
        if (await _boxExists(productsBoxName)) {
          final productsBox = await Hive.openBox(productsBoxName);
          
          for (final key in productsBox.keys) {
            final productData = productsBox.get(key);
            if (productData is Map && !productData.containsKey('last_updated')) {
              productData['last_updated'] = DateTime.now().toIso8601String();
              await productsBox.put(key, productData);
            }
          }
          
          await productsBox.close();
          if (kDebugMode) debugPrint('✅ Products box timestamp metadata added');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Products box migration failed: $e');
      }
      
      if (kDebugMode) debugPrint('✅ v1->v2 migration completed');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ v1->v2 migration failed: $e');
      rethrow;
    }
  }
  
  /// Migration from version 2 to 3: Add user isolation improvements and security enhancements
  static Future<void> _migrateFromV2ToV3() async {
    if (kDebugMode) debugPrint('🔄 Migrating from v2 to v3...');
    
    try {
      final userId = await _getUserId();
      if (userId == null || userId == 0) {
        if (kDebugMode) debugPrint('⚠️ No valid user ID for v2->v3 migration, skipping');
        return;
      }
      
      // NOTE: previously called clearOtherUserBoxes() here, which permanently
      // deletes other users' local Hive data (including anything not yet
      // synced to the server). Box names are already scoped per user, so no
      // cleanup of other users' boxes is needed for isolation or migration
      // correctness. See clearOtherUserBoxes() below for details.
      
      // Add user ID verification to all boxes
      final boxBases = [
        _salesBoxBase,
        _productsBoxBase,
        _customersBoxBase,
        _invoicesBoxBase,
        _purchaseOrdersBoxBase,
        _khataBoxBase,
        _idempotencyBoxBase,
        _expensesBoxBase,
        _inventoryBoxBase,
      ];
      
      for (final base in boxBases) {
        try {
          final boxName = '${base}_$userId';
          if (await _boxExists(boxName)) {
            final box = await Hive.openBox(boxName);
            
            // Add user_id metadata to box
            await box.put('_user_id', userId);
            await box.put('_schema_version', 3);
            await box.put('_migration_timestamp', DateTime.now().toIso8601String());
            
            await box.close();
            if (kDebugMode) debugPrint('✅ User ID metadata added to $boxName');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Failed to add metadata to $base: $e');
        }
      }
      
      // Purge any remaining legacy unscoped boxes
      await purgeLegacyUnscopedHiveBoxes();
      
      if (kDebugMode) debugPrint('✅ v2->v3 migration completed');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ v2->v3 migration failed: $e');
      rethrow;
    }
  }
  
  /// Helper method to check if a box exists on disk
  static Future<bool> _boxExists(String boxName) async {
    try {
      if (kIsWeb) return false;
      
      final appDir = await getApplicationDocumentsDirectory();
      final hiveDir = Directory('${appDir.path}/hive');
      if (!await hiveDir.exists()) return false;
      
      // Check for box files (Hive creates .hive files)
      final boxFile = File('${hiveDir.path}/$boxName.hive');
      return await boxFile.exists();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error checking box existence: $e');
      return false;
    }
  }

  /// Resolve a Hive box name scoped to the current user.
  /// Never use a shared global sales box — prevents fake/leaked data on new accounts.
  static Future<String> _getScopedBoxName(String base) async {
    final userId = await _getUserId();
    
    // 🔒 VALIDATION: Ensure we have a valid user ID before creating scoped box
    if (userId == null || userId == 0) {
      throw Exception('SECURITY: Cannot store data without authenticated user_id. User ID is null or zero.');
    }
    
    final scopedName = '${base}_$userId';
    
    // 🔒 COLLISION DETECTION: Check for potential box name collisions
    // Ensure the box name doesn't conflict with legacy unscoped boxes
    if (base == scopedName) {
      if (kDebugMode) debugPrint('⚠️ BOX NAME COLLISION DETECTED: $base matches unscoped box name');
      throw Exception('SECURITY: Box name collision detected. Cannot use unscoped box name as scoped box.');
    }
    
    // Check if a legacy unscoped box with the same base name exists
    if (await _boxExists(base)) {
      if (kDebugMode) debugPrint('⚠️ LEGACY BOX CONFLICT: Unscoped box $base exists, may cause data leakage');
      // In production, you might want to migrate or delete the legacy box here
    }
    
    // Verify the scoped box belongs to the current user by checking metadata
    if (await _boxExists(scopedName)) {
      try {
        final box = await Hive.openBox(scopedName);
        final boxUserId = box.get('_user_id');
        await box.close();
        
        if (boxUserId != null && boxUserId != userId) {
          if (kDebugMode) debugPrint('⚠️ BOX OWNERSHIP MISMATCH: Box $scopedName belongs to user $boxUserId, not current user $userId');
          throw Exception('SECURITY: Box ownership mismatch. Data isolation violated.');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Error checking box ownership: $e');
        // Continue but log the issue
      }
    }
    
    if (kDebugMode) {
      debugPrint('🔍 Creating scoped box: $scopedName');
    }
    
    return scopedName;
  }

  static Future<bool> _hasValidUserId() async {
    final id = await _getUserId();
    return id != null && id > 0;
  }

  /// Close all boxes for the current user to ensure data isolation between accounts.
  static Future<void> closeUserBoxes() async {
    try {
      final userId = await _getUserId();
      if (userId == null || userId == 0) {
        if (kDebugMode) debugPrint('⚠️ No user ID found, skipping box closure');
        return;
      }

      final boxBases = [
        _salesBoxBase,
        _productsBoxBase,
        _customersBoxBase,
        _invoicesBoxBase,
        _purchaseOrdersBoxBase,
        _khataBoxBase,
        _idempotencyBoxBase,
        _expensesBoxBase,
        _inventoryBoxBase,
      ];

      for (final base in boxBases) {
        final boxName = '${base}_$userId';
        try {
          if (Hive.isBoxOpen(boxName)) {
            await Hive.box(boxName).close();
            if (kDebugMode) debugPrint('🔒 Closed box: $boxName');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Failed to close box $boxName: $e');
        }
      }
      
      // 🔒 SECURITY: Also close any legacy unscoped boxes that might be open
      final legacyBoxNames = [
        'sales_v2', 'products_v2', 'customers_v2', 'invoices_v2',
        'purchase_orders_v2', 'khata_v2', 'deductions_idempotency_v2',
        'expenses_v2', 'inventory_v2', 'sync_queue_v2',
      ];
      
      for (final legacyName in legacyBoxNames) {
        try {
          if (Hive.isBoxOpen(legacyName)) {
            await Hive.box(legacyName).close();
            if (kDebugMode) debugPrint('🔒 Closed legacy box: $legacyName');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Failed to close legacy box $legacyName: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error closing user boxes: $e');
    }
  }

  /// Remove legacy SharedPreferences sales (pre-Hive) that caused cross-account leakage.
  static Future<void> purgeLegacyPrefsSales() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('all_sales');
    if (kDebugMode) debugPrint('🧹 Purged legacy prefs all_sales');
  }

  /// ⚠️ DEPRECATED — DO NOT wire this back into logout, login, or migration.
  ///
  /// This deleted every OTHER user's local Hive boxes (sales, invoices,
  /// customers, inventory, khata) from disk whenever it ran — including
  /// data that hadn't synced to the server yet. On a shared device (e.g. a
  /// shop owner and a cashier both logging into one tablet), that meant
  /// real, unrecoverable data loss for whichever account wasn't currently
  /// active, every time anyone logged out or entered customer mode. The
  /// box-detection logic here was improved (scans actual box names on disk
  /// instead of assuming a small fixed user-ID range), but the underlying
  /// operation — deleting another user's business data — was never safe.
  ///
  /// Data isolation between accounts is already guaranteed without
  /// deletion: every box name is scoped per user (e.g. "sales_v2_$userId"),
  /// and closeUserBoxes() closes the current user's boxes on logout. The
  /// next user who logs in resolves their own scoped names and can never
  /// read or write another user's box.
  ///
  /// If a genuine need arises to wipe another account's local cache (e.g. a
  /// confirmed account-deletion request from that account's own owner),
  /// build a narrowly-scoped, explicitly-confirmed flow for that specific
  /// case — do not restore this as an automatic logout/migration step.
  @Deprecated('Destructive — no longer called from any flow. Read the doc comment before re-adding a call site.')
  static Future<void> clearOtherUserBoxes() async {
    if (kDebugMode) {
      debugPrint('⚠️ clearOtherUserBoxes() called but is now a no-op — see deprecation notice in local_storage_service.dart.');
    }
    return;
  }

  static Future<List<String>> _listUserScopedBoxNames() async {
    try {
      if (kIsWeb) return [];

      final appDir = await getApplicationDocumentsDirectory();
      final hiveDir = Directory('${appDir.path}/hive');
      if (!await hiveDir.exists()) return [];

      final boxNames = <String>{};
      await for (final entity in hiveDir.list()) {
        if (entity is File) {
          final fileName = entity.uri.pathSegments.last;
          if (fileName.endsWith('.hive') || fileName.endsWith('.lock')) {
            final stem = fileName.replaceAll('.hive', '').replaceAll('.lock', '');
            if (stem.contains('_')) {
              boxNames.add(stem);
            }
          }
        }
      }
      return boxNames.toList();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to list user-scoped Hive boxes: $e');
      return [];
    }
  }

  static String? _boxBaseFromScopedName(String boxName) {
    final parts = boxName.split('_');
    if (parts.length < 2) return null;
    final base = parts.take(parts.length - 1).join('_');
    return base.isEmpty ? null : base;
  }

  static int? _userIdFromScopedBoxName(String boxName) {
    try {
      final parts = boxName.split('_');
      if (parts.length < 2) return null;
      final raw = parts.last;
      return int.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Delete legacy unscoped Hive boxes (pre user_id isolation).
  static Future<void> purgeLegacyUnscopedHiveBoxes() async {
    const legacy = [
      'sales_v2',
      'products_v2',
      'customers_v2',
      'invoices_v2',
      'purchase_orders_v2',
      'khata_v2',
      'deductions_idempotency_v2',
      'expenses_v2',
      'inventory_v2',
      'sync_queue_v2',
    ];
    for (final name in legacy) {
      try {
        if (Hive.isBoxOpen(name)) {
          await Hive.box(name).close();
        }
        if (await Hive.boxExists(name)) {
          await Hive.deleteBoxFromDisk(name);
          if (kDebugMode) debugPrint('🧹 Deleted legacy Hive box: $name');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ purgeLegacyUnscopedHiveBoxes $name: $e');
      }
    }
  }

  /// Wipe orphan global/unauthenticated sales boxes from older app versions.
  static Future<void> clearOrphanSalesBoxes() async {
    for (final suffix in ['_global', '_unauthenticated']) {
      final name = '${_salesBoxBase}$suffix';
      try {
        if (Hive.isBoxOpen(name)) {
          await Hive.box(name).clear();
          await Hive.box(name).put('all_sales', []);
        } else {
          final box = await Hive.openBox(name);
          await box.put('all_sales', []);
          await box.close();
        }
        if (kDebugMode) debugPrint('🧹 Cleared orphan sales box: ' + name);
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ clearOrphanSalesBoxes $name: $e');
      }
    }
    await purgeLegacyPrefsSales();
  }

  // =========== CORE BOX MANAGEMENT ===========
  
  static Future<Box> _getBox(String base, {bool encrypted = false}) async {
    // 🔒 SECURITY: Validate user ID before accessing any box
    if (!await _hasValidUserId()) {
      if (kDebugMode) debugPrint('⚠️ _getBox failed — no valid user_id');
      throw Exception('SECURITY: Cannot access storage without authenticated user_id. Please log in first.');
    }
    
    final name = await _getScopedBoxName(base);
    if (!Hive.isBoxOpen(name)) {
      if (encrypted) {
        const secureStorage = FlutterSecureStorage();
        final encryptionKeyString = await secureStorage.read(key: 'hive_key_');
        if (encryptionKeyString == null) {
          final key = Hive.generateSecureKey();
          await secureStorage.write(key: 'hive_key_', value: base64UrlEncode(key));
          return await Hive.openBox(name, encryptionCipher: HiveAesCipher(key));
        }
        final encryptionKeyUint8List = base64Url.decode(encryptionKeyString);
        return await Hive.openBox(name, encryptionCipher: HiveAesCipher(encryptionKeyUint8List));
      }
      return await Hive.openBox(name);
    }
    return Hive.box(name);
  }

  // =========== SALES (BUSINESS CRITICAL) ===========
  
  static Future<void> saveSales(List<dynamic> salesHistory) async {
    if (!await _hasValidUserId()) {
      if (kDebugMode) debugPrint('⚠️ saveSales skipped — no logged-in user');
      return;
    }
    final box = await _getBox(_salesBoxBase, encrypted: true);
    final userId = await _getUserId();

    // Callers are responsible for loading/merging the current history when
    // they need an additive update. This method persists exactly the list it
    // receives, avoiding the previous double-merge O(n²) path.
    // SalesDedupHelper only collapses records sharing a stable business ID;
    // content-identical sales remain separate legitimate transactions.
    final dedupedSales = SalesDedupHelper.dedupeBills(salesHistory);
    final List<StoredSale> typedSales = dedupedSales.map<StoredSale>((sale) {
      return StoredSale.fromJson(Map<String, dynamic>.from(sale));
    }).toList();

    await box.put('all_sales', typedSales.map((sale) => sale.toJson()).toList());
    if (kDebugMode) {
      debugPrint('💾 [LocalStorage] Replaced sales with ${typedSales.length} deduplicated records for user: $userId');
    }
  }

  /// Replace the canonical sales snapshot without content-based collapsing.
  /// Use this only when the caller has already reconciled stable identities.
  static Future<void> replaceSalesCanonical(List<dynamic> salesHistory) async {
    if (!await _hasValidUserId()) return;
    final box = await _getBox(_salesBoxBase, encrypted: true);
    final typedSales = salesHistory.whereType<Map>().map<StoredSale>((sale) {
      return StoredSale.fromJson(Map<String, dynamic>.from(sale));
    }).toList();
    await box.put('all_sales', typedSales.map((sale) => sale.toJson()).toList());
  }

  static Future<List<dynamic>> loadSales() async {
    if (!await _hasValidUserId()) {
      if (kDebugMode) debugPrint('⚠️ loadSales: no user_id — returning empty (no fake data)');
      return [];
    }
    final box = await _getBox(_salesBoxBase, encrypted: true);
    final userId = await _getUserId();
    final sales = box.get('all_sales', defaultValue: []);
    final typedSales = List<dynamic>.from(sales).map((sale) {
      if (sale is StoredSale) return sale.toJson();
      if (sale is Map) return Map<String, dynamic>.from(sale);
      return sale;
    }).toList();
    if (kDebugMode) debugPrint('🔍 [LocalStorage] Loaded ${typedSales.length} sales for USER_ID: $userId');
    return typedSales;
  }

  static Future<bool> cancelSale(String saleId) async {
    if (!await _hasValidUserId()) return false;
    final box = await _getBox(_salesBoxBase, encrypted: true);
    final List<dynamic> sales = List<dynamic>.from(box.get('all_sales', defaultValue: []));
    
    int index = sales.indexWhere((s) => (s['sale_id'] ?? s['id'] ?? '').toString() == saleId);
    if (index == -1) return false;

    // Mark as cancelled
    final sale = Map<String, dynamic>.from(sales[index]);
    if (sale['status'] == 'CANCELLED') return true; // Already cancelled
    
    sale['status'] = 'CANCELLED';
    sale['cancelled_at'] = DateTime.now().toIso8601String();
    sales[index] = sale;
    
    await box.put('all_sales', sales);
    
    // Release idempotency so it can be re-deducted if re-billed (or just mark as reverted)
    final idemBox = await _getBox(_idempotencyBoxBase);
    await idemBox.delete(saleId);
    
    return true;
  }

  // =========== PRODUCTS (INVENTORY) ===========
  
  static Future<void> saveBackendProducts(List<Map<String, dynamic>> products) async {
    if (!await _hasValidUserId()) return;
    final box = await _getBox(_productsBoxBase);
    final normalized = InventoryStockHelper.normalizeProducts(products);
    await box.put('backend_products', normalized);
    if (kDebugMode) debugPrint('💾 [LocalStorage] Saved ${normalized.length} backend products');
  }

  static Future<List<Map<String, dynamic>>> loadBackendProducts() async {
    if (!await _hasValidUserId()) return [];
    final box = await _getBox(_productsBoxBase);
    final data = box.get('backend_products', defaultValue: []);
    return InventoryStockHelper.normalizeProducts(List<dynamic>.from(data));
  }

  static Future<void> saveLocalProducts(Map<String, dynamic> products) async {
    if (!await _hasValidUserId()) return;
    final box = await _getBox(_productsBoxBase);
    await box.put('local_products', products);
  }

  static Future<Map<String, dynamic>> loadLocalProducts() async {
    if (!await _hasValidUserId()) return {};
    final box = await _getBox(_productsBoxBase);
    final data = box.get('local_products', defaultValue: {});
    return Map<String, dynamic>.from(data);
  }

  // =========== INVOICES & CUSTOMERS ===========
  
  static Future<void> saveLocalInvoices(List<dynamic> invoices) async {
    // 🔒 SECURITY FIX: Require valid user ID to prevent data leakage
    if (!await _hasValidUserId()) {
      if (kDebugMode) debugPrint('⚠️ saveLocalInvoices failed — no logged-in user');
      throw Exception('SECURITY: Cannot save invoices without authenticated user_id. Please log in first.');
    }
    final box = await _getBox(_invoicesBoxBase);
    final List<dynamic> existingInvoices = List<dynamic>.from(box.get('manual_invoices', defaultValue: []));
    final Map<String, Map<String, dynamic>> invoiceMap = {};

    for (final rawInvoice in [...existingInvoices, ...invoices]) {
      if (rawInvoice is! Map) continue;
      final invoice = Map<String, dynamic>.from(rawInvoice);
      final id = invoice['sale_id']?.toString() ??
                 invoice['invoice_number']?.toString() ??
                 invoice['id']?.toString() ??
                 invoice['invoiceId']?.toString() ??
                 '';
      if (id.isEmpty) {
        final key = '__anon_invoice_${invoiceMap.length}';
        invoiceMap[key] = invoice;
      } else {
        final existing = invoiceMap[id];
        if (existing == null) {
          invoiceMap[id] = invoice;
        } else {
          final existingUpdatedAt = DateTime.tryParse(existing['updated_at']?.toString() ?? existing['created_at']?.toString() ?? '') ?? DateTime(1970);
          final currentUpdatedAt = DateTime.tryParse(invoice['updated_at']?.toString() ?? invoice['created_at']?.toString() ?? '') ?? DateTime(1970);
          invoiceMap[id] = currentUpdatedAt.isAfter(existingUpdatedAt) ? invoice : existing;
        }
      }
    }

    final dedupedInvoices = invoiceMap.values.toList();
    await box.put('manual_invoices', dedupedInvoices);
    if (kDebugMode) debugPrint('💾 [LocalStorage] Saved ${dedupedInvoices.length} invoices');
  }

  static Future<List<dynamic>> loadLocalInvoices() async {
    // 🔒 SECURITY FIX: Require valid user ID to prevent data leakage
    if (!await _hasValidUserId()) {
      if (kDebugMode) debugPrint('⚠️ loadLocalInvoices failed — no logged-in user');
      throw Exception('SECURITY: Cannot load invoices without authenticated user_id. Please log in first.');
    }
    final box = await _getBox(_invoicesBoxBase);
    final data = box.get('manual_invoices', defaultValue: []);
    return List<dynamic>.from(data);
  }

  static Future<void> savePurchaseOrders(List<dynamic> orders) async {
    if (!await _hasValidUserId()) return;
    final box = await _getBox(_purchaseOrdersBoxBase);
    await box.put('purchase_orders', orders);
  }

  static Future<List<dynamic>> loadPurchaseOrders() async {
    if (!await _hasValidUserId()) return [];
    final box = await _getBox(_purchaseOrdersBoxBase);
    final data = box.get('purchase_orders', defaultValue: []);
    return List<dynamic>.from(data);
  }

  static Future<void> saveLocalCustomers(List<dynamic> customers) async {
    if (!await _hasValidUserId()) return;
    final box = await _getBox(_customersBoxBase, encrypted: true);
    await box.put('customers', customers);
  }

  static Future<List<dynamic>> loadLocalCustomers() async {
    if (!await _hasValidUserId()) return [];
    final box = await _getBox(_customersBoxBase, encrypted: true);
    final data = box.get('customers', defaultValue: []);
    return List<dynamic>.from(data);
  }

  // =========== KHATA (CREDIT TRACKING) ===========

  static Future<void> saveKhataBalances(Map<String, double> balances) async {
    if (!await _hasValidUserId()) return;
    final box = await _getBox(_khataBoxBase, encrypted: true);
    await box.put('balances', balances);
  }

  static Future<Map<String, double>> loadKhataBalances() async {
    if (!await _hasValidUserId()) return {};
    final box = await _getBox(_khataBoxBase, encrypted: true);
    final data = box.get('balances', defaultValue: <String, double>{});
    return Map<String, double>.from(data.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())));
  }

  
  // =========== UNIFIED LEDGER ===========
  // Canonical invoice ledger:
  //   * local manual/borrow invoices are authoritative when present
  //   * cloud-restored sales are promoted to invoice records when no invoice
  //     mirror exists (critical after app-data clearing)
  //   * one stable invoice identity is used to prevent double-counting
  //   * customer balances are derived from invoice outstanding amounts only
  static Future<List<Map<String, dynamic>>> loadUnifiedCustomersLedger() async {
    final sales = await loadSales();
    final invoices = await loadLocalInvoices();
    final customers = await loadLocalCustomers();
    final khataBalances = await loadKhataBalances();

    String invoiceKey(Map<String, dynamic> row) {
      for (final field in const [
        'invoice_id',
        'sale_id',
        'invoice_number',
        'invoiceId',
        'backend_id',
        'id',
      ]) {
        final value = row[field]?.toString().trim().toLowerCase() ?? '';
        if (value.isNotEmpty && value != 'null' && value != '0') {
          return value;
        }
      }
      final date =
          (row['business_date'] ??
                  row['invoice_date'] ??
                  row['sale_date'] ??
                  row['date'] ??
                  row['created_at'] ??
                  '')
              .toString();
      final phone =
          (row['customer_phone'] ?? row['phone'] ?? '').toString().trim();
      final total = double.tryParse(
            (row['total_amount'] ?? row['total'] ?? 0).toString(),
          ) ??
          0.0;
      return 'fallback|$date|$phone|${total.toStringAsFixed(2)}';
    }

    double amount(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    // Build one canonical invoice map. A real invoice record wins over a
    // flattened sale copy because it contains the authoritative payment state.
    final Map<String, Map<String, dynamic>> canonical = {};

    void mergeInvoice(
      dynamic raw, {
      bool prefer = false,
    }) {
      if (raw is! Map) return;
      final row = Map<String, dynamic>.from(raw);
      final key = invoiceKey(row);
      if (key.isEmpty) return;

      final existing = canonical[key];
      if (existing == null) {
        canonical[key] = row;
        return;
      }

      final existingUpdated = DateTime.tryParse(
            existing['updated_at']?.toString() ??
                existing['last_updated']?.toString() ??
                existing['created_at']?.toString() ??
                '',
          ) ??
          DateTime(1970);
      final incomingUpdated = DateTime.tryParse(
            row['updated_at']?.toString() ??
                row['last_updated']?.toString() ??
                row['created_at']?.toString() ??
                '',
          ) ??
          DateTime(1970);

      if (prefer || incomingUpdated.isAfter(existingUpdated)) {
        canonical[key] = {...existing, ...row};
      } else {
        canonical[key] = {
          ...row,
          ...existing,
          if ((existing['customer_name'] ?? '').toString().trim().isEmpty &&
              (row['customer_name'] ?? '').toString().trim().isNotEmpty)
            'customer_name': row['customer_name'],
          if ((existing['customer_phone'] ?? '').toString().trim().isEmpty &&
              (row['customer_phone'] ?? '').toString().trim().isNotEmpty)
            'customer_phone': row['customer_phone'],
          if ((existing['payment_method'] ?? '').toString().trim().isEmpty &&
              (row['payment_method'] ?? '').toString().trim().isNotEmpty)
            'payment_method': row['payment_method'],
        };
      }
    }

    // Existing invoice mirrors are authoritative.
    for (final invoice in invoices) {
      mergeInvoice(invoice, prefer: true);
    }

    // Promote any cloud-restored/legacy sales that do not already have an
    // invoice mirror. This is the key recovery path after app-data clearing.
    for (final rawSale in sales) {
      if (rawSale is! Map) continue;
      final sale = Map<String, dynamic>.from(rawSale);
      final key = invoiceKey(sale);
      if (canonical.containsKey(key)) continue;

      final rawItems = sale['line_items'] ?? sale['items'];
      List<dynamic> lineItems = const [];
      if (rawItems is List && rawItems.isNotEmpty) {
        lineItems = rawItems;
      } else if ((sale['product_name'] ?? sale['product'] ?? '').toString().trim().isNotEmpty) {
        final p = amount(sale['price']);
        final q = amount(sale['quantity'] ?? sale['qty']);
        lineItems = [
          {
            'product_name':
                (sale['product_name'] ?? sale['product']).toString(),
            'price': p,
            'quantity': q > 0 ? q : 1,
            'qty': q > 0 ? q : 1,
            'total': amount(sale['total']) > 0
                ? amount(sale['total'])
                : p * (q > 0 ? q : 1),
          }
        ];
      }

      final total = amount(
        sale['total_amount'] ??
            sale['total'] ??
            sale['invoice_total'] ??
            sale['grand_total'] ??
            sale['final_amount'],
      );
      final paid = amount(
        sale['paid_amount'] ??
            sale['amount_paid'] ??
            sale['paid'] ??
            (sale['payment_status']?.toString().toUpperCase() == 'PAID'
                ? total
                : 0),
      ).clamp(0.0, total);

      canonical[key] = {
        ...sale,
        'invoice_number': sale['invoice_number'] ??
            sale['sale_id'] ??
            sale['invoice_id'] ??
            sale['id'],
        'sale_id': sale['sale_id'] ??
            sale['invoice_number'] ??
            sale['invoice_id'] ??
            sale['id'],
        'customer_name':
            sale['customer_name'] ?? sale['name'] ?? 'Cash Customer',
        'customer_phone':
            sale['customer_phone'] ?? sale['phone'] ?? '',
        'total_amount': total,
        'paid_amount': paid,
        'payment_status': sale['payment_status'] ??
            _deriveInvoiceStatus(total, paid),
        'line_items': lineItems,
        'items': lineItems,
        'is_recovered_from_sale': true,
      };
    }

    // Persist promoted records so the recovered invoices survive a restart and
    // do not depend on the in-memory ledger being rebuilt again.
    final recovered = canonical.values
        .where((row) => row['is_recovered_from_sale'] == true)
        .toList();
    if (recovered.isNotEmpty) {
      try {
        await saveLocalInvoices(recovered);
      } catch (_) {
        // Ledger remains usable even if a legacy record cannot be persisted.
      }
    }

    final Map<String, Map<String, dynamic>> unified = {};

    String customerKey({
      dynamic customerId,
      dynamic phone,
    }) {
      final id = customerId?.toString().trim() ?? '';
      if (id.isNotEmpty && id != '0' && id.toLowerCase() != 'null') {
        return 'id:$id';
      }
      final normalizedPhone = phone?.toString().trim() ?? '';
      if (normalizedPhone.isNotEmpty) {
        return 'phone:$normalizedPhone';
      }
      return '';
    }

    Map<String, dynamic> ensureCustomer({
      dynamic customerId,
      dynamic phone,
      dynamic name,
    }) {
      final key = customerKey(customerId: customerId, phone: phone);
      if (key.isEmpty) return {};

      return unified.putIfAbsent(
        key,
        () => {
          'customer_id': customerId,
          'phone': phone?.toString() ?? '',
          'name': (name?.toString().trim().isNotEmpty ?? false)
              ? name.toString()
              : 'Customer',
          'unified_balance': 0.0,
          'last_transaction': DateTime(1970).toIso8601String(),
          'history': <dynamic>[],
        },
      );
    }

    // Customer directory entries should exist even before they have a pending
    // balance.
    for (final c in customers) {
      if (c is! Map) continue;
      ensureCustomer(
        customerId: c['id'] ?? c['customer_id'],
        phone: c['phone'] ?? c['customer_phone'],
        name: c['name'] ?? c['customer_name'],
      );
    }

    // Build balances strictly from canonical invoice records. Fully-paid
    // invoices stay in history but contribute zero outstanding amount.
    for (final row in canonical.values) {
      final customerPhone =
          (row['customer_phone'] ?? row['phone'] ?? '').toString().trim();
      final customerId = row['customer_id'] ?? row['customerId'];
      final customerName =
          (row['customer_name'] ?? row['name'] ?? 'Cash Customer').toString();

      final entry = ensureCustomer(
        customerId: customerId,
        phone: customerPhone,
        name: customerName,
      );
      if (entry.isEmpty) continue;

      final total = amount(
        row['total_amount'] ??
            row['total'] ??
            row['amount'] ??
            row['invoice_total'] ??
            row['grand_total'],
      );
      final paid = amount(
        row['paid_amount'] ??
            row['amount_paid'] ??
            row['paid'] ??
            row['received_amount'],
      ).clamp(0.0, total);
      final outstanding = (total - paid).clamp(0.0, double.infinity);

      final normalized = {
        ...row,
        'total_amount': total,
        'paid_amount': paid,
        'pending_amount': outstanding,
        'payment_status': _deriveInvoiceStatus(total, paid),
        'invoice_number': row['invoice_number'] ??
            row['sale_id'] ??
            row['invoice_id'] ??
            row['id'],
        'customer_name': customerName,
        'customer_phone': customerPhone,
      };

      (entry['history'] as List<dynamic>).add(normalized);
      final transactionDate =
          row['business_date'] ??
          row['invoice_date'] ??
          row['sale_date'] ??
          row['date'] ??
          row['created_at'];
      if (transactionDate != null) {
        entry['last_transaction'] = transactionDate.toString();
      }
      if (outstanding > 0.01) {
        entry['unified_balance'] =
            (entry['unified_balance'] as double) + outstanding;
      }
    }

    // Legacy manual Khata adjustments are additive for records that have not
    // been attached to a canonical invoice yet.
    for (final pair in khataBalances.entries) {
      final key = customerKey(phone: pair.key);
      if (key.isEmpty) continue;

      final entry = unified.putIfAbsent(
        key,
        () => {
          'customer_id': null,
          'phone': pair.key,
          'name': 'Customer',
          'unified_balance': 0.0,
          'last_transaction': DateTime.now().toIso8601String(),
          'history': <dynamic>[],
        },
      );
      entry['unified_balance'] =
          (entry['unified_balance'] as double) + pair.value;
    }

    return unified.values.toList();
  }

  static String _deriveInvoiceStatus(double total, double paid) {
    if (paid >= total - 0.01) return 'PAID';
    if (paid > 0) return 'PARTIAL';
    return 'UNPAID';
  }

  static Future<void> recordUnifiedPayment(
    String customerPhone,
    double amount, {
    String? invoiceId,
    String? invoiceNumber,
    String paymentMethod = 'CASH',
    String? paymentDate,
    String? idempotencyKey,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Payment must be greater than zero');
    }

    final invoices = await loadLocalInvoices();

    // Idempotency: replaying the same payment action must never add the
    // payment twice after a timeout/retry.
    if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty) {
      final key = idempotencyKey.trim();
      final alreadyApplied = invoices.any(
        (raw) =>
            raw is Map &&
            raw['last_payment_idempotency_key']?.toString() == key,
      );
      if (alreadyApplied) return;
    }

    // Prefer exact invoice settlement. This makes "Mark Paid" an actual
    // payment-state change instead of simply hiding the customer from the UI.
    if (invoiceId != null && invoiceId.trim().isNotEmpty ||
        invoiceNumber != null && invoiceNumber.trim().isNotEmpty) {
      final target = (invoiceId ?? invoiceNumber)!.trim().toLowerCase();
      int index = invoices.indexWhere((raw) {
        if (raw is! Map) return false;
        final row = Map<String, dynamic>.from(raw);
        final ids = [
          row['invoice_id'],
          row['sale_id'],
          row['invoice_number'],
          row['invoiceId'],
          row['backend_id'],
          row['id'],
        ];
        return ids.any(
          (v) => v?.toString().trim().toLowerCase() == target,
        );
      });

      // Also match invoice number separately when invoiceId is numeric.
      if (index < 0 && invoiceNumber != null) {
        final number = invoiceNumber.trim().toLowerCase();
        index = invoices.indexWhere(
          (raw) =>
              raw is Map &&
              raw['invoice_number']?.toString().trim().toLowerCase() ==
                  number,
        );
      }

      if (index >= 0) {
        final row = Map<String, dynamic>.from(invoices[index]);
        final total = double.tryParse(
              (row['total_amount'] ??
                      row['total'] ??
                      row['invoice_total'] ??
                      row['grand_total'] ??
                      0)
                  .toString(),
            ) ??
            0.0;
        final currentPaid = double.tryParse(
              (row['paid_amount'] ??
                      row['amount_paid'] ??
                      row['paid'] ??
                      row['received_amount'] ??
                      0)
                  .toString(),
            ) ??
            0.0;

        final newPaid =
            (currentPaid + amount).clamp(0.0, total).toDouble();
        final outstanding =
            (total - newPaid).clamp(0.0, double.infinity).toDouble();

        row['paid_amount'] = newPaid;
        row['payment_status'] = _deriveInvoiceStatus(total, newPaid);
        row['status'] = row['payment_status'];
        row['pending_amount'] = outstanding;
        row['last_payment_amount'] = amount;
        row['last_payment_method'] = paymentMethod;
        row['payment_method'] = paymentMethod;
        row['paid_at'] = paymentDate ?? DateTime.now().toUtc().toIso8601String();
        row['payment_date'] = paymentDate ?? DateTime.now().toUtc().toIso8601String();
        if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
          row['last_payment_idempotency_key'] = idempotencyKey;
        }
        row['updated_at'] = DateTime.now().toUtc().toIso8601String();

        invoices[index] = row;
        await saveLocalInvoices(invoices);
        return;
      }
    }

    // Some restored/offline transactions can exist in sales history before
    // an invoice mirror is available. Persist the payment there too.
    if (invoiceId != null || invoiceNumber != null) {
      final sales = await loadSales();
      final targetIds = {
        (invoiceId ?? '').trim().toLowerCase(),
        (invoiceNumber ?? '').trim().toLowerCase(),
      }..removeWhere((v) => v.isEmpty);

      for (var i = 0; i < sales.length; i++) {
        final raw = sales[i];
        if (raw is! Map) continue;
        final sale = Map<String, dynamic>.from(raw);
        final saleIds = {
          (sale['sale_id'] ?? '').toString().trim().toLowerCase(),
          (sale['invoice_number'] ?? '').toString().trim().toLowerCase(),
          (sale['invoice_id'] ?? '').toString().trim().toLowerCase(),
          (sale['id'] ?? '').toString().trim().toLowerCase(),
        }..removeWhere((v) => v.isEmpty);

        if (saleIds.intersection(targetIds).isEmpty) continue;

        final total = double.tryParse(
              (sale['total_amount'] ?? sale['total'] ?? 0).toString(),
            ) ??
            0.0;
        final currentPaid = double.tryParse(
              (sale['paid_amount'] ?? sale['amount_paid'] ?? 0).toString(),
            ) ??
            0.0;
        final newPaid = (currentPaid + amount).clamp(0.0, total).toDouble();

        sale['paid_amount'] = newPaid;
        sale['payment_status'] = _deriveInvoiceStatus(total, newPaid);
        sale['status'] = sale['payment_status'];
        sale['pending_amount'] =
            (total - newPaid).clamp(0.0, double.infinity).toDouble();
        sale['last_payment_amount'] = amount;
        sale['last_payment_method'] = paymentMethod;
        sale['payment_method'] = paymentMethod;
        sale['paid_at'] =
            paymentDate ?? DateTime.now().toUtc().toIso8601String();
        sale['payment_date'] =
            paymentDate ?? DateTime.now().toUtc().toIso8601String();
        if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
          sale['last_payment_idempotency_key'] = idempotencyKey;
        }
        sale['updated_at'] = DateTime.now().toUtc().toIso8601String();
        sales[i] = sale;
        await saveSales(sales);
        return;
      }
    }

    // Legacy/manual customer-level Khata balance. Keep this only for old
    // records that are not attached to a specific invoice yet.
    final balances = await loadKhataBalances();
    final current = balances[customerPhone] ?? 0.0;
    balances[customerPhone] = current - amount;
    await saveKhataBalances(balances);
  }

  static Future<void> updateCustomerBalance(String customerId, double balance) async {
    final balances = await loadKhataBalances();
    balances[customerId] = balance;
    await saveKhataBalances(balances);
  }

  // =========== INVENTORY IDEMPOTENCY ===========

  static Future<void> markDeductionProcessed(String saleId) async {
    if (!await _hasValidUserId()) return;
    final box = await _getBox(_idempotencyBoxBase);
    await box.put(saleId, true);
  }

  static Future<bool> isDeductionProcessed(String saleId) async {
    if (!await _hasValidUserId()) return false;
    final box = await _getBox(_idempotencyBoxBase);
    return box.get(saleId) == true;
  }

  // =========== EXPENSES ===========

  static Future<void> saveExpenses(List<dynamic> expenses) async {
    if (!await _hasValidUserId()) return;
    final box = await _getBox(_expensesBoxBase);
    await box.put('all_expenses', expenses);
    if (kDebugMode) debugPrint('💾 [LocalStorage] Saved ${expenses.length} expenses');
  }

  static Future<List<dynamic>> loadExpenses() async {
    if (!await _hasValidUserId()) return [];
    final box = await _getBox(_expensesBoxBase);
    final data = box.get('all_expenses', defaultValue: []);
    return List<dynamic>.from(data);
  }

  // =========== INVENTORY ===========

  static Future<void> saveInventory(List<dynamic> inventory) async {
    if (!await _hasValidUserId()) return;
    final box = await _getBox(_inventoryBoxBase);
    await box.put('all_inventory', inventory);
    if (kDebugMode) debugPrint('💾 [LocalStorage] Saved ${inventory.length} inventory items');
  }

  static Future<List<dynamic>> loadInventory() async {
    if (!await _hasValidUserId()) return [];
    final box = await _getBox(_inventoryBoxBase);
    final data = box.get('all_inventory', defaultValue: []);
    return List<dynamic>.from(data);
  }

  // =========== SYSTEM ISOLATION & LOGOUT ===========

  /// Clears only session-specific cache. 
  /// BUSINESS DATA (Sales/Inventory) in Hive remains untouched but inaccessible 
  /// until the user logs back in (since it's keyed by userId).
  static Future<void> clearSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('session_cache');
    if (kDebugMode) debugPrint('🧹 [LocalStorage] Session data cleared (Business records preserved)');
  }

  // =========== LEGACY SUPPORT & SHPREFS WRAPPERS ===========
  
  Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  // =========== BACKUP & RECOVERY PROTOCOL ===========
  static Future<String?> exportSecureBackup() async {
    try {
      final sales = await loadSales();
      final products = await loadLocalProducts();
      final backendProducts = await loadBackendProducts();
      final customers = await loadLocalCustomers();
      final invoices = await loadLocalInvoices();
      final inventory = await loadInventory();
      final prefs = await SharedPreferences.getInstance();
      
      final Map<String, dynamic> backupData = {
        'timestamp': DateTime.now().toIso8601String(),
        'schema_version': _schemaVersion,
        'user_id': await _getUserId(),
        'sales': sales,
        'products': products,
        'backend_products': backendProducts,
        'customers': customers,
        'invoices': invoices,
        'inventory': inventory,
        'scoped_preferences': prefs.getKeys().where((k) => !k.contains('token') && !k.contains('password')).fold<Map<String, dynamic>>({}, (m, k) {
          final v = prefs.get(k);
          if (v is String || v is num || v is bool || v is List<String>) m[k] = v;
          return m;
        }),
      };
      
      final jsonString = jsonEncode(backupData);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/retail_mind_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);
      
      if (kDebugMode) debugPrint('✅ Backup exported to ${file.path}');
      return file.path;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Backup failed: $e');
      return null;
    }
  }
  
  static Future<bool> importSecureBackup(String jsonPayload) async {
    try {
      final Map<String, dynamic> backupData = jsonDecode(jsonPayload);
      
      final sales = backupData['sales'] as List<dynamic>? ?? [];
      final products = backupData['products'] as List<dynamic>? ?? [];
      final backendProducts = backupData['backend_products'] as List<dynamic>? ?? [];
      final customers = backupData['customers'] as List<dynamic>? ?? [];
      final invoices = backupData['invoices'] as List<dynamic>? ?? [];
      final inventory = backupData['inventory'] as List<dynamic>? ?? [];

      final expectedUser = await _getUserId();
      final backupUser = int.tryParse(backupData['user_id']?.toString() ?? '');
      if (expectedUser != null && backupUser != null && expectedUser != backupUser) {
        throw Exception('Backup belongs to a different account');
      }
      
      final salesBox = await _getBox(_salesBoxBase, encrypted: true);
      final productsBox = await _getBox(_productsBoxBase, encrypted: true);
      final customersBox = await _getBox(_customersBoxBase, encrypted: true);

      await salesBox.clear();
      await productsBox.clear();
      await customersBox.clear();

      await salesBox.put('all_sales', sales);
      
      for (var p in products) {
        if (p is Map && p.containsKey('product_id')) {
          await productsBox.put(p['product_id'], p);
        } else if (p is Map && p.containsKey('barcode')) {
          await productsBox.put(p['barcode'], p);
        }
      }
      
      await customersBox.put('customers', customers);
      final backendProductsBox = await _getBox(_productsBoxBase, encrypted: true);
      await backendProductsBox.put('backend_products', backendProducts);
      final invoicesBox = await _getBox(_invoicesBoxBase, encrypted: true);
      await invoicesBox.put('all_invoices', invoices);
      final inventoryBox = await _getBox(_inventoryBoxBase, encrypted: true);
      await inventoryBox.put('all_inventory', inventory);
      
      if (kDebugMode) debugPrint('✅ Backup imported successfully');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Backup import failed: $e');
      return false;
    }
  }

  // =========== CONFLICT RESOLUTION ===========
  static List<dynamic> syncLedgerWithConflictResolution(List<dynamic> localLedger, List<dynamic> cloudLedger) {
    final Map<String, dynamic> merged = {};
    
    // Add local records
    for (var item in localLedger) {
      final id = item['id']?.toString() ?? item['invoice_id']?.toString();
      if (id != null) merged[id] = item;
    }
    
    // Merge cloud records using Last Write Wins
    for (var cloudItem in cloudLedger) {
      final id = cloudItem['id']?.toString() ?? cloudItem['invoice_id']?.toString();
      if (id != null) {
        if (merged.containsKey(id)) {
          final localTime = merged[id]['last_updated'] ?? 0;
          final cloudTime = cloudItem['last_updated'] ?? 0;
          
          if (cloudTime > localTime) {
            merged[id] = cloudItem; // Cloud is newer
          }
        } else {
          merged[id] = cloudItem; // Cloud has new record
        }
      }
    }
    
    return merged.values.toList();
  }

  // =========== REFUND WORKFLOW ===========
  static Future<bool> executeRefund(String invoiceId) async {
    try {
      final salesBox = await _getBox(_salesBoxBase, encrypted: true);
      final productsBox = await _getBox(_productsBoxBase, encrypted: true);
      
      final currentSales = List<dynamic>.from(salesBox.get('all_sales', defaultValue: []));
      final currentProducts = List<dynamic>.from(productsBox.get('all_products', defaultValue: []));
      
      final saleIndex = currentSales.indexWhere((s) => s['invoice_id'] == invoiceId || s['id'] == invoiceId);
      if (saleIndex == -1) throw Exception('Invoice not found');
      
      final sale = Map<String, dynamic>.from(currentSales[saleIndex]);
      if (sale['status'] == 'REFUNDED') throw Exception('Already refunded');
      
      // Restore Inventory
      final items = List<dynamic>.from(sale['items'] ?? []);
      for (var item in items) {
        final productId = item['id']?.toString() ?? item['product_id']?.toString() ?? '';
        final double qtyToRestore = double.tryParse(item['qty']?.toString() ?? '1') ?? 1.0;
        
        final pIndex = currentProducts.indexWhere((p) => p['id']?.toString() == productId);
        if (pIndex != -1) {
          final p = Map<String, dynamic>.from(currentProducts[pIndex]);
          final currentStock = double.tryParse(p['stock']?.toString() ?? '0') ?? 0.0;
          
          p['stock'] = (currentStock + qtyToRestore).toString();
          p['last_updated'] = DateTime.now().millisecondsSinceEpoch;
          currentProducts[pIndex] = p;
        }
      }
      
      // Update Sale Status
      sale['status'] = 'REFUNDED';
      sale['last_updated'] = DateTime.now().millisecondsSinceEpoch;
      currentSales[saleIndex] = sale;
      
      // Batch Commit
      await productsBox.put('all_products', currentProducts);
      await salesBox.put('all_sales', currentSales);
      
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Refund Failed: ');
      return false;
    }
  }
}
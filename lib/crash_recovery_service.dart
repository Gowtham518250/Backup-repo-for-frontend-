import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_storage_service.dart';
import 'sync_queue_manager.dart';
import 'api_client.dart';
import 'secure_token_storage.dart';
import 'background_sync_worker.dart';
import 'sync_queue_manager.dart';
import 'inventory_management_service.dart';

/// Crash Recovery Service
/// Handles startup recovery and cleanup of incomplete transactions
/// Ensures data integrity after app crashes or force-closes
class CrashRecoveryService {
  static CrashRecoveryService? _instance;
  static const String _incompleteTransactionsKey = 'incomplete_transactions';
  static const String _crashFlagKey = 'app_crashed_flag';
  static const String _lastCleanShutdownKey = 'last_clean_shutdown';
  static const String _quarantinedSalesKey = 'quarantined_sales';
  static const String _quarantinedProductsKey = 'quarantined_products';
  static const String _quarantinedCustomersKey = 'quarantined_customers';
  
  CrashRecoveryService._();
  
  static CrashRecoveryService get instance {
    _instance ??= CrashRecoveryService._();
    return _instance!;
  }
  
  /// Initialize crash recovery on app startup
  Future<void> initialize() async {
    try {
      if (kDebugMode) debugPrint('🔍 Initializing crash recovery service');
      
      // Check if app crashed
      final prefs = await SharedPreferences.getInstance();
      final lastCleanShutdown = prefs.getString(_lastCleanShutdownKey);
      final crashFlag = prefs.getBool(_crashFlagKey) ?? false;
      
      if (crashFlag || lastCleanShutdown == null) {
        if (kDebugMode) debugPrint('⚠️ Potential crash detected, starting recovery');
        await _performRecovery();
      } else {
        if (kDebugMode) debugPrint('✅ Clean shutdown detected, no recovery needed');
      }
      
      // Set crash flag for next run
      await prefs.setBool(_crashFlagKey, true);
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Crash recovery initialization error: $e');
    }
  }
  
  /// Mark clean shutdown (call on app exit)
  Future<void> markCleanShutdown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastCleanShutdownKey, DateTime.now().toIso8601String());
      await prefs.setBool(_crashFlagKey, false);
      if (kDebugMode) debugPrint('✅ Clean shutdown marked');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error marking clean shutdown: $e');
    }
  }
  
  /// Perform crash recovery
  Future<void> _performRecovery() async {
    try {
      if (kDebugMode) debugPrint('🔄 Starting crash recovery');
      
      // Recover incomplete transactions
      await _recoverIncompleteTransactions();
      
      // Verify data integrity
      await _verifyDataIntegrity();
      
      // Clean up any corrupted data
      await _cleanupCorruptedData();
      
      // Force sync with backend to ensure consistency
      await _forceSyncAfterRecovery();
      
      if (kDebugMode) debugPrint('✅ Crash recovery completed');
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Crash recovery error: $e');
    }
  }
  
  /// Recover incomplete transactions
  Future<void> _recoverIncompleteTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final incompleteJson = prefs.getString(_incompleteTransactionsKey);
      
      if (incompleteJson == null || incompleteJson.isEmpty) {
        if (kDebugMode) debugPrint('✅ No incomplete transactions to recover');
        return;
      }
      
      final List<dynamic> incomplete = json.decode(incompleteJson);
      if (kDebugMode) debugPrint('📋 Found ${incomplete.length} incomplete transactions');
      
      for (final transaction in incomplete) {
        try {
          await _recoverTransaction(transaction as Map<String, dynamic>);
        } catch (e) {
          if (kDebugMode) debugPrint('❌ Error recovering transaction: $e');
        }
      }
      
      // Clear incomplete transactions after recovery attempt
      await prefs.remove(_incompleteTransactionsKey);
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error recovering incomplete transactions: $e');
    }
  }
  
  /// Recover a single transaction
  Future<void> _recoverTransaction(Map<String, dynamic> transaction) async {
    try {
      final type = transaction['type'] as String;
      final data = transaction['data'] as Map<String, dynamic>;
      
      if (kDebugMode) debugPrint('🔄 Recovering transaction: $type');
      
      switch (type) {
        case 'sale':
          await _recoverSale(data);
          break;
        case 'product_update':
          await _recoverProductUpdate(data);
          break;
        case 'customer_update':
          await _recoverCustomerUpdate(data);
          break;
        default:
          if (kDebugMode) debugPrint('⚠️ Unknown transaction type: $type');
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error in transaction recovery: $e');
    }
  }
  
  /// Recover sale transaction using the same durable outbox as normal sales.
  /// Recovery is idempotent: restoring a sale that already exists is harmless,
  /// and local inventory deduction itself is guarded by sale-level idempotency.
  Future<void> _recoverSale(Map<String, dynamic> data) async {
    try {
      final sales = await LocalStorageService.loadSales();
      final saleId = data['sale_id']?.toString();
      if (saleId == null || saleId.isEmpty) {
        throw StateError('Recovered sale is missing sale_id');
      }

      final exists = sales.any((s) =>
          (s is Map && (s['sale_id'] ?? s['invoice_number']).toString() == saleId));

      if (!exists) {
        await LocalStorageService.saveSales([...sales, data]);
      }

      final items = (data['items'] is List)
          ? (data['items'] as List)
          : <dynamic>[];

      if (items.isNotEmpty) {
        // This method is idempotent by saleId, so it repairs a crash that
        // happened after sale persistence but before local inventory update.
        await InventoryManagementService.deductStockLocally(
          items,
          saleId: saleId,
        );
      }

      final invoicePayload = <String, dynamic>{
        'invoice_number': saleId,
        'offline_id': saleId,
        'customer_name': data['customer_name'] ?? 'Cash Customer',
        'customer_phone': data['customer_phone'],
        'total_amount': data['total_amount'] ?? data['total'] ?? 0,
        'paid_amount': data['paid_amount'] ?? 0,
        'tax': data['tax'] ?? 0,
        'payment_status': data['payment_status'] ?? 'UNPAID',
        'invoice_date': data['invoice_date'] ??
            data['business_date'] ??
            data['sale_date'] ??
            DateTime.now().toIso8601String().split('T').first,
        'line_items': items,
        'notes': data['notes'] ?? 'Recovered offline sale',
      };

      final queued = await SyncQueueManager.enqueue('save_sale', {
        'endpoint': ApiClient.invoicesSync,
        'payload': invoicePayload,
        'invoice_payload': invoicePayload,
        'sale_id': saleId,
        'retry_priority': 'critical',
      });

      if (!queued) {
        throw StateError('Failed to restore sale into durable outbox: $saleId');
      }

      if (kDebugMode) {
        debugPrint('✅ Sale recovery complete: $saleId');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error recovering sale: $e');
    }
  }
  
  /// Recover product update transaction
  Future<void> _recoverProductUpdate(Map<String, dynamic> data) async {
    try {
      final productId = data['product_id'] as String?;
      if (productId == null) return;
      
      final products = await LocalStorageService.loadBackendProducts();
      final index = products.indexWhere((p) => p['id'].toString() == productId);
      
      if (index != -1) {
        products[index] = data;
        await LocalStorageService.saveBackendProducts(products);
        if (kDebugMode) debugPrint('✅ Product update recovered');
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error recovering product update: $e');
    }
  }
  
  /// Recover customer update transaction
  Future<void> _recoverCustomerUpdate(Map<String, dynamic> data) async {
    try {
      final customerId = data['customer_id'] as String?;
      if (customerId == null) return;
      
      final customers = await LocalStorageService.loadLocalCustomers();
      final index = customers.indexWhere((c) => c['id'].toString() == customerId);
      
      if (index != -1) {
        customers[index] = data;
        await LocalStorageService.saveLocalCustomers(customers);
        if (kDebugMode) debugPrint('✅ Customer update recovered');
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error recovering customer update: $e');
    }
  }
  
  /// Verify data integrity
  Future<void> _verifyDataIntegrity() async {
    try {
      if (kDebugMode) debugPrint('🔍 Verifying data integrity');
      
      // Verify sales data
      await _verifySalesIntegrity();
      
      // Verify products data
      await _verifyProductsIntegrity();
      
      // Verify customers data
      await _verifyCustomersIntegrity();
      
      if (kDebugMode) debugPrint('✅ Data integrity verification completed');
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Data integrity verification error: $e');
    }
  }
  
  /// Verify sales data integrity
  Future<void> _verifySalesIntegrity() async {
    try {
      final sales = await LocalStorageService.loadSales();
      int quarantinedCount = 0;
      
      for (int i = sales.length - 1; i >= 0; i--) {
        final sale = sales[i];
        if (!_isValidSale(sale)) {
          // 🔒 FIX: Quarantine instead of delete
          await _quarantineSale(sale);
          sales.removeAt(i);
          quarantinedCount++;
        }
      }
      
      if (quarantinedCount > 0) {
        await LocalStorageService.saveSales(sales);
        if (kDebugMode) debugPrint('🔧 Quarantined $quarantinedCount corrupted sales');
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error verifying sales integrity: $e');
    }
  }
  
  /// Verify products data integrity
  Future<void> _verifyProductsIntegrity() async {
    try {
      final products = await LocalStorageService.loadBackendProducts();
      int quarantinedCount = 0;
      
      for (int i = products.length - 1; i >= 0; i--) {
        final product = products[i];
        if (!_isValidProduct(product)) {
          // 🔒 FIX: Quarantine instead of delete
          await _quarantineProduct(product);
          products.removeAt(i);
          quarantinedCount++;
        }
      }
      
      if (quarantinedCount > 0) {
        await LocalStorageService.saveBackendProducts(products);
        if (kDebugMode) debugPrint('🔧 Quarantined $quarantinedCount corrupted products');
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error verifying products integrity: $e');
    }
  }
  
  /// Verify customers data integrity
  Future<void> _verifyCustomersIntegrity() async {
    try {
      final customers = await LocalStorageService.loadLocalCustomers();
      int quarantinedCount = 0;
      
      for (int i = customers.length - 1; i >= 0; i--) {
        final customer = customers[i];
        if (!_isValidCustomer(customer)) {
          // 🔒 FIX: Quarantine instead of delete
          await _quarantineCustomer(customer);
          customers.removeAt(i);
          quarantinedCount++;
        }
      }
      
      if (quarantinedCount > 0) {
        await LocalStorageService.saveLocalCustomers(customers);
        if (kDebugMode) debugPrint('🔧 Quarantined $quarantinedCount corrupted customers');
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error verifying customers integrity: $e');
    }
  }
  
  /// Check if sale data is valid
  bool _isValidSale(dynamic sale) {
    try {
      if (sale == null) return false;
      
      // 🔒 FIX: Enhanced validation with multiple checks
      final saleId = sale['sale_id'];
      final totalAmount = sale['total_amount'];
      final items = sale['items'];
      final customerName = sale['customer_name'];
      final paymentMethod = sale['payment_method'];
      final totals = sale['totals'];
      
      // Basic required fields
      if (saleId == null || saleId.toString().isEmpty) return false;
      if (totalAmount == null) return false;
      
      // Validate items if present
      if (items != null && items is List) {
        if (items.isEmpty) return false;
        for (var item in items) {
          if (item['product_name'] == null || item['product_name'].toString().isEmpty) {
            return false;
          }
        }
      }
      
      // Validate payment info if present
      if (paymentMethod != null && paymentMethod.toString().isEmpty) {
        return false;
      }
      
      // Validate totals if present
      if (totals != null && totals is Map) {
        if (totals['subtotal'] == null) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Check if product data is valid
  bool _isValidProduct(dynamic product) {
    try {
      return product != null &&
             product['id'] != null &&
             product['product_name'] != null &&
             product['product_name'].toString().isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Check if customer data is valid
  bool _isValidCustomer(dynamic customer) {
    try {
      return customer != null &&
             customer['id'] != null &&
             customer['name'] != null &&
             customer['name'].toString().isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Quarantine corrupted sale data
  Future<void> _quarantineSale(dynamic sale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final quarantinedJson = prefs.getString(_quarantinedSalesKey) ?? '[]';
      final List<dynamic> quarantined = json.decode(quarantinedJson);
      
      quarantined.add({
        'sale': sale,
        'quarantine_timestamp': DateTime.now().toIso8601String(),
        'reason': 'Integrity check failed',
      });
      
      await prefs.setString(_quarantinedSalesKey, json.encode(quarantined));
      if (kDebugMode) debugPrint('🔒 Quarantined sale: ${sale['sale_id']}');
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error quarantining sale: $e');
    }
  }
  
  /// Quarantine corrupted product data
  Future<void> _quarantineProduct(dynamic product) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final quarantinedJson = prefs.getString(_quarantinedProductsKey) ?? '[]';
      final List<dynamic> quarantined = json.decode(quarantinedJson);
      
      quarantined.add({
        'product': product,
        'quarantine_timestamp': DateTime.now().toIso8601String(),
        'reason': 'Integrity check failed',
      });
      
      await prefs.setString(_quarantinedProductsKey, json.encode(quarantined));
      if (kDebugMode) debugPrint('🔒 Quarantined product: ${product['id']}');
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error quarantining product: $e');
    }
  }
  
  /// Quarantine corrupted customer data
  Future<void> _quarantineCustomer(dynamic customer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final quarantinedJson = prefs.getString(_quarantinedCustomersKey) ?? '[]';
      final List<dynamic> quarantined = json.decode(quarantinedJson);
      
      quarantined.add({
        'customer': customer,
        'quarantine_timestamp': DateTime.now().toIso8601String(),
        'reason': 'Integrity check failed',
      });
      
      await prefs.setString(_quarantinedCustomersKey, json.encode(quarantined));
      if (kDebugMode) debugPrint('🔒 Quarantined customer: ${customer['id']}');
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error quarantining customer: $e');
    }
  }
  
  /// Clean up corrupted data
  Future<void> _cleanupCorruptedData() async {
    try {
      if (kDebugMode) debugPrint('🧹 Cleaning up corrupted data');
      
      // Clear any invalid cache entries
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('invalid_cache_flag');
      
      if (kDebugMode) debugPrint('✅ Corrupted data cleanup completed');
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error cleaning up corrupted data: $e');
    }
  }
  
  /// Force sync after recovery
  Future<void> _forceSyncAfterRecovery() async {
    try {
      if (kDebugMode) debugPrint('🔄 Forcing sync after recovery');
      
      // 🔒 FIX: Implement actual force sync to ensure backend consistency
      try {
        // Trigger sync with backend
        await BackgroundSyncWorker.instance.forceSync();
        if (kDebugMode) debugPrint('✅ Forced sync completed successfully');
      } catch (syncError) {
        if (kDebugMode) debugPrint('⚠️ Force sync failed (will retry on next app launch): $syncError');
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error forcing sync after recovery: $e');
    }
  }
  
  /// Register incomplete transaction
  Future<void> registerIncompleteTransaction(String type, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final incompleteJson = prefs.getString(_incompleteTransactionsKey) ?? '[]';
      final List<dynamic> incomplete = json.decode(incompleteJson);
      
      // 🔒 FIX: Add duplicate protection to prevent duplicate queue entries
      final transactionId = data['sale_id'] ?? data['product_id'] ?? data['customer_id'];
      final existing = incomplete.any((transaction) {
        final t = transaction as Map<String, dynamic>;
        return t['type'] == type && 
               (t['data']['sale_id'] == transactionId || 
                t['data']['product_id'] == transactionId ||
                t['data']['customer_id'] == transactionId);
      });
      
      if (existing) {
        if (kDebugMode) debugPrint('⚠️ Transaction already exists in recovery queue: $type - $transactionId');
        return;
      }
      
      incomplete.add({
        'type': type,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      await prefs.setString(_incompleteTransactionsKey, json.encode(incomplete));
      
      if (kDebugMode) debugPrint('📝 Registered incomplete transaction: $type');
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error registering incomplete transaction: $e');
    }
  }
  
  /// Clear incomplete transactions
  Future<void> clearIncompleteTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_incompleteTransactionsKey);
      if (kDebugMode) debugPrint('🗑️ Cleared incomplete transactions');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error clearing incomplete transactions: $e');
    }
  }
  
  /// Clear specific incomplete transaction by type and data
  Future<void> clearSpecificTransaction(String type, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final incompleteJson = prefs.getString(_incompleteTransactionsKey);
      
      if (incompleteJson == null || incompleteJson.isEmpty) {
        return;
      }
      
      final List<dynamic> incomplete = json.decode(incompleteJson);
      final transactionId = data['sale_id'] ?? data['product_id'] ?? data['customer_id'];
      
      incomplete.removeWhere((transaction) {
        final t = transaction as Map<String, dynamic>;
        return t['type'] == type && 
               (t['data']['sale_id'] == transactionId || 
                t['data']['product_id'] == transactionId ||
                t['data']['customer_id'] == transactionId);
      });
      
      await prefs.setString(_incompleteTransactionsKey, json.encode(incomplete));
      if (kDebugMode) debugPrint('🗑️ Cleared specific transaction: $type - $transactionId');
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error clearing specific transaction: $e');
    }
  }
}
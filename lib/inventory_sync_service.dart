import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'secure_token_storage.dart';
import 'local_storage_service.dart';
import 'notification_service.dart';

/// 
/// INVENTORY SYNC SERVICE - SINGLE SOURCE OF TRUTH
/// ================================================
/// 
/// CRITICAL ARCHITECTURAL CHANGE:
/// - Backend PostgreSQL is NOW the ONLY source of truth for inventory
/// - Local storage is ONLY a cache - never authoritative
/// - All stock deductions MUST go through backend
/// - Frontend fetches updated stock after every operation
/// 
/// This fixes the critical bug where stock was lost after app data clear
/// 
class InventorySyncService {
  
  /// Deduct stock via backend with idempotency protection
  /// This is the ONLY way to deduct stock - local changes are forbidden
  /// PHASE 5 FIX: Prevent negative inventory
  static Future<Map<String, dynamic>> deductStock({
    required int productId,
    required int quantity,
    required String referenceId, // invoice_number or sale_id
    String reason = 'SALE',
  }) async {
    const String context = 'INVENTORY_DEDUCT';
    
    try {
      if (kDebugMode) debugPrint('🔒 Backend Stock Deduction: Product $productId, Qty: $quantity');
      
      // 🔒 PHASE 5 FIX: Prevent negative deductions
      if (quantity <= 0) {
        if (kDebugMode) debugPrint('❌ Invalid quantity: $quantity');
        return {
          'success': false,
          'error': 'INVALID_QUANTITY',
          'message': 'Quantity must be greater than 0'
        };
      }
      
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        if (kDebugMode) debugPrint('❌ No auth token - cannot deduct stock');
        return {
          'success': false,
          'error': 'NOT_AUTHENTICATED',
          'message': 'Authentication required for stock operations'
        };
      }
      
      // Generate idempotency key to prevent duplicate deductions
      final idempotencyKey = '${productId}_${referenceId}';
      
      final response = await ApiClient.postJson(
        '/api/inventory-sync/deduct-stock',
        {
          'product_id': productId,
          'quantity': quantity,
          'reason': reason,
          'reference_id': referenceId,
          'idempotency_key': idempotencyKey,
        },
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        
        // 🔒 PHASE 5 FIX: Verify new stock is not negative
        final newStock = data['new_stock'] ?? 0;
        if (newStock < 0) {
          if (kDebugMode) debugPrint('⚠️ Backend returned negative stock: $newStock');
          return {
            'success': false,
            'error': 'NEGATIVE_STOCK',
            'message': 'Stock deduction would result in negative inventory',
            'attempted_qty': quantity,
            'available_stock': data['previous_stock'],
          };
        }
        
        if (kDebugMode) {
          debugPrint('✅ Stock deducted successfully');
          debugPrint('   Previous: ${data['previous_stock']}');
          debugPrint('   New: $newStock');
        }
        
        // Update local cache with backend truth
        await _updateLocalCache(productId, newStock);
        
        return {
          'success': true,
          'product_id': productId,
          'previous_stock': data['previous_stock'],
          'new_stock': newStock,
          'message': data['message'],
          'sync_timestamp': data['sync_timestamp'],
        };
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        final errorMsg = error['detail'] ?? 'Stock deduction failed';
        
        // 🔒 PHASE 5 FIX: Check if error is due to insufficient stock
        if (errorMsg.toString().contains('insufficient') || errorMsg.toString().contains('negative')) {
          if (kDebugMode) debugPrint('⚠️ Insufficient stock for product $productId');
          return {
            'success': false,
            'error': 'INSUFFICIENT_STOCK',
            'message': errorMsg,
            'status_code': 400,
          };
        }
        
        if (kDebugMode) debugPrint('❌ Stock deduction error: $errorMsg');
        return {
          'success': false,
          'error': 'BACKEND_ERROR',
          'message': errorMsg,
          'status_code': 400,
        };
      } else {
        return {
          'success': false,
          'error': 'SERVER_ERROR',
          'message': 'Server error',
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Stock deduction exception: $e');
      return {
        'success': false,
        'error': 'NETWORK_ERROR',
        'message': 'Network error: $e',
      };
    }
  }
  
  /// Batch stock deduction for multiple products (invoice sync)
  /// PHASE 5 FIX: Prevent negative inventory in batch operations
  static Future<Map<String, dynamic>> deductStockBatch(List<Map<String, dynamic>> items) async {
    try {
      if (kDebugMode) debugPrint('🔒 Batch Stock Deduction: ${items.length} items');
      
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        return {
          'success': false,
          'error': 'NOT_AUTHENTICATED',
          'message': 'Authentication required'
        };
      }
      
      // 🔒 PHASE 5 FIX: Validate quantities before batch deduction
      final validationErrors = <String>[];
      for (int i = 0; i < items.length; i++) {
        final qty = items[i]['qty'] ?? items[i]['quantity'];
        final qtyInt = qty is int ? qty : (qty is double ? qty.toInt() : int.tryParse(qty?.toString() ?? '0'));
        
        if (qtyInt == null || qtyInt <= 0) {
          validationErrors.add('Item $i has invalid quantity: $qty');
        }
      }
      
      if (validationErrors.isNotEmpty) {
        if (kDebugMode) debugPrint('❌ Batch validation failed: ${validationErrors.join(', ')}');
        return {
          'success': false,
          'error': 'VALIDATION_ERROR',
          'message': validationErrors.join('; '),
        };
      }
      
      // Prepare batch request
      final updates = items.map((item) => {
        'product_id': item['product_id'] ?? item['id'],
        'quantity': item['qty'] ?? item['quantity'],
        'reason': 'INVOICE_SYNC',
        'reference_id': item['reference_id'] ?? item['invoice_number'],
        'idempotency_key': '${item['product_id']}_${item['reference_id']}',
      }).toList();
      
      final response = await ApiClient.postJson(
        '/api/inventory-sync/deduct-stock-batch',
        {'updates': updates},
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (kDebugMode) {
          debugPrint('✅ Batch deduction complete');
          debugPrint('   Successful: ${data['successful']}/${data['total_items']}');
          debugPrint('   Failed: ${data['failed']}');
        }
        
        // 🔒 PHASE 5 FIX: Verify no negative stocks were created
        final negativeStocks = <Map<String, dynamic>>[];
        for (var result in data['results']) {
          if (result['new_stock'] != null && (result['new_stock'] as num) < 0) {
            negativeStocks.add({
              'product_id': result['product_id'],
              'product_name': result['product_name'],
              'new_stock': result['new_stock'],
            });
          }
        }
        
        if (negativeStocks.isNotEmpty) {
          if (kDebugMode) {
            debugPrint('⚠️ Negative stocks detected after batch deduction:');
            for (var neg in negativeStocks) {
              debugPrint('   ${neg['product_name']}: ${neg['new_stock']}');
            }
          }
          return {
            'success': false,
            'error': 'NEGATIVE_STOCK_CREATED',
            'message': 'Batch deduction resulted in negative inventory',
            'negative_stocks': negativeStocks,
          };
        }
        
        // Update local cache for successful items
        for (var result in data['results']) {
          if (result['success']) {
            await _updateLocalCache(result['product_id'], result['new_stock']);
          }
        }
        
        return {
          'success': data['success'],
          'total_items': data['total_items'],
          'successful': data['successful'],
          'failed': data['failed'],
          'results': data['results'],
          'failed_items': data['failed_items'],
        };
      } else {
        return {
          'success': false,
          'error': 'BACKEND_ERROR',
          'message': 'Batch deduction failed',
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Batch deduction exception: $e');
      return {
        'success': false,
        'error': 'NETWORK_ERROR',
        'message': 'Network error: $e',
      };
    }
  }
  
  /// Fetch current stock from backend (single source of truth)
  static Future<Map<String, dynamic>> getCurrentStock(int productId) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        return {'success': false, 'error': 'NOT_AUTHENTICATED'};
      }
      
      final response = await ApiClient.getJson(
        '/api/inventory-sync/current-stock/$productId',
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Update local cache
        await _updateLocalCache(productId, data['current_stock']);
        
        return {
          'success': true,
          'product_id': data['product_id'],
          'product_name': data['product_name'],
          'current_stock': data['current_stock'],
          'min_stock': data['min_stock'],
          'max_stock': data['max_stock'],
          'last_updated': data['last_updated'],
          'recent_movements': data['recent_movements'],
        };
      } else {
        return {'success': false, 'error': 'BACKEND_ERROR'};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Failed to fetch current stock: $e');
      return {'success': false, 'error': 'NETWORK_ERROR'};
    }
  }
  
  /// Fetch all inventory from backend and refresh local cache
  static Future<Map<String, dynamic>> refreshAllInventory() async {
    try {
      if (kDebugMode) debugPrint('🔄 Refreshing all inventory from backend...');

      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        return {'success': false, 'error': 'NOT_AUTHENTICATED'};
      }

      final response = await ApiClient.getJson(
        '/api/inventory-sync/all-stock',
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rawProducts = data is Map ? data['products'] : null;

        final backendProducts = rawProducts is List
            ? rawProducts
                .whereType<Map>()
                .map((p) => Map<String, dynamic>.from(p))
                .toList()
            : <Map<String, dynamic>>[];

        final cachedProducts =
            await LocalStorageService.loadBackendProducts();

        // A 200 response containing zero products is not allowed to erase a
        // healthy non-empty local snapshot. Keep the last known inventory
        // until a meaningful cloud snapshot arrives.
        if (backendProducts.isEmpty && cachedProducts.isNotEmpty) {
          if (kDebugMode) {
            debugPrint(
              '⚠️ Inventory backend returned 200 with 0 products; '
              'preserving ${cachedProducts.length} cached products',
            );
          }

          return {
            'success': true,
            'total_products': cachedProducts.length,
            'timestamp': data is Map ? data['timestamp'] : null,
            'products': cachedProducts,
            'cache_preserved': true,
          };
        }

        await LocalStorageService.saveBackendProducts(backendProducts);

        if (kDebugMode) {
          debugPrint('✅ Inventory refreshed from backend');
          debugPrint('   Total products: ${backendProducts.length}');
          debugPrint('   Timestamp: ${data is Map ? data['timestamp'] : null}');
        }

        return {
          'success': true,
          'total_products': backendProducts.length,
          'timestamp': data is Map ? data['timestamp'] : null,
          'products': backendProducts,
        };
      } else {
        return {'success': false, 'error': 'BACKEND_ERROR'};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Failed to refresh inventory: $e');
      return {'success': false, 'error': 'NETWORK_ERROR'};
    }
  }

  /// Reconcile local cache with backend
  /// Detects discrepancies and provides correct values
  static Future<Map<String, dynamic>> reconcileInventory() async {
    try {
      if (kDebugMode) debugPrint('🔍 Reconciling inventory with backend...');
      
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        return {'success': false, 'error': 'NOT_AUTHENTICATED'};
      }
      
      // Get local inventory
      final localProducts = await LocalStorageService.loadBackendProducts();
      
      final response = await ApiClient.postJson(
        '/api/inventory-sync/reconcile',
        {'local_inventory': localProducts},
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (kDebugMode) {
          debugPrint('📊 Reconciliation complete');
          debugPrint('   Discrepancies found: ${data['discrepancies_found']}');
          debugPrint('   Fixes applied: ${data['fixes_applied']}');
        }
        
        // If discrepancies found, refresh from backend
        if (data['discrepancies_found'] > 0) {
          if (kDebugMode) debugPrint('⚠️ Discrepancies detected - refreshing from backend');
          await refreshAllInventory();
          
          // Show notification
          NotificationService.show(
            'Inventory Reconciled',
            '${data['fixes_applied']} stock discrepancies fixed',
            payload: 'inventory_reconciled',
          );
        }
        
        return {
          'success': true,
          'reconciled': data['reconciled'],
          'discrepancies_found': data['discrepancies_found'],
          'fixes_applied': data['fixes_applied'],
          'details': data['details'],
        };
      } else {
        return {'success': false, 'error': 'BACKEND_ERROR'};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Reconciliation failed: $e');
      return {'success': false, 'error': 'NETWORK_ERROR'};
    }
  }
  
  /// Update local cache with backend stock value
  static Future<void> _updateLocalCache(int productId, int newStock) async {
    try {
      final products = await LocalStorageService.loadBackendProducts();
      
      for (var p in products) {
        if ((p['id']?.toString() ?? p['product_id']?.toString()) == productId.toString()) {
          p['current_stock'] = newStock;
          p['stock'] = newStock; // For compatibility
          break;
        }
      }
      
      await LocalStorageService.saveBackendProducts(products);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to update local cache: $e');
    }
  }

  /// Decrease stock in local cache immediately (Critical for offline sales)
  static bool _isUpdatingLocalStock = false;

  static Future<void> decreaseLocalStock(int productId, int quantitySold) async {
    while (_isUpdatingLocalStock) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _isUpdatingLocalStock = true;
    try {
      final products = await LocalStorageService.loadBackendProducts();
      bool changed = false;
      
      for (var p in products) {
        if ((p['id']?.toString() ?? p['product_id']?.toString()) == productId.toString()) {
          int current = (p['current_stock'] as num?)?.toInt() ?? (p['stock'] as num?)?.toInt() ?? 0;
          int newStock = current - quantitySold;
          if (newStock < 0) newStock = 0;
          
          p['current_stock'] = newStock;
          p['stock'] = newStock;
          changed = true;
          break;
        }
      }
      
      if (changed) {
        await LocalStorageService.saveBackendProducts(products);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to decrease local stock: $e');
    } finally {
      _isUpdatingLocalStock = false;
    }
  }
  
  /// Get stock from local cache (fallback when offline)
  static Future<int?> getLocalStock(int productId) async {
    try {
      final products = await LocalStorageService.loadBackendProducts();
      
      for (var p in products) {
        if ((p['id']?.toString() ?? p['product_id']?.toString()) == productId.toString()) {
          return p['current_stock'] as int? ?? p['stock'] as int?;
        }
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to get local stock: $e');
      return null;
    }
  }
  
  /// Check if local cache is stale (older than 5 minutes)
  static Future<bool> isCacheStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncStr = prefs.getString('last_inventory_sync');
      
      if (lastSyncStr == null) return true;
      
      final lastSync = DateTime.tryParse(lastSyncStr);
      if (lastSync == null) return true;
      
      final staleThreshold = DateTime.now().subtract(const Duration(minutes: 5));
      return lastSync.isBefore(staleThreshold);
    } catch (e) {
      return true;
    }
  }
  
  /// Update last sync timestamp
  static Future<void> updateLastSyncTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_inventory_sync', DateTime.now().toIso8601String());
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to update sync timestamp: $e');
    }
  }
}

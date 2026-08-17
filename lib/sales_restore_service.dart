import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'secure_token_storage.dart';
import 'local_storage_service.dart';
import 'inventory_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 
/// SALES RESTORE SERVICE - Complete Sales Recovery After App Reinstall
/// =================================================================
/// 
/// Restores:
/// - invoices
/// - invoice items
/// - stock impact
/// - customer history
/// - payment status
/// 
/// Called after app reinstall to recover all data from backend.
/// 
class SalesRestoreService {
  
  /// Restore all sales from backend after app reinstall
  static Future<Map<String, dynamic>> restoreAllSales({
    String? startDate,
    String? endDate,
    bool includeStockImpact = true,
  }) async {
    try {
      if (kDebugMode) debugPrint('🔄 Starting sales restoration from backend...');
      
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        return {
          'success': false,
          'error': 'NOT_AUTHENTICATED',
          'message': 'Authentication required'
        };
      }
      
      final requestBody = <String, dynamic>{};
      if (startDate != null) requestBody['start_date'] = startDate;
      if (endDate != null) requestBody['end_date'] = endDate;
      requestBody['include_stock_impact'] = includeStockImpact;
      
      final response = await ApiClient.postJson(
        '/api/sales-restore/restore-all',
        requestBody,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Save restored sales to local storage
        await _saveRestoredSales(data['invoices']);
        
        // Refresh inventory from backend to ensure consistency
        if (includeStockImpact) {
          await InventorySyncService.refreshAllInventory();
        }
        
        if (kDebugMode) {
          debugPrint('✅ Sales restoration complete');
          debugPrint('   Invoices restored: ${data['total_invoices_restored']}');
          debugPrint('   Line items restored: ${data['total_line_items_restored']}');
          debugPrint('   Customers restored: ${data['customers_restored']}');
          debugPrint('   Stock impact applied: ${data['stock_impact_applied']}');
        }
        
        return {
          'success': true,
          'total_invoices_restored': data['total_invoices_restored'],
          'total_line_items_restored': data['total_line_items_restored'],
          'customers_restored': data['customers_restored'],
          'stock_impact_applied': data['stock_impact_applied'],
          'invoices': data['invoices'],
          'summary': data['summary'],
          'timestamp': data['timestamp'],
        };
      } else {
        return {
          'success': false,
          'error': 'BACKEND_ERROR',
          'message': 'Sales restoration failed',
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Sales restoration exception: $e');
      return {
        'success': false,
        'error': 'NETWORK_ERROR',
        'message': 'Network error: $e',
      };
    }
  }
  
  /// Get summary of available sales data for restoration
  static Future<Map<String, dynamic>> getRestoreSummary() async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        return {'success': false, 'error': 'NOT_AUTHENTICATED'};
      }
      
      final response = await ApiClient.getJson(
        '/api/sales-restore/restore-summary',
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'available_for_restore': data['available_for_restore'],
          'invoice_summary': data['invoice_summary'],
          'date_range': data['date_range'],
          'financial_summary': data['financial_summary'],
          'timestamp': data['timestamp'],
        };
      } else {
        return {'success': false, 'error': 'BACKEND_ERROR'};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Failed to get restore summary: $e');
      return {'success': false, 'error': 'NETWORK_ERROR'};
    }
  }
  
  /// Restore customers from backend
  static Future<Map<String, dynamic>> restoreCustomers() async {
    try {
      if (kDebugMode) debugPrint('🔄 Restoring customers from backend...');
      
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        return {'success': false, 'error': 'NOT_AUTHENTICATED'};
      }
      
      final response = await ApiClient.postJson(
        '/api/sales-restore/restore-customers',
        {},
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Save restored customers to local storage
        await _saveRestoredCustomers(data['customers']);
        try { await InventorySyncService.refreshAllInventory(); } catch (_) {}
        
        if (kDebugMode) {
          debugPrint('✅ Customer restoration complete');
          debugPrint('   Customers restored: ${data['total_customers_restored']}');
        }
        
        return {
          'success': true,
          'total_customers_restored': data['total_customers_restored'],
          'customers': data['customers'],
          'timestamp': data['timestamp'],
        };
      } else {
        return {'success': false, 'error': 'BACKEND_ERROR'};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Customer restoration exception: $e');
      return {'success': false, 'error': 'NETWORK_ERROR'};
    }
  }
  
  /// Complete restoration after app reinstall
  /// This is the main entry point called on login after reinstall
  static Future<Map<String, dynamic>> completeRestoration() async {
    try {
      if (kDebugMode) debugPrint('🚀 Starting complete data restoration...');

      // Guard: skip if restoration was already completed on this device.
      // Without this guard the service runs on every login, merges backend
      // sales into local storage each time, and the dedup logic can still
      // produce duplicate bill records (e.g. after clearing app data and
      // re-logging in the pref key is gone so the guard would allow one
      // restore run, then markRestorationComplete() writes the key and
      // subsequent logins are skipped — which is the desired behaviour).
      final alreadyDone = await wasRestorationCompleted();
      if (alreadyDone) {
        if (kDebugMode) debugPrint('✅ Restoration already complete — skipping to prevent duplicates');
        return {
          'success': true,
          'message': 'Restoration already completed on this device',
          'steps_completed': [],
        };
      }

      // Step 1: Get restore summary
      final summary = await getRestoreSummary();
      if (!summary['success'] || !summary['available_for_restore']) {
        if (kDebugMode) debugPrint('⚠️ No data available for restoration');
        return {
          'success': true,
          'message': 'No data available for restoration',
          'steps_completed': [],
        };
      }
      
      final stepsCompleted = <String>[];
      
      // Step 2: Restore sales
      final salesResult = await restoreAllSales(includeStockImpact: true);
      if (salesResult['success']) {
        stepsCompleted.add('Sales restored: ${salesResult['total_invoices_restored']} invoices');
      } else {
        stepsCompleted.add('Sales restoration failed: ${salesResult['error']}');
      }
      
      // Step 3: Restore customers
      final customersResult = await restoreCustomers();
      if (customersResult['success']) {
        stepsCompleted.add('Customers restored: ${customersResult['total_customers_restored']} customers');
      } else {
        stepsCompleted.add('Customer restoration failed: ${customersResult['error']}');
      }
      
      // Step 4: Reconcile inventory
      final reconcileResult = await InventorySyncService.reconcileInventory();
      if (reconcileResult['success']) {
        stepsCompleted.add('Inventory reconciled: ${reconcileResult['discrepancies_found']} discrepancies found');
      } else {
        stepsCompleted.add('Inventory reconciliation failed: ${reconcileResult['error']}');
      }
      
      // Step 5: Update last sync timestamp
      await InventorySyncService.updateLastSyncTimestamp();

      final restorationSucceeded = salesResult['success'] == true &&
          customersResult['success'] == true &&
          reconcileResult['success'] == true;
      if (restorationSucceeded) {
        await markRestorationComplete();
      }
      
      if (kDebugMode) {
        debugPrint('✅ Complete restoration finished');
        for (var step in stepsCompleted) {
          debugPrint('   - $step');
        }
      }
      
      return {
        'success': restorationSucceeded,
        'steps_completed': stepsCompleted,
        'total_steps': stepsCompleted.length,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Complete restoration exception: $e');
      return {
        'success': false,
        'error': 'RESTORATION_FAILED',
        'message': 'Restoration failed: $e',
      };
    }
  }
  
  /// Save restored sales to local storage
  static Future<void> _saveRestoredSales(List<dynamic> invoices) async {
    try {
      // 🔧 FIX: Load existing local sales and invoices first to merge instead of overwrite
      final List<dynamic> existingSales = await LocalStorageService.loadSales();
      final List<dynamic> existingLocalInvoices = await LocalStorageService.loadLocalInvoices();
      
      final Map<String, dynamic> existingSalesMap = {};
      final Map<String, dynamic> existingInvoiceMap = {};
      
      for (var s in existingSales) {
        final saleId = (s['sale_id'] ?? s['invoice_number']).toString();
        existingSalesMap[saleId] = s;
      }
      
      for (var inv in existingLocalInvoices) {
        final invId = (inv['invoice_number']).toString();
        existingInvoiceMap[invId] = inv;
      }
      
      final List<Map<String, dynamic>> salesHistory = [];
      final List<Map<String, dynamic>> localInvoicesList = [];
      final Set<String> processedSaleIds = {};
      final Set<String> processedInvoiceIds = {};
      
      // First pass: add all existing local sales and invoices
      for (var s in existingSales) {
        final saleId = (s['sale_id'] ?? s['invoice_number']).toString();
        salesHistory.add(Map<String, dynamic>.from(s));
        processedSaleIds.add(saleId);
      }
      
      for (var inv in existingLocalInvoices) {
        final invId = (inv['invoice_number']).toString();
        localInvoicesList.add(Map<String, dynamic>.from(inv));
        processedInvoiceIds.add(invId);
      }
      
      // Second pass: merge backend sales and invoices
      for (var invoice in invoices) {
        final saleId = invoice['invoice_number'].toString();
        
        // Convert backend invoice to local invoice format
        final productName = invoice['notes'] ?? 
            (invoice['line_items']?.isNotEmpty == true 
                ? (invoice['line_items'][0]['product_name'] ?? invoice['line_items'][0]['description']) 
                : 'Custom Invoice');
        
        final backendInvoiceRecord = {
          'invoice_number': invoice['invoice_number'],
          'id': invoice['id'],
          'product': productName,
          'customer_name': invoice['customer_name'] ?? 'Cash Customer',
          'customer_phone': invoice['customer_phone'],
          'total_amount': invoice['total_amount'],
          'paid_amount': invoice['paid_amount'],
          'due_date': invoice['due_date'],
          'status': invoice['status'],
          'payment_status': invoice['payment_status'],
          'is_local': false,
          // Business date and technical timestamps are separate concepts.
          // Missing business dates remain missing so analytics can surface the
          // record as unreconciled instead of moving it into today's sales.
          'business_date': invoice['sale_date'] ?? invoice['invoice_date'] ?? invoice['date'],
          'created_at': invoice['created_at'],
          'updated_at': invoice['updated_at'],
        };
        
        // Add to local invoices list if not already present
        if (!existingInvoiceMap.containsKey(saleId)) {
          localInvoicesList.add(backendInvoiceRecord);
          if (kDebugMode) debugPrint('➕ Added new backend invoice $saleId to local invoices');
        } else {
          // Update existing invoice if backend is newer
          final existingInv = existingInvoiceMap[saleId];
          final existingUpdatedAt = existingInv['updated_at'] ?? existingInv['created_at'];
          final backendUpdatedAt = invoice['updated_at'] ?? invoice['created_at'];

          DateTime existingDate = existingUpdatedAt != null 
              ? DateTime.tryParse(existingUpdatedAt.toString()) ?? DateTime(1970) 
              : DateTime(1970);
          DateTime backendDate = backendUpdatedAt != null 
              ? DateTime.tryParse(backendUpdatedAt.toString()) ?? DateTime(1970) 
              : DateTime(1970);

          if (backendDate.isAfter(existingDate)) {
            final index = localInvoicesList.indexWhere((i) => i['invoice_number'].toString() == saleId);
            if (index != -1) {
              localInvoicesList[index] = backendInvoiceRecord;
              if (kDebugMode) debugPrint('🔄 Updated local invoice $saleId with newer backend data');
            }
          }
        }
        
        // 🔧 FIX: Validate product_name in line items for sales
        final List<dynamic> validLineItems = [];
        for (var item in invoice['line_items'] ?? []) {
          final itemProductName = (item['product_name'] ?? item['description'] ?? '').toString().trim();
          if (itemProductName.isEmpty || itemProductName.toLowerCase() == 'unknown' || itemProductName.toLowerCase() == 'unknown item') {
            if (kDebugMode) debugPrint('⚠️ Skipping line item with invalid product_name: $itemProductName');
            continue;
          }
          validLineItems.add(item);
        }
        
        if (validLineItems.isNotEmpty) {
          final normalizedLineItems = validLineItems.map((item) {
            final desc = (item['product_name'] ?? item['name'] ?? item['product'] ?? item['description'] ?? '').toString().trim();
            final safeDesc = desc.isEmpty ? 'Custom Product' : desc;
            final qty = item['quantity'] is num
              ? item['quantity'] as num
              : num.tryParse(item['quantity']?.toString() ?? '') ?? 1;
            final price = item['unit_price'] is num
              ? item['unit_price'] as num
              : num.tryParse(item['unit_price']?.toString() ?? '') ?? 0.0;
            final total = item['line_total'] is num
              ? item['line_total'] as num
              : qty * price;
            return {
              'product_name': safeDesc,
              'product': safeDesc,
              'name': safeDesc,
              'item': safeDesc,
              'qty': qty.toDouble(),
              'quantity': qty.toDouble(),
              'price': price.toDouble(),
              'unit_price': price.toDouble(),
              'total': total.toDouble(),
              'line_total': total.toDouble(),
            };
          }).toList();

          // Convert invoice to sales history format with sync metadata
          final backendSaleRecord = {
            'sale_id': invoice['invoice_number'],
            'offline_id': invoice['offline_id'] ?? invoice['invoice_number'],
            'invoice_id': invoice['id'],
            // Keep the invoice business date distinct from insert/update time.
            'business_date': invoice['sale_date'] ?? invoice['invoice_date'] ?? invoice['date'],
            'created_at': invoice['created_at'],
            'updated_at': invoice['updated_at'],
            'user_id': null,
            'sync_status': 'synced',
            'sync_attempts': 0,
            'last_sync_attempt': DateTime.now().toUtc().toIso8601String(),
            'backend_id': invoice['id'],
            'is_deleted': false,
            'customer_name': invoice['customer_name'] ?? 'Cash Customer',
            'customer_phone': invoice['customer_phone'],
            'items': normalizedLineItems,
            'subtotal': invoice['subtotal'].toString(),
            'total': invoice['total_amount'].toString(),
            'total_amount': invoice['total_amount'],
            'paid_amount': invoice['paid_amount'].toString(),
            'payment_status': invoice['payment_status'],
            'gst_applied': (invoice['tax'] ?? 0) > 0,
            'payment_method': invoice['payment_method'] ?? 'Cash',
            'source': invoice['source'],
            'restored': true,
          };
          
          if (existingSalesMap.containsKey(saleId)) {
            // Conflict resolution: keep the newer one
            final existingSale = existingSalesMap[saleId];
            final existingUpdatedAt = existingSale['updated_at'] ?? existingSale['created_at'];
            final backendUpdatedAt = backendSaleRecord['updated_at'];
            
            // Parse dates
            DateTime existingDate = existingUpdatedAt != null 
                ? DateTime.tryParse(existingUpdatedAt.toString()) ?? DateTime(1970)
                : DateTime(1970);
            DateTime backendDate = backendUpdatedAt != null 
                ? DateTime.tryParse(backendUpdatedAt.toString()) ?? DateTime(1970)
                : DateTime(1970);
            
            if (backendDate.isAfter(existingDate)) {
              // Backend is newer - update existing
              final index = salesHistory.indexWhere((s) => (s['sale_id'] ?? s['invoice_number']).toString() == saleId);
              if (index != -1) {
                // Merge backend data but preserve local sync metadata if it's pending
                if (existingSale['sync_status'] == 'pending') {
                  // Keep local pending sale - don't overwrite
                  if (kDebugMode) debugPrint('⏭️ Keeping local pending sale $saleId (has pending sync)');
                } else {
                  // Overwrite with backend
                  salesHistory[index] = {
                    ...backendSaleRecord,
                    'sync_status': 'synced',
                    'sync_attempts': existingSale['sync_attempts'] ?? 0,
                  };
                  if (kDebugMode) debugPrint('🔄 Updated local sale $saleId with newer backend data');
                }
              }
            } else {
              // Local is newer - keep local
              if (kDebugMode) debugPrint('⏭️ Keeping local sale $saleId (newer than backend)');
            }
          } else {
            // New sale from backend
            salesHistory.add(backendSaleRecord);
            if (kDebugMode) debugPrint('➕ Added new backend sale $saleId');
          }
        }
      }
      
      await LocalStorageService.saveSales(salesHistory);
      await LocalStorageService.saveLocalInvoices(localInvoicesList);
      
      if (kDebugMode) debugPrint('💾 Saved ${salesHistory.length} sales and ${localInvoicesList.length} invoices (merged restored with local)');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to save restored sales/invoices: $e');
    }
  }
  
  /// Save restored customers to local storage
  static Future<void> _saveRestoredCustomers(List<dynamic> customers) async {
    try {
      // Convert to customer format expected by local storage
      final List<Map<String, dynamic>> customerData = [];
      
      for (var customer in customers) {
        customerData.add({
          'id': customer['id'],
          'customer_name': customer['customer_name'],
          'email': customer['email'],
          'phone': customer['phone'],
          'whatsapp_number': customer['whatsapp_number'],
          'address': customer['address'],
          'city': customer['city'],
          'credit_limit': customer['credit_limit'],
          'payment_terms': customer['payment_terms'],
          'contact_preference': customer['contact_preference'],
          'is_active': customer['is_active'],
          'created_at': customer['created_at'],
          'restored': true,
        });
      }
      
      final existingCustomers = await LocalStorageService.loadLocalCustomers();
      final mergedCustomers = <String, Map<String, dynamic>>{};
      for (final existing in existingCustomers) {
        if (existing is Map) {
          final key = (existing['id'] ?? existing['phone'] ?? '').toString();
          if (key.isNotEmpty) mergedCustomers[key] = Map<String, dynamic>.from(existing);
        }
      }
      for (final customer in customerData) {
        final key = (customer['id'] ?? customer['phone'] ?? '').toString();
        if (key.isNotEmpty) mergedCustomers[key] = customer;
      }
      await LocalStorageService.saveLocalCustomers(mergedCustomers.values.toList());
      
      if (kDebugMode) debugPrint('💾 Saved ${customerData.length} restored customers to local storage');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to save restored customers: $e');
    }
  }
  
  /// Check if restoration is needed (first login after reinstall)
  static Future<bool> isRestorationNeeded() async {
    try {
      // Check if local sales exist
      final localSales = await LocalStorageService.loadSales();
      
      // ✅ FIX: Only check sales - inventory is refreshed separately
      // This ensures sales are restored even if inventory was already synced
      return localSales.isEmpty;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to check restoration status: $e');
      return false;
    }
  }
  
  /// Mark restoration as complete
  static Future<void> markRestorationComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('restoration_complete', true);
      await prefs.setString('restoration_date', DateTime.now().toIso8601String());
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to mark restoration complete: $e');
    }
  }
  
  /// Check if restoration was already completed
  static Future<bool> wasRestorationCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('restoration_complete') ?? false;
    } catch (e) {
      return false;
    }
  }
}
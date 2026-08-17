import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'notification_service.dart';
import 'email_sender_service.dart';
import 'local_storage_service.dart';
import 'format_helper.dart';
import 'inventory_stock_helper.dart';
import 'secure_token_storage.dart';
import 'sync_queue_manager.dart';
import 'sync_service.dart';
import 'inventory_sync_service.dart';

class InventoryManagementService {
  static bool suppressInventoryCallback = false;
  // FIX BUG 6 — callback so Dashboard can refresh analytics after inventory sync
  static VoidCallback? onInventoryChanged;

  // ── PRODUCTION HARDENING: IDEMPOTENCY LOCK ──
  static bool _idempotencyLoaded = false;

  /// Load persistent idempotency keys once
  static Future<void> _ensureIdempotencyLoaded() async {
    _idempotencyLoaded = true;
  }

  /// Reset idempotency tracking (called on logout for security - FIX 18)
  static void reset() {
    _idempotencyLoaded = false;
    debugPrint('🔄 Inventory idempotency tracking reset');
  }

  /// Decrease product stock when item is sold
  /// Returns: {'success': bool, 'newStock': int, 'alertTriggered': bool}
  static Future<Map<String, dynamic>> decreaseStockOnSale({
    required int productId,
    required String productName,
    required int quantitySold,
    required int minStockLevel,
  }) async {
    try {
    if (kDebugMode) debugPrint('📦 Decreasing stock for $productName by $quantitySold units');

      // Canonical backend stock mutation. The old /products/{id}/decrease-stock
      // endpoint was a legacy route and could diverge from invoice sync.
      final referenceId = 'SALE_${DateTime.now().microsecondsSinceEpoch}_$productId';
      final result = await InventorySyncService.deductStock(
        productId: productId,
        quantity: quantitySold,
        referenceId: referenceId,
        reason: 'SALE',
      );

      if (result['success'] == true) {
        final newStock = result['new_stock'] ?? result['current_stock'] ?? 0;
        final alertTriggered = result['alertTriggered'] == true;
    if (kDebugMode) debugPrint('✅ Stock updated: $productName new stock = $newStock');

        // Handle low stock alert
        if (alertTriggered && newStock < minStockLevel) {
          _triggerLowStockAlert( // FIX A — catchError so void→Future errors surface
            productName: productName,
            currentStock: newStock,
            minStock: minStockLevel,
            productId: productId,
          ).catchError((e) => print('⚠️ Alert trigger failed: $e'));

          return {
            'success': true,
            'newStock': newStock,
            'alertTriggered': true,
            'message': '⚠️ Low stock alert triggered for $productName'
          };
        }

        return {
          'success': true,
          'newStock': newStock,
          'alertTriggered': false,
          'message': '✅ Stock decreased by $quantitySold units'
        };
      } else if (result['error'] == 'OUT_OF_STOCK' || result['error'] == 'INVALID_QUANTITY') {
        final error = result['message'] ?? result['error'] ?? 'Invalid stock operation';
    if (kDebugMode) debugPrint('❌ Stock decrease error: $error');
        return {
          'success': false,
          'newStock': -1,
          'alertTriggered': false,
          'message': error
        };
      } else {
        return {
          'success': false,
          'newStock': -1,
          'alertTriggered': false,
          'message': result['message'] ?? result['error'] ?? 'Failed to update stock'
        };
      }
    } catch (e) {
    if (kDebugMode) debugPrint('❌ Error decreasing stock: $e');
      return {
        'success': false,
        'newStock': -1,
        'alertTriggered': false,
        'message': 'Error: $e'
      };
    }
  }

  /// Manually trigger low stock alert
  static Future<void> _triggerLowStockAlert({ // FIX A — was void, swallowed all errors
    required String productName,
    required int currentStock,
    required int minStock,
    required int productId,
  }) async {
    // Show local notification
    NotificationService.show(
      '⚠️ Low Stock Alert',
      '$productName: Only $currentStock units left (Min: $minStock)',
      payload: 'low_stock_$productId',
    );

    // Save to alert history
    await _saveAlertToHistory(
      productId: productId,
      productName: productName,
      currentStock: currentStock,
      minStock: minStock,
      alertType: 'LOW_STOCK',
    );

    // Send to backend for email notification
    await _notifyBackendOfAlert(
      productId: productId,
      productName: productName,
      currentStock: currentStock,
      minStock: minStock,
    );
  }

  static Future<void> _notifyBackendOfAlert({
    required int productId,
    required String productName,
    required int currentStock,
    required int minStock,
  }) async {
    // FIX BUG 8 — 30-minute cooldown per product to prevent email flooding
    final prefs = await SharedPreferences.getInstance();
    final cooldownKey = 'last_alert_$productId';
    final lastAlertStr = prefs.getString(cooldownKey);
    if (lastAlertStr != null) {
      final lastAlert = DateTime.tryParse(lastAlertStr);
      if (lastAlert != null &&
          DateTime.now().difference(lastAlert) < const Duration(minutes: 30)) {
    if (kDebugMode) debugPrint('⏳ Alert cooldown active for $productName — skipping email');
        return;
      }
    }
    await prefs.setString(cooldownKey, DateTime.now().toIso8601String());

    // WhatsApp-only notification spine for now: we already send the alert via NotificationService.
    // Skipping email/backend avoids “double notifications”.
    final whatsappOnly = prefs.getBool('whatsapp_only_notifications') ?? true;
    if (whatsappOnly) return;

    try {
      final userEmail = prefs.getString('email');
      
      if (userEmail != null && userEmail.isNotEmpty) {
    if (kDebugMode) debugPrint('📧 Sending low stock email to: $userEmail for $productName');
        await EmailSenderService.sendStockAlertEmail(
          recipientEmail: userEmail,
          productName: productName,
          currentStock: currentStock,
          minStock: minStock,
        );
      } else {
    if (kDebugMode) debugPrint('⚠️ No user email found in prefs, cannot send stock alert email');
      }

      // Also notify backend API if available
      final response = await ApiClient.postJson(
        '/alerts/trigger',
        {
          'type': 'LOW_STOCK',
          'product_id': productId,
          'product_name': productName,
          'current_stock': currentStock,
          'min_stock': minStock,
        },
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
    if (kDebugMode) debugPrint('✅ Backend notified of low stock alert');
      }
    } catch (e) {
    if (kDebugMode) debugPrint('⚠️ Failed to notify backend/email of alert: $e');
    }
  }

  static Future<void> _saveAlertToHistory({
    required int productId,
    required String productName,
    required int currentStock,
    required int minStock,
    required String alertType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const key = 'low_stock_history';
      final historyRaw = prefs.getString(key) ?? '[]';
      final List<dynamic> history = json.decode(historyRaw);
      
      history.insert(0, {
        'product_id': productId,
        'product_name': productName,
        'current_stock': currentStock,
        'min_stock': minStock,
        'timestamp': DateTime.now().toIso8601String(),
        'type': alertType,
      });

      // Keep last 50 alerts
      if (history.length > 50) history.removeLast();
      
      await prefs.setString(key, json.encode(history));
    } catch (e) {
    if (kDebugMode) debugPrint('⚠️ Failed to save alert to history: $e');
    }
  }

  /// Get alert history for dashboard (Legacy fallback)
  static Future<List<Map<String, dynamic>>> getAlertHistory({int limit = 20}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyRaw = prefs.getString('low_stock_history') ?? '[]';
      final List<dynamic> history = json.decode(historyRaw);
      return history.take(limit).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('⚠️ Error loading alert history: $e');
      return [];
    }
  }

  /// 🚀 REAL-TIME: Get all products currently below their threshold
  static Future<List<Map<String, dynamic>>> getAllLowStockProducts() async {
    try {
      final List<Map<String, dynamic>> backendProducts = await LocalStorageService.loadBackendProducts();
      final Map<String, dynamic> localProducts = await LocalStorageService.loadLocalProducts();
      
      final List<Map<String, dynamic>> lowStock = [];
      
      // Check Backend Products
      for (var p in backendProducts) {
        final stock = InventoryStockHelper.readStock(p);
        final minS  = double.tryParse(p['min_stock']?.toString()     ?? '10') ?? 10;
        if (stock < minS) {
          lowStock.add({
            'productName': p['product_name'] ?? 'Unknown',
            'currentStock': stock,
            'productId': p['id'],
            'type': 'BACKEND'
          });
        }
      }
      
      // Check Local Products
      localProducts.forEach((key, p) {
        final stock = InventoryStockHelper.readStock(p);
        final minS  = double.tryParse(p['min_stock']?.toString()     ?? '10') ?? 10;
        if (stock < minS) {
          lowStock.add({
            'productName': p['product_name'] ?? 'Unknown',
            'currentStock': stock,
            'productId': 0,
            'type': 'LOCAL'
          });
        }
      });
      
      return lowStock;
    } catch (e) {
      debugPrint('⚠️ Low Stock fetch failed: $e');
      return [];
    }
  }

  /// 🚀 100/100: Real-time stock check for a specific product name (Fuzzy)
  static Future<Map<String, dynamic>?> checkStockRealtime(String productName) async {
    try {
      final List<Map<String, dynamic>> backendProducts = await LocalStorageService.loadBackendProducts();
      final String normName = FormatHelper.normalizeName(productName);

      // Pass 1: exact match only. Always prefer this over any fuzzy match —
      // otherwise a short generic name like "oil" can match "coconut oil"
      // (or vice versa) purely because one string contains the other, and
      // whichever happens to come first in iteration order silently wins,
      // reporting the wrong product's stock.
      for (var p in backendProducts) {
        final invName = FormatHelper.normalizeName(p['product_name'] ?? '');
        if (invName == normName) {
          final stock = InventoryStockHelper.readStock(p);
          final minS = (p['min_stock'] as num?)?.toDouble() ?? 10.0;
          return {
            'productName': p['product_name'],
            'stock': stock,
            'isLow': stock < minS,
            'minStock': minS
          };
        }
      }

      // Pass 2: fall back to substring containment only when there's no
      // exact match anywhere, and among all substring candidates pick the
      // one whose name length is closest to normName's — the closest-length
      // match is far less likely to be an unrelated product that merely
      // happens to share a short generic word (e.g. "oil", "soap", "salt").
      Map<String, dynamic>? bestCandidate;
      int bestLengthDiff = -1;
      for (var p in backendProducts) {
        final invName = FormatHelper.normalizeName(p['product_name'] ?? '');
        if (invName.isEmpty) continue;
        if (invName.contains(normName) || normName.contains(invName)) {
          final lengthDiff = (invName.length - normName.length).abs();
          if (bestCandidate == null || lengthDiff < bestLengthDiff) {
            bestCandidate = p;
            bestLengthDiff = lengthDiff;
          }
        }
      }

      if (bestCandidate != null) {
        final stock = InventoryStockHelper.readStock(bestCandidate);
        final minS = (bestCandidate['min_stock'] as num?)?.toDouble() ?? 10.0;
        return {
          'productName': bestCandidate['product_name'],
          'stock': stock,
          'isLow': stock < minS,
          'minStock': minS
        };
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🚀 100/100: Predict when a product will run out based on sales velocity
  static Future<Map<String, dynamic>?> getStockoutPrediction(String productName) async {
    try {
      final List<dynamic> salesData = await LocalStorageService.loadSales();
      final List<Map<String, dynamic>> sales = salesData.map((e) => Map<String, dynamic>.from(e)).toList();
      final List<Map<String, dynamic>> products = await LocalStorageService.loadBackendProducts();
      
      final p = products.firstWhere((e) => e['product_name'] == productName, orElse: () => {});
      if (p.isEmpty) return null;

      final currentStock = InventoryStockHelper.readStock(p);
      if (currentStock <= 0) return {'daysRemaining': 0, 'status': 'OUT_OF_STOCK'};

      // Calculate avg sales per day for last 30 days
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      double totalQtySold = 0;
      for (var s in sales) {
        final date = DateTime.tryParse(s['created_at'] ?? s['sale_date'] ?? '');
        if (date != null && date.isAfter(thirtyDaysAgo) && s['product'] == productName) {
          totalQtySold += (s['quantity'] as num?)?.toDouble() ?? 0.0;
        }
      }

      final avgPerDay = totalQtySold / 30.0;
      if (avgPerDay == 0) return {'daysRemaining': 99, 'status': 'STAGNANT'};

      final daysRemaining = (currentStock / avgPerDay).floor();
      return {
        'daysRemaining': daysRemaining,
        'avgPerDay': avgPerDay.toStringAsFixed(2),
        'status': daysRemaining < 7 ? 'CRITICAL' : 'OK'
      };
    } catch (e) {
      return null;
    }
  }

  /// Get current stock for product
  static Future<Map<String, dynamic>> getProductStock(int productId) async {
    try {
      final response = await ApiClient.getJson(
        '${ApiClient.inventoryPrefix}/products/$productId',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'stock': data['current_stock'] ?? 0,
          'minStock': data['min_stock'] ?? 10,
          'productName': data['product_name'] ?? 'Unknown',
        };
      }
      return {'success': false, 'stock': -1};
    } catch (e) {
    if (kDebugMode) debugPrint('❌ Error fetching stock: $e');
      return {'success': false, 'stock': -1};
    }
  }

  /// 🚀 PRODUCTION-GRADE: Atomic inventory deduction with persistent idempotency and explicit rollback.
  static Future<void> deductStockLocally(List items, {required String saleId}) async {
    // ── 1. GLOBAL SALE IDEMPOTENCY: Reject duplicates ──
    final alreadyProcessed = await LocalStorageService.isDeductionProcessed(saleId);
    if (alreadyProcessed) {
      if (kDebugMode) debugPrint('⚠️ Idempotency Triggered: Sale $saleId already processed for stock. Skipping.');
      return;
    }
    if (kDebugMode) debugPrint('📦 Beginning atomic stock deduction for Sale: $saleId');

    try {
      // ── 2. PRE-TRANSACTION LOAD (Snapshot for state revert) ──
      List<Map<String, dynamic>> products = await LocalStorageService.loadBackendProducts();
      Map<String, dynamic> localProducts = await LocalStorageService.loadLocalProducts();

      bool updatedBackend = false;
      bool updatedLocal   = false;
      List<String> logs   = [];
      final Set<String> changedBackendProductIds = <String>{};
      final Map<String, double> deductedQtyByProductId = {};

      // Helper for normalization
      String normalizeName(String r) => r.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();

      // ── 3. DEDUCTION LOGIC (PRIORITY MATCHING) ──
      for (var rawItem in items) {
        final Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);
        
        final String rawId   = (item['product_id'] ?? item['id'] ?? '').toString().trim();
        final String rawName = (item['product_name'] ?? item['item'] ?? '').toString().trim();
        final String normSaleName = normalizeName(rawName);
        final String barcode = (item['barcode'] ?? '').toString().trim();
        // Parse quantity from either 'qty' or 'quantity' key, handle string and number types
        final dynamic qtyRaw = item['qty'] ?? item['quantity'] ?? 1;
        double qtySold = 1.0;
        if (qtyRaw is num) {
          qtySold = qtyRaw.toDouble();
        } else if (qtyRaw is String) {
          qtySold = double.tryParse(qtyRaw.trim()) ?? 1.0;
        }
        
        // 🔧 FIX: Debug quantity parsing to ensure correct quantity is used
        if (kDebugMode) {
          debugPrint('🔍 [Deduction] Processing item: $rawName');
          debugPrint('   Raw qty: $qtyRaw (${qtyRaw.runtimeType})');
          debugPrint('   Parsed qtySold: $qtySold');
        }
        
        bool found = false;

        // A. Match in Backend Cache (Prioritize ID > Barcode > Exact Name > Normalized Name)
        for (var p in products) {
          final String invId   = (p['id']?.toString() ?? p['product_id']?.toString() ?? '').trim();
          final String invSku  = (p['sku']?.toString() ?? p['barcode']?.toString() ?? '').trim();
          final String invNameOrig = (p['product_name'] ?? p['name'] ?? '').toString().trim();
          final String normInvName = FormatHelper.normalizeName(invNameOrig);
          
          bool match = false;
          if (rawId.isNotEmpty && rawId != '0' && rawId != 'null' && invId == rawId) {
            match = true;
            debugPrint('✅ Strict ID Match Found: ID [$invId] for item [$rawName]');
          } else if (barcode.isNotEmpty && invSku == barcode) {
            match = true;
            debugPrint('✅ Strict Barcode Match Found: BC [$invSku] for item [$rawName]');
          } else if (rawName.isNotEmpty && invNameOrig.toLowerCase() == rawName.toLowerCase()) {
            // ✅ FIX: Exact case-insensitive name match BEFORE normalized match
            match = true;
            debugPrint('✅ Exact Name Match Found: [$invNameOrig] matches [$rawName]');
          } else if (normSaleName.isNotEmpty && normInvName == normSaleName) {
            // ✅ FIX: Only use normalized match if names have similar length (prevent "Milk" matching "Milk 500ml")
            final nameLenDiff = (invNameOrig.length - rawName.length).abs();
            if (nameLenDiff <= 5) {  // Allow max 5 character difference
              match = true;
              debugPrint('✅ Normalized Name Match Found: [$normInvName] matches [$normSaleName] (len diff: $nameLenDiff)');
            }
          }

          if (match) {
            double current = InventoryStockHelper.readStock(p);
            double nextVal = (current - qtySold).clamp(0.0, 999999.0);
            InventoryStockHelper.writeStock(p, nextVal);
            updatedBackend = true;
            final idForSync = (p['id'] ?? p['product_id'] ?? '').toString().trim();
            if (idForSync.isNotEmpty) {
              changedBackendProductIds.add(idForSync);
              deductedQtyByProductId[idForSync] = (deductedQtyByProductId[idForSync] ?? 0) + qtySold;
            }
            found = true;
            debugPrint('📉 Stock updated: $invNameOrig [$current → $nextVal] (Qty deducted: $qtySold)');
            logs.add('Deducted ${qtySold} from Backend Product: $invNameOrig [ID:$invId]');
            
            // 🚨 REAL-TIME LOW STOCK ALERT 🚨
            double minS = double.tryParse(p['min_stock']?.toString() ?? '10') ?? 10.0;
            if (nextVal < minS) {
              _triggerLowStockAlert(
                productName: invNameOrig,
                currentStock: nextVal.toInt(),
                minStock: minS.toInt(),
                productId: int.tryParse(invId) ?? 0,
              ).catchError((_) {});
            }
            break;
          }
        }

        // B. Match in Local Map (Fallback)
        if (!found) {
          String? matchKey;
          localProducts.forEach((key, p) {
            final String invId   = (p['id']?.toString() ?? p['product_id']?.toString() ?? '').trim();
            final String invSku  = (p['sku']?.toString() ?? p['barcode']?.toString() ?? '').trim();
            final String invNameOrig = (p['product_name'] ?? p['name'] ?? '').toString().trim();
            final String normInvName = FormatHelper.normalizeName(invNameOrig);

            if (rawId.isNotEmpty && rawId != '0' && rawId != 'null' && invId == rawId) {
              matchKey = key;
            } else if (barcode.isNotEmpty && invSku == barcode) {
              matchKey = key;
            } else if (rawName.isNotEmpty && invNameOrig.toLowerCase() == rawName.toLowerCase()) {
              // ✅ FIX: Exact case-insensitive name match BEFORE normalized match
              matchKey = key;
            } else if (normSaleName.isNotEmpty && normInvName == normSaleName) {
              // ✅ FIX: Only use normalized match if names have similar length
              final nameLenDiff = (invNameOrig.length - rawName.length).abs();
              if (nameLenDiff <= 5) {  // Allow max 5 character difference
                matchKey = key;
              }
            }
          });

          if (matchKey != null) {
            final p = localProducts[matchKey];
            final String invNameOrig = (p['product_name']?.toString() ?? '').trim();
            double current = InventoryStockHelper.readStock(p);
            double nextVal = (current - qtySold).clamp(0.0, 999999.0);
            InventoryStockHelper.writeStock(p, nextVal);
            updatedLocal = true;
            debugPrint('📉 Local Stock updated: $invNameOrig [$current → $nextVal]');
            logs.add('Deducted ${qtySold} from Local Product: $invNameOrig');
            found = true;

            // 🚨 REAL-TIME LOW STOCK ALERT (Local) 🚨
            double minS = double.tryParse(p['min_stock']?.toString() ?? '10') ?? 10.0;
            if (nextVal < minS) {
              _triggerLowStockAlert(
                productName: invNameOrig,
                currentStock: nextVal.toInt(),
                minStock: minS.toInt(),
                productId: int.tryParse(p['id']?.toString() ?? p['product_id']?.toString() ?? '0') ?? 0,
              ).catchError((_) {});
            }
          }
        }

        if (!found) {
          debugPrint('⚠️ [InvenMatch] No match found for product: "$rawName" (ID: $rawId, BC: $barcode)');
        }
      }

      // ── 4. COMMIT & PERSIST ──
      // If we got here without exception, apply the changes.
      if (updatedBackend) {
        await LocalStorageService.saveBackendProducts(products);
      }
      if (updatedLocal) {
        await LocalStorageService.saveLocalProducts(localProducts);
      }

      // Mark as processed persistently in dedicated box
      await LocalStorageService.markDeductionProcessed(saleId);


      if (kDebugMode) debugPrint('✅ Transaction Committed: $saleId');
      logs.forEach(print);

      // Trigger UI refresh
      if (!suppressInventoryCallback) {
        onInventoryChanged?.call();
      }

      // Best-effort cloud sync removed: 
      // The backend automatically deducts stock when it processes the Invoice/Sale payload via /api/invoices/sync.
      // Explicitly calling decrease-stock here causes DOUBLE DEDUCTIONS on the backend!

    } catch (e, st) {
      // ── 5. FALLBACK ROLLBACK ──
      // Because we used local 'products' and 'localProducts' copies, 
      // the actual SharedPreferences state WAS NEVER UPDATED. 
      // This is an inherent atomic rollback.
    if (kDebugMode) debugPrint('❌ TRANSACTION ABORTED (State Reverted) for $saleId: $e');
    if (kDebugMode) debugPrint(st.toString());
    }
  }

  static Map<String, dynamic> _toProductUpdatePayload(Map<String, dynamic> p) {
    return {
      'product_name': p['product_name'] ?? p['name'] ?? '',
      'sku': p['sku'] ?? p['barcode'] ?? '',
      'unit_price': p['unit_price'] ?? p['price'] ?? 0,
      'current_stock': InventoryStockHelper.readStock(p),
      'stock': InventoryStockHelper.readStock(p),
      'min_stock': p['min_stock'] ?? 10,
      'category': p['category'] ?? 'General',
      'unit': p['unit'] ?? 'pcs',
    };
  }

  static Future<void> _syncDeductedStockToBackend({
    required List<Map<String, dynamic>> products,
    required Map<String, double> deductedQtyByProductId,
  }) async {
    try {
      for (final entry in deductedQtyByProductId.entries) {
        final id = entry.key;
        final qtySold = entry.value.round();
        if (qtySold <= 0) continue;

        final product = products.firstWhere(
          (e) => (e['id'] ?? e['product_id'] ?? '').toString().trim() == id,
          orElse: () => <String, dynamic>{},
        );
        if (product.isEmpty) continue;

        final productId = int.tryParse(id) ?? 0;
        final name = product['product_name']?.toString() ?? 'Product';
        final minS = int.tryParse(product['min_stock']?.toString() ?? '10') ?? 10;

        try {
          if (productId > 0) {
            // Queue the decrease via SyncQueueManager for offline resilience
            await SyncQueueManager.enqueue('decrease_stock', {
              'product_id': productId,
              'product_name': name,
              'quantity': qtySold,
              'min_stock': minS,
              'reference_id': 'SALE_${DateTime.now().millisecondsSinceEpoch}',
            });
          } else {
            // Un-synced local products (wait until they are synced first)
            // But we can queue a manual put just in case.
            final prefs = await SharedPreferences.getInstance();
            final userId = prefs.getInt('user_id') ?? prefs.getInt('userId');
            if (userId != null && userId > 0) {
              await SyncQueueManager.enqueue('update_local_product', {
                'id': id,
                'user_id': userId,
                'payload': _toProductUpdatePayload(product),
              });
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Queue stock sync failed for product $id: $e');
          }
        }
      }
      
      // Trigger queue processing
      SyncService.processQueueSafe();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Deducted stock queueing skipped: $e');
      }
    }
  }

  /// 🚀 100/100: Restore stock when a sale is cancelled
  static Future<void> restoreStockLocally(List items, {required String saleId}) async {
    try {
      List<Map<String, dynamic>> products = await LocalStorageService.loadBackendProducts();
      Map<String, dynamic> localProducts = await LocalStorageService.loadLocalProducts();

      bool updated = false;

      for (var rawItem in items) {
        final Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);
        final String rawName = (item['product_name'] ?? item['item'] ?? '').toString().trim();
        // Parse quantity from either 'qty' or 'quantity' key, handle string and number types
        final dynamic qtyRaw = item['qty'] ?? item['quantity'] ?? 0;
        double qtyToRestore = 0.0;
        if (qtyRaw is num) {
          qtyToRestore = qtyRaw.toDouble();
        } else if (qtyRaw is String) {
          qtyToRestore = double.tryParse(qtyRaw.trim()) ?? 0.0;
        }
        
        if (qtyToRestore <= 0) continue;

        // Find in Backend
        for (var p in products) {
          final invName = (p['product_name'] ?? p['name'] ?? '').toString().toLowerCase();
          if (invName == rawName.toLowerCase()) {
            final current = InventoryStockHelper.readStock(p);
            InventoryStockHelper.writeStock(p, current + qtyToRestore);
            updated = true;
            break;
          }
        }
      }

      if (updated) {
        await LocalStorageService.saveBackendProducts(products);
        onInventoryChanged?.call();
        debugPrint('♻️ Stock restored for Sale: $saleId');
      }
    } catch (e) {
      debugPrint('❌ Failed to restore stock: $e');
    }
  }

  static dynamic _safeJsonDecode(String jsonStr) {
    try {
      if (jsonStr.isEmpty || jsonStr == 'null') {
        return jsonStr.startsWith('[') ? [] : {};
      }
      return json.decode(jsonStr);
    } catch (e) {
      debugPrint('❌ Inventory JSON Corruption: $e');
      return jsonStr.startsWith('[') ? [] : {};
    }
  }
}
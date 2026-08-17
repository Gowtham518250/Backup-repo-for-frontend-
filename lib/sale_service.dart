import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_client.dart';
import 'stock_alert_service.dart';
import 'inventory_management_service.dart';
import 'secure_token_storage.dart';
import 'financial_math.dart';
import 'sync_queue_manager.dart';
import 'local_storage_service.dart';
import 'retail_growth_kit.dart';
import 'sync_service.dart';
import 'agent_debug_log.dart';
import 'crash_recovery_service.dart';

/// PRODUCTION-READY SALE SERVICE: Integrated Idempotency, Encryption, and Error Handling
class SaleService {
  static final Set<String> _pendingSales = {};

  /// FIX: the three call sites below used to each inline
  /// `paidAmount >= grandTotal - 0.5 ? 'PAID' : ...` — a flat 50-paise
  /// tolerance. That's wide enough that a customer who genuinely still owes
  /// up to 49 paise would be marked PAID. 0.01 (1 paisa) is enough to absorb
  /// real floating-point rounding noise without masking a real balance due.
  static String paymentStatusFor(double paidAmount, double grandTotal) {
    // Compare money at paise precision so floating-point noise cannot
    // incorrectly turn a genuinely unpaid balance into PAID.
    final paidPaise = (paidAmount * 100).round();
    final totalPaise = (grandTotal * 100).round();

    if (paidPaise >= totalPaise) return 'PAID';
    if (paidPaise > 0) return 'PARTIAL';
    return 'UNPAID';
}

  /// Returns true only when the device currently has a network transport.
  /// This is NOT a server-success check; the caller still requires a 2xx ACK.
  static Future<bool> _hasNetworkTransport() async {
    try {
      final dynamic connection = await Connectivity().checkConnectivity();
      if (connection is List) {
        if (connection.isEmpty) return false;
        return connection.any((item) => item != ConnectivityResult.none);
      }
      return connection != ConnectivityResult.none;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _postInvoiceWithRetry(
    Map<String, dynamic> invoicePayload,
  ) async {
    final token = await SecureTokenStorage.getToken() ?? '';
    if (token.isEmpty) return false;

    const maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await ApiClient.postJson(
          ApiClient.invoicesSync,
          invoicePayload,
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 12));

        AgentDebugLog.log(
          location: 'sale_service.dart:_postInvoiceWithRetry',
          message: 'INVOICE SYNC ATTEMPT',
          hypothesisId: 'H2_RETRY',
          data: {
            'attempt': attempt,
            'statusCode': response.statusCode,
            'invoiceNumber': invoicePayload['invoice_number'],
          },
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return true;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Invoice sync attempt $attempt/$maxAttempts failed: $e');
        }
      }

      if (attempt < maxAttempts) {
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }
    return false;
  }

  static Future<Map<String, dynamic>> submitSale({
    required String saleId,
    required List<Map<String, dynamic>> items,
    required double grandTotal,
    required double paidAmount,
    required String customerName,
    required String customerPhone,
    required bool withTax,
    required Map<String, dynamic> totals,
    String paymentMethod = 'Cash',
    bool isBorrow = false,
  }) async {
    const String context = 'SALE_SUBMIT';

    if (_pendingSales.contains(saleId)) {
      if (kDebugMode) debugPrint('🚨 Sale $saleId is already being processed - skipping duplicate');
      return {
        'success': false,
        'error': 'DUPLICATE_REQUEST',
        'message': 'This sale is already being processed'
      };
    }

    InventoryManagementService.suppressInventoryCallback = true;

    final isSynced = await _isSaleSynced(saleId);
    if (isSynced) {
      if (kDebugMode) debugPrint('⚠️ Sale $saleId already synced to backend - skipping');
      InventoryManagementService.suppressInventoryCallback = false;
      return {
        'success': true,
        'syncCount': 0,
        'saleId': saleId,
        'status': 'ALREADY_SYNCED',
        'message': 'Sale already synced to backend'
      };
    }

    final stockValidation = await _validateStockAvailabilityLocally(items);
    if (!stockValidation['valid']) {
  InventoryManagementService.suppressInventoryCallback = false;
  return {
    'success': false,
    'error': 'INSUFFICIENT_STOCK',
    'message': stockValidation['message'],
    'insufficient_items': stockValidation['insufficient_items'],
  };
}

_pendingSales.add(saleId);

AgentDebugLog.log(
  location: 'sale_service.dart:submitSale:entry',
  message: 'SALE CREATION START',
  hypothesisId: 'H1',
  data: {
    'saleId': saleId,
    'grandTotal': grandTotal,
    'paymentMethod': paymentMethod,
    'itemCount': items.length,
    'isBorrow': isBorrow,
  },
);

try {
  if (kDebugMode) {
    debugPrint('🚀 Processing ${isBorrow ? 'Invoice/Borrow' : 'Sale'} Transaction (Offline-First): $saleId');
  }

  // Stable offline_id = saleId so retries remain idempotent.
  final String offlineId = saleId;

  final localProducts = await LocalStorageService.loadLocalProducts();

  final lineItems = items.map((item) {
    final productIdRaw = item['product_id'] ?? item['id'] ?? '0';
    final parsedId = int.tryParse(productIdRaw.toString()) ?? 0;

    int validId = parsedId > 0 ? parsedId : 0;
    if (validId == 0) {
      final String itemName = item['product_name'] ?? item['itemName'] ?? item['name'] ?? '';
      final String barcode = item['barcode'] ?? '';
      final productsList = localProducts is List ? localProducts as List : localProducts.values.toList();

      for (var p in productsList) {
        final pId = (p['id'] ?? p['product_id'] ?? '').toString();
        final pSku = (p['sku'] ?? p['barcode'] ?? '').toString();
        final pName = (p['product_name'] ?? p['name'] ?? '').toString().toLowerCase();

        if (pId.isNotEmpty && int.tryParse(pId) != null) {
          final int parsedPId = int.parse(pId);
          if (barcode.isNotEmpty && pSku == barcode) {
            validId = parsedPId;
            break;
          } else if (pName == itemName.toLowerCase()) {
            validId = parsedPId;
            break;
          }
        }
      }
    }

    final nameRaw = item['product_name'] ?? item['itemName'] ?? item['name'] ?? item['title'] ?? item['product'];
    String validName = nameRaw?.toString().trim() ?? '';
    if (validName.isEmpty || validName.toLowerCase() == 'unknown' || validName.toLowerCase() == 'unknown item') {
      if (kDebugMode) debugPrint('⚠️ Warning: Empty product name detected, falling back to Custom Item');
      validName = 'Custom Item';
    }

    final qtyRaw = item['qty'] ?? item['quantity'] ?? 1;
    // Preserve fractional quantities (kg/litre); never truncate with toInt().
    final qtyDouble = (qtyRaw is num)
        ? qtyRaw.toDouble()
        : double.tryParse(qtyRaw.toString()) ?? 1.0;
    final qtyWire = double.parse(qtyDouble.toStringAsFixed(3));

    final priceRaw = item['price'] ?? item['unit_price'] ?? 0;
    final price = (priceRaw is num) ? priceRaw.toDouble() : double.tryParse(priceRaw.toString()) ?? 0.0;
    final lineTotalFromItem = item['line_total'] ?? item['total_with_tax'];
    final lineTotal = (lineTotalFromItem is num)
        ? lineTotalFromItem.toDouble()
        : (double.tryParse(lineTotalFromItem?.toString() ?? '') ??
            CurrencyManager.multiply(price, qtyWire));

    return {
      'product_id': validId > 0 ? validId : null,
      'product_name': validName,
      'quantity': qtyWire,
      'qty': qtyWire,
      'unit_price': price,
      'line_total': lineTotal,
      if (item['discount'] != null) 'discount': item['discount'],
      if (item['original_price'] != null) 'original_price': item['original_price'],
    };
  }).toList();

  final invalidItem = lineItems.firstWhere(
    (line) => (line['unit_price'] ?? 0) <= 0 || (line['quantity'] ?? line['qty'] ?? 0) <= 0,
    orElse: () => {},
  );
  if (invalidItem.isNotEmpty) {
    // 🔧 FIX: saleId was added to _pendingSales above, before this
    // validation ran. Returning here without removing it left the id in
    // the set forever — a leak on every rejected sale, and since
    // _pendingSales gating is checked by saleId at the top of this
    // function, it also meant a corrected retry with a *different* new
    // saleId would work, but anything that ever reused this exact id
    // would incorrectly report itself as already-processing forever.
    _pendingSales.remove(saleId);
    InventoryManagementService.suppressInventoryCallback = false;
    return {
      'success': false,
      'error': 'INVALID_SALE_ITEM',
      'message': 'Sale contains an invalid item with zero or negative price/quantity.',
    };
  }

  try {
    await CrashRecoveryService.instance.registerIncompleteTransaction('sale', {
      'sale_id': saleId,
      'customer_name': customerName.isNotEmpty ? customerName : 'Guest Customer',
      'customer_phone': customerPhone,
      'items': lineItems,
      'total': grandTotal.toString(),
      'total_amount': grandTotal,
      'paid_amount': paidAmount.toString(),
      'gst_applied': withTax,
      'payment_method': paymentMethod,
      'sync_status': 'pending',
      'pending_sync': true,
    });
  } catch (e) {
    if (kDebugMode) debugPrint('⚠️ Failed to register incomplete-transaction safety net: $e');
  }

  bool backendSuccess = false;

  // OFFLINE-FIRST: persist the sale and enqueue it BEFORE attempting any network call.
  // Capture the exact transaction timestamp once. The same value is used by
  // local history and the backend so a later sync cannot rewrite the sale time.
  final DateTime saleTimestamp = DateTime.now().toUtc();
  final String saleTimestampIso = saleTimestamp.toIso8601String();

  final invoicePayload = {
    'invoice_number': saleId,
    'offline_id': offlineId,
    'customer_name': customerName.isNotEmpty ? customerName : 'Cash Customer',
    'customer_phone': customerPhone.isNotEmpty ? customerPhone : null,
    'total_amount': grandTotal,
    'paid_amount': paidAmount,
    'tax': withTax ? (totals['tax'] ?? 0.0) : 0.0,
    'payment_status': paymentStatusFor(paidAmount, grandTotal),
    'invoice_date': saleTimestampIso.split('T')[0],
    'sale_timestamp': saleTimestampIso,
    'created_at': saleTimestampIso,
    'notes': isBorrow ? 'Payment via $paymentMethod - Borrow Invoice' : 'Payment via $paymentMethod - Regular Sale',
    'line_items': lineItems,
  };

  final prefs = await SharedPreferences.getInstance();
  await _persistToLocalHistory(
    prefs: prefs,
    saleId: saleId,
    customerName: customerName,
    customerPhone: customerPhone,
    items: lineItems,
    grandTotal: grandTotal,
    paidAmount: paidAmount,
    withTax: withTax,
    totals: totals,
    paymentMethod: paymentMethod,
    syncStatus: 'pending',
  );

  await SyncQueueManager.enqueue('save_sale', {
    'is_borrow': isBorrow,
    'endpoint': ApiClient.invoicesSync,
    'payload': invoicePayload,
    'invoice_payload': invoicePayload,
    'sale_id': saleId,
    'retry_priority': 'high',
  });

  // Local inventory is updated once. Backend inventory is updated only by /invoices/sync.
  await InventoryManagementService.deductStockLocally(items, saleId: saleId);
  SyncService.triggerDashboardRefresh();

  final networkAvailableAtCheckout = await _hasNetworkTransport();
  

  if (networkAvailableAtCheckout) {
    backendSuccess = await _postInvoiceWithRetry(invoicePayload);
    if (backendSuccess) {
      await _markSaleAsSynced(saleId);
    }
  } else {
    if (kDebugMode) {
      debugPrint('🌐 Device is offline; sale remains durable + queued.');
    }
  }

  _pendingSales.remove(saleId);
  InventoryManagementService.suppressInventoryCallback = false;

  // Kick the durable queue after the foreground attempt. The queue is the source of truth.
  unawaited(SyncService.processQueueSafe());

  if (backendSuccess) {
    await _persistToLocalHistory(
      prefs: prefs,
      saleId: saleId,
      customerName: customerName,
      customerPhone: customerPhone,
      items: lineItems,
      grandTotal: grandTotal,
      paidAmount: paidAmount,
      withTax: withTax,
      totals: totals,
      paymentMethod: paymentMethod,
      syncStatus: 'synced',
    );
    await RetailGrowthKit.recordBillCompleted();
    SyncService.triggerDashboardRefresh();
    unawaited(SyncService.downloadUserDataSafe());
  } else {
    await RetailGrowthKit.recordBillCompleted();
  }

  final bool cloudConfirmed = backendSuccess;

  AgentDebugLog.log(
    location: 'sale_service.dart:submitSale:final_result',
    message: 'FINAL RESULT',
    hypothesisId: 'H5',
    data: {
      'saleUploadedToBackend': backendSuccess,
      'backendSuccess': backendSuccess,
      'success': cloudConfirmed || !networkAvailableAtCheckout,
      'saleId': saleId,
      'syncStatus': backendSuccess ? 'synced' : 'pending',
      'cloudConfirmed': cloudConfirmed,
      'networkAvailableAtCheckout': networkAvailableAtCheckout,
    },
  );

  if (networkAvailableAtCheckout && !backendSuccess) {
    // IMPORTANT: internet presence is not server acknowledgement.
    // Keep the sale in the durable outbox, but do not tell checkout that the
    // cloud committed it. The UI keeps the transaction visible so the owner
    // does not accidentally create a second sale.
    return {
      'success': false,
      'error': 'SYNC_NOT_CONFIRMED',
      'message': 'Sale saved on this device, but the server did not confirm it yet. Do not create another bill; automatic sync will retry.',
      'saleId': saleId,
      'syncStatus': 'pending',
      'cloudConfirmed': false,
      'localSaved': true,
      'retryQueued': true,
      'syncCount': 0,
    };
  }

  return {
    'success': true,
    'syncCount': backendSuccess ? items.length : 0,
    'saleId': saleId,
    'syncStatus': backendSuccess ? 'synced' : 'pending',
    'cloudConfirmed': cloudConfirmed,
    'localSaved': true,
    'retryQueued': !backendSuccess,
  };

} catch (e, st) {
  _pendingSales.remove(saleId);
  InventoryManagementService.suppressInventoryCallback = false;
  if (kDebugMode) debugPrint('❌ TRANSACTION CRITICAL FAILURE [$context]: $e');
  if (kDebugMode) debugPrint(st.toString());
  AgentDebugLog.log(
    location: 'sale_service.dart:submitSale:critical_failure',
    message: 'CRITICAL FAILURE',
    hypothesisId: 'H5',
    data: {'error': e.toString(), 'saleId': saleId},
  );
  return {
    'success': false,
    'error': e.toString(),
    'recovery_action': 'RETRY_SYNC',
  };
} finally {
  _pendingSales.remove(saleId);
  try {
    await CrashRecoveryService.instance.clearSpecificTransaction('sale', {'sale_id': saleId});
  } catch (e) {
    if (kDebugMode) debugPrint('⚠️ Failed to clear incomplete-transaction safety net: $e');
  }
  InventoryManagementService.suppressInventoryCallback = false;
  InventoryManagementService.onInventoryChanged?.call();
}

}

  static Future<bool> _markSaleAsSynced(String saleId) async {
    if (saleId.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncedSales = prefs.getStringList('synced_sales') ?? <String>[];
      if (!syncedSales.contains(saleId)) {
        syncedSales.add(saleId);
        if (syncedSales.length > 1000) {
          syncedSales.removeRange(0, syncedSales.length - 1000);
        }
        final saved = await prefs.setStringList('synced_sales', syncedSales);
        if (!saved) return false;
      }

      final sales = await LocalStorageService.loadSales();
      bool updated = false;
      for (int i = 0; i < sales.length; i++) {
        final raw = sales[i];
        if (raw is! Map) continue;
        final currentId = (raw['sale_id'] ?? raw['invoice_number'] ?? raw['id'] ?? '').toString();
        if (currentId != saleId) continue;
        sales[i] = {
          ...Map<String, dynamic>.from(raw),
          'sync_status': 'synced',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'last_sync_attempt': DateTime.now().toUtc().toIso8601String(),
          'is_synced': true,
        };
        updated = true;
        break;
      }

      if (updated) {
        await LocalStorageService.saveSales(sales);
      }

      // The idempotency marker is the durable acknowledgement even if the
      // local sales cache does not currently contain the sale.
      return (await _isSaleSynced(saleId));
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to mark sale as synced: $e');
      return false;
    }
  }

  static Future<bool> _isSaleSynced(String saleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncedSales = prefs.getStringList('synced_sales') ?? [];
      return syncedSales.contains(saleId);
    } catch (e) {
      return false;
    }
  }

  static Future<bool> markSaleAsSynced(String saleId) async {
    if (saleId.trim().isEmpty) return false;
    return _markSaleAsSynced(saleId.trim());
  }

  static void triggerBackgroundAlert(Map<String, dynamic> item) {
    try {
      StockAlertService.checkAndAlertLowStock(
        productName: item['product_name']?.toString() ?? 'Unknown',
        quantitySold: (item['qty'] is num
            ? (item['qty'] as num).toDouble()
            : double.tryParse(item['qty']?.toString() ?? '1') ?? 1.0).round(),
        productId: int.tryParse((item['product_id'] ?? item['id'] ?? '0').toString()) ?? 0,
      );
    } catch (_) {}
  }

  /// Local-only stock check. Missing stock fields default to 0 (not 9999).
  static Future<Map<String, dynamic>> _validateStockAvailabilityLocally(List<Map<String, dynamic>> items) async {
    try {
      final localProducts = await LocalStorageService.loadLocalProducts();
      final productsList = localProducts is List ? localProducts as List : localProducts.values.toList();
      final insufficientItems = <Map<String, dynamic>>[];
      final bool catalogLoaded = productsList.isNotEmpty;

      for (var item in items) {
        final productId = int.tryParse((item['product_id'] ?? item['id'] ?? '0').toString()) ?? 0;
        final qty = (item['qty'] is num
            ? (item['qty'] as num).toDouble()
            : double.tryParse(item['qty']?.toString() ?? '1') ?? 1.0);
        final itemName = (item['product_name'] ?? item['itemName'] ?? item['name'] ?? '').toString().toLowerCase();

        if (productId > 0 || itemName.isNotEmpty) {
          Map<String, dynamic>? found;
          for (var p in productsList) {
            final pIdRaw = (p['id'] ?? p['product_id'] ?? '').toString();
            final pId = int.tryParse(pIdRaw) ?? 0;
            final pName = (p['product_name'] ?? p['name'] ?? '').toString().toLowerCase();

            if ((productId > 0 && pId == productId) || (itemName.isNotEmpty && pName == itemName)) {
              found = Map<String, dynamic>.from(p as Map);
              break;
            }
          }

          if (found != null) {
            final stockRaw = found['current_stock'] ?? found['stock'] ?? found['quantity'];
            final currentStock = stockRaw == null
                ? 0.0
                : ((stockRaw is num) ? stockRaw.toDouble() : double.tryParse(stockRaw.toString()) ?? 0.0);
            if (qty > currentStock) {
              insufficientItems.add({
                'product_id': productId,
                'product_name': found['product_name'] ?? found['name'] ?? itemName,
                'requested_qty': qty,
                'available_stock': currentStock,
              });
            }
          } else {
            // Unknown/local-unsynced products cannot be safely rejected solely
            // because the local catalog is stale or unavailable. Backend
            // invoice validation remains authoritative when connectivity exists.
            // Only reject when the product was actually found and confirmed
            // to have insufficient stock locally.
          }
        }
      }

      if (insufficientItems.isEmpty) {
        return {'valid': true, 'message': 'Stock check passed'};
      }
      final productNames = insufficientItems.map((i) => i['product_name']).join(', ');
      return {
        'valid': false,
        'message': 'Insufficient stock for: $productNames',
        'insufficient_items': insufficientItems,
      };
    } catch (e) {
      // Local stock is an optimization/safety check, not the authority for
      // whether a bill may be created. Fresh installs, data clears and a
      // closed Hive box must never brick billing. The backend invoice-sync
      // endpoint remains authoritative when available.
      if (kDebugMode) debugPrint('⚠️ Local stock validation unavailable; allowing sale to proceed: $e');
      return {
        'valid': true,
        'message': 'Stock check skipped (catalog unavailable)',
        'stock_check_skipped': true,
      };
    }
  }

  static void clearInFlight() => _pendingSales.clear();

  static Future<void> _persistToLocalHistory({
    required SharedPreferences prefs,
    required String saleId,
    required String customerName,
    required String customerPhone,
    required List<Map<String, dynamic>> items,
    required double grandTotal,
    required double paidAmount,
    required bool withTax,
    required Map<String, dynamic> totals,
    String paymentMethod = 'Cash',
    String syncStatus = 'synced',
  }) async {
    List<dynamic> history = await LocalStorageService.loadSales();

    int existingIndex = history.indexWhere((s) {
      if (s is! Map) return false;
      final id = (s['sale_id'] ?? s['invoice_number'] ?? s['id'] ?? '').toString();
      return id == saleId;
    });

    final String safePhone = customerPhone.isNotEmpty
        ? customerPhone
        : 'GUEST_${saleId.length >= 6 ? saleId.substring(saleId.length - 6) : saleId.padLeft(6, '0')}';

    final existingSale = existingIndex >= 0
      ? Map<String, dynamic>.from(history[existingIndex] as Map)
      : null;
    final String saleTimestamp = DateTime.now().toUtc().toIso8601String();
    final String businessDate = (existingSale?['business_date'] ??
        existingSale?['sale_date'] ??
        existingSale?['invoice_date'] ??
        existingSale?['date'] ??
        saleTimestamp)
      .toString();

    final List<Map<String, dynamic>> normalizedItems = items.map((item) {
      final double price = (item['unit_price'] ?? item['price'] ?? 0.0) is num
          ? (item['unit_price'] ?? item['price'] ?? 0.0).toDouble()
          : double.tryParse((item['unit_price'] ?? item['price'] ?? '0').toString()) ?? 0.0;
      final double qty = (item['quantity'] ?? item['qty'] ?? 1) is num
          ? (item['quantity'] ?? item['qty'] ?? 1).toDouble()
          : double.tryParse((item['quantity'] ?? item['qty'] ?? '1').toString()) ?? 1.0;
      final double lineTotal = (item['line_total'] ?? item['total']) is num
          ? (item['line_total'] ?? item['total']).toDouble()
          : CurrencyManager.multiply(price, qty);

      return {
        ...item,
        'price': price,
        'price_str': price.toString(),
        'unit_price': price,
        'qty': qty,
        'quantity': qty,
        'qty_str': qty.toString(),
        'total': lineTotal,
        'line_total': lineTotal,
        'total_with_tax': lineTotal,
        'product': item['product_name'] ?? item['product'] ?? item['item'] ?? '',
        'name': item['product_name'] ?? item['product'] ?? item['item'] ?? '',
        'item': item['product_name'] ?? item['product'] ?? item['item'] ?? '',
      };
    }).toList();

    final userId = prefs.getInt('user_id') ?? prefs.getInt('userId');

    final Map<String, dynamic> saleRecord = {
      'sale_id': saleId,
      'offline_id': saleId,
      'invoice_number': saleId,
      'created_at': existingSale?['created_at'] ?? saleTimestamp,
      'sale_timestamp': existingSale?['sale_timestamp'] ?? (existingSale?['created_at'] ?? saleTimestamp),
      'updated_at': saleTimestamp,
      'user_id': userId,
      'sync_status': syncStatus,
      'pending_sync': syncStatus != 'synced',
      'sync_attempts': 0,
      'last_sync_attempt': null,
      'backend_id': existingSale?['backend_id'],
      'is_deleted': false,
      'customer_name': customerName.isNotEmpty ? customerName : 'Guest Customer',
      'customer_phone': customerPhone,
      'guest_id': safePhone,
      'items': normalizedItems,
      'business_date': businessDate,
      'subtotal': totals['subtotal'].toString(),
      'total': grandTotal.toString(),
      'total_amount': grandTotal,
      'paid_amount': paidAmount.toString(),
      'payment_status': paymentStatusFor(paidAmount, grandTotal),
      'gst_applied': withTax,
      'payment_method': paymentMethod,
    };

    if (existingIndex >= 0) {
      history[existingIndex] = {
        ...existingSale!,
        ...saleRecord,
        'updated_at': saleTimestamp,
      };
    } else {
      history.add(saleRecord);
    }

    if (history.length > 5000) {
      history = history.sublist(history.length - 5000);
    }
    await LocalStorageService.saveSales(history);
    if (kDebugMode) debugPrint('📝 Created local sale with sync metadata: $saleId');
  }
}
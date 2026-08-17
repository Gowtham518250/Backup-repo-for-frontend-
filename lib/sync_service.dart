import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:synchronized/synchronized.dart';
import 'api_client.dart';
import 'models.dart';
import 'local_storage_service.dart';
import 'secure_token_storage.dart';
import 'sync_queue_manager.dart';
import 'sale_service.dart';
import 'error_log_helper.dart';
import 'sales_dedup_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'agent_debug_log.dart';
import 'attendance_offline_service.dart';

class SyncService {
  static DateTime? _lastServerTime;
  static Duration? _serverTimeOffset;  // Duration, not DateTime!
  
  static final _syncStatusController = StreamController<int>.broadcast();
  static Stream<int> get syncQueueStream => _syncStatusController.stream;
  static const int _maxQueueRetries = 8;
  
  // 🔒 Use Lock for atomic operations (prevents race conditions)
  static final _syncLock = Lock();
  
  static final _refreshNotifier = StreamController<void>.broadcast();
  static Stream<void> get refreshStream => _refreshNotifier.stream;
  /// Public method: call after saving to Hive to force Dashboard to reload.
  static void triggerDashboardRefresh() {
    try { _refreshNotifier.add(null); } catch (_) {}
  }
  static Timer? _pulseTimer;
  static bool _initialized = false;
  static StreamSubscription<ConnectivityResult>? _connectivitySub;

  /// Initialize and start periodic sync workers
  static Future<void> init() async {
    if (_initialized) {
      if (kDebugMode) debugPrint('⚠️ SyncService already initialized, skipping...');
      return;
    }
    _initialized = true;
    
    try {
      // Listen for connectivity changes
      _connectivitySub?.cancel();
      _connectivitySub = Connectivity().onConnectivityChanged.listen((dynamic result) {
        final bool isOffline = result is List 
            ? (result.isEmpty || (result.length == 1 && result.first == ConnectivityResult.none))
            : result == ConnectivityResult.none;
            
        if (!isOffline) {
          processQueueSafe();
          downloadUserDataSafe();
        }
      });

      // 🚀 Start LivePulseTimer (Runs every 60 seconds)
      _startPulseTimer();
      
      // Initial sync
      await processQueueSafe();
      await downloadUserDataSafe();
      
      if (kDebugMode) debugPrint('✅ SyncService initialized successfully');
    } catch (e) {
      await ErrorLogHelper.logException(e, StackTrace.current, context: 'SyncService.init');
    }
  }
  
  /// Start or restart the pulse timer
  static void _startPulseTimer() {
    _pulseTimer?.cancel();
    // 🚨 DATA-LOSS-PREVENTION FIX: shortened 60s -> 20s AND now also drives the
    // pending sync queue (sales, purchase orders, stock updates, etc). Previously
    // this timer only re-downloaded data; the queue itself only re-ran on a
    // connectivity-change EVENT, which frequently never fires on flaky mobile/5G
    // networks (tower handoffs, weak-signal "still connected" states). That gap is
    // exactly why a sale could sit unsynced for a long time despite having signal.
    _pulseTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      if (!_initialized) return;

      try {
        final connection = await Connectivity().checkConnectivity();
        if (connection != ConnectivityResult.none) {
          // Always try to flush the pending queue first — this is the data that
          // must not be lost (sales, purchase orders, stock decrements, etc).
          await processQueueSafe();
          await downloadUserDataSafe();
          _refreshNotifier.add(null); // Notify UI to rebuild
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Pulse timer error: $e');
        await ErrorLogHelper.logException(e, StackTrace.current, context: 'SyncService.pulseTimer');
      }
    });
  }
  
  /// Dispose all resources
  static Future<void> dispose() async {
    if (kDebugMode) debugPrint('🛑 Disposing SyncService...');
    _pulseTimer?.cancel();
    _pulseTimer = null;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _initialized = false;
    
    try {
      await _syncStatusController.close();
      await _refreshNotifier.close();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error closing streams: $e');
    }
  }
  
  static Future<bool> checkInWorker(String workerId) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        await ErrorLogHelper.logMessage('Token unavailable for checkIn', level: 'WARNING');
        return false;
      }

      final res = await ApiClient.postJson(
        '${ApiClient.checkIn}?employee_id=$workerId',
        {},
        headers: {'Authorization': 'Bearer $token'}
      );
      
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (kDebugMode) debugPrint('✅ Worker checked in: $workerId');
        return true;
      } else {
        await ErrorLogHelper.logMessage(
          'Worker check-in failed: ${res.statusCode}',
          level: 'ERROR',
          attributes: {'workerId': workerId, 'status': res.statusCode.toString()},
        );
        return false;
      }
    } catch (e) {
      await ErrorLogHelper.logException(e, StackTrace.current, 
        context: 'SyncService.checkInWorker',
        attributes: {'workerId': workerId});
      return false;
    }
  }

  /// Syncs an individual check-out event to the backend
  static Future<bool> checkOutWorker(String workerId) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        await ErrorLogHelper.logMessage('Token unavailable for checkOut', level: 'WARNING');
        return false;
      }

      final res = await ApiClient.postJson(
        '${ApiClient.checkOut}?employee_id=$workerId',
        {},
        headers: {'Authorization': 'Bearer $token'}
      );
      
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (kDebugMode) debugPrint('✅ Worker checked out: $workerId');
        return true;
      } else {
        await ErrorLogHelper.logMessage(
          'Worker check-out failed: ${res.statusCode}',
          level: 'ERROR',
          attributes: {'workerId': workerId, 'status': res.statusCode.toString()},
        );
        return false;
      }
    } catch (e) {
      await ErrorLogHelper.logException(e, StackTrace.current,
        context: 'SyncService.checkOutWorker',
        attributes: {'workerId': workerId});
      return false;
    }
  }
  
  /// Syncs a queued attendance check-in event to the backend.
  ///
  /// Queue payloads have appeared in different builds with either
  /// `employee_id` or `worker_id`. Normalize both here and reuse the same
  /// authenticated endpoint used by the live check-in flow so offline
  /// check-ins are persisted to the backend when connectivity returns.
  static Future<bool> _syncAttendanceCheckInItem(
    Map<String, dynamic> data,
  ) async {
    try {
      final rawEmployeeId =
          data['employee_id'] ??
          data['worker_id'] ??
          data['workerId'] ??
          data['id'];

      final employeeId = rawEmployeeId?.toString().trim() ?? '';
      if (employeeId.isEmpty) {
        await ErrorLogHelper.logMessage(
          'Queued attendance check-in missing employee_id/worker_id',
          level: 'ERROR',
          attributes: {'data': jsonEncode(data)},
        );
        return false;
      }

      return await checkInWorker(employeeId);
    } catch (e, stackTrace) {
      await ErrorLogHelper.logException(
        e,
        stackTrace,
        context: 'SyncService._syncAttendanceCheckInItem',
        attributes: {'data': jsonEncode(data)},
      );
      return false;
    }
  }

  /// Syncs a queued attendance check-out event to the backend.
  ///
  /// Uses the exact same authenticated endpoint as the live check-out flow,
  /// ensuring queued offline events are not silently dropped.
  static Future<bool> _syncAttendanceCheckOutItem(
    Map<String, dynamic> data,
  ) async {
    try {
      final rawEmployeeId =
          data['employee_id'] ??
          data['worker_id'] ??
          data['workerId'] ??
          data['id'];

      final employeeId = rawEmployeeId?.toString().trim() ?? '';
      if (employeeId.isEmpty) {
        await ErrorLogHelper.logMessage(
          'Queued attendance check-out missing employee_id/worker_id',
          level: 'ERROR',
          attributes: {'data': jsonEncode(data)},
        );
        return false;
      }

      return await checkOutWorker(employeeId);
    } catch (e, stackTrace) {
      await ErrorLogHelper.logException(
        e,
        stackTrace,
        context: 'SyncService._syncAttendanceCheckOutItem',
        attributes: {'data': jsonEncode(data)},
      );
      return false;
    }
  }

  /// Syncs worker profile data to the backend
  static Future<bool> syncWorkerProfile(Map<String, dynamic> workerData) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs?.getInt('user_id') ?? prefs?.getInt('userId');
      
      if (token.isEmpty || userId == null) {
        await ErrorLogHelper.logMessage('Missing token or userId for worker sync', level: 'WARNING');
        return false;
      }

      final res = await ApiClient.postJson(
        '${ApiClient.attendancePrefix}/workers?user_id=$userId',
        workerData,
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (kDebugMode) debugPrint('✅ Worker profile synced: ${workerData['id'] ?? 'unknown'}');
        return true;
      } else {
        await ErrorLogHelper.logMessage(
          'Worker profile sync failed: ${res.statusCode}',
          level: 'ERROR',
          attributes: {'worker': workerData['id']?.toString() ?? 'unknown'},
        );
        return false;
      }
    } catch (e) {
      await ErrorLogHelper.logException(e, StackTrace.current,
        context: 'SyncService.syncWorkerProfile');
      return false;
    }
  }

  /// Downloads user data (workers, shop details) from backend - Thread-safe
  static Future<void> downloadUserDataSafe() async {
    await _syncLock.synchronized(() async {
      try {
        await _downloadUserDataImpl();
      } catch (e) {
        await ErrorLogHelper.logException(e, StackTrace.current, context: 'SyncService.downloadUserData');
      }
    });
  }

  /// Internal implementation - calls Synchronized
  static Future<void> _downloadUserDataImpl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs == null) {
        await ErrorLogHelper.logMessage('SharedPreferences unavailable', level: 'WARNING');
        return;
      }
      
      final userId = prefs.getInt('user_id') ?? prefs.getInt('userId');
      if (userId == null) {
        if (kDebugMode) debugPrint('⚠️ No userId found, skipping download');
        return;
      }

      // 1. Fetch Workers
      try {
        final token = await SecureTokenStorage.getToken() ?? '';
        if (token.isEmpty) {
          await ErrorLogHelper.logMessage('Token unavailable for worker fetch', level: 'WARNING');
        } else {
        final res = await ApiClient.getJson('${ApiClient.attendancePrefix}/workers?user_id=$userId', headers: {
          'Authorization': 'Bearer $token',
        });
        
        if (res.statusCode == 200) {
          final List<dynamic> workers = jsonDecode(res.body);
          await prefs.setString('workers_json', jsonEncode(workers));
          if (kDebugMode) debugPrint('✅ Workers downloaded: ${workers.length} records');
        } else {
          await ErrorLogHelper.logMessage(
            'Worker fetch failed: ${res.statusCode}',
            level: 'WARNING',
          );
        }
        }
      } catch (e) {
        await ErrorLogHelper.logException(e, StackTrace.current, context: 'SyncService.downloadWorkers');
      }

      // 2. Fetch Invoices/Sales (to populate Dashboard and Credit Book)
      try {
        final token = await SecureTokenStorage.getToken() ?? '';
        if (token.isNotEmpty) {
          final List<dynamic> allApiItems = [];
          
          // Fetch invoices from /api/invoices/
          try {
            final invoicesRes = await ApiClient.getJson(ApiClient.invoicesList, headers: {
              'Authorization': 'Bearer $token',
            });
            if (invoicesRes.statusCode == 200) {
              final decoded = jsonDecode(invoicesRes.body);
              final invoices = decoded is List ? decoded : (decoded['invoices'] ?? decoded['results'] ?? []);
              allApiItems.addAll(invoices);
            }
          } catch (e) {
            if (kDebugMode) debugPrint('⚠️ Failed to fetch invoices from /api/invoices: $e');
          }
          
          // Canonical source: /api/invoices. The legacy /auth/sales feed is line-item based
          // and is intentionally NOT merged into the canonical invoice dataset because doing so
          // can double-count the same business transaction. Legacy recovery is handled separately.
          
          // IMPORTANT: persist the canonical invoice records separately from
          // the dashboard sales mirror. Dashboard sales may be rebuilt from the
          // cloud, but Khata/Paid Invoice history must not depend on that mirror.
          try {
            final Map<String, List<Map<String, dynamic>>> invoiceGroups = {};
            String invoiceKey(Map<String, dynamic> row) {
              for (final field in const [
                'invoice_id',
                'sale_id',
                'invoice_number',
                'number',
                'backend_id',
                'id',
              ]) {
                final value = row[field]?.toString().trim() ?? '';
                if (value.isNotEmpty && value != '0' && value != 'null') {
                  return value;
                }
              }
              return '';
            }

            for (final raw in allApiItems) {
              if (raw is! Map) continue;
              final row = Map<String, dynamic>.from(raw);
              final key = invoiceKey(row);
              if (key.isEmpty) continue;
              invoiceGroups.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(row);
            }

            double amount(dynamic value) {
              if (value is num) return value.toDouble();
              return double.tryParse(value?.toString() ?? '') ?? 0.0;
            }

            final List<Map<String, dynamic>> restoredInvoices = [];
            for (final group in invoiceGroups.values) {
              final first = group.first;

              dynamic rawItems = first['line_items'] ?? first['items'];
              if (rawItems is! List || rawItems.isEmpty) {
                rawItems = group;
              }

              final List<Map<String, dynamic>> lineItems = [];
              if (rawItems is List) {
                for (final rawItem in rawItems) {
                  if (rawItem is! Map) continue;
                  final name = (rawItem['product_name'] ??
                          rawItem['description'] ??
                          rawItem['item'] ??
                          rawItem['name'] ??
                          rawItem['product'] ??
                          '')
                      .toString()
                      .trim();
                  if (name.isEmpty) continue;

                  final price = amount(
                    rawItem['unit_price'] ?? rawItem['price'] ?? 0,
                  );
                  final qty = amount(
                    rawItem['quantity'] ?? rawItem['qty'] ?? 1,
                  );
                  final lineTotal = amount(
                    rawItem['line_total'] ??
                        rawItem['total'] ??
                        rawItem['total_with_tax'] ??
                        price * (qty > 0 ? qty : 1),
                  );

                  lineItems.add({
                    ...rawItem,
                    'product_name': name,
                    'quantity': qty > 0 ? qty : 1,
                    'qty': qty > 0 ? qty : 1,
                    'price': price,
                    'unit_price': price,
                    'total': lineTotal,
                    'line_total': lineTotal,
                    'total_with_tax': lineTotal,
                  });
                }
              }

              final total = amount(
                first['total_amount'] ??
                    first['total'] ??
                    first['invoice_total'] ??
                    first['grand_total'],
              );
              final paid = amount(
                first['paid_amount'] ??
                    first['amount_paid'] ??
                    first['paid'] ??
                    first['received_amount'],
              ).clamp(0.0, total).toDouble();
              final outstanding =
                  (total - paid).clamp(0.0, double.infinity).toDouble();
              final statusRaw =
                  (first['payment_status'] ?? first['status'] ?? '')
                      .toString()
                      .toUpperCase();
              final status = statusRaw == 'PAID' ||
                      statusRaw == 'PARTIAL' ||
                      statusRaw == 'UNPAID'
                  ? statusRaw
                  : (paid >= total - 0.01
                      ? 'PAID'
                      : paid > 0
                          ? 'PARTIAL'
                          : 'UNPAID');

              restoredInvoices.add({
                ...first,
                'invoice_id': first['invoice_id'] ?? first['id'],
                'invoice_number': first['invoice_number'] ??
                    first['number'] ??
                    first['sale_id'] ??
                    first['id'],
                'sale_id': first['sale_id'] ??
                    first['invoice_number'] ??
                    first['id'],
                'customer_name':
                    first['customer_name'] ?? first['name'] ?? 'Cash Customer',
                'customer_phone':
                    first['customer_phone'] ?? first['phone'] ?? '',
                'business_date': first['business_date'] ??
                    first['invoice_date'] ??
                    first['sale_date'] ??
                    first['date'] ??
                    first['created_at'],
                'created_at': first['created_at'],
                'sale_timestamp': first['sale_timestamp'] ?? first['created_at'],
                'total_amount': total,
                'paid_amount': paid,
                'pending_amount': outstanding,
                'payment_status': status,
                'status': status,
                'line_items': lineItems,
                'items': lineItems,
                'sync_status': 'synced',
                'is_synced': true,
                'source': 'cloud_restore',
              });
            }

            if (restoredInvoices.isNotEmpty) {
              await LocalStorageService.saveLocalInvoices(restoredInvoices);
              if (kDebugMode) {
                debugPrint(
                  '✅ Cloud restore: ${restoredInvoices.length} canonical invoices persisted',
                );
              }
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️ Failed to persist canonical invoice restore: $e');
            }
          }

          final currentLocal = await LocalStorageService.loadSales();
          final localBills = currentLocal
              .whereType<Map>()
              .map((s) => Map<String, dynamic>.from(s))
              .toList();
          final existingIds = localBills.map((s) => s['sale_id'].toString()).toSet();
          final List<Map<String, dynamic>> newItems = [];

          // Group API rows — /auth/sales returns one row per line item (flattened)
          final Map<String, List<dynamic>> grouped = {};
          for (final item in allApiItems) {
            if (item is! Map) continue;
            final saleId = (item['invoice_number'] ?? item['sale_id'] ?? item['number'] ?? '').toString();
            if (saleId.isEmpty) continue;
            grouped.putIfAbsent(saleId, () => []).add(item);
          }

          for (final entry in grouped.entries) {
            final saleId = entry.key;
            if (existingIds.contains(saleId)) continue;

            final firstItem = entry.value.first as Map;
            dynamic rawLineItems = firstItem['line_items'] ?? firstItem['items'];
            if (rawLineItems == null || (rawLineItems is List && rawLineItems.isEmpty)) {
              rawLineItems = entry.value;
            }
            if (rawLineItems is! List || rawLineItems.isEmpty) continue;
            
            final validItems = <Map<String, dynamic>>[];
            for (final li in rawLineItems) {
              if (li is! Map) continue;
              final name = (li['product_name'] ?? li['description'] ?? li['item'] ?? li['name'] ?? li['product'] ?? '').toString().trim();
              if (name.isEmpty || name.toLowerCase() == 'unknown' || name.toLowerCase() == 'unknown item') continue;
              
              final double price = double.tryParse((li['unit_price'] ?? li['price'] ?? 0).toString()) ?? 0.0;
              final double qty = double.tryParse((li['quantity'] ?? li['qty'] ?? 1).toString()) ?? 1.0;
              final double lineTotal = double.tryParse((li['line_total'] ?? li['total'] ?? li['total_with_tax'] ?? (price * qty)).toString()) ?? price * qty;
              
              validItems.add({
                'product_name': name,
                'item': name,
                'name': name,
                'product': name,
                'qty': qty,
                'quantity': qty,
                'price': price,
                'unit_price': price,
                'total': lineTotal,
                'line_total': lineTotal,
                'total_with_tax': lineTotal,
              });
            }
            if (validItems.isEmpty) continue;
            
            final businessDate = firstItem['business_date'] ??
                firstItem['sale_date'] ??
                firstItem['invoice_date'] ??
                firstItem['date'];
            newItems.add({
              'sale_id': saleId,
              'customer_name': firstItem['customer_name'] ?? 'Cash Customer',
              'customer_phone': firstItem['customer_phone'] ?? '',
              'items': validItems,
              'business_date': businessDate,
              'created_at': firstItem['created_at'],
              'updated_at': firstItem['updated_at'],
              'total': firstItem['total_amount']?.toString() ?? firstItem['total']?.toString() ?? firstItem['totalAmount']?.toString() ?? '0',
              'paid_amount': firstItem['paid_amount']?.toString() ?? '0',
              'payment_status': firstItem['payment_status'] ?? 'PAID',
              'sync_status': 'synced',
              'is_synced': true,
              'source': 'cloud_restore',
            });
          }

          // #region agent log
          AgentDebugLog.log(
            location: 'sync_service.dart:downloadUserData',
            message: 'CLOUD MERGE RESULT',
            hypothesisId: 'H4',
            data: {
              'apiItemCount': allApiItems.length,
              'groupedBills': grouped.length,
              'newItemsMerged': newItems.length,
            },
          );
          // #endregion

          if (newItems.isNotEmpty) {
            final List<Map<String, dynamic>> merged = [...localBills, ...newItems];
            final deduped = SalesDedupHelper.dedupeBills(merged);
            await LocalStorageService.saveSales(deduped);
            if (kDebugMode) {
              debugPrint('✅ Cloud restore: ${newItems.length} new bills from API');
            }
            _refreshNotifier.add(null);
          }
        }
      } catch (e) {
        await ErrorLogHelper.logException(e, StackTrace.current, context: 'SyncService.downloadSales');
      }

      // Option B: always run one-time dedupe after cloud fetch
      final cleanup = await SalesDedupHelper.cleanupAndPersist();
      if (cleanup.removed > 0) {
        _refreshNotifier.add(null);
      }
      
    } catch (e) {
      await ErrorLogHelper.logException(e, StackTrace.current, context: 'SyncService._downloadUserDataImpl');
    }
  }


  /// High-reliability sale sync (Queued by default for offline-first)
  static Future<void> syncSale(Map<String, dynamic> sale) async {
    try {
      await SyncQueueManager.enqueue('sync_sale', sale);
      _syncStatusController.add(await SyncQueueManager.getQueueSize());
      await processQueueSafe();
    } catch (e) {
      await ErrorLogHelper.logException(e, StackTrace.current, context: 'SyncService.syncSale');
    }
  }

  /// Update payment status - queued for offline safety
  static Future<void> updateSalePayment(String saleId, String status, double amount) async {
    try {
      await SyncQueueManager.enqueue('update_payment', {
        'invoice_number': saleId,
        'payment_status': status,
        'paid_amount': amount,
      });
      _syncStatusController.add(await SyncQueueManager.getQueueSize());
      await processQueueSafe();
    } catch (e) {
      await ErrorLogHelper.logException(e, StackTrace.current, context: 'SyncService.updateSalePayment');
    }
  }

  /// Process sync queue - Thread-safe with Lock
  static Future<void> processQueueSafe() async {
    if (SyncQueueManager.isSyncing) {
      if (kDebugMode) debugPrint('⚠️ Sync already in progress, skipping overlap');
      return;
    }
    SyncQueueManager.isSyncing = true;
    try {
      await _syncLock.synchronized(() async {
        try {
          await _processQueueImpl();
        } catch (e) {
          await ErrorLogHelper.logException(e, StackTrace.current, context: 'SyncService.processQueue');
        }
      });
    } finally {
      SyncQueueManager.isSyncing = false;
    }
  }

  /// Internal queue processing implementation
  static Future<void> _processQueueImpl() async {
    try {
      // Self-healing: recover any quarantined or stuck items from previous sessions
      await SyncQueueManager.recoverQuarantinedForCurrentUser();
      await SyncQueueManager.recoverStuckItems();

      final dynamic connection = await Connectivity().checkConnectivity();
      final bool isOffline = connection is List 
          ? (connection.isEmpty || (connection.length == 1 && connection.first == ConnectivityResult.none))
          : connection == ConnectivityResult.none;
          
      if (isOffline) {
        _syncStatusController.add(await SyncQueueManager.getQueueSize());
        return;
      }

      final List<Map<String, dynamic>> pending = await SyncQueueManager.getAll();
      if (kDebugMode) debugPrint('🔄 Processing sync queue: ${pending.length} items');

      int successCount = 0;
      int failureCount = 0;
      int consecutiveNetworkFailures = 0;

      for (var item in pending) {
        final actionId = item['action_id'];
        final action = item['action'];
        final status = item['status'];
        
        if (status == 'PARKED') continue; // Skip permanently failed items

        final nextAttemptRaw = item['next_attempt_at']?.toString();
        if (nextAttemptRaw != null && nextAttemptRaw.isNotEmpty) {
          final nextAttemptAt = DateTime.tryParse(nextAttemptRaw);
          if (nextAttemptAt != null && DateTime.now().isBefore(nextAttemptAt)) {
            continue;
          }
        }
        
        // Retry timing is controlled by next_attempt_at written below after failures.

        final data = Map<String, dynamic>.from(item['data'] ?? {});
        item['status'] = 'SYNCING';
        item['updated_at'] = DateTime.now().toIso8601String();
        await SyncQueueManager.update(actionId, item);
        bool success = false;

        try {
          switch (action) {
            case 'sync_sale':
              success = await _syncSaleItem(data);
              break;

            case 'save_sale':
            case 'create_sale':
              success = await _syncSaleBatchItem(data);
              break;

            case 'sync_invoice_batch':
              success = await _syncInvoiceBatchItem(data);
              break;

            case 'update_payment':
            case 'update_invoice_payment':
              success = await _updatePaymentItem(data);
              break;
              
            case 'update_invoice_paid':
            case 'update_invoice_unpaid':
              success = await _updateInvoiceItem(data, action);
              break;
              
            case 'send_daily_email':
              success = await _sendEmailItem(data);
              break;
              
            case 'worker_profile':
              success = await syncWorkerProfile(data);
              break;

            case 'attendance_check_in':
              success = await _syncAttendanceCheckInItem(data);
              break;

            case 'attendance_check_out':
              success = await _syncAttendanceCheckOutItem(data);
              break;

            case 'decrease_stock':
              success = await _decreaseStockItem(data);
              break;
              
            case 'update_local_product':
              success = await _updateLocalProductItem(data);
              break;

            case 'create_local_product':
              success = await _createLocalProductItem(data);
              break;

            case 'delete_product':
              success = await _deleteProductItem(data);
              break;

            case 'create_purchase_order':
              success = await _createPurchaseOrderItem(data);
              break;

            case 'update_purchase_order_status':
              success = await _updatePurchaseOrderStatusItem(data);
              break;

            case 'record_khata_payment':
              success = await _recordKhataPaymentItem(data);
              break;

            case 'save_customer':
            case 'create_customer':
              success = await _saveCustomerItem(data);
              break;

            default:
              if (kDebugMode) debugPrint('⚠️ Unknown action: $action');
              success = false;
          }

          if (success) {
            // ACK protocol: persist local SYNCED state first. Only then can the
            // durable outbox item be removed. If local marking fails, the queue
            // stays intact and the operation is retried safely.
            if (action == 'save_sale' || action == 'sync_sale') {
              final saleId = data['sale_id']?.toString() ?? data['invoice_number']?.toString() ?? '';
              if (saleId.isNotEmpty) {
                final marked = await SaleService.markSaleAsSynced(saleId);
                if (!marked) {
                  success = false;
                  throw StateError('LOCAL_SYNC_ACK_FAILED:$saleId');
                }
                SyncService.triggerDashboardRefresh();
              }
            }

            if (success) {
              await SyncQueueManager.remove(actionId);
              successCount++;
              consecutiveNetworkFailures = 0;
              if (action == 'create_purchase_order' || action == 'update_purchase_order_status') {
                SyncService.triggerDashboardRefresh();
              }
            }
          }
          if (!success) {
            final retryCount = ((item['retries'] as num?)?.toInt() ?? 0) + 1;
            item['retries'] = retryCount;
            item['last_attempt'] = DateTime.now().toUtc().toIso8601String();
            item['last_error'] = 'SYNC_FAILED';

            const criticalActions = <String>{
              'save_sale',
              'create_sale',
              'sync_sale',
              'sync_invoice_batch',
              'update_payment',
              'update_invoice_payment',
              'update_invoice_paid',
              'update_invoice_unpaid',
              'record_khata_payment',
              'decrease_stock',
              'create_purchase_order',
              'update_purchase_order_status',
            };

            final isCritical = criticalActions.contains(action);

            final retryDelaySeconds = switch (retryCount) {
              1 => 2,
              2 => 5,
              3 => 15,
              4 => 30,
              5 => 60,
              6 => 120,
              7 => 300,
              8 => 600,
              9 => 1800,
              _ => 3600,
            };

            item['next_attempt_at'] = DateTime.now()
                .toUtc()
                .add(Duration(seconds: retryDelaySeconds))
                .toIso8601String();

            if (isCritical) {
              // Critical operations NEVER become permanently dead.
              item['status'] = 'RETRY_WAIT';
              item['needs_attention'] = retryCount >= 8;
              if (kDebugMode) debugPrint('⚠️ CRITICAL: Action $actionId (retry $retryCount) will retry in ${retryDelaySeconds}s.');
            } else {
              // Non-critical operations may be parked after repeated failure,
              // but the record remains durable for manual recovery.
              item['status'] = retryCount >= 12 ? 'PARKED' : 'RETRY_WAIT';
              item['needs_attention'] = retryCount >= 12;
              if (kDebugMode) debugPrint('⚠️ Action $actionId (retry $retryCount) will retry in ${retryDelaySeconds}s.');
            }

            await SyncQueueManager.update(actionId, item);
            failureCount++;
            consecutiveNetworkFailures++;
          }
        } catch (e, stack) {
          await ErrorLogHelper.logException(e, stack,
            context: 'SyncService._processQueueImpl - action: $action',
            attributes: {'action_id': actionId, 'action': action},
          );
          failureCount++;
          consecutiveNetworkFailures++;
          
          final retryCount = ((item['retries'] as num?)?.toInt() ?? 0) + 1;
          item['retries'] = retryCount;
          item['last_attempt'] = DateTime.now().toUtc().toIso8601String();
          item['last_error'] = e.toString();

          const criticalActions = <String>{
            'save_sale',
            'create_sale',
            'sync_sale',
            'sync_invoice_batch',
            'update_payment',
            'update_invoice_payment',
            'update_invoice_paid',
            'update_invoice_unpaid',
            'record_khata_payment',
            'decrease_stock',
            'create_purchase_order',
            'update_purchase_order_status',
          };

          final isCritical = criticalActions.contains(action);

          final retryDelaySeconds = switch (retryCount) {
            1 => 2,
            2 => 5,
            3 => 15,
            4 => 30,
            5 => 60,
            6 => 120,
            7 => 300,
            8 => 600,
            9 => 1800,
            _ => 3600,
          };

          item['next_attempt_at'] = DateTime.now()
              .toUtc()
              .add(Duration(seconds: retryDelaySeconds))
              .toIso8601String();

          if (isCritical) {
            // Critical operations NEVER become permanently dead.
            item['status'] = 'RETRY_WAIT';
            item['needs_attention'] = retryCount >= 8;
            if (kDebugMode) debugPrint('🚨 CRITICAL EXCEPTION: Action $actionId (retry $retryCount) will retry in ${retryDelaySeconds}s. Error: $e');
          } else {
            // Non-critical operations may be parked after repeated failure,
            // but the record remains durable for manual recovery.
            item['status'] = retryCount >= 12 ? 'PARKED' : 'RETRY_WAIT';
            item['needs_attention'] = retryCount >= 12;
            if (kDebugMode) debugPrint('⚠️ Action $actionId (retry $retryCount) will retry in ${retryDelaySeconds}s.');
          }

          await SyncQueueManager.update(actionId, item);
        }
      }

      _syncStatusController.add(await SyncQueueManager.getQueueSize());
      
      if (kDebugMode) {
        debugPrint('✅ Sync complete: $successCount succeeded, $failureCount failed');
      }
    } catch (e) {
      await ErrorLogHelper.logException(e, StackTrace.current, context: 'SyncService._processQueueImpl');
    }
  }

  /// Sync one or many line items for a single bill (idempotent).
  static Future<bool> _syncSaleBatchItem(Map<String, dynamic> data) async {
    // ONE sale sync path: /api/invoices/sync. It is the authoritative atomic
    // transaction for invoice + lines + backend inventory deduction.
    Map<String, dynamic>? payload;
    String endpoint = ApiClient.invoicesSync;

    if (data['payload'] is Map) {
      payload = Map<String, dynamic>.from(data['payload'] as Map);
      endpoint = data['endpoint']?.toString() ?? ApiClient.invoicesSync;
    } else if (data['invoice_payload'] is Map) {
      payload = Map<String, dynamic>.from(data['invoice_payload'] as Map);
    }

    if (payload == null || payload.isEmpty) {
      if (kDebugMode) debugPrint('⚠️ Invalid queued sale payload; parking it instead of using legacy /auth/sales.');
      return false;
    }

    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      final res = await ApiClient.postJson(
        endpoint,
        payload,
        headers: {
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      // 201 = created; 200 = already exists/idempotent duplicate.
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Offline Sale/Invoice Sync failed: $e');
      return false;
    }
  }

static Future<bool> _syncSaleItem(Map<String, dynamic> data) async {
    // Legacy sync_sale queue entries are normalized into the same JSON
    // invoice-sync contract used by save_sale/create_sale. Never send
    // form-data to the invoice JSON endpoint.
    try {
      final normalized = <String, dynamic>{...data};
      if (data['payload'] is Map || data['invoice_payload'] is Map) {
        return _syncSaleBatchItem(data);
      }

      final rawItems = data['line_items'] ?? data['items'];
      final lineItems = rawItems is List
          ? rawItems.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      final invoiceNumber = (data['invoice_number'] ??
              data['sale_id'] ??
              data['id'] ??
              '')
          .toString()
          .trim();

      if (invoiceNumber.isEmpty || lineItems.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ sync_sale skipped: missing invoice_number or line_items');
        }
        return false;
      }

      final payload = <String, dynamic>{
        'invoice_number': invoiceNumber,
        'offline_id': data['offline_id'] ?? invoiceNumber,
        'customer_name': data['customer_name'] ?? 'Cash Customer',
        'customer_phone': data['customer_phone'],
        'total_amount': data['total_amount'] ?? data['total'] ?? 0,
        'paid_amount': data['paid_amount'] ?? data['amount_paid'] ?? 0,
        'payment_status': data['payment_status'] ?? 'PAID',
        'invoice_date': data['invoice_date'] ??
            data['business_date'] ??
            data['sale_date'] ??
            data['date'],
        if (data['sale_timestamp'] != null)
          'sale_timestamp': data['sale_timestamp'],
        if (data['created_at'] != null)
          'created_at': data['created_at'],
        'line_items': lineItems,
      };

      normalized
        ..clear()
        ..addAll({
          'endpoint': ApiClient.invoicesSync,
          'payload': payload,
          'invoice_payload': payload,
          'sale_id': invoiceNumber,
        });

      return _syncSaleBatchItem(normalized);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error syncing legacy sale queue item: $e');
      return false;
    }
  }


static Future<bool> _updatePaymentItem(Map<String, dynamic> data) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) return false;
      
      final res = await ApiClient.putJson('${ApiClient.invoicesPrefix}/update_payment', data, headers: {
        'Authorization': 'Bearer $token',
      });
      
      return res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error updating payment: $e');
      return false;
    }
  }


static Future<bool> _updateInvoiceItem(Map<String, dynamic> data, String action) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) return false;
      
      final invoiceNumber = data['invoice_number'];
      final paymentStatus = data['payment_status'];
      
      final res = await ApiClient.putJson(
        '${ApiClient.invoicesPrefix}/number/$invoiceNumber',
        {
          'payment_status': paymentStatus,
          'paid_amount': data['paid_amount'] ?? data['amount'],
          'updated_at': DateTime.now().toIso8601String(),
        },
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (res.statusCode == 200) {
        if (kDebugMode) debugPrint('✅ Invoice $invoiceNumber marked as $paymentStatus');
        return true;
      } else {
        if (kDebugMode) debugPrint('❌ Failed to update invoice: ${res.statusCode}');
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error updating invoice: $e');
      return false;
    }
  }


static Future<bool> _sendEmailItem(Map<String, dynamic> data) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) return false;
      
      final res = await ApiClient.postJson(
        '/api/email/send-summary',
        data,
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (kDebugMode) debugPrint('📧 Daily email sent: ${data['email']}');
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error sending email: $e');
      return false;
    }
  }


static Future<bool> _decreaseStockItem(Map<String, dynamic> data) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) return false;
      
      final productId = data['product_id'];
      
      final res = await ApiClient.putJson(
        '${ApiClient.inventoryPrefix}/products/$productId/decrease-stock',
        {
          'quantity': data['quantity'],
          'reason': 'SALE',
          'reference_id': data['reference_id'] ?? 'SALE_${DateTime.now().millisecondsSinceEpoch}',
        },
        headers: {'Authorization': 'Bearer $token'},
      );
      
      return res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error syncing stock decrease: $e');
      return false;
    }
  }


static Future<bool> _updateLocalProductItem(Map<String, dynamic> data) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) return false;
      
      final id = data['id'];
      final userId = data['user_id'];
      final payload = data['payload'];
      
      final res = await ApiClient.putJson(
        '${ApiClient.inventoryPrefix}/products/$id?user_id=$userId',
        payload,
        headers: {'Authorization': 'Bearer $token'},
      );
      
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error syncing local product update: $e');
      return false;
    }
  }


static Future<bool> _createLocalProductItem(Map<String, dynamic> data) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) return false;

      final userId = data['user_id'];
      final payload = data['payload'];
      if (payload is! Map) return false;

      final raw = Map<String, dynamic>.from(payload);
      final apiPayload = <String, dynamic>{
        'product_name': raw['product_name'] ?? raw['name'] ?? '',
        'sku': raw['sku'] ?? raw['barcode'] ?? '',
        'unit_price': raw['unit_price'] ?? raw['price'] ?? 0,
        'current_stock': raw['current_stock'] ?? raw['stock'] ?? raw['quantity'] ?? 0,
        'min_stock': raw['min_stock'] ?? 10,
        'category': raw['category'] ?? 'General',
      };

      final res = await ApiClient.postJson(
        '${ApiClient.inventoryPrefix}/products?user_id=$userId',
        apiPayload,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 || res.statusCode == 201) {
        // Mirror into the backend-products cache so it shows as synced
        // without waiting for the next full inventory fetch.
        try {
          final saved = jsonDecode(res.body);
          final cached = await LocalStorageService.loadBackendProducts();
          cached.add(saved);
          await LocalStorageService.saveBackendProducts(cached);
        } catch (_) {}
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error syncing local product create: $e');
      return false;
    }
  }



static Future<bool> _deleteProductItem(Map<String, dynamic> data) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) return false;
      final id = int.tryParse(data['id']?.toString() ?? '');
      final userId = data['user_id'];
      if (id == null || id <= 0) return false;
      final res = await ApiClient.deleteJson(
        '${ApiClient.inventoryPrefix}/products/$id?user_id=$userId',
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      return res.statusCode == 200 || res.statusCode == 204 || res.statusCode == 404;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error syncing product deletion: $e');
      return false;
    }
  }

static Future<bool> _createPurchaseOrderItem(Map<String, dynamic> data) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) return false;
      final normalizedItems = <Map<String, dynamic>>[];
      final rawItems = data['items'];
      if (rawItems is List) {
        for (final raw in rawItems) {
          if (raw is! Map) continue;
          final item = Map<String, dynamic>.from(raw);
          final name = (item['product_name'] ?? item['product'] ?? item['name'] ?? item['item'] ?? '').toString().trim();
          final qty = double.tryParse((item['quantity'] ?? item['qty'] ?? 0).toString()) ?? 0.0;
          final cost = double.tryParse((item['unit_cost'] ?? item['unit_price'] ?? item['price'] ?? 0).toString()) ?? 0.0;
          if (name.isEmpty || qty <= 0) continue;
          normalizedItems.add({'product_id': item['product_id'] ?? item['id'], 'product_name': name, 'quantity': qty, 'unit_cost': cost});
        }
      }
      if (normalizedItems.isEmpty) return false;
      final payload = {...data, 'supplier_name': (data['supplier_name'] ?? data['supplier'] ?? '').toString().trim(), 'items': normalizedItems};
      final res = await ApiClient.postJson('/purchase-orders/', payload, headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 20));
      final success = res.statusCode == 200 || res.statusCode == 201;
      if (!success && kDebugMode) debugPrint('❌ Purchase order backend rejected sync: ${res.statusCode} ${res.body}');
      return success;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error creating purchase order: $e');
      return false;
    }
  }


static Future<bool> _updatePurchaseOrderStatusItem(Map<String, dynamic> data) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) return false;

      final poId = data['po_id'];
      final action = data['po_action']; // 'mark-delivered' or 'cancel'

      final res = await ApiClient.postJson(
        '/purchase-orders/$poId/$action',
        {},
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 20));

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error updating purchase order status: $e');
      return false;
    }
  }


static Future<bool> _recordKhataPaymentItem(
    Map<String, dynamic> data,
  ) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) return false;

      // Repair old queued records created by previous builds that could contain
      // customer_id: "" or a phone number in the integer field.
      final payload = Map<String, dynamic>.from(data);

      final rawCustomerId = payload['customer_id'];
      int? customerId;

      if (rawCustomerId is int && rawCustomerId > 0) {
        customerId = rawCustomerId;
      } else if (rawCustomerId is num && rawCustomerId.toInt() > 0) {
        customerId = rawCustomerId.toInt();
      } else {
        final parsed = int.tryParse(
          rawCustomerId?.toString().trim() ?? '',
        );
        if (parsed != null && parsed > 0) {
          customerId = parsed;
        }
      }

      final customerPhone =
          (payload['customer_phone'] ?? payload['phone'] ?? '')
              .toString()
              .trim();

      // Never send an empty/string customer_id to a FastAPI integer field.
      if (customerId != null) {
        payload['customer_id'] = customerId;
      } else {
        payload.remove('customer_id');
      }

      if (customerPhone.isNotEmpty) {
        payload['customer_phone'] = customerPhone;
      } else {
        payload.remove('customer_phone');
      }

      final rawInvoiceId = payload['invoice_id'];
      final invoiceId = rawInvoiceId is int
          ? rawInvoiceId
          : int.tryParse(rawInvoiceId?.toString().trim() ?? '');

      // Exact invoice settlement is the safest identity and does not require a
      // customer phone/id. This is important for Mark Paid because the payment
      // must survive app-data clearing against the same server invoice.
      if (invoiceId != null && invoiceId > 0) {
        payload['invoice_id'] = invoiceId;
      } else if (customerId == null && customerPhone.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            '❌ Khata payment has no valid invoice/customer identity; keeping it queued.',
          );
        }
        return false;
      }

      final res = await ApiClient.postJson(
        '/api/khata/record-payment',
        payload,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      // 200/201 = created or idempotent success.
      // 409 is also treated as success when the backend reports a duplicate
      // idempotency key, because the payment already exists server-side.
      if (res.statusCode == 200 || res.statusCode == 201) {
        return true;
      }

      if (res.statusCode == 409) {
        return true;
      }

      if (kDebugMode) {
        debugPrint(
          '❌ Khata payment sync rejected: '
          '${res.statusCode} ${res.body}',
        );
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error syncing khata payment: $e');
      }
      return false;
    }
  }


static Future<bool> _saveCustomerItem(Map<String, dynamic> data) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) return false;

      final payload = {
        'name': data['name'] ?? data['customer_name'] ?? '',
        'phone': data['phone'] ?? data['phone_number'] ?? '',
        'address': data['address'] ?? '',
        'email': data['email'] ?? '',
      };

      final res = await ApiClient.postJson(
        ApiClient.customersPrefix,
        payload,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 20));

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error syncing customer: $e');
      return false;
    }
  }


static Future<DateTime> getAuthoritativeTime() async {
    try {
      // Try to get server time from backend
      // Format: GET /api/time -> {"timestamp": "2026-04-09T15:30:00Z"}
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/time'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final serverTime = DateTime.parse(json['timestamp'] as String? ?? DateTime.now().toIso8601String());
          _lastServerTime = serverTime;
          _serverTimeOffset = serverTime.difference(DateTime.now());
          if (kDebugMode) debugPrint('✅ Server time synced: ${serverTime.toIso8601String()}');
          return serverTime;
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Failed to parse server time: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Server time fetch failed: $e');
    }
    
    // Fallback: use device time + last known offset (if any)
    if (_serverTimeOffset != null) {
      return DateTime.now().add(_serverTimeOffset!);
    }
    
    // Ultimate fallback: device time (less secure)
    return DateTime.now();
  }


  static Future<DateTime> getDateBoundaryTime() => getAuthoritativeTime();

static Future<bool> isDeviceTimeValid() async {
    try {
      final serverTime = await getAuthoritativeTime();
      final deviceTime = DateTime.now();
      final drift = serverTime.difference(deviceTime).abs();
      
      if (drift.inMinutes > 5) {
        if (kDebugMode) debugPrint('🚨 Device time drift detected: ${drift.inMinutes} minutes');
        return false;  // Device time is too far off
      }
      return true;
    } catch (e) {
      return true;  // Can't validate, assume OK
    }
  }


  /// Verify synchronization state: backend + pending = local
  /// Sync one or many line items for a single bill (idempotent).
static Future<bool> _syncInvoiceBatchItem(
  Map<String, dynamic> data,
) async {
  try {
    final token = await SecureTokenStorage.getToken() ?? '';

    final response = await ApiClient.postJson(
      ApiClient.invoicesSync,
      data,
      headers: {
        if (token.isNotEmpty)
          'Authorization': 'Bearer $token',
      },
    ).timeout(
      const Duration(seconds: 15),
    );

    return response.statusCode == 200 ||
        response.statusCode == 201;
  } catch (e) {
    if (kDebugMode) {
      debugPrint(
        '⚠️ Offline Invoice Batch Sync failed: $e',
      );
    }
    return false;
  }
}

/// Verify synchronization state.
///
/// Diagnostic only. This method must NOT decide whether
/// a sale is saved, synced, or retried.
static Future<Map<String, dynamic>> verifySyncState() async {
  try {
    // -------------------------------------------------------
    // 1. Local sales
    // -------------------------------------------------------
    final localSales =
        await LocalStorageService.loadSales();

    final localCount = localSales.length;

    // -------------------------------------------------------
    // 2. Pending durable queue
    // -------------------------------------------------------
    final pendingQueue =
        await SyncQueueManager.getAll();

    final pendingCount = pendingQueue.length;

    // -------------------------------------------------------
    // 3. Connectivity
    // -------------------------------------------------------
    bool online = false;

    try {
      final connection =
          await Connectivity().checkConnectivity();

      online = connection != ConnectivityResult.none;
    } catch (_) {
      online = false;
    }

    // -------------------------------------------------------
    // 4. Backend counts
    // -------------------------------------------------------
    int backendSalesCount = 0;
    int backendInvoiceCount = 0;

    final token =
        await SecureTokenStorage.getToken() ?? '';

    if (online && token.isNotEmpty) {
      // -----------------------------
      // Backend sales
      // -----------------------------
      try {
        final salesResponse = await ApiClient.getJson(
          ApiClient.salesEndpoint,
          headers: {
            'Authorization': 'Bearer $token',
          },
        );

        if (salesResponse.statusCode == 200) {
          final decoded =
              jsonDecode(salesResponse.body);

          if (decoded is List) {
            backendSalesCount = decoded.length;
          } else if (decoded is Map) {
            final count = decoded['count'];

            if (count is num) {
              backendSalesCount = count.toInt();
            } else if (decoded['sales'] is List) {
              backendSalesCount =
                  (decoded['sales'] as List).length;
            } else if (decoded['results'] is List) {
              backendSalesCount =
                  (decoded['results'] as List).length;
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Could not fetch backend sales count: $e',
          );
        }
      }

      // -----------------------------
      // Backend invoices
      // -----------------------------
      try {
        final invoiceResponse = await ApiClient.getJson(
          ApiClient.invoicesList,
          headers: {
            'Authorization': 'Bearer $token',
          },
        );

        if (invoiceResponse.statusCode == 200) {
          final decoded =
              jsonDecode(invoiceResponse.body);

          if (decoded is List) {
            backendInvoiceCount = decoded.length;
          } else if (decoded is Map) {
            if (decoded['invoices'] is List) {
              backendInvoiceCount =
                  (decoded['invoices'] as List).length;
            } else if (decoded['results'] is List) {
              backendInvoiceCount =
                  (decoded['results'] as List).length;
            } else if (decoded['count'] is num) {
              backendInvoiceCount =
                  (decoded['count'] as num).toInt();
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Could not fetch backend invoice count: $e',
          );
        }
      }
    }

    // -------------------------------------------------------
    // IMPORTANT:
    // Do NOT simply add backend sales + invoices.
    //
    // A sale may already exist as an invoice, which would
    // double-count the same business transaction.
    //
    // Therefore this verification is intentionally
    // conservative.
    // -------------------------------------------------------

    final backendCount =
        backendInvoiceCount > 0
            ? backendInvoiceCount
            : backendSalesCount;

    bool verified = true;
    String verificationMessage;

    if (!online) {
      verificationMessage =
          '⚠️ Offline: local=$localCount, '
          'pending=$pendingCount; cloud confirmation is unavailable.';

      verified = false;
    } else if (token.isEmpty) {
      verificationMessage =
          '⚠️ Online but authentication token unavailable: '
          'local=$localCount, pending=$pendingCount; cloud confirmation is unavailable.';

      verified = false;
    } else if (backendCount == 0) {
      verificationMessage =
          '⚠️ Backend returned no countable records: '
          'local=$localCount, pending=$pendingCount; sync is not verified.';

      verified = false;
    } else {
      // Approximate consistency check only.
      //
      // Pending items are expected to already exist locally,
      // so we compare local against backend + a reasonable
      // pending range rather than requiring exact equality.
      final lowerBound =
          backendCount;

      final upperBound =
          backendCount + pendingCount + 10;

      if (localCount >= lowerBound &&
          localCount <= upperBound) {
        verificationMessage =
            '✅ Sync approximately verified: '
            'backend=$backendCount, '
            'pending=$pendingCount, '
            'local=$localCount';
      } else {
        verified = false;

        verificationMessage =
            '❌ Possible sync mismatch: '
            'backend=$backendCount, '
            'pending=$pendingCount, '
            'local=$localCount';
      }
    }

    if (kDebugMode) {
      debugPrint(verificationMessage);
    }

    return {
      'verified': verified,
      'message': verificationMessage,
      'local_count': localCount,
      'pending_count': pendingCount,
      'backend_count': backendCount,
      'backend_sales_count': backendSalesCount,
      'backend_invoice_count': backendInvoiceCount,
      'online': online,
    };
  } catch (e, stackTrace) {
    if (kDebugMode) {
      debugPrint(
        '❌ Sync verification failed: $e',
      );
      debugPrint(stackTrace.toString());
    }

    return {
      'verified': false,
      'message': 'Verification failed: $e',
      'local_count': 0,
      'pending_count': 0,
      'backend_count': 0,
      'backend_sales_count': 0,
      'backend_invoice_count': 0,
      'online': false,
    };
  }
}
}
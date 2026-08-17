import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

/// Durable, user-scoped offline outbox.
///
/// Design goals:
/// - Never silently reject a critical financial operation because the queue
///   reached an arbitrary size limit.
/// - Never move unauthenticated data into an arbitrary logged-in account.
/// - Never permanently dead-letter a transaction without a recovery path.
/// - Make retries idempotent by business identifier.
/// - Keep the queue encrypted and serialized with one lock.
class SyncQueueManager {
  static const String _queueBoxName = 'sync_queue_secure_v4';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // High-value operations must never be rejected because of queue pressure.
  static const Set<String> _criticalActions = <String>{
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
    'delete_product',
    'create_purchase_order',
    'update_purchase_order_status',
    'attendance_check_in',
    'attendance_check_out',
  };

  static const int _softQueueLimit = 10000;

  static Box? _box;
  static String? _boxName;

  static final Lock _queueLock = Lock();

  // Public because SyncService already reads this field.
  static bool isSyncing = false;
  static DateTime? _syncStartTime;
  static const Duration _syncTimeout = Duration(minutes: 5);
  static Timer? _syncTimeoutTimer;

  static Future<bool> _setSyncLock() async {
    if (isSyncing) {
      final started = _syncStartTime;
      if (started != null &&
          DateTime.now().difference(started) > _syncTimeout) {
        await _clearSyncLock();
      } else {
        return false;
      }
    }

    isSyncing = true;
    _syncStartTime = DateTime.now();

    _syncTimeoutTimer?.cancel();
    _syncTimeoutTimer = Timer(_syncTimeout, () async {
      await _clearSyncLock();
    });

    return true;
  }

  static Future<void> _clearSyncLock() async {
    isSyncing = false;
    _syncStartTime = null;
    _syncTimeoutTimer?.cancel();
    _syncTimeoutTimer = null;
  }

  static bool _validateQueueData(
    String action,
    Map<String, dynamic> data,
  ) {
    if (action.trim().isEmpty || data.isEmpty) return false;

    switch (action) {
      case 'save_sale':
      case 'create_sale':
      case 'sync_sale':
      case 'sync_invoice_batch':
        final identifier = _businessIdentifier(data);
        return identifier.isNotEmpty;

      case 'save_customer':
      case 'create_customer':
        return data.containsKey('customer_id') ||
            data.containsKey('phone') ||
            data.containsKey('operation_id');

      case 'update_inventory':
      case 'decrease_stock':
        return data['product_id'] != null ||
            data['product_name'] != null;

      case 'delete_product':
        return data['id'] != null || data['product_id'] != null;

      default:
        return true;
    }
  }

  static String _businessIdentifier(Map<dynamic, dynamic> data) {
    String firstNonEmpty(Iterable<dynamic> values) {
      for (final value in values) {
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) return text.toLowerCase();
      }
      return '';
    }

    final invoicePayload = data['invoice_payload'];
    final payload = data['payload'];

    return firstNonEmpty(<dynamic>[
      data['sale_id'],
      data['offline_id'],
      data['operation_id'],
      data['idempotency_key'],
      data['invoice_number'],
      if (invoicePayload is Map) invoicePayload['invoice_number'],
      if (invoicePayload is Map) invoicePayload['offline_id'],
      if (payload is Map) payload['invoice_number'],
      if (payload is Map) payload['offline_id'],
    ]);
  }

  static Future<List<int>> _getHiveKey() async {
    const keyName = 'hive_encryption_key_v2';
    final stored = await _secureStorage.read(key: keyName);

    if (stored == null || stored.isEmpty) {
      final key = Hive.generateSecureKey();
      await _secureStorage.write(
        key: keyName,
        value: base64UrlEncode(key),
      );
      return key;
    }

    return base64Url.decode(stored);
  }

  static Future<int?> _currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id') ?? prefs.getInt('userId');
  }

  static Future<Box> _getBoxUnlocked() async {
    final userId = await _currentUserId();

    // A missing user is isolated in a quarantine box. It is NEVER merged
    // automatically into an arbitrary future account.
    final scopedName = userId == null || userId <= 0
        ? '${_queueBoxName}_quarantine'
        : '${_queueBoxName}_user_$userId';

    if (_box != null &&
        _box!.isOpen &&
        _boxName == scopedName) {
      return _box!;
    }

    if (_box != null && _box!.isOpen && _boxName != scopedName) {
      try {
        await _box!.close();
      } catch (_) {}
      _box = null;
      _boxName = null;
    }

    final key = await _getHiveKey();
    _box = await Hive.openBox(
      scopedName,
      encryptionCipher: HiveAesCipher(key),
    );
    _boxName = scopedName;

    return _box!;
  }

  /// Recover only queue records explicitly owned by the authenticated user.
  ///
  /// Legacy quarantine items without owner_user_id remain quarantined so they
  /// cannot leak into a different account.
  static Future<int> recoverQuarantinedForCurrentUser() async {
    return _queueLock.synchronized(() async {
      try {
        final userId = await _currentUserId();
        if (userId == null || userId <= 0) return 0;

        final key = await _getHiveKey();
        final quarantine = await Hive.openBox(
          '${_queueBoxName}_quarantine',
          encryptionCipher: HiveAesCipher(key),
        );
        final target = await _getBoxUnlocked();

        int moved = 0;
        for (final keyValue in quarantine.keys.toList()) {
          final raw = quarantine.get(keyValue);
          if (raw is! Map) continue;

          final ownerId =
              int.tryParse(raw['owner_user_id']?.toString() ?? '');
          if (ownerId != userId) continue;

          await target.put(keyValue, Map<String, dynamic>.from(raw));
          await quarantine.delete(keyValue);
          moved++;
        }

        await quarantine.close();
        if (moved > 0 && kDebugMode) {
          debugPrint(
            '✅ [SyncQueue] Recovered $moved authenticated quarantine items',
          );
        }
        return moved;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [SyncQueue] Quarantine recovery failed: $e');
        }
        return 0;
      }
    });
  }

  static Future<bool> enqueue(
    String action,
    Map<String, dynamic> data,
  ) async {
    return _queueLock.synchronized(() async {
      try {
        if (!_validateQueueData(action, data)) {
          if (kDebugMode) {
            debugPrint('⚠️ [SyncQueue] Invalid queue data: $action');
          }
          return false;
        }

        final userId = await _currentUserId();
        final box = await _getBoxUnlocked();

        // Critical financial operations are never rejected because the queue
        // reached an arbitrary soft limit. Non-critical operations are bounded.
        if (box.length >= _softQueueLimit &&
            !_criticalActions.contains(action)) {
          if (kDebugMode) {
            debugPrint(
              '⚠️ [SyncQueue] Soft limit reached; rejecting non-critical action $action',
            );
          }
          return false;
        }

        final identifier = _businessIdentifier(data);

        if (identifier.isNotEmpty) {
          for (final raw in box.values) {
            if (raw is! Map) continue;

            final rawAction = raw['action']?.toString() ?? '';
            if (rawAction != action &&
                !(_criticalActions.contains(action) &&
                    (rawAction == 'save_sale' ||
                        rawAction == 'create_sale' ||
                        rawAction == 'sync_sale'))) {
              continue;
            }

            final rawData = raw['data'];
            if (rawData is! Map) continue;

            if (_businessIdentifier(rawData) == identifier) {
              // Existing record is already durable. Treat a repeated enqueue
              // as an idempotent success so UI retries do not report a
              // persistence failure for an operation that is already safely
              // stored in the outbox.
              if (kDebugMode) {
                debugPrint(
                  '✅ [SyncQueue] Existing durable operation reused: $action/$identifier',
                );
              }
              return true;
            }
          }
        }

        final now = DateTime.now().toUtc();
        final actionId = sha256
            .convert(
              utf8.encode(
                '$action|$identifier|${now.microsecondsSinceEpoch}',
              ),
            )
            .toString()
            .substring(0, 24);

        final item = <String, dynamic>{
          'action_id': actionId,
          'action': action,
          'data': Map<String, dynamic>.from(data),
          'owner_user_id': userId,
          'timestamp': now.millisecondsSinceEpoch,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
          'status': 'PENDING',
          'retries': 0,
          'last_attempt': null,
          'next_attempt_at': now.toIso8601String(),
          'last_error': null,
          'needs_attention': false,
        };

        // The durable write is the success boundary.
        await box.put(actionId, item);

        if (kDebugMode) {
          debugPrint('📦 [SyncQueue] Durable enqueue: $action/$actionId');
        }
        return true;
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('❌ [SyncQueue] Enqueue failed: $e');
          debugPrint(st.toString());
        }
        return false;
      }
    });
  }

  /// Convert legacy PARKED/FAILED records into retryable records. This prevents
  /// a financial transaction from becoming permanently invisible to the queue.
  static Future<int> recoverStuckItems() async {
    return _queueLock.synchronized(() async {
      try {
        final box = await _getBoxUnlocked();
        int recovered = 0;

        for (final key in box.keys.toList()) {
          final raw = box.get(key);
          if (raw is! Map) continue;

          final item = Map<String, dynamic>.from(raw);
          final action = item['action']?.toString() ?? '';
          final status = item['status']?.toString() ?? '';

          if ((status == 'PARKED' || status == 'FAILED') &&
              _criticalActions.contains(action)) {
            item['status'] = 'PENDING';
            item['needs_attention'] = false;
            item['next_attempt_at'] =
                DateTime.now().toUtc().toIso8601String();
            item['updated_at'] =
                DateTime.now().toUtc().toIso8601String();
            await box.put(key, item);
            recovered++;
          }
        }

        return recovered;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [SyncQueue] Stuck-item recovery failed: $e');
        }
        return 0;
      }
    });
  }

  static Future<bool> containsAction(String actionId) async {
    return _queueLock.synchronized(() async {
      try {
        final box = await _getBoxUnlocked();
        return box.containsKey(actionId);
      } catch (_) {
        return false;
      }
    });
  }

  static Future<Map<String, dynamic>?> peek() async {
    return _queueLock.synchronized(() async {
      try {
        final box = await _getBoxUnlocked();
        if (box.isEmpty) return null;

        Map<String, dynamic>? oldest;
        DateTime? oldestTime;

        for (final raw in box.values) {
          if (raw is! Map) continue;
          final item = Map<String, dynamic>.from(raw);
          final created =
              DateTime.tryParse(item['created_at']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(
                    (item['timestamp'] as int?) ?? 0,
                  );

          if (oldestTime == null || created.isBefore(oldestTime)) {
            oldestTime = created;
            oldest = item;
          }
        }

        return oldest;
      } catch (_) {
        return null;
      }
    });
  }

  static Future<void> remove(String actionId) async {
    await _queueLock.synchronized(() async {
      final box = await _getBoxUnlocked();
      await box.delete(actionId);
    });
  }

  static Future<bool> update(
    String actionId,
    Map<String, dynamic> item,
  ) async {
    return _queueLock.synchronized(() async {
      try {
        final box = await _getBoxUnlocked();
        final updated = Map<String, dynamic>.from(item);
        updated['updated_at'] = DateTime.now().toUtc().toIso8601String();
        await box.put(actionId, updated);
        return true;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ [SyncQueue] Update failed for $actionId: $e');
        }
        return false;
      }
    });
  }

  static Future<bool> containsBusinessOperation(
    String action,
    String identifier,
  ) async {
    if (action.trim().isEmpty || identifier.trim().isEmpty) {
      return false;
    }

    return _queueLock.synchronized(() async {
      try {
        final box = await _getBoxUnlocked();
        final wanted = identifier.trim().toLowerCase();

        for (final raw in box.values) {
          if (raw is! Map) continue;
          if (raw['action']?.toString() != action) continue;

          final data = raw['data'];
          if (data is! Map) continue;

          if (_businessIdentifier(data) == wanted) return true;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ [SyncQueue] containsBusinessOperation failed: $e',
          );
        }
      }

      return false;
    });
  }

  static Future<List<Map<String, dynamic>>> getAll() async {
    await recoverQuarantinedForCurrentUser();
    await recoverStuckItems();

    return _queueLock.synchronized(() async {
      final box = await _getBoxUnlocked();
      return box.values
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    });
  }

  static Future<int> getQueueSize() async {
    return _queueLock.synchronized(() async {
      final box = await _getBoxUnlocked();
      return box.length;
    });
  }

  static Future<int> getAttentionCount() async {
    return _queueLock.synchronized(() async {
      final box = await _getBoxUnlocked();
      return box.values.where((raw) {
        if (raw is! Map) return false;
        return raw['needs_attention'] == true;
      }).length;
    });
  }

  /// Intentionally requires an explicit caller. Never use this to discard
  /// financial operations automatically.
  static Future<void> clearQueue() async {
    await _queueLock.synchronized(() async {
      final box = await _getBoxUnlocked();
      await box.clear();
    });
  }

  static Future<void> resetBoxReference() async {
    await _queueLock.synchronized(() async {
      if (_box != null && _box!.isOpen) {
        try {
          await _box!.close();
        } catch (_) {}
      }
      _box = null;
      _boxName = null;
    });
  }

  static Future<void> dispose() async {
    await _queueLock.synchronized(() async {
      try {
        _syncTimeoutTimer?.cancel();
        _syncTimeoutTimer = null;
        await _clearSyncLock();

        if (_box != null && _box!.isOpen) {
          try {
            await _box!.close();
          } catch (_) {}
        }

        _box = null;
        _boxName = null;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [SyncQueue] dispose failed: $e');
        }
      }
    });
  }
}

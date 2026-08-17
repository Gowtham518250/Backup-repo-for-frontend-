import 'package:flutter/foundation.dart';
import 'local_storage_service.dart';

/// Lightweight local consistency checks for offline-first recovery.
/// This service intentionally never deletes a record because a mismatch may
/// represent a real business transaction. It only reports and repairs safe
/// metadata inconsistencies.
class ReconciliationService {
  static Future<Map<String, dynamic>> reconcileLocalSales() async {
    try {
      final raw = await LocalStorageService.loadSales();
      final sales = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final seenIds = <String>{};
      final duplicateIds = <String>{};
      final missingIds = <int>[];
      int repairedPendingFlags = 0;

      for (int i = 0; i < sales.length; i++) {
        final sale = sales[i];
        final id = (sale['sale_id'] ?? sale['invoice_number'] ?? sale['id'] ?? '')
            .toString()
            .trim();

        if (id.isEmpty) {
          missingIds.add(i);
          continue;
        }

        if (!seenIds.add(id)) {
          duplicateIds.add(id);
        }

        final status = (sale['sync_status'] ?? '').toString().toLowerCase();
        final expectedPending = status != 'synced';
        final pendingFlag = sale['pending_sync'];
        if (pendingFlag is bool && pendingFlag != expectedPending) {
          sales[i] = {
            ...sale,
            'pending_sync': expectedPending,
          };
          repairedPendingFlags++;
        }
      }

      if (repairedPendingFlags > 0) {
        await LocalStorageService.saveSales(sales);
      }

      return {
        'ok': true,
        'sales': sales.length,
        'duplicate_ids': duplicateIds.toList(),
        'missing_id_count': missingIds.length,
        'repaired_pending_flags': repairedPendingFlags,
      };
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ReconciliationService.reconcileLocalSales failed: $e');
        debugPrint(st.toString());
      }
      return {
        'ok': false,
        'sales': 0,
        'duplicate_ids': <String>[],
        'missing_id_count': 0,
        'repaired_pending_flags': 0,
        'error': e.toString(),
      };
    }
  }
}

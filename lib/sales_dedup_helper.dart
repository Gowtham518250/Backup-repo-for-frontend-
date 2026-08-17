import 'package:flutter/foundation.dart';
import 'format_helper.dart';
import 'local_storage_service.dart';
import 'financial_math.dart';

/// Result of a one-time Hive sales cleanup (Option B).
class SalesCleanupResult {
  final int before;
  final int after;
  final int removed;

  const SalesCleanupResult({
    required this.before,
    required this.after,
    required this.removed,
  });
}

/// Prevents duplicate bills/lines from cloud sync + dashboard merge.
class SalesDedupHelper {
  static String _dayKey(dynamic dateStr) {
    final s = dateStr?.toString() ?? '';
    if (s.isEmpty) return '';
    return s.split('T').first.split(' ').first;
  }

  static double _num(dynamic v, [double fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  /// Extracts the microsecond timestamp encoded in a 'SALE_<micros>' id
  /// (see sales_entry_page.dart: `'SALE_${DateTime.now().microsecondsSinceEpoch}'`).
  /// Returns null if the id isn't in that format.
  static int? _saleIdTimestampMicros(String saleId) {
    if (!saleId.startsWith('SALE_')) return null;
    return int.tryParse(saleId.substring(5));
  }

  static String _productKey(Map item) {
    final raw = (item['product_name'] ?? item['item'] ?? item['product'] ?? 'unknown').toString();
    return FormatHelper.normalizeName(raw);
  }

  /// Content-only fingerprint for a full bill — day + normalized items +
  /// quantities + prices + total. Deliberately does NOT include sale_id:
  /// identity (sale_id) and content must stay separate concepts, or content
  /// matching can never actually find a match between two records that
  /// differ only by ID (which is exactly what a retry/double-submission
  /// produces — same content, new SALE_<timestamp> id).
  static String billContentFingerprint(Map<String, dynamic> sale) {
    final day = _dayKey(sale['business_date'] ?? sale['sale_date'] ?? sale['created_at'] ?? sale['date']);
    final total = _num(sale['total']).toStringAsFixed(2);
    final items = sale['items'] as List? ?? [];

    if (items.isEmpty) {
      final product = FormatHelper.normalizeName((sale['product'] ?? 'unknown').toString());
      final qty = _num(sale['quantity'] ?? sale['qty'], 1).toStringAsFixed(2);
      final price = _num(sale['price']).toStringAsFixed(2);
      return '${day}_${product}_${qty}_${price}_$total';
    }

    final parts = <String>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final product = _productKey(item);
      final qty = _num(item['qty'] ?? item['quantity'], 1).toStringAsFixed(2);
      final price = _num(item['price']).toStringAsFixed(2);
      parts.add('${product}_${qty}_$price');
    }
    parts.sort();
    return '${day}_${parts.join('|')}_$total';
  }

  /// Content-only fingerprint — catches duplicate lines even with different sale_id.
  static String lineContentFingerprint(Map<String, dynamic> line) {
    final day = _dayKey(line['business_date'] ?? line['sale_date'] ?? line['created_at'] ?? line['date']);
    final product = FormatHelper.normalizeName(
      (line['product_name'] ?? line['product'] ?? line['item'] ?? 'unknown').toString(),
    );
    final qty = _num(line['quantity'] ?? line['qty'], 1).toStringAsFixed(2);
    final price = _num(line['price']).toStringAsFixed(2);
    final total = _num(line['total']).toStringAsFixed(2);
    return '${day}_${product}_${qty}_${price}_$total';
  }

  /// Prefer owner-created local bills over cloud-reimport copies.
  static bool _preferIncomingBill(Map<String, dynamic> existing, Map<String, dynamic> incoming) {
    final eId = (existing['sale_id'] ?? existing['id'] ?? '').toString();
    final iId = (incoming['sale_id'] ?? incoming['id'] ?? '').toString();
    final eCloud = existing['customer_name']?.toString() == 'Cloud Restore' || existing['is_synced'] == true;
    final iCloud = incoming['customer_name']?.toString() == 'Cloud Restore' || incoming['is_synced'] == true;

    if (eId.startsWith('SALE_') && !iId.startsWith('SALE_')) return false;
    if (iId.startsWith('SALE_') && !eId.startsWith('SALE_')) return true;
    if (!eCloud && iCloud) return false;
    if (eCloud && !iCloud) return true;
    return false;
  }

  /// Real bill only — rejects empty/zero rows that polluted dashboards.
  static bool isValidBill(Map<String, dynamic> sale) {
    if (sale['status']?.toString() == 'CANCELLED') return true;
    final total = _num(sale['total']);
    final items = sale['items'] as List? ?? [];
    if (items.isEmpty) {
      final price = _num(sale['price']);
      final qty = _num(sale['quantity'] ?? sale['qty'], 1);
      return price > 0 && qty > 0 && total > 0;
    }
    return total > 0 || items.isNotEmpty;
  }

  /// Remove only true duplicate records. Stable business identities always win;
  /// content similarity alone must NEVER merge two legitimate sales.
  static List<Map<String, dynamic>> dedupeBills(List<dynamic> raw) {
    final byIdentity = <String, Map<String, dynamic>>{};
    final anonymous = <Map<String, dynamic>>[];
    final cancelled = <Map<String, dynamic>>[];

    String identityOf(Map<String, dynamic> sale) {
      const fields = <String>[
        'offline_id',
        'sale_id',
        'invoice_number',
        'backend_id',
        'invoice_id',
        'id',
      ];
      for (final field in fields) {
        final value = sale[field]?.toString().trim();
        if (value != null && value.isNotEmpty && value != 'null' && value != '0') {
          return '${field.toLowerCase()}:$value';
        }
      }
      return '';
    }

    for (final entry in raw) {
      if (entry is! Map) continue;
      final sale = Map<String, dynamic>.from(entry);
      if (!isValidBill(sale)) continue;

      if (sale['status']?.toString().toUpperCase() == 'CANCELLED') {
        cancelled.add(sale);
        continue;
      }

      final identity = identityOf(sale);
      if (identity.isEmpty) {
        // Records without any stable ID cannot safely be merged merely because
        // their contents happen to match. Keep them until a stable identity is
        // assigned by the sale/sync pipeline.
        anonymous.add(sale);
        continue;
      }

      final existing = byIdentity[identity];
      if (existing == null) {
        byIdentity[identity] = sale;
      } else if (_preferIncomingBill(existing, sale)) {
        byIdentity[identity] = sale;
      } else {
        // Preserve useful fields from a richer copy without creating a second
        // business transaction.
        final merged = <String, dynamic>{...existing};
        for (final entry in sale.entries) {
          final value = entry.value;
          final current = merged[entry.key];
          if (current == null || current.toString().trim().isEmpty) {
            merged[entry.key] = value;
          }
        }
        byIdentity[identity] = merged;
      }
    }

    return [...byIdentity.values, ...anonymous, ...cancelled];
  }

  /// Remove duplicate flattened lines shown in charts/transactions.
  /// A content fingerprint is only safe when the line is tied to a stable sale
  /// identity; anonymous lines are preserved because two real sales may have
  /// identical content.
  static List<Map<String, dynamic>> dedupeFlattenedLines(List<Map<String, dynamic>> lines) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];

    for (final line in lines) {
      final saleId = (line['sale_id'] ??
              line['invoice_number'] ??
              line['offline_id'] ??
              line['backend_id'] ??
              '')
          .toString()
          .trim();

      if (saleId.isEmpty) {
        out.add(line);
        continue;
      }

      final fp = lineContentFingerprint(line);
      final compositeKey = '${saleId}_$fp';
      if (seen.contains(compositeKey)) continue;
      seen.add(compositeKey);
      out.add(line);
    }
    return out;
  }

  /// Option B: one-time cleanup — dedupe Hive bills and persist if changed.
  static Future<SalesCleanupResult> cleanupAndPersist() async {
    final raw = await LocalStorageService.loadSales();
    final before = raw.length;
    final deduped = dedupeBills(raw);
    final after = deduped.length;

    if (after < before) {
      await LocalStorageService.saveSales(deduped);
      if (kDebugMode) debugPrint('🧹 Sales cleanup: removed ${before - after} duplicate bills ($after remain)');
    }

    return SalesCleanupResult(before: before, after: after, removed: before - after);
  }

  /// True only when the cloud and local records share a stable business identity.
  /// Content similarity is NEVER sufficient to declare two sales duplicates.
  static bool isDuplicateBill(
    Map<String, dynamic> cloud,
    Iterable<Map<String, dynamic>> localBills,
  ) {
    const fields = <String>[
      'offline_id',
      'sale_id',
      'invoice_number',
      'backend_id',
      'invoice_id',
      'id',
    ];

    String normalize(dynamic value) => value?.toString().trim() ?? '';

    final cloudIds = <String>{};
    for (final field in fields) {
      final value = normalize(cloud[field]);
      if (value.isNotEmpty && value != 'null' && value != '0') {
        cloudIds.add(value);
      }
    }
    if (cloudIds.isEmpty) return false;

    for (final local in localBills) {
      for (final field in fields) {
        final localId = normalize(local[field]);
        if (localId.isNotEmpty && localId != 'null' && localId != '0' && cloudIds.contains(localId)) {
          return true;
        }
      }
    }

    // Never use content fingerprints to merge bills with distinct identities.
    return false;
  }

  /// Group API line rows (one row per item) into bills by sale_id.
  static List<Map<String, dynamic>> groupApiLinesIntoBills(List<dynamic> apiSales) {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final raw in apiSales) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);

      final price = _num(item['price']);
      final qty = _num(item['quantity'] ?? item['qty'], 1);
      if (price <= 0 || qty <= 0) continue;

      final lineTotal = _num(item['total'], CurrencyManager.multiply(price, qty));
      final timestamp = item['sale_date'] ?? item['created_at'] ?? DateTime.now().toUtc().toIso8601String();
      final saleId = (item['sale_id'] ?? item['id'] ?? 'API_${item.hashCode}').toString();
      final product = (item['product'] ?? item['product_name'] ?? item['item'] ?? item['name'] ?? item['itemName'] ?? item['title'] ?? '').toString().trim();

      if (product.isEmpty || product.toLowerCase() == 'unknown' || product.toLowerCase() == 'unknown item' || product.toLowerCase() == 'product') {
        if (kDebugMode) debugPrint('Skipping invalid restored record: $saleId');
        continue;
      }
      
      if (kDebugMode) {
        debugPrint('SALE RESTORED:\ninvoice_number: $saleId\nproduct_name: $product\nquantity: $qty\nprice: $price');
      }

      grouped.putIfAbsent(saleId, () => {
        'sale_id': saleId,
        'customer_name': item['customer_name'] ?? 'Cloud Restore',
        'items': <Map<String, dynamic>>[],
        'sale_date': timestamp,
        'created_at': timestamp,
        'date': timestamp,
        'total': 0.0,
        'paid_amount': 0.0,
        'payment_status': 'PAID',
        'is_synced': true,
      });

      final bill = grouped[saleId]!;
      (bill['items'] as List).add({
        'product_name': product,
        'item': product,
        'qty': qty,
        'quantity': qty,
        'price': price,
        'total': lineTotal,
        'total_with_tax': lineTotal,
      });
      bill['total'] = _num(bill['total']) + lineTotal;
      bill['paid_amount'] = bill['total'];
    }

    return grouped.values.map((b) => Map<String, dynamic>.from(b)).toList();
  }
}
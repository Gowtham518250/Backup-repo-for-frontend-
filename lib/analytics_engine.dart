import 'package:flutter/foundation.dart';
import 'format_helper.dart';
import 'financial_math.dart';

class AnalyticsEngine {
  // ── Helper: Format product name / fallback guard ──────────────
  static bool isPlaceholderProductName(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return true;
    const generic = {
      'product', 'unknown', 'unknown item', 'cloud item', 'item', 'invoice',
      'guest', 'guest product', 'cash product', 'n/a', '-', '—',
    };
    if (generic.contains(value)) return true;
    if (RegExp(r'^sale[_ -]?\d+', caseSensitive: false).hasMatch(value)) return true;
    if (RegExp(r'^(invoice|order|transaction)[_-]\d+', caseSensitive: false).hasMatch(value)) return true;
    return false;
  }

  static String formatProductName(String raw) {
    final value = raw.trim();
    if (isPlaceholderProductName(value)) return 'Unknown';
    return value.split(RegExp(r'\s+')).map((word) =>
      word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase()
    ).join(' ');
  }

  // Backward-compatible instance helper for older widgets/services.
  bool isPlaceholderProductNameLegacy(String? raw) => isPlaceholderProductName(raw ?? '');

  List<dynamic> sales = [];
  int selectedTimeFilter = 0;

  List<Map<String, dynamic>> filteredSalesCache = [];
  Map<String, double> salesByMonthCache = {};
  Map<String, double> salesByWeekCache = {};
  Map<String, double> salesByYearCache = {};
  Map<String, Map<String, dynamic>> productAnalyticsCache = {};
  Map<String, Map<int, double>> monthlyProductSales = {}; // Added for Dashboard compatibility

  // ═══ Metrics ═══
  double totalSales = 0.0;
  int totalTransactions = 0;
  double averageSale = 0.0;
  int uniqueProducts = 0;
  double growthPercentage = 0.0;
  int totalOnlineOrders = 0; // 🔒 NEW: Track online orders
  
  double filteredTotalSales = 0.0;
  int filteredTotalTransactions = 0;
  double filteredAverageSale = 0.0;
  int filteredUniqueProducts = 0;
  double filteredGrowthPercentage = 0.0;
  int filteredOnlineOrders = 0; // 🔒 NEW: Track filtered online orders
  final List<String> analyticsIntegrityErrors = [];
  
  double todayRevenue = 0.0;
  double yesterdayRevenue = 0.0;
  int todayTransactionsCount = 0;
  int todayOnlineOrders = 0;
  String todayTopProduct = '';
  String todayBestHourLabel = '';
  int yesterdayTransactionsCount = 0;
  String yesterdayTopProduct = '';
  String yesterdayBestHourLabel = '';
  double previousDayRevenue = 0.0;

  // Compatibility Getters for Dashboard
  double get todaySalesValue => todayRevenue;
  int get todayTransactionsValue => todayTransactionsCount;
  
  // FIX: Access salesByMonthCache for current month revenue
  double get monthlyRevenue {
    final now = DateTime.now();
    final currentMon = '${_months[now.month - 1]} ${now.year.toString().substring(2)}';
    return salesByMonthCache[currentMon] ?? 0.0;
  }

  String _transactionKey(Map<String, dynamic> sale) {
    for (final field in const ['invoice_id', 'backend_id', 'sale_id', 'invoice_number', 'id']) {
      final value = sale[field]?.toString().trim().toLowerCase() ?? '';
      if (value.isNotEmpty && value != 'null') return value;
    }
    return '';
  }

  // FIX-A: Filter-aware display getters for KPI cards
  /// Period-filtered metrics for analytics screens.
  double get displayRevenue {
    return filteredTotalSales;
  }

  int get displayTransactions {
    return filteredTotalTransactions;
  }

  /// Lifetime metrics for dashboard headline KPIs.
  double get lifetimeRevenue => totalSales;
  int get lifetimeTransactions => totalTransactions;

  /// Gross invoiced value for the current filter.
  double get displayInvoiced => displayRevenue;

  /// Cash/UPI/etc. actually collected for the current filter.
  double get displayCollected {
    return filteredSalesCache.fold(0.0, (sum, t) {
      final collected = _toDouble(t['collected_revenue']);
      if (collected > 0) return sum + collected;
      final total = _toDouble(t['gross_revenue'] ?? t['total_amount'] ?? t['total']);
      return sum + _toDouble(t['paid_amount']).clamp(0.0, total).toDouble();
    });
  }

  /// Outstanding amount for the current filter.
  double get displayOutstanding {
    return filteredSalesCache.fold(0.0, (sum, t) {
      final outstanding = _toDouble(t['outstanding_amount']);
      if (outstanding > 0) return sum + outstanding;
      final total = _toDouble(t['gross_revenue'] ?? t['total_amount'] ?? t['total']);
      final paid = _toDouble(t['paid_amount']);
      return sum + (total - paid).clamp(0.0, double.infinity).toDouble();
    });
  }

  List<Map<String, dynamic>> recentSales = [];

  static const List<String> _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  /// Parse sale date with multiple format support and force Indian Time (IST)
  DateTime getLocalDate(Map<String, dynamic> sale) {
    try {
      String str = (sale['business_date'] ?? '').toString().trim();
      final hasTime = str.contains('T') || RegExp(r'\d{2}:\d{2}').hasMatch(str);
      if (str.isEmpty || !hasTime) {
        for (final field in const ['sale_timestamp', 'invoice_timestamp', 'created_at', 'createdAt', 'timestamp', 'sale_date', 'invoice_date', 'date']) {
          final candidate = (sale[field] ?? '').toString().trim();
          if (candidate.isNotEmpty) { str = candidate; if (candidate.contains('T') || RegExp(r'\d{2}:\d{2}').hasMatch(candidate)) break; }
        }
      }
      if (str.isEmpty) return DateTime(1970);
      
      if (kDebugMode) debugPrint('🔍 Date parsing: "$str", is_local: ${sale['is_local']}, available fields: ${sale.keys.join(', ')}');
      
      // If it's just a date (YYYY-MM-DD), convert to datetime at start of day in IST
      if (str.length == 10 && str.contains('-')) {
        final parts = str.split('-');
        if (parts.length == 3) {
          final year = int.tryParse(parts[0]) ?? 1970;
          final month = int.tryParse(parts[1]) ?? 1;
          final day = int.tryParse(parts[2]) ?? 1;
          final date = DateTime(year, month, day);
          // Return as IST (already at midnight)
          return date;
        }
      }
      
      DateTime? parsed = DateTime.tryParse(str);
      if (parsed == null) {
        if (kDebugMode) debugPrint('❌ Failed to parse date: $str');
        return DateTime(1970);
      }
      
        // Explicit-zone timestamps are converted to IST. Zone-less backend
        // timestamps are treated as business-local values, never as UTC.
        final hasExplicitZone = str.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(str);
        final istTime = hasExplicitZone
          ? parsed.toUtc().add(const Duration(hours: 5, minutes: 30))
          : DateTime(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute, parsed.second, parsed.millisecond, parsed.microsecond);
      
      if (kDebugMode) debugPrint('✅ Date: "$str" → $istTime (IST)');
      
      return istTime;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Date parsing error: $e');
      return DateTime(1970);
    }
  }

  /// Timestamp used for intraday charts such as Best Hour. Prefer the real
  /// creation timestamp; business_date is often date-only and would otherwise
  /// collapse every sale into 00:00 (or midnight), producing a fake Best Hour.
  DateTime getEventDate(Map<String, dynamic> sale) {
    final value = sale['sale_timestamp'] ?? sale['invoice_timestamp'] ??
        sale['created_at'] ?? sale['updated_at'] ?? sale['timestamp'] ?? sale['createdAt'];
    if (value != null && value.toString().trim().isNotEmpty) {
      final parsed = _parseFlexibleDate(value.toString());
      if (parsed != null) return parsed;
    }
    return getLocalDate(sale);
  }

  DateTime? _parseFlexibleDate(String str) {
    final parsed = DateTime.tryParse(str.trim());
    if (parsed == null) return null;
    final hasExplicitZone = str.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(str);
    return hasExplicitZone
        ? parsed.toUtc().add(const Duration(hours: 5, minutes: 30))
        : DateTime(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute, parsed.second, parsed.millisecond, parsed.microsecond);
  }

  DateTime? _tryGetBusinessDate(Map<String, dynamic> sale) {
    final value = sale['business_date'] ?? sale['sale_date'] ?? sale['invoice_date'] ?? sale['date'];
    if (value == null || value.toString().trim().isEmpty) return null;
    final parsed = getLocalDate(sale);
    return parsed.year == 1970 && parsed.month == 1 && parsed.day == 1 ? null : parsed;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    try {
      // Remove everything except numbers, dots, and negative signs
      String cleaned = v.toString().replaceAll(RegExp(r'[^0-9.\-]'), '');
      if (cleaned.isEmpty || cleaned == '.' || cleaned == '-') return 0.0;
      return double.tryParse(cleaned) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  /// Canonical transaction key. Prefer the offline/business identity so a
  /// locally-created sale and its cloud invoice collapse into one transaction.
  String _canonicalTransactionKey(Map<String, dynamic> sale) {
    const fields = [
      'offline_id',
      'sale_id',
      'invoice_number',
      'invoice_id',
      'backend_id',
      'id',
    ];
    for (final field in fields) {
      final value = sale[field]?.toString().trim().toLowerCase() ?? '';
      if (value.isNotEmpty && value != 'null' && value != '0') return value;
    }

    final date = (sale['business_date'] ?? sale['invoice_date'] ?? sale['sale_date'] ?? '').toString();
    final created = (sale['created_at'] ?? sale['timestamp'] ?? '').toString();
    final phone = (sale['customer_phone'] ?? sale['phone'] ?? '').toString().trim();
    final total = _toDouble(sale['total_amount'] ?? sale['total']);
    final items = sale['items'] ?? sale['line_items'];
    final itemParts = <String>[];
    if (items is List) {
      for (final raw in items) {
        if (raw is! Map) continue;
        final name = (raw['product_id'] ?? raw['product_name'] ?? raw['product'] ?? raw['item'] ?? '').toString().trim().toLowerCase();
        final qty = _toDouble(raw['quantity'] ?? raw['qty']).toStringAsFixed(3);
        final price = _toDouble(raw['unit_price'] ?? raw['price']).toStringAsFixed(2);
        itemParts.add('$name:$qty:$price');
      }
      itemParts.sort();
    }
    return 'fallback|$date|$created|$phone|${total.toStringAsFixed(2)}|${itemParts.join(';')}';
  }

  Map<String, dynamic> _mergeCanonicalTransaction(
    Map<String, dynamic> current,
    Map<String, dynamic> incoming,
  ) {
    final currentUpdated = DateTime.tryParse(current['updated_at']?.toString() ?? '');
    final incomingUpdated = DateTime.tryParse(incoming['updated_at']?.toString() ?? '');
    final incomingIsNewer = incomingUpdated != null &&
        (currentUpdated == null || incomingUpdated.isAfter(currentUpdated));

    Map<String, dynamic> merged = {
      ...current,
      if (incomingIsNewer) ...incoming,
    };

    // Prefer real customer data over generic placeholders.
    final currentName = (current['customer_name'] ?? '').toString().trim();
    final incomingName = (incoming['customer_name'] ?? '').toString().trim();
    if ((currentName.isEmpty || currentName == 'Guest Customer' || currentName == 'Cash Customer') &&
        incomingName.isNotEmpty && incomingName != 'Guest Customer' && incomingName != 'Cash Customer') {
      merged['customer_name'] = incomingName;
    }
    final currentPhone = (current['customer_phone'] ?? '').toString().trim();
    final incomingPhone = (incoming['customer_phone'] ?? '').toString().trim();
    if (currentPhone.isEmpty && incomingPhone.isNotEmpty) {
      merged['customer_phone'] = incomingPhone;
    }

    // Merge line items without duplicating the same line from local + cloud copies.
    final lines = <Map<String, dynamic>>[];
    void addLines(dynamic raw) {
      if (raw is! List) return;
      for (final value in raw) {
        if (value is! Map) continue;
        final line = Map<String, dynamic>.from(value);
        final productId = (line['product_id'] ?? line['id'] ?? '').toString().trim();
        final name = (line['product_name'] ?? line['product'] ?? line['item'] ?? line['description'] ?? '').toString().trim().toLowerCase();
        final qty = _toDouble(line['quantity'] ?? line['qty']);
        final price = _toDouble(line['unit_price'] ?? line['price']);
        final key = '$productId|$name|${qty.toStringAsFixed(3)}|${price.toStringAsFixed(2)}';
        if (!lines.any((existing) {
          final eProductId = (existing['product_id'] ?? existing['id'] ?? '').toString().trim();
          final eName = (existing['product_name'] ?? existing['product'] ?? existing['item'] ?? existing['description'] ?? '').toString().trim().toLowerCase();
          final eQty = _toDouble(existing['quantity'] ?? existing['qty']);
          final ePrice = _toDouble(existing['unit_price'] ?? existing['price']);
          return '$eProductId|$eName|${eQty.toStringAsFixed(3)}|${ePrice.toStringAsFixed(2)}' == key;
        })) {
          lines.add(line);
        }
      }
    }
    addLines(current['items'] ?? current['line_items']);
    addLines(incoming['items'] ?? incoming['line_items']);
    if (lines.isNotEmpty) merged['items'] = lines;

    // Keep the strongest monetary values. Paid amount is monotonic for normal
    // retail payments and therefore using the larger value prevents a cloud
    // copy with stale paid_amount=0 from erasing a locally recorded payment.
    final currentTotal = _toDouble(current['total_amount'] ?? current['total']);
    final incomingTotal = _toDouble(incoming['total_amount'] ?? incoming['total']);
    if (incomingTotal > 0 || currentTotal == 0) merged['total_amount'] = incomingTotal > 0 ? incomingTotal : currentTotal;
    final currentPaid = _toDouble(current['paid_amount']);
    final incomingPaid = _toDouble(incoming['paid_amount']);
    merged['paid_amount'] = currentPaid > incomingPaid ? currentPaid : incomingPaid;

    if (current['sync_status']?.toString().toLowerCase() == 'synced' ||
        incoming['sync_status']?.toString().toLowerCase() == 'synced' ||
        incoming['is_synced'] == true) {
      merged['sync_status'] = 'synced';
      merged['is_synced'] = true;
    }
    merged['transaction_key'] = _canonicalTransactionKey(merged);
    return merged;
  }

  /// Build one canonical transaction per business sale/invoice.
  /// Analytics must never count a local sale and its cloud invoice twice.
  List<Map<String, dynamic>> _canonicalizeTransactions(List<dynamic> rawSales) {
    final Map<String, Map<String, dynamic>> byKey = {};
    for (final raw in rawSales) {
      if (raw is! Map) continue;
      final record = Map<String, dynamic>.from(raw);
      final key = _canonicalTransactionKey(record);
      if (!byKey.containsKey(key)) {
        record['transaction_key'] = key;
        byKey[key] = record;
      } else {
        byKey[key] = _mergeCanonicalTransaction(byKey[key]!, record);
      }
    }
    return byKey.values.toList();
  }

  /// 🚀 Production analytics: one canonical transaction pass.
  /// Revenue is gross invoice/sale value. Collected cash is tracked separately.
  void recalculateAnalytics(List<dynamic> newSales, int timeFilter) {
    selectedTimeFilter = timeFilter;

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));
    final prevDayDate = todayDate.subtract(const Duration(days: 2));
    final normalizedNow = todayDate;

    final canonicalTransactions = _canonicalizeTransactions(newSales);
    sales = canonicalTransactions;

    todayRevenue = 0.0;
    yesterdayRevenue = 0.0;
    previousDayRevenue = 0.0;
    todayTransactionsCount = 0;
    yesterdayTransactionsCount = 0;
    todayOnlineOrders = 0;
    totalOnlineOrders = 0;
    filteredOnlineOrders = 0;
    totalSales = 0.0;
    filteredTotalSales = 0.0;
    totalTransactions = 0;
    filteredTotalTransactions = 0;
    averageSale = 0.0;
    filteredAverageSale = 0.0;
    uniqueProducts = 0;
    filteredUniqueProducts = 0;
    analyticsIntegrityErrors.clear();

    final todayProductRevenue = <String, double>{};
    final yesterdayProductRevenue = <String, double>{};
    final todayHourRevenue = <int, double>{};
    final yesterdayHourRevenue = <int, double>{};
    final todayKeys = <String>{};
    final yesterdayKeys = <String>{};
    final onlineKeys = <String>{};

    salesByMonthCache = {};
    for (int i = 11; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final mon = '${_months[d.month - 1]} ${d.year.toString().substring(2)}';
      salesByMonthCache[mon] = 0.0;
    }
    salesByWeekCache = {for (int i = 1; i <= 8; i++) 'w$i': 0.0};
    salesByYearCache = {};
    monthlyProductSales = {};

    String lineKey(Map<String, dynamic> item) {
      final id = (item['product_id'] ?? item['id'] ?? '').toString().trim();
      final name = (item['product_name'] ?? item['product'] ?? item['item'] ?? item['description'] ?? '').toString().trim().toLowerCase();
      final qty = _toDouble(item['quantity'] ?? item['qty']);
      final price = _toDouble(item['unit_price'] ?? item['price']);
      return '$id|$name|${qty.toStringAsFixed(3)}|${price.toStringAsFixed(2)}';
    }

    final transactionsWithDates = <Map<String, dynamic>>[];
    for (final transaction in canonicalTransactions) {
      final dt = _tryGetBusinessDate(transaction);
      if (dt == null) {
        analyticsIntegrityErrors.add('Missing or invalid business date for ${transaction['transaction_key'] ?? _canonicalTransactionKey(transaction)}');
        continue;
      }

      final gross = _toDouble(transaction['total_amount'] ?? transaction['total']);
      final paid = _toDouble(transaction['paid_amount']);
      final double outstanding = (gross - paid).clamp(0.0, double.infinity).toDouble();
      final status = (transaction['payment_status'] ?? transaction['status'] ?? '').toString().toUpperCase();
      final double collected = paid > gross && gross > 0 ? gross : paid.clamp(0.0, gross).toDouble();

      transaction['gross_revenue'] = gross;
      transaction['collected_revenue'] = collected;
      transaction['outstanding_amount'] = outstanding;
      // Keep this key for compatibility with existing widgets, but make it
      // gross revenue so unpaid Udhaar does not incorrectly make sales = ₹0.
      transaction['recognized_revenue'] = gross;
      transaction['payment_status_normalized'] = status.isEmpty
          ? (collected >= gross && gross > 0 ? 'PAID' : collected > 0 ? 'PARTIAL' : 'UNPAID')
          : status;
      transaction['transaction_key'] = _canonicalTransactionKey(transaction);
      transactionsWithDates.add(transaction);

      final key = transaction['transaction_key'].toString();
      if (dt.year == now.year) {
        final mon = '${_months[dt.month - 1]} ${dt.year.toString().substring(2)}';
        salesByMonthCache[mon] = (salesByMonthCache[mon] ?? 0.0) + gross;
      }
      salesByYearCache['${dt.year}'] = (salesByYearCache['${dt.year}'] ?? 0.0) + gross;
      final day = DateTime(dt.year, dt.month, dt.day);
      final daysDiff = normalizedNow.difference(day).inDays;
      if (daysDiff >= 0 && daysDiff < 56) {
        final wk = 8 - (daysDiff ~/ 7);
        final wkLabel = 'w$wk';
        if (salesByWeekCache.containsKey(wkLabel)) {
          salesByWeekCache[wkLabel] = (salesByWeekCache[wkLabel] ?? 0.0) + gross;
        }
      }

      final eventDt = getEventDate(transaction);
      if (day == todayDate) {
        todayRevenue += gross;
        todayKeys.add(key);
        todayHourRevenue[eventDt.hour] = (todayHourRevenue[eventDt.hour] ?? 0.0) + gross;
      } else if (day == yesterdayDate) {
        yesterdayRevenue += gross;
        yesterdayKeys.add(key);
        yesterdayHourRevenue[eventDt.hour] = (yesterdayHourRevenue[eventDt.hour] ?? 0.0) + gross;
      } else if (day == prevDayDate) {
        previousDayRevenue += gross;
      }

      final source = (transaction['source'] ?? transaction['order_source'] ?? 'OFFLINE').toString().toUpperCase();
      if (source == 'ONLINE' || source == 'WEB' || source == 'APP') onlineKeys.add(key);

      final lines = transaction['items'] ?? transaction['line_items'];
      if (lines is List) {
        final seenLines = <String>{};
        for (final rawLine in lines) {
          if (rawLine is! Map) continue;
          final item = Map<String, dynamic>.from(rawLine);
          final lk = lineKey(item);
          if (!seenLines.add(lk)) continue;
          final productName = formatProductName(
            (item['product_name'] ?? item['product'] ?? item['item'] ?? item['description'] ?? 'Unknown').toString(),
          );
          if (productName == 'Unknown') continue;
          final quantity = _toDouble(item['quantity'] ?? item['qty']);
          final lineGross = _toDouble(item['line_total'] ?? item['total_with_tax'] ?? item['total']) > 0
              ? _toDouble(item['line_total'] ?? item['total_with_tax'] ?? item['total'])
              : CurrencyManager.multiply(_toDouble(item['unit_price'] ?? item['price']), quantity);
          todayProductRevenue[productName] = (todayProductRevenue[productName] ?? 0) + (day == todayDate ? lineGross : 0);
          yesterdayProductRevenue[productName] = (yesterdayProductRevenue[productName] ?? 0) + (day == yesterdayDate ? lineGross : 0);
          if (dt.year == now.year) {
            monthlyProductSales.putIfAbsent(productName, () => {});
            monthlyProductSales[productName]![dt.month] = (monthlyProductSales[productName]![dt.month] ?? 0.0) + lineGross;
          }
        }
      }
    }

    final sortedTransactions = transactionsWithDates;
    final filtered = sortedTransactions.where((transaction) {
      final dt = _tryGetBusinessDate(transaction);
      if (dt == null) return false;
      final daysAgo = normalizedNow.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
      if (selectedTimeFilter == 0) return daysAgo == 0;
      if (selectedTimeFilter == 1) return daysAgo >= 0 && daysAgo < 7;
      if (selectedTimeFilter == 2) return daysAgo >= 0 && daysAgo < 30;
      if (selectedTimeFilter == 3) return dt.year == now.year;
      return true;
    }).toList();

    filteredSalesCache = filtered;
    filteredTotalSales = filtered.fold(0.0, (sum, t) => sum + _toDouble(t['gross_revenue']));
    filteredTotalTransactions = filtered.length;
    filteredAverageSale = filtered.isEmpty ? 0.0 : filteredTotalSales / filtered.length;
    filteredOnlineOrders = filtered.where((t) {
      final source = (t['source'] ?? t['order_source'] ?? 'OFFLINE').toString().toUpperCase();
      return source == 'ONLINE' || source == 'WEB' || source == 'APP';
    }).map((t) => t['transaction_key'].toString()).toSet().length;

    totalSales = sortedTransactions.fold(0.0, (sum, t) => sum + _toDouble(t['gross_revenue']));
    totalTransactions = sortedTransactions.length;
    averageSale = totalTransactions == 0 ? 0.0 : totalSales / totalTransactions;
    totalOnlineOrders = onlineKeys.length;
    todayTransactionsCount = todayKeys.length;
    yesterdayTransactionsCount = yesterdayKeys.length;
    todayOnlineOrders = filtered.where((t) {
      final dt = _tryGetBusinessDate(t);
      final source = (t['source'] ?? t['order_source'] ?? 'OFFLINE').toString().toUpperCase();
      return dt != null && DateTime(dt.year, dt.month, dt.day) == todayDate &&
          (source == 'ONLINE' || source == 'WEB' || source == 'APP');
    }).map((t) => t['transaction_key'].toString()).toSet().length;

    final productKeys = <String>{};
    final filteredProductKeys = <String>{};
    productAnalyticsCache = {};
    void addProductAnalytics(Map<String, dynamic> transaction, bool includeFiltered) {
      final lines = transaction['items'] ?? transaction['line_items'];

      // Normal path: invoice contains line items.
      if (lines is List) {
        final seenLines = <String>{};
        for (final rawLine in lines) {
          if (rawLine is! Map) continue;
          final item = Map<String, dynamic>.from(rawLine);
          final lk = lineKey(item);
          if (!seenLines.add(lk)) continue;
          final id = (item['product_id'] ?? item['id'] ?? item['barcode'] ?? '').toString().trim();
          final rawName = (item['product_name'] ?? item['product'] ?? item['item'] ?? item['description'] ?? 'Unknown').toString();
          final key = id.isNotEmpty && id != '0' ? id : FormatHelper.normalizeName(rawName);
          final name = formatProductName(rawName);
          if (key.isEmpty || name == 'Unknown') continue;
          final q = _toDouble(item['quantity'] ?? item['qty']);
          final value = _toDouble(item['line_total'] ?? item['total_with_tax'] ?? item['total']) > 0
              ? _toDouble(item['line_total'] ?? item['total_with_tax'] ?? item['total'])
              : CurrencyManager.multiply(_toDouble(item['unit_price'] ?? item['price']), q);
          productKeys.add(key);
          if (includeFiltered) filteredProductKeys.add(key);
          final data = productAnalyticsCache.putIfAbsent(key, () => {
            'total': 0.0,
            'count': 0,
            'quantity': 0.0,
            'name': name,
            'display_name': name,
          });
          if (includeFiltered) {
            data['total'] = (data['total'] as double) + value;
            data['count'] = (data['count'] as int) + 1;
            data['quantity'] = (data['quantity'] as double) + q;
          }
        }
        return;
      }

      // Fallback: some restored/legacy sales are already flattened and carry
      // product fields directly on the transaction instead of line_items.
      final rawName = (transaction['product_name'] ??
              transaction['product'] ??
              transaction['item'] ??
              transaction['name'] ??
              '')
          .toString()
          .trim();
      if (rawName.isEmpty) return;

      final id = (transaction['product_id'] ??
              transaction['barcode'] ??
              '')
          .toString()
          .trim();
      final key = id.isNotEmpty && id != '0'
          ? id
          : FormatHelper.normalizeName(rawName);
      final name = formatProductName(rawName);
      if (key.isEmpty || name == 'Unknown') return;

      final q = _toDouble(transaction['quantity'] ?? transaction['qty']);
      final value = _toDouble(
        transaction['line_total'] ??
            transaction['total_with_tax'] ??
            transaction['total'] ??
            transaction['total_amount'],
      );

      productKeys.add(key);
      if (includeFiltered) filteredProductKeys.add(key);
      final data = productAnalyticsCache.putIfAbsent(key, () => {
        'total': 0.0,
        'count': 0,
        'quantity': 0.0,
        'name': name,
        'display_name': name,
      });
      if (includeFiltered) {
        data['total'] = (data['total'] as double) + value;
        data['count'] = (data['count'] as int) + 1;
        data['quantity'] = (data['quantity'] as double) + q;
      }
    }
    for (final t in sortedTransactions) {
      addProductAnalytics(t, filtered.contains(t));
    }
    uniqueProducts = productKeys.length;
    filteredUniqueProducts = filteredProductKeys.length;
    if (filteredTotalSales > 0) {
      productAnalyticsCache.forEach((key, data) {
        data['percentage'] = ((data['total'] as double) / filteredTotalSales) * 100;
      });
    }

    todayTopProduct = todayProductRevenue.isEmpty
        ? ''
        : todayProductRevenue.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    yesterdayTopProduct = yesterdayProductRevenue.isEmpty
        ? ''
        : yesterdayProductRevenue.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    todayBestHourLabel = _findBestHour(todayHourRevenue);
    yesterdayBestHourLabel = _findBestHour(yesterdayHourRevenue);

    recentSales = List<Map<String, dynamic>>.from(filtered)
      ..sort((a, b) => getLocalDate(b).compareTo(getLocalDate(a)));
    recentSales = recentSales.take(5).toList();

    if (filtered.isEmpty) {
      filteredGrowthPercentage = 0.0;
    } else {
      _calculateGrowth(timeFilter);
    }
    growthPercentage = filteredGrowthPercentage;

    if (kDebugMode) {
      debugPrint('📊 Canonical analytics: ${sortedTransactions.length} transactions, gross sales ₹$totalSales');
    }
  }

  /// FIX-6 R2: Growth calculation — compare against meaningful baseline per time filter
  void _calculateGrowth(int timeFilter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    double current = 0, previous = 0;

    if (timeFilter == 0) {
      // Today vs Yesterday
      current = todayRevenue;
      previous = yesterdayRevenue;
    } else if (timeFilter == 1) {
      // This week vs last week (Monday-based weeks)
      final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
      final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
      for (final s in sales) {
        final sMap = Map<String, dynamic>.from(s as Map);
        final dt = getLocalDate(sMap);
        final val = _toDouble(sMap['recognized_revenue'] ?? sMap['total']);
        final saleDay = DateTime(dt.year, dt.month, dt.day);
        
        if (!saleDay.isBefore(thisWeekStart) && saleDay.isBefore(today.add(const Duration(days: 1)))) {
          current += val; // This week
        } else if (!saleDay.isBefore(lastWeekStart) && saleDay.isBefore(thisWeekStart)) {
          previous += val; // Last week
        }
      }
    } else if (timeFilter == 2) {
      // This month vs last month
      final thisMonthStart = DateTime(now.year, now.month, 1);
      final lastMonthStart = now.month == 1
          ? DateTime(now.year - 1, 12, 1)
          : DateTime(now.year, now.month - 1, 1);
      for (final s in sales) {
        final sMap = Map<String, dynamic>.from(s as Map);
        final dt = getLocalDate(sMap);
        final val = _toDouble(sMap['recognized_revenue'] ?? sMap['total']);
        
        if (!dt.isBefore(thisMonthStart)) {
          current += val; // This month
        } else if (!dt.isBefore(lastMonthStart) && dt.isBefore(thisMonthStart)) {
          previous += val; // Last month
        }
      }
    } else if (timeFilter == 3) {
      // Year-over-Year growth: This year vs Previous year
      final thisYear = now.year;
      final prevYear = now.year - 1;
      for (final s in sales) {
        final sMap = Map<String, dynamic>.from(s as Map);
        final dt = getLocalDate(sMap);
        final val = _toDouble(sMap['recognized_revenue'] ?? sMap['total']);
        
        if (dt.year == thisYear) {
          current += val;
        } else if (dt.year == prevYear) {
          previous += val;
        }
      }
    }

    // 🔒 BUG FIX: Calculate and set BOTH growth percentage variables
    final calculatedGrowth = previous == 0
        ? (current > 0 ? 100.0 : 0.0)
        : ((current - previous) / previous) * 100;
    
    filteredGrowthPercentage = calculatedGrowth;
    growthPercentage = calculatedGrowth; // 🔒 FIX: Also set the main growthPercentage
  }

  String _findBestHour(Map<int, double> hourRevenue) {
    if (hourRevenue.isEmpty) return 'No Sales';
    double maxVal = -1;
    int bestH = -1;
    hourRevenue.forEach((h, v) {
      if (v > maxVal) { maxVal = v; bestH = h; }
    });
    if (bestH < 0 || maxVal <= 0) return 'No Sales';
    return _formatHourRange(bestH);
  }

  String _formatHourRange(int hour) {
    String fmt(int h) {
      if (h == 0) return '12 AM';
      if (h < 12) return '$h AM';
      if (h == 12) return '12 PM';
      return '${h - 12} PM';
    }
    return '${fmt(hour)} - ${fmt((hour + 1) % 24)}';
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'dart:convert';
import 'local_storage_service.dart';
import 'whatsapp_message_service.dart';
import 'api_client.dart';
import 'sync_queue_manager.dart';
import 'sync_service.dart';
import 'visual_widgets.dart';
import 'paid_invoices_page.dart';

class KhataPage extends StatefulWidget {
  final String? focusPhone;
  const KhataPage({super.key, this.focusPhone});

  static _KhataPageState? _state;
  static void refreshKhata() {
    _state?._loadKhata();
    _state?._loadInvoiceAnalytics();
  }

  @override
  State<KhataPage> createState() => _KhataPageState();
}

class _KhataPageState extends State<KhataPage> with SingleTickerProviderStateMixin {
  static const Color _primary = AppColors.primary;     // #635BFF
  static const Color _danger = Color(0xFFEF4444);      // Red
  static const Color _success = Color(0xFF10B981);     // Green
  static const Color _warning = Color(0xFFF59E0B);     // Amber

  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  
  // Analytics State
  double _totalOutstanding = 0.0;
  double _totalOverdue = 0.0;
  double _collectedToday = 0.0;
  double _dueThisWeek = 0.0;
  int _pendingCount = 0;
  int _overdueCount = 0;

  bool _loading = true;
  String _searchQuery = '';
  String _activeFilter = 'ALL'; // ALL, OVERDUE, HIGH_BALANCE
  final TextEditingController _searchController = TextEditingController();

  // ── Invoice Analytics Tab State ──
  late final TabController _tabController;
  bool _invoicesLoading = true;
  bool _invoiceLoadInProgress = false;
  List<Map<String, dynamic>> _allInvoices = [];
  String _invoiceStatusFilter = 'ALL'; // ALL, PAID, PARTIAL, UNPAID
  double _invoicedTotal = 0.0;
  double _paidTotal = 0.0;
  double _pendingTotal = 0.0;
  int _paidCount = 0;
  int _partialCount = 0;
  int _unpaidCount = 0;

  // Search / sort for invoice list
  String _invoiceSearchQuery = '';
  final TextEditingController _invoiceSearchController = TextEditingController();
  String _invoiceSortOption = 'DATE_DESC'; // DATE_DESC, DATE_ASC, AMOUNT_DESC, AMOUNT_ASC, STATUS

  // Top customers ranked by UNCLEARED (outstanding) amount, not total revenue
  List<Map<String, dynamic>> _topOutstandingCustomers = [];

  @override
  void initState() {
    super.initState();
    KhataPage._state = this;
    _tabController = TabController(length: 2, vsync: this);
    
    // Load local data immediately
    _loadKhata();
    _loadInvoiceAnalytics();
    
    // Sync with backend after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _loadKhata();
        _loadInvoiceAnalytics();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _invoiceSearchController.dispose();
    _tabController.dispose();
    if (KhataPage._state == this) {
      KhataPage._state = null;
    }
    super.dispose();
  }

  /// Canonicalize local invoices + sales so one business transaction is counted once.
  /// A business invoice may exist in local invoice storage, sales history and
  /// a restored backend record with different identifier fields. Merge those
  /// representations before calculating totals or rendering cards.
  Map<String, Map<String, dynamic>> _canonicalInvoiceMap(
    List<dynamic> invoices,
    List<dynamic> sales,
  ) {
    final canonical = <String, Map<String, dynamic>>{};
    final aliasToCanonical = <String, String>{};
    int sequence = 0;

    List<String> aliases(Map<String, dynamic> row) {
      final values = <String>[];
      for (final field in const [
        'invoice_number',
        'number',
        'sale_id',
        'offline_id',
        'invoice_id',
        'backend_id',
        'id',
      ]) {
        final value = row[field]?.toString().trim().toLowerCase() ?? '';
        if (value.isNotEmpty && value != 'null' && value != '0') {
          // Preserve the original field alias and add a shared transaction
          // alias so different representations (invoice_number vs sale_id)
          // resolve to the same logical invoice.
          values.add('$field:$value');
          values.add('transaction:$value');
        }
      }
      return values;
    }

    String fallbackKey(Map<String, dynamic> row) {
      final date = (row['business_date'] ??
              row['invoice_date'] ??
              row['sale_date'] ??
              row['date'] ??
              row['created_at'] ??
              '')
          .toString();
      final phone =
          (row['customer_phone'] ?? row['phone'] ?? '').toString().trim();
      final total = double.tryParse(
            (row['total_amount'] ?? row['total'] ?? 0).toString(),
          ) ??
          0.0;
      return 'fallback|$date|$phone|${total.toStringAsFixed(2)}';
    }

    void add(dynamic raw, {bool prefer = false}) {
      if (raw is! Map) return;

      final row = Map<String, dynamic>.from(raw);
      final rowAliases = aliases(row);

      String? existingKey;
      for (final alias in rowAliases) {
        final mapped = aliasToCanonical[alias];
        if (mapped != null) {
          existingKey = mapped;
          break;
        }
      }

      final key = existingKey ??
          (rowAliases.isNotEmpty ? rowAliases.first : fallbackKey(row));

      if (existingKey == null) {
        canonical[key] = row;
      } else {
        final existing = canonical[key]!;
        final existingUpdated =
            DateTime.tryParse(existing['updated_at']?.toString() ?? '');
        final incomingUpdated =
            DateTime.tryParse(row['updated_at']?.toString() ?? '');
        final incomingNewer = incomingUpdated != null &&
            (existingUpdated == null ||
                incomingUpdated.isAfter(existingUpdated));

        if (incomingNewer || prefer) {
          canonical[key] = {
            ...existing,
            ...row,
          };
        } else {
          canonical[key] = {
            ...row,
            ...existing,
            if ((existing['customer_phone'] ?? '').toString().trim().isEmpty &&
                (row['customer_phone'] ?? '').toString().trim().isNotEmpty)
              'customer_phone': row['customer_phone'],
            if ((existing['customer_name'] ?? '').toString().trim().isEmpty ||
                const ['Guest Customer', 'Cash Customer']
                    .contains(existing['customer_name']))
              if ((row['customer_name'] ?? '').toString().trim().isNotEmpty &&
                  !const ['Guest Customer', 'Cash Customer']
                      .contains(row['customer_name']))
                'customer_name': row['customer_name'],
          };
        }
      }

      for (final alias in rowAliases) {
        aliasToCanonical[alias] = key;
      }

      if (rowAliases.isEmpty) {
        aliasToCanonical['generated:$sequence'] = key;
        sequence++;
      }
    }

    for (final inv in invoices) {
      add(inv, prefer: true);
    }
    for (final sale in sales) {
      add(sale);
    }

    return canonical;
  }

  /// Khata only accepts real customer phone numbers.
  /// Indian mobile format: 10 digits beginning with 6-9, optionally prefixed by 91/+91.
  bool _isValidCustomerPhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    final normalized = digits.startsWith('91') && digits.length == 12
        ? digits.substring(2)
        : digits;
    return normalized.length == 10 && RegExp(r'^[6-9][0-9]{9}$').hasMatch(normalized);
  }

  /// Mirror a received Khata payment into the local invoice ledger immediately.
  /// This fixes the offline-first gap where the backend eventually becomes PAID
  /// but the local invoice remains UNPAID until a later restore.
  Future<void> _persistLocalInvoicePayment({
    required String customerPhone,
    required double amount,
    required double expectedPaidAmount,
    String? invoiceId,
    String? invoiceNumber,
  }) async {
    if (!_isValidCustomerPhone(customerPhone) || amount <= 0) return;

    try {
      final invoices = (await LocalStorageService.loadLocalInvoices())
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final target = (invoiceId ?? '').trim();
      final number = (invoiceNumber ?? '').trim();

      for (final invoice in invoices) {
        final invPhone =
            (invoice['customer_phone'] ?? invoice['phone'] ?? invoice['mobile'] ?? '')
                .toString()
                .trim();

        if (!_isValidCustomerPhone(invPhone)) continue;

        final ids = <String>{
          (invoice['invoice_id'] ?? '').toString().trim(),
          (invoice['backend_id'] ?? '').toString().trim(),
          (invoice['id'] ?? '').toString().trim(),
        }..removeWhere((v) => v.isEmpty || v == 'null');

        final numbers = <String>{
          (invoice['invoice_number'] ?? '').toString().trim(),
          (invoice['sale_id'] ?? '').toString().trim(),
          (invoice['number'] ?? '').toString().trim(),
        }..removeWhere((v) => v.isEmpty || v == 'null');

        final sameInvoice =
            (target.isNotEmpty && ids.contains(target)) ||
            (number.isNotEmpty && numbers.contains(number));

        if (!sameInvoice) continue;

        final total = double.tryParse(
              (invoice['total_amount'] ??
                      invoice['total'] ??
                      invoice['invoice_total'] ??
                      0)
                  .toString(),
            ) ??
            0.0;

        final oldPaid = double.tryParse(
              (invoice['paid_amount'] ??
                      invoice['amount_paid'] ??
                      invoice['paid'] ??
                      0)
                  .toString(),
            ) ??
            0.0;

        // Idempotent mirror: if recordUnifiedPayment() already persisted the
        // invoice amount, keep that value instead of applying the payment twice.
        final targetPaid = expectedPaidAmount > oldPaid
            ? expectedPaidAmount
            : oldPaid;
        final newPaid =
            targetPaid.clamp(0.0, total).toDouble();

        invoice['paid_amount'] =
            double.parse(newPaid.toStringAsFixed(2));

        if (newPaid >= total - 0.01) {
          invoice['paid_amount'] =
              double.parse(total.toStringAsFixed(2));
          invoice['payment_status'] = 'PAID';
          invoice['status'] = 'PAID';
        } else {
          invoice['payment_status'] = 'PARTIAL';
          invoice['status'] = 'PARTIAL';
        }

        invoice['customer_phone'] = invPhone;
        invoice['updated_at'] = DateTime.now().toUtc().toIso8601String();

        await LocalStorageService.saveLocalInvoices(invoices);
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Local Khata invoice payment mirror failed: $e');
      }
    }
  }

  Future<void> _loadInvoiceAnalytics() async {
    if (!mounted || _invoiceLoadInProgress) return;

    _invoiceLoadInProgress = true;
    setState(() => _invoicesLoading = true);

    try {
      final rawInvoices = await LocalStorageService.loadLocalInvoices();
      final rawSales = await LocalStorageService.loadSales();
      final canonical = _canonicalInvoiceMap(rawInvoices, rawSales);

      double parseAmount(dynamic value) {
        if (value is num) return value.toDouble();
        return double.tryParse(value?.toString() ?? '') ?? 0.0;
      }

      final normalized = canonical.values.map((row) {
        final total = parseAmount(
          row['total_amount'] ??
              row['total'] ??
              row['amount'] ??
              row['invoice_total'] ??
              row['grand_total'],
        );
        final paidRaw = parseAmount(
          row['paid_amount'] ??
              row['amount_paid'] ??
              row['paid'] ??
              row['received_amount'],
        );
        final paid = paidRaw.clamp(0.0, total).toDouble();
        final status = _deriveStatus(total, paid);
        final businessDate = row['sale_timestamp'] ??
            row['created_at'] ??
            row['business_date'] ??
            row['invoice_date'] ??
            row['sale_date'] ??
            row['date'];
        final invoiceNumber =
            row['invoice_number'] ?? row['number'] ?? row['sale_id'] ?? row['id'];
        final phone =
            (row['customer_phone'] ?? row['phone'] ?? row['mobile'] ?? '')
                .toString()
                .trim();
        final rawName =
            (row['customer_name'] ?? row['name'] ?? row['customer'] ?? '')
                .toString()
                .trim();

        return {
          ...row,
          'invoice_number': invoiceNumber,
          'customer_name': rawName.isNotEmpty ? rawName : 'Customer',
          'customer_phone': phone,
          'business_date': businessDate,
          'total_amount': total,
          'paid_amount': paid,
          'pending_amount':
              (total - paid).clamp(0.0, double.infinity).toDouble(),
          'payment_status': status,
        };
      }).toList();

      // Khata is a CREDIT ledger, not a general sales report.
      // Only show:
      //   1) a valid customer phone number
      //   2) an outstanding amount
      // This excludes normal cash/paid sales and anonymous records.
      final invoices = normalized.where((inv) {
        final phone = (inv['customer_phone'] ?? '').toString().trim();
        final total = (inv['total_amount'] as num?)?.toDouble() ?? 0.0;
        final paid = (inv['paid_amount'] as num?)?.toDouble() ?? 0.0;
        final pending = (total - paid).clamp(0.0, double.infinity).toDouble();

        return _isValidCustomerPhone(phone) && pending > 0.01;
      }).toList();

      invoices.sort((a, b) {
        final da =
            DateTime.tryParse(a['business_date']?.toString() ?? '') ??
                DateTime(1970);
        final db =
            DateTime.tryParse(b['business_date']?.toString() ?? '') ??
                DateTime(1970);
        return db.compareTo(da);
      });

      double creditTotal = 0.0;
      double collectedAgainstCredit = 0.0;
      int partialCount = 0;
      int unpaidCount = 0;

      final outstandingByCustomer = <String, Map<String, dynamic>>{};

      for (final inv in invoices) {
        final total =
            (inv['total_amount'] as num?)?.toDouble() ?? 0.0;
        final paidAmt =
            (inv['paid_amount'] as num?)?.toDouble() ?? 0.0;
        final pending =
            (total - paidAmt).clamp(0.0, double.infinity).toDouble();

        creditTotal += total;
        collectedAgainstCredit += paidAmt;

        final status =
            (inv['payment_status'] ?? _deriveStatus(total, paidAmt))
                .toString()
                .toUpperCase();

        if (status == 'PARTIAL') {
          partialCount++;
        } else {
          unpaidCount++;
        }

        final customerId =
            (inv['customer_id'] ?? '').toString().trim();
        final phone =
            (inv['customer_phone'] ?? '').toString().trim();
        final name =
            (inv['customer_name'] ?? 'Customer').toString().trim();

        final key = customerId.isNotEmpty && customerId != '0'
            ? 'id:$customerId'
            : 'phone:$phone';

        final existing = outstandingByCustomer[key];
        if (existing == null) {
          outstandingByCustomer[key] = {
            'customer_id':
                customerId.isNotEmpty ? customerId : null,
            'name': name.isNotEmpty ? name : 'Customer',
            'phone': phone,
            'outstanding': pending,
            'invoice_count': 1,
          };
        } else {
          existing['outstanding'] =
              (existing['outstanding'] as double) + pending;
          existing['invoice_count'] =
              (existing['invoice_count'] as int) + 1;
        }
      }

      final topOutstanding = outstandingByCustomer.values.toList()
        ..sort(
          (a, b) =>
              (b['outstanding'] as double)
                  .compareTo(a['outstanding'] as double),
        );

      if (!mounted) return;

      setState(() {
        _allInvoices = invoices;
        _invoicedTotal = creditTotal;
        _paidTotal = collectedAgainstCredit;
        _pendingTotal = invoices.fold<double>(
          0.0,
          (sum, inv) =>
              sum +
              ((inv['pending_amount'] as num?)?.toDouble() ?? 0.0),
        );

        // Paid invoices are intentionally not part of this Khata view.
        _paidCount = 0;
        _partialCount = partialCount;
        _unpaidCount = unpaidCount;
        _topOutstandingCustomers = topOutstanding.take(5).toList();
        _invoicesLoading = false;

        if (_invoiceStatusFilter == 'PAID') {
          _invoiceStatusFilter = 'ALL';
        }
      });

      // Backend reconciliation is already performed by _loadKhata().
      // Avoid recursively calling _loadInvoiceAnalytics() here.
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading invoice analytics: $e');
      }
      if (mounted) setState(() => _invoicesLoading = false);
    } finally {
      _invoiceLoadInProgress = false;
    }
  }

  String _deriveStatus(double total, double paid) {
    if (paid >= total - 0.01) return 'PAID';
    if (paid > 0) return 'PARTIAL';
    return 'UNPAID';
  }

  List<Map<String, dynamic>> get _filteredInvoices {
    List<Map<String, dynamic>> list = _invoiceStatusFilter == 'ALL'
        ? List.from(_allInvoices)
        : _allInvoices.where((inv) {
            final total = (inv['total_amount'] as num?)?.toDouble() ??
                double.tryParse(inv['total_amount']?.toString() ?? inv['total']?.toString() ?? '0') ??
                0.0;
            final paidAmt = (inv['paid_amount'] as num?)?.toDouble() ??
                double.tryParse(inv['paid_amount']?.toString() ?? '0') ??
                0.0;
            final status = (inv['payment_status']?.toString() ?? _deriveStatus(total, paidAmt)).toUpperCase();
            return status == _invoiceStatusFilter;
          }).toList();

    // Search by customer name or invoice/sale number
    if (_invoiceSearchQuery.trim().isNotEmpty) {
      final q = _invoiceSearchQuery.trim().toLowerCase();
      list = list.where((inv) {
        final name = (inv['customer_name'] ?? '').toString().toLowerCase();
        final phone = (inv['customer_phone'] ?? '').toString().toLowerCase();
        final number = (inv['invoice_number'] ?? inv['sale_id'] ?? '').toString().toLowerCase();
        return name.contains(q) || phone.contains(q) || number.contains(q);
      }).toList();
    }

    double totalOf(Map<String, dynamic> inv) =>
        (inv['total_amount'] as num?)?.toDouble() ??
        double.tryParse(inv['total_amount']?.toString() ?? inv['total']?.toString() ?? '0') ??
        0.0;
    DateTime dateOf(Map<String, dynamic> inv) =>
      DateTime.tryParse(inv['business_date']?.toString() ?? '') ?? DateTime(1970);

    switch (_invoiceSortOption) {
      case 'DATE_ASC':
        list.sort((a, b) => dateOf(a).compareTo(dateOf(b)));
        break;
      case 'AMOUNT_DESC':
        list.sort((a, b) => totalOf(b).compareTo(totalOf(a)));
        break;
      case 'AMOUNT_ASC':
        list.sort((a, b) => totalOf(a).compareTo(totalOf(b)));
        break;
      case 'STATUS':
        list.sort((a, b) {
          const order = {'UNPAID': 0, 'PARTIAL': 1, 'PAID': 2};
          final sa = (a['payment_status']?.toString() ?? _deriveStatus(totalOf(a), 0)).toUpperCase();
          final sb = (b['payment_status']?.toString() ?? _deriveStatus(totalOf(b), 0)).toUpperCase();
          return (order[sa] ?? 3).compareTo(order[sb] ?? 3);
        });
        break;
      case 'DATE_DESC':
      default:
        list.sort((a, b) => dateOf(b).compareTo(dateOf(a)));
    }

    return list;
  }

  Future<void> _loadKhata() async {
    if (!mounted) return;
    setState(() => _loading = true);

    // Local ledger is the UI source of truth. This makes Khata work with no
    // network and keeps it consistent with local invoice analytics.
    try {
      await _loadKhataLocalFallback();
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading local khata: $e');
    }

    _applyFilter();
    if (mounted) setState(() => _loading = false);

    // Reconcile in the background. Never replace the local view merely because
    // a remote endpoint is temporarily empty or unavailable.
    try {
      await SyncService.downloadUserDataSafe();
      await _loadKhataLocalFallback();
      _applyFilter();
      if (mounted) setState(() {});
      // Cloud restore persists canonical invoices separately. Reload invoice
      // analytics after the restore so a fresh install/data-clear immediately
      // repopulates Udhar/Invoice Analytics without requiring relogin.
      await _loadInvoiceAnalytics();
    } catch (e) {
      if (kDebugMode) debugPrint('Khata background reconciliation skipped: $e');
    }
  }

  Future<void> _loadKhataLocalFallback() async {
    var unified = await LocalStorageService.loadUnifiedCustomersLedger();
    _customers = [];
    _totalOutstanding = 0.0;
    _totalOverdue = 0.0;
    _pendingCount = 0;
    _overdueCount = 0;

    if (kDebugMode) debugPrint('📦 Loading ${unified.length} customers from local storage');

    final today = DateTime.now();
    for (var c in unified) {
      // Khata is customer-credit only: an invoice/customer must have a valid
      // mobile number to appear in this screen.
      final customerPhone = (c['phone'] ?? c['customer_phone'] ?? '').toString().trim();
      if (!_isValidCustomerPhone(customerPhone)) {
        continue;
      }

      // FIX: loadUnifiedCustomersLedger() returns 'unified_balance' and
      // 'history', not 'balance' and 'invoices'. Reading the wrong keys
      // meant `bal` was always 0.0 here, so this tab silently showed zero
      // pending customers even when real outstanding balances existed
      // locally — every time the backend call above failed or was slow
      // (exactly the offline-first case), this was the only data source.
      double bal = (c['unified_balance'] as num?)?.toDouble() ??
              (c['total_balance'] as num?)?.toDouble() ??
              (c['balance'] as num?)?.toDouble() ?? 0.0;
      if (bal > 0.01) {
        final dueDateRaw = c['due_date']?.toString();
        DateTime? dueDate;
        if (dueDateRaw != null && dueDateRaw.isNotEmpty) {
          dueDate = DateTime.tryParse(dueDateRaw);
        }

        bool overdue = false;
        int daysOverdue = 0;
        if (dueDate != null) {
          final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
          final diff = today.difference(dueDateOnly).inDays;
          overdue = diff > 0;
          daysOverdue = overdue ? diff : 0;
        }

        _totalOutstanding += bal;
        if (overdue) {
          _totalOverdue += bal;
          _overdueCount++;
        }
        _pendingCount++;
        _customers.add({
          'customer_id': c['customer_id'] ?? c['phone'],
          'customer_name': c['name'] ?? 'Customer',
          'customer_phone': customerPhone,
          'total_balance': bal,
          'overdue_amount': overdue ? bal : 0.0,
          'is_overdue': overdue,
          'days_overdue': daysOverdue,
          'earliest_due_date': dueDateRaw,
          'invoices': c['history'] ?? []
        });
      }
    }
  }

  void _applyFilter() {
    List<Map<String, dynamic>> temp = List.from(_customers);

    // Search filter
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      temp = temp.where((c) {
        final name = (c['customer_name'] ?? '').toString().toLowerCase();
        final phone = (c['customer_phone'] ?? '').toString().toLowerCase();
        return name.contains(q) || phone.contains(q);
      }).toList();
    }

    // Filter Chips
    if (_activeFilter == 'OVERDUE') {
      temp = temp.where((c) => c['is_overdue'] == true).toList();
    } else if (_activeFilter == 'HIGH_BALANCE') {
      temp = temp.where((c) => (c['total_balance'] as num? ?? 0) >= 1000).toList();
    }

    _filteredCustomers = temp;
  }

  Future<void> _makePhoneCall(String phone) async {
    if (phone.isEmpty) {
      _showToast('No phone number registered for this customer');
      return;
    }
    final url = 'tel:${phone.replaceAll(RegExp(r'[^\d+]'), '')}';
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      _showToast('Could not launch phone dialer');
    }
  }

  Future<void> _sendWhatsAppReminder(Map<String, dynamic> customer) async {
    final phone = customer['customer_phone']?.toString() ?? '';
    final name = customer['customer_name']?.toString() ?? 'Customer';
    final balance = (customer['total_balance'] as num?)?.toDouble() ?? 0.0;
    final dueDate = customer['earliest_due_date']?.toString() ?? 'As soon as possible';

    if (phone.isEmpty) {
      _showToast('No phone number available for WhatsApp');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final shopName = prefs.getString('shop_name') ?? prefs.getString('user_name') ?? 'Our Store';
    final upiId = prefs.getString('upi_id') ?? prefs.getString('shop_upi_id') ?? prefs.getString('upi_vpa');

    final success = await WhatsAppMessageService.sendPaymentReminderWithUPI(
      phone: phone,
      customerName: name,
      pendingAmount: balance,
      shopName: shopName,
      upiId: upiId,
      dueDate: dueDate,
    );

    if (success) {
      _showToast('WhatsApp reminder opened for $name!');
      return;
    }
    // Reliable fallback when the native WhatsApp intent is unavailable.
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final normalized = digits.startsWith('91') ? digits : '91$digits';
    final fallback = Uri.parse('https://wa.me/$normalized?text=${Uri.encodeComponent('Hello $name, your pending balance is ₹${balance.toStringAsFixed(2)} at $shopName.')}' );
    try {
      await launchUrlString(fallback.toString());
    } catch (_) {
      _showToast('Could not launch WhatsApp or browser');
    }
  }

  Future<void> _batchWhatsAppAllOverdue() async {
    final overdueList = _customers.where((c) => c['is_overdue'] == true || (c['total_balance'] as num? ?? 0) > 0).toList();

    if (overdueList.isEmpty) {
      _showToast('No pending overdue customers to notify');
      return;
    }

    _showToast('Sending WhatsApp reminder to ${overdueList.length} customers...');

    for (var c in overdueList) {
      await _sendWhatsAppReminder(c);
      await Future.delayed(const Duration(milliseconds: 600));
    }
  }

  void _showPaymentModal(Map<String, dynamic> customer) {
    final TextEditingController amountController = TextEditingController(
      text: (customer['total_balance'] as num?)?.toStringAsFixed(2) ?? '0.00',
    );
    final TextEditingController notesController = TextEditingController();
    String selectedMethod = 'CASH';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Settle Udhar / Payment',
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                          ),
                          Text(
                            customer['customer_name'] ?? 'Customer',
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Current Pending Balance:', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                        Text(
                          '₹${((customer['total_balance'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: _primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Payment Received (₹)',
                      prefixIcon: const Icon(Icons.currency_rupee),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Payment Mode:', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: ['CASH', 'UPI', 'CARD', 'TRANSFER'].map((method) {
                      final isSelected = selectedMethod == method;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedMethod = method),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? _primary : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSelected ? _primary : Colors.grey.shade300),
                            ),
                            child: Text(
                              method,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes / Payment Ref (Optional)',
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                              if (amt <= 0) {
                                _showToast('Please enter a valid payment amount');
                                return;
                              }

                              setModalState(() => isSubmitting = true);

                              final customerPhone =
                                  (customer['customer_phone'] ?? customer['phone'] ?? '')
                                      .toString()
                                      .trim();

                              if (!_isValidCustomerPhone(customerPhone)) {
                                _showToast(
                                  'A valid customer phone number is required for Khata payment.',
                                );
                                setModalState(() => isSubmitting = false);
                                return;
                              }

                              final paymentDate =
                                  DateTime.now().toUtc().toIso8601String();

                              // Build a stable invoice list from the customer's
                              // canonical ledger history. Payments are allocated
                              // oldest-first so each invoice gets a real persisted
                              // paid_amount/status transition.
                              final rawHistory =
                                  customer['invoices'] ?? customer['history'] ?? [];
                              final invoices = rawHistory
                                  .whereType<Map>()
                                  .map((e) => Map<String, dynamic>.from(e))
                                  .where((inv) {
                                    final total = double.tryParse(
                                          (inv['total_amount'] ??
                                                  inv['total'] ??
                                                  inv['invoice_total'] ??
                                                  0)
                                              .toString(),
                                        ) ??
                                        0.0;
                                    final paid = double.tryParse(
                                          (inv['paid_amount'] ??
                                                  inv['amount_paid'] ??
                                                  inv['paid'] ??
                                                  0)
                                              .toString(),
                                        ) ??
                                        0.0;
                                    return (total - paid) > 0.01;
                                  })
                                  .toList();

                              invoices.sort((a, b) {
                                DateTime dateOf(Map<String, dynamic> inv) =>
                                    DateTime.tryParse(
                                      (inv['due_date'] ??
                                              inv['business_date'] ??
                                              inv['invoice_date'] ??
                                              inv['created_at'] ??
                                              '')
                                          .toString(),
                                    ) ??
                                    DateTime(9999);
                                return dateOf(a).compareTo(dateOf(b));
                              });

                              double remaining = amt;
                              int allocationCount = 0;

                              try {
                                for (final invoice in invoices) {
                                  if (remaining <= 0.009) break;

                                  final total = double.tryParse(
                                        (invoice['total_amount'] ??
                                                invoice['total'] ??
                                                invoice['invoice_total'] ??
                                                0)
                                            .toString(),
                                      ) ??
                                      0.0;
                                  final alreadyPaid = double.tryParse(
                                        (invoice['paid_amount'] ??
                                                invoice['amount_paid'] ??
                                                invoice['paid'] ??
                                                0)
                                            .toString(),
                                      ) ??
                                      0.0;
                                  final outstanding = (total - alreadyPaid)
                                      .clamp(0.0, double.infinity)
                                      .toDouble();

                                  if (outstanding <= 0.01) continue;

                                  final applied =
                                      remaining < outstanding ? remaining : outstanding;

                                  final invoiceId =
                                      invoice['invoice_id']?.toString() ??
                                      invoice['backend_id']?.toString() ??
                                      invoice['id']?.toString();
                                  final invoiceNumber =
                                      invoice['invoice_number']?.toString() ??
                                      invoice['sale_id']?.toString() ??
                                      invoiceId ??
                                      '';

                                  final identity = invoiceId?.trim().isNotEmpty == true
                                      ? invoiceId!.trim()
                                      : invoiceNumber.trim();

                                  if (identity.isEmpty) {
                                    continue;
                                  }

                                  final idempotencyKey =
                                      'khata_${identity}_${paymentDate}_${applied.toStringAsFixed(2)}';

                                  // Immediately persist the invoice payment locally.
                                  // The backend sync remains queued separately.
                                  await LocalStorageService.recordUnifiedPayment(
                                    customerPhone,
                                    applied,
                                    invoiceId: invoiceId,
                                    invoiceNumber: invoiceNumber,
                                    paymentMethod: selectedMethod,
                                    paymentDate: paymentDate,
                                    idempotencyKey: idempotencyKey,
                                  );

                                  await _persistLocalInvoicePayment(
                                    customerPhone: customerPhone,
                                    amount: applied,
                                    expectedPaidAmount: alreadyPaid + applied,
                                    invoiceId: invoiceId,
                                    invoiceNumber: invoiceNumber,
                                  );

                                  final paymentPayload = <String, dynamic>{
                                    if (invoiceId != null &&
                                        int.tryParse(invoiceId.trim()) != null)
                                      'invoice_id': int.parse(invoiceId.trim()),
                                    'invoice_number': invoiceNumber,
                                    if (customer['customer_id'] != null &&
                                        int.tryParse(
                                              customer['customer_id'].toString(),
                                            ) !=
                                            null)
                                      'customer_id': int.parse(
                                        customer['customer_id'].toString(),
                                      ),
                                    if (customerPhone.isNotEmpty)
                                      'customer_phone': customerPhone,
                                    'amount': applied,
                                    'payment_method': selectedMethod,
                                    'notes': notesController.text.trim(),
                                    'payment_date': paymentDate,
                                    'idempotency_key': idempotencyKey,
                                  };

                                  await SyncQueueManager.enqueue(
                                    'record_khata_payment',
                                    paymentPayload,
                                  );

                                  remaining -= applied;
                                  allocationCount++;
                                }

                                // Preserve any legacy/customer-level amount that
                                // cannot be tied to an invoice. This prevents money
                                // from disappearing if an old record has no
                                // canonical invoice identity.
                                if (remaining > 0.009 && _isValidCustomerPhone(customerPhone)) {
                                  await LocalStorageService.recordUnifiedPayment(
                                    customerPhone,
                                    remaining,
                                    paymentMethod: selectedMethod,
                                    paymentDate: paymentDate,
                                    idempotencyKey:
                                        'khata_customer_${customerPhone}_$paymentDate',
                                  );

                                  await SyncQueueManager.enqueue(
                                    'record_khata_payment',
                                    {
                                      if (customer['customer_id'] != null &&
                                          int.tryParse(
                                                customer['customer_id'].toString(),
                                              ) !=
                                              null)
                                        'customer_id': int.parse(
                                          customer['customer_id'].toString(),
                                        ),
                                      if (customerPhone.isNotEmpty)
                                        'customer_phone': customerPhone,
                                      'amount': remaining,
                                      'payment_method': selectedMethod,
                                      'notes': notesController.text.trim(),
                                      'payment_date': paymentDate,
                                      'idempotency_key':
                                          'khata_customer_${customerPhone}_$paymentDate',
                                    },
                                  );

                                  remaining = 0;
                                  allocationCount++;
                                }

                                if (allocationCount == 0) {
                                  throw StateError(
                                    'No payable invoice was found for this customer.',
                                  );
                                }

                                if (ctx.mounted) Navigator.pop(ctx);
                                _showToast(
                                  '✅ Payment of ₹${amt.toStringAsFixed(2)} recorded and queued. Pending invoices will update automatically.',
                                );

                                await _loadKhata();
                                await _loadInvoiceAnalytics();
                                unawaited(SyncService.processQueueSafe());
                              } catch (e) {
                                _showToast(
                                  '❌ Payment could not be saved locally: $e',
                                );
                              } finally {
                                if (ctx.mounted) setModalState(() => isSubmitting = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Record Payment', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeadlineModal(Map<String, dynamic> customer) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    bool isSaving = false;

    showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    ).then((picked) async {
      if (picked != null) {
        final dateStr = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
        try {
          final resp = await ApiClient.postJson('/api/khata/update-deadline', {
            'customer_phone': customer['customer_phone'],
            'customer_id': customer['customer_id'],
            'due_date': dateStr,
          });

          if (resp.statusCode == 200) {
            _showToast('⏰ Payment deadline set to $dateStr');
            _loadKhata();
          } else {
            _showToast('Failed to update deadline');
          }
        } catch (e) {
          _showToast('Error setting deadline: $e');
        }
      }
    });
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: const Color(0xFF1E293B),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Khata & Pending Udhar',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          IconButton(
            icon: const Icon(Icons.verified_rounded, color: _success),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PaidInvoicesPage(),
                ),
              ).then((_) {
                if (!mounted) return;
                _loadKhata();
                _loadInvoiceAnalytics();
              });
            },
            tooltip: 'Paid Invoices',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _loadKhata();
              _loadInvoiceAnalytics();
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primary,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: _primary,
          labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Pending Udhar'),
            Tab(text: 'Invoice Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildKhataTab(),
          _buildInvoiceAnalyticsTab(),
        ],
      ),
    );
  }

  Widget _buildKhataTab() {
    return _loading
        ? const Center(child: CircularProgressIndicator(color: _primary))
        : RefreshIndicator(
            onRefresh: _loadKhata,
            color: _primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. ANALYTICS HEADER CARDS
                  _buildAnalyticsHeader(),

                  const SizedBox(height: 16),

                  // 2. BATCH ACTION & SEARCH BAR
                  _buildSearchBarAndActions(),

                  const SizedBox(height: 12),

                  // 3. FILTER CHIPS
                  _buildFilterChips(),

                  const SizedBox(height: 16),

                  // 4. CUSTOMER PENDING LIST
                  if (_filteredCustomers.isEmpty)
                    _buildEmptyState()
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredCustomers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, idx) => _buildCustomerCard(_filteredCustomers[idx]),
                    ),
                ],
              ),
            ),
          );
  }

  Widget _buildAnalyticsHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF635BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL OUTSTANDING UDHAR',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_totalOutstanding.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_alt_outlined, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '$_pendingCount Pending',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat('Overdue Amount', '₹${_totalOverdue.toStringAsFixed(0)}', _danger),
              _buildMiniStat('Due This Week', '₹${_dueThisWeek.toStringAsFixed(0)}', _warning),
              _buildMiniStat('Paid Today', '₹${_collectedToday.toStringAsFixed(0)}', _success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color badgeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildSearchBarAndActions() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              _searchQuery = val;
              setState(() => _applyFilter());
            },
            decoration: InputDecoration(
              hintText: 'Search by customer or phone...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
              fillColor: Colors.white,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _batchWhatsAppAllOverdue,
          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            padding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          tooltip: 'WhatsApp All Overdue',
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip('ALL', 'All Pending (${_customers.length})'),
          const SizedBox(width: 8),
          _buildChip('OVERDUE', 'Overdue (${_overdueCount})', color: _danger),
          const SizedBox(width: 8),
          _buildChip('HIGH_BALANCE', 'High Balance (>₹1000)', color: _warning),
        ],
      ),
    );
  }

  Widget _buildChip(String key, String label, {Color? color}) {
    final isSelected = _activeFilter == key;
    final activeColor = color ?? _primary;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _activeFilter = key;
          _applyFilter();
        });
      },
      selectedColor: activeColor.withValues(alpha: 0.15),
      backgroundColor: Colors.white,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? activeColor : const Color(0xFF64748B),
      ),
      side: BorderSide(color: isSelected ? activeColor : Colors.grey.shade200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> c) {
    final name = c['customer_name'] ?? 'Customer';
    final phone = c['customer_phone'] ?? '';
    final balance = (c['total_balance'] as num?)?.toDouble() ?? 0.0;
    final isOverdue = c['is_overdue'] == true;
    final daysOverdue = (c['days_overdue'] as num?)?.toInt() ?? 0;
    final invoices = List<Map<String, dynamic>>.from(c['invoices'] ?? []);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isOverdue ? _danger.withValues(alpha: 0.3) : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isOverdue ? _danger.withValues(alpha: 0.1) : _primary.withValues(alpha: 0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'C',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isOverdue ? _danger : _primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                      if (phone.isNotEmpty)
                        Text(phone, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                      if (isOverdue)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '⚠️ Overdue by $daysOverdue days',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _danger),
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${balance.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _primary)),
                    Text('${invoices.length} bill(s)', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          // ACTION BUTTONS BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(Icons.call_rounded, 'Call', Colors.blue, () => _makePhoneCall(phone)),
                _buildActionButton(Icons.chat_bubble_outline_rounded, 'WhatsApp', const Color(0xFF25D366), () => _sendWhatsAppReminder(c)),
                _buildActionButton(Icons.check_circle_outline_rounded, 'Mark Paid', _success, () => _showPaymentModal(c)),
                _buildActionButton(Icons.calendar_month_outlined, 'Deadline', _warning, () => _showDeadlineModal(c)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 64, color: _success.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'All Udhar Clear!',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Text(
              'No pending customer balances found.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // INVOICE ANALYTICS TAB
  // ══════════════════════════════════════════════════════════

  Widget _buildInvoiceAnalyticsTab() {
    if (_invoicesLoading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }

    return RefreshIndicator(
      onRefresh: _loadInvoiceAnalytics,
      color: _primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Overview', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                TextButton.icon(
                  onPressed: _exportSummary,
                  icon: const Icon(Icons.ios_share_rounded, size: 16),
                  label: Text('Export', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(foregroundColor: _primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInvoiceSummaryCards(),
            const SizedBox(height: 20),
            _buildPaymentStatusChart(),
            const SizedBox(height: 20),
            _buildTopOutstandingCustomers(),
            const SizedBox(height: 20),
            Text('Pending Credit Invoices', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
            const SizedBox(height: 10),
            _buildInvoiceSearchAndSort(),
            const SizedBox(height: 10),
            _buildInvoiceStatusChips(),
            const SizedBox(height: 12),
            if (_filteredInvoices.isEmpty)
              _buildInvoiceEmptyState()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredInvoices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, idx) => _buildInvoiceTile(_filteredInvoices[idx]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceSearchAndSort() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _invoiceSearchController,
            onChanged: (val) => setState(() => _invoiceSearchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search invoice #, customer, phone...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
              isDense: true,
              fillColor: Colors.white,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: PopupMenuButton<String>(
            initialValue: _invoiceSortOption,
            onSelected: (val) => setState(() => _invoiceSortOption = val),
            icon: const Icon(Icons.sort_rounded, color: Color(0xFF64748B)),
            itemBuilder: (ctx) => [
              _sortMenuItem('DATE_DESC', 'Newest first'),
              _sortMenuItem('DATE_ASC', 'Oldest first'),
              _sortMenuItem('AMOUNT_DESC', 'Amount: high to low'),
              _sortMenuItem('AMOUNT_ASC', 'Amount: low to high'),
              _sortMenuItem('STATUS', 'Status: unpaid first'),
            ],
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _sortMenuItem(String value, String label) {
    final isSelected = _invoiceSortOption == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (isSelected) const Icon(Icons.check, size: 16, color: _primary) else const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  /// Customers with the highest UNCLEARED (outstanding) balance across their invoices —
  /// this is who to chase for payment, not just who bought the most.
  Widget _buildTopOutstandingCustomers() {
    if (_topOutstandingCustomers.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxOutstanding = (_topOutstandingCustomers.first['outstanding'] as double);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.priority_high_rounded, size: 16, color: Color(0xFFEF4444)),
              const SizedBox(width: 6),
              Text('Top Customers by Uncleared Amount', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 14),
          ..._topOutstandingCustomers.map((c) {
            final name = c['name'] as String;
            final outstanding = c['outstanding'] as double;
            final invoiceCount = c['invoice_count'] as int;
            final phone = c['phone'] as String;
            final ratio = maxOutstanding > 0 ? (outstanding / maxOutstanding) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(name,
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text('₹${outstanding.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _danger)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: ratio.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade100,
                            valueColor: const AlwaysStoppedAnimation(_danger),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('$invoiceCount unpaid/partial invoice(s)',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _makePhoneCall(phone),
                      icon: const Icon(Icons.call_rounded, size: 18, color: Colors.blue),
                      tooltip: 'Call $name',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInvoiceSummaryCards() {
    return Row(
      children: [
        Expanded(child: _buildSummaryCard('Total Invoiced', _invoicedTotal, const Color(0xFF4F46E5), Icons.receipt_long_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _buildSummaryCard('Total Paid', _paidTotal, _success, Icons.check_circle_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _buildSummaryCard('Total Pending', _pendingTotal, _danger, Icons.pending_actions_rounded)),
      ],
    );
  }

  Widget _buildSummaryCard(String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Payment status breakdown: Paid / Partial / Unpaid as a donut chart
  Widget _buildPaymentStatusChart() {
    final total = _paidCount + _partialCount + _unpaidCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Outstanding Credit Status', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
          const SizedBox(height: 16),
          if (total == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No invoices yet', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 32,
                      sections: [
                        if (_paidCount > 0)
                          PieChartSectionData(
                            value: _paidCount.toDouble(),
                            color: _success,
                            title: '$_paidCount',
                            radius: 26,
                            titleStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (_partialCount > 0)
                          PieChartSectionData(
                            value: _partialCount.toDouble(),
                            color: _warning,
                            title: '$_partialCount',
                            radius: 26,
                            titleStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (_unpaidCount > 0)
                          PieChartSectionData(
                            value: _unpaidCount.toDouble(),
                            color: _danger,
                            title: '$_unpaidCount',
                            radius: 26,
                            titleStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendRow('Paid', _paidCount, total, _success),
                      const SizedBox(height: 10),
                      _buildLegendRow('Partial', _partialCount, total, _warning),
                      const SizedBox(height: 10),
                      _buildLegendRow('Unpaid', _unpaidCount, total, _danger),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String label, int count, int total, Color color) {
    final pct = total > 0 ? (count / total * 100) : 0.0;
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text('$label ($count)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
        ),
        Text('${pct.toStringAsFixed(0)}%', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildInvoiceStatusChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildInvoiceChip('ALL', 'All (${_allInvoices.length})'),
          const SizedBox(width: 8),
          _buildInvoiceChip('PARTIAL', 'Partial ($_partialCount)', color: _warning),
          const SizedBox(width: 8),
          _buildInvoiceChip('UNPAID', 'Unpaid ($_unpaidCount)', color: _danger),
        ],
      ),
    );
  }

  Widget _buildInvoiceChip(String key, String label, {Color? color}) {
    final isSelected = _invoiceStatusFilter == key;
    final activeColor = color ?? _primary;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _invoiceStatusFilter = key),
      selectedColor: activeColor.withValues(alpha: 0.15),
      backgroundColor: Colors.white,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? activeColor : const Color(0xFF64748B),
      ),
      side: BorderSide(color: isSelected ? activeColor : Colors.grey.shade200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildInvoiceTile(Map<String, dynamic> inv) {
    final total = (inv['total_amount'] as num?)?.toDouble() ??
        double.tryParse(inv['total_amount']?.toString() ?? inv['total']?.toString() ?? '0') ??
        0.0;
    final paidAmt = (inv['paid_amount'] as num?)?.toDouble() ??
        double.tryParse(inv['paid_amount']?.toString() ?? '0') ??
        0.0;
    final status = (inv['payment_status']?.toString() ?? _deriveStatus(total, paidAmt)).toUpperCase();
    final customerName = inv['customer_name']?.toString() ?? 'Guest Customer';
    final invoiceNumber = inv['invoice_number']?.toString() ?? inv['sale_id']?.toString() ?? '—';
    final dateStr = inv['business_date']?.toString() ?? '';

    Color statusColor;
    switch (status) {
      case 'PAID':
        statusColor = _success;
        break;
      case 'PARTIAL':
        statusColor = _warning;
        break;
      default:
        statusColor = _danger;
    }

    return InkWell(
      onTap: () => _showInvoiceDetailModal(inv),
      borderRadius: BorderRadius.circular(14),
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.receipt_rounded, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#$invoiceNumber · $customerName',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(dateStr.split('T').first, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${total.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(status, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
        ],
      ),
      ),
    );
  }

  /// Bottom sheet showing full line-item breakdown for a single invoice
  void _showInvoiceDetailModal(Map<String, dynamic> inv) {
    final total = (inv['total_amount'] as num?)?.toDouble() ??
        double.tryParse(inv['total_amount']?.toString() ?? inv['total']?.toString() ?? '0') ??
        0.0;
    final paidAmt = (inv['paid_amount'] as num?)?.toDouble() ??
        double.tryParse(inv['paid_amount']?.toString() ?? '0') ??
        0.0;
    final status = (inv['payment_status']?.toString() ?? _deriveStatus(total, paidAmt)).toUpperCase();
    final customerName = inv['customer_name']?.toString() ?? 'Guest Customer';
    final customerPhone = inv['customer_phone']?.toString() ?? '';
    final invoiceNumber = inv['invoice_number']?.toString() ?? inv['sale_id']?.toString() ?? '—';
    final dateStr = inv['business_date']?.toString() ?? '';
    final lineItems = List<Map<String, dynamic>>.from(inv['line_items'] ?? inv['items'] ?? []);

    Color statusColor;
    switch (status) {
      case 'PAID':
        statusColor = _success;
        break;
      case 'PARTIAL':
        statusColor = _warning;
        break;
      default:
        statusColor = _danger;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Invoice #$invoiceNumber', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                          Text(dateStr.split('T').first, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: _primary.withValues(alpha: 0.1),
                          child: Text(customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _primary)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(customerName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                              if (customerPhone.isNotEmpty)
                                Text(customerPhone, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(status, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Line Items', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Expanded(
                    child: lineItems.isEmpty
                        ? Center(
                            child: Text('No line-item detail saved for this invoice',
                                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: lineItems.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (ctx, idx) {
                              final item = lineItems[idx];
                              final name = item['product_name'] ?? item['name'] ?? item['product'] ?? 'Item';
                              final qty = item['quantity'] ?? item['qty'] ?? 1;
                              final price = (item['unit_price'] as num?)?.toDouble() ?? (item['price'] as num?)?.toDouble() ?? 0.0;
                              final lineTotal = (item['line_total'] as num?)?.toDouble() ?? (item['total'] as num?)?.toDouble() ?? (price * (qty is num ? qty : 1));
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text('$name', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text('x$qty', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text('₹${lineTotal.toStringAsFixed(0)}', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(height: 24),
                  _buildDetailRow('Total Amount', '₹${total.toStringAsFixed(2)}', bold: true),
                  _buildDetailRow('Paid Amount', '₹${paidAmt.toStringAsFixed(2)}', color: _success),
                  if (total - paidAmt > 0.01) _buildDetailRow('Balance Due', '₹${(total - paidAmt).toStringAsFixed(2)}', color: _danger, bold: true),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
          Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: color ?? const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  /// Builds a plain-text summary and copies it to the clipboard so it can be
  /// pasted into WhatsApp/SMS/email. (Wire up `share_plus` if you want the
  /// native OS share sheet instead of copy-to-clipboard.)
  Future<void> _exportSummary() async {
    final buffer = StringBuffer();
    buffer.writeln('📊 INVOICE SUMMARY');
    buffer.writeln('Generated: ${DateTime.now().toString().split('.').first}');
    buffer.writeln('─────────────────────');
    buffer.writeln('Total Invoiced: ₹${_invoicedTotal.toStringAsFixed(2)}');
    buffer.writeln('Total Paid: ₹${_paidTotal.toStringAsFixed(2)}');
    buffer.writeln('Total Pending: ₹${_pendingTotal.toStringAsFixed(2)}');
    buffer.writeln('');
    buffer.writeln('Payment Status:');
    buffer.writeln('  Paid: $_paidCount invoice(s)');
    buffer.writeln('  Partial: $_partialCount invoice(s)');
    buffer.writeln('  Unpaid: $_unpaidCount invoice(s)');

    if (_topOutstandingCustomers.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Top Uncleared Balances:');
      for (final c in _topOutstandingCustomers) {
        buffer.writeln('  ${c['name']}: ₹${(c['outstanding'] as double).toStringAsFixed(2)}');
      }
    }

    final summary = buffer.toString();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Export Summary', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: SelectableText(summary, style: GoogleFonts.inter(fontSize: 13, height: 1.5)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: summary));
              if (mounted) Navigator.pop(ctx);
              _showToast('📋 Summary copied to clipboard');
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy'),
            style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No invoices found', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
            const SizedBox(height: 4),
            Text('Invoices will appear here once sales are recorded.',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}
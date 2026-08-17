import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'local_storage_service.dart';
import 'sync_service.dart';

class PaidInvoicesPage extends StatefulWidget {
  const PaidInvoicesPage({super.key});

  @override
  State<PaidInvoicesPage> createState() => _PaidInvoicesPageState();
}

class _PaidInvoicesPageState extends State<PaidInvoicesPage>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF635BFF);
  static const Color _success = Color(0xFF10B981);

  late final AnimationController _animationController;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _paidInvoices = [];
  bool _loading = true;
  String _query = '';
  String _sort = 'DATE_DESC';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    _loadPaidInvoices();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  double _amount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  DateTime _dateOf(Map<String, dynamic> invoice) {
    return DateTime.tryParse(
          (invoice['paid_at'] ??
                  invoice['payment_date'] ??
                  invoice['updated_at'] ??
                  invoice['business_date'] ??
                  invoice['invoice_date'] ??
                  invoice['created_at'] ??
                  '')
              .toString(),
        ) ??
        DateTime(1970);
  }

  String _invoiceKey(Map<String, dynamic> invoice) {
    for (final field in const [
      'invoice_id',
      'invoice_number',
      'sale_id',
      'backend_id',
      'id',
    ]) {
      final value = invoice[field]?.toString().trim() ?? '';
      if (value.isNotEmpty && value != '0' && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return 'unknown-${invoice.hashCode}';
  }

  Future<void> _loadPaidInvoices() => _loadPaidInvoicesFromLocalOnly();

  Future<void> _loadPaidInvoicesFromLocalOnly() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final raw = await LocalStorageService.loadLocalInvoices();
      final Map<String, Map<String, dynamic>> canonical = {};

      for (final item in raw) {
        if (item is! Map) continue;
        final invoice = Map<String, dynamic>.from(item);
        final key = _invoiceKey(invoice);

        final total = _amount(
          invoice['total_amount'] ??
              invoice['total'] ??
              invoice['invoice_total'] ??
              invoice['grand_total'],
        );
        final paid = _amount(
          invoice['paid_amount'] ??
              invoice['amount_paid'] ??
              invoice['paid'],
        ).clamp(0.0, total);
        final outstanding =
            (total - paid).clamp(0.0, double.infinity).toDouble();

        final status =
            (invoice['payment_status'] ?? invoice['status'] ?? '').toString().toUpperCase();
        if (outstanding > 0.01 && status != 'PAID') continue;

        canonical[key] = {
          ...invoice,
          'total_amount': total,
          'paid_amount': paid,
          'pending_amount': outstanding,
          'payment_status': 'PAID',
        };
      }

      final paid = canonical.values.toList();
      paid.sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));

      if (!mounted) return;
      setState(() {
        _paidInvoices = paid;
        _loading = false;
      });

      // Rehydrate after app-data clear/login before showing an empty paid list.
      unawaited(() async {
        try {
          await SyncService.downloadUserDataSafe();
          if (!mounted) return;
          final restored = await LocalStorageService.loadLocalInvoices();
          final restoredKeys = restored.whereType<Map>().map((m) => _invoiceKey(Map<String, dynamic>.from(m))).toSet();
          final localKeys = paid.map(_invoiceKey).toSet();
          if (restoredKeys.length != localKeys.length || restoredKeys.difference(localKeys).isNotEmpty) {
            await _loadPaidInvoicesFromLocalOnly();
          }
        } catch (e) {
          if (mounted && _paidInvoices.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paid invoices will appear after cloud sync completes.')));
          }
        }
      }());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _paidInvoices = [];
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load paid invoices: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredInvoices {
    var result = _paidInvoices.where((invoice) {
      if (_query.isEmpty) return true;
      final name = (invoice['customer_name'] ?? invoice['name'] ?? '')
          .toString()
          .toLowerCase();
      final phone = (invoice['customer_phone'] ?? invoice['phone'] ?? '')
          .toString()
          .toLowerCase();
      final number =
          (invoice['invoice_number'] ?? invoice['sale_id'] ?? '').toString().toLowerCase();
      return name.contains(_query) ||
          phone.contains(_query) ||
          number.contains(_query);
    }).toList();

    result.sort((a, b) {
      final totalA = _amount(a['total_amount']);
      final totalB = _amount(b['total_amount']);
      switch (_sort) {
        case 'DATE_ASC':
          return _dateOf(a).compareTo(_dateOf(b));
        case 'AMOUNT_DESC':
          return totalB.compareTo(totalA);
        case 'AMOUNT_ASC':
          return totalA.compareTo(totalB);
        case 'DATE_DESC':
        default:
          return _dateOf(b).compareTo(_dateOf(a));
      }
    });
    return result;
  }

  String _formatDate(DateTime date) {
    if (date.year <= 1970) return 'Date unavailable';
    final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} • '
        '${hour.toString().padLeft(2, '0')}:$minute $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final invoices = _filteredInvoices;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paid Invoices',
              style: GoogleFonts.poppins(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${_paidInvoices.length} completed payments',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadPaidInvoices,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _success))
          : RefreshIndicator(
              onRefresh: _loadPaidInvoices,
              color: _success,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _animationController,
                        curve: Curves.easeOut,
                      ),
                      child: _buildHeader(),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildControls()),
                  if (invoices.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final animation = CurvedAnimation(
                              parent: _animationController,
                              curve: Interval(
                                (index / invoices.length).clamp(0.0, 0.82),
                                ((index + 1) / invoices.length).clamp(0.18, 1.0),
                                curve: Curves.easeOutCubic,
                              ),
                            );
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.06),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: _buildPaidCard(invoices[index]),
                              ),
                            );
                          },
                          childCount: invoices.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final totalCollected = _paidInvoices.fold<double>(
      0.0,
      (sum, invoice) => sum + _amount(invoice['paid_amount']),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _success.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.32),
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 35,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Completed',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Every paid invoice remains safely available here.',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '₹${totalCollected.toStringAsFixed(2)} collected',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search customer, phone or invoice...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => _searchController.clear(),
                      icon: const Icon(Icons.clear_rounded),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Sort',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _sort,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'DATE_DESC',
                      child: Text('Newest first'),
                    ),
                    DropdownMenuItem(
                      value: 'DATE_ASC',
                      child: Text('Oldest first'),
                    ),
                    DropdownMenuItem(
                      value: 'AMOUNT_DESC',
                      child: Text('Highest amount'),
                    ),
                    DropdownMenuItem(
                      value: 'AMOUNT_ASC',
                      child: Text('Lowest amount'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sort = value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaidCard(Map<String, dynamic> invoice) {
    final name = (invoice['customer_name'] ?? invoice['name'] ?? 'Cash Customer')
        .toString();
    final phone =
        (invoice['customer_phone'] ?? invoice['phone'] ?? '').toString();
    final number =
        (invoice['invoice_number'] ?? invoice['sale_id'] ?? 'Invoice').toString();
    final total = _amount(invoice['total_amount']);
    final paid = _amount(invoice['paid_amount']);
    final date = _dateOf(invoice);
    final itemList = invoice['line_items'] ?? invoice['items'];
    final itemCount = itemList is List ? itemList.length : 0;

    final initial = name.trim().isEmpty ? 'C' : name.trim()[0].toUpperCase();

    return GestureDetector(
      onTap: () => _showInvoiceDetails(invoice),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF14B8A6), Color(0xFF10B981)],
                ),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 7,
                    runSpacing: 4,
                    children: [
                      _tinyBadge('PAID', _success),
                      _tinyBadge(number, _primary),
                      if (itemCount > 0)
                        _tinyBadge(
                          '$itemCount item${itemCount == 1 ? '' : 's'}',
                          const Color(0xFF64748B),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatDate(date),
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${paid.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _success,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'of ₹${total.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 5),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFCBD5E1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tinyBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.75, end: 1.0),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: 94,
                height: 94,
                decoration: BoxDecoration(
                  color: _success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _success.withValues(alpha: 0.18),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: _success,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _query.isEmpty
                  ? 'No paid invoices yet'
                  : 'No matching paid invoices',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _query.isEmpty
                  ? 'When an Udhar invoice is fully settled, it will move here and remain available permanently.'
                  : 'Try a different customer name, phone number, or invoice number.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xFF64748B),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInvoiceDetails(Map<String, dynamic> invoice) {
    final name =
        (invoice['customer_name'] ?? invoice['name'] ?? 'Cash Customer').toString();
    final phone =
        (invoice['customer_phone'] ?? invoice['phone'] ?? '').toString();
    final number =
        (invoice['invoice_number'] ?? invoice['sale_id'] ?? 'Invoice').toString();
    final total = _amount(invoice['total_amount']);
    final paid = _amount(invoice['paid_amount']);
    final date = _dateOf(invoice);
    final method =
        (invoice['last_payment_method'] ?? invoice['payment_method'] ?? 'CASH')
            .toString();
    final lineItems = invoice['line_items'] ?? invoice['items'];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Column(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.75, end: 1),
                          duration: const Duration(milliseconds: 550),
                          curve: Curves.easeOutBack,
                          builder: (context, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDCFCE7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Color(0xFF16A34A),
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: 11),
                        Text(
                          'Payment Completed',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${paid.toStringAsFixed(2)} paid',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: _success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _detailRow('Customer', name),
                  if (phone.isNotEmpty) _detailRow('Phone', phone),
                  _detailRow('Invoice', number),
                  _detailRow('Paid date', _formatDate(date)),
                  _detailRow('Payment method', method),
                  const Divider(height: 28),
                  _detailRow('Invoice amount', '₹${total.toStringAsFixed(2)}'),
                  _detailRow('Amount paid', '₹${paid.toStringAsFixed(2)}'),
                  _detailRow('Balance', '₹0.00'),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFBBF7D0),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This invoice is fully settled and remains in Paid Invoice History.',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF166534),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (lineItems is List && lineItems.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Items',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...lineItems.whereType<Map>().map((item) {
                      final itemMap = Map<String, dynamic>.from(item);
                      final itemName = (itemMap['product_name'] ??
                              itemMap['product'] ??
                              itemMap['name'] ??
                              'Item')
                          .toString();
                      final qty =
                          _amount(itemMap['quantity'] ?? itemMap['qty'] ?? 1);
                      final value = _amount(
                        itemMap['total'] ??
                            itemMap['line_total'] ??
                            itemMap['total_with_tax'],
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                itemName,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ),
                            Text(
                              'x${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2)}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              '₹${value.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'local_storage_service.dart';
import 'whatsapp_message_service.dart';
import 'api_client.dart';
import 'visual_widgets.dart';

class KhataPageAdvanced extends StatefulWidget {
  const KhataPageAdvanced({super.key});

  @override
  State<KhataPageAdvanced> createState() => _KhataPageAdvancedState();
}

class _KhataPageAdvancedState extends State<KhataPageAdvanced> {
  static const _primary = AppColors.primary;
  static const _danger = Color(0xFFEF4444);
  static const _success = Color(0xFF10B981);
  static const _warning = Color(0xFFF59E0B);
  static const _info = Color(0xFF3B82F6);

  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  
  // Enhanced Analytics
  double _totalOutstanding = 0.0, _totalOverdue = 0.0, _collectedToday = 0.0, _avgBalance = 0.0, _dueThisWeek = 0.0;
  int _pendingCount = 0, _overdueCount = 0, _highRiskCount = 0;
  String _trend = 'STABLE'; // UP, DOWN, STABLE
  
  bool _loading = true;
  String _searchQuery = '', _activeFilter = 'ALL', _sortBy = 'BALANCE_DESC';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadKhata();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadKhata() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final responses = await Future.wait([
        ApiClient.getJson('/api/khata/pending-summary'),
        ApiClient.getJson('/api/khata/pending-customers'),
      ]);

      if (responses.every((r) => r.statusCode == 200)) {
        final sumData = json.decode(responses[0].body);
        final listData = json.decode(responses[1].body);

        _totalOutstanding = (sumData['total_outstanding'] as num?)?.toDouble() ?? 0.0;
        _totalOverdue = (sumData['total_overdue'] as num?)?.toDouble() ?? 0.0;
        _collectedToday = (sumData['collected_today'] as num?)?.toDouble() ?? 0.0;
        _dueThisWeek = (sumData['due_this_week'] as num?)?.toDouble() ?? 0.0;
        _pendingCount = (sumData['pending_customers_count'] as num?)?.toInt() ?? 0;
        _overdueCount = (sumData['overdue_customers_count'] as num?)?.toInt() ?? 0;
        _customers = List<Map<String, dynamic>>.from(listData['customers'] ?? []);
        
        // Calculate enhanced analytics
        _calculateAdvancedAnalytics();
      } else {
        await _loadKhataLocalFallback();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading khata: $e');
      await _loadKhataLocalFallback();
    }

    _applyFilter();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadKhataLocalFallback() async {
    final unified = await LocalStorageService.loadUnifiedCustomersLedger();
    _customers = unified
        .where((c) => ((c['balance'] as num?)?.toDouble() ?? 0.0) > 0.01)
        .map((c) => {
              'customer_id': c['customer_id'],
              'customer_name': c['name'] ?? 'Customer',
              'customer_phone': c['phone'] ?? '',
              'total_balance': c['balance'],
              'overdue_amount': c['balance'],
              'is_overdue': false,
              'invoices': c['invoices'] ?? []
            })
        .toList();
    _totalOutstanding = _customers.fold(0.0, (sum, c) => sum + ((c['total_balance'] as num?)?.toDouble() ?? 0.0));
    _pendingCount = _customers.length;
    _calculateAdvancedAnalytics();
  }

  void _calculateAdvancedAnalytics() {
    if (_customers.isEmpty) return;
    
    // Average balance per customer
    _avgBalance = _totalOutstanding / _customers.length;
    
    // High risk customers (balance > 5000 or overdue > 30 days)
    _highRiskCount = _customers.where((c) {
      final balance = (c['total_balance'] as num?)?.toDouble() ?? 0.0;
      final daysOverdue = (c['days_overdue'] as num?)?.toInt() ?? 0;
      return balance > 5000 || daysOverdue > 30;
    }).length;
    
    // Calculate trend based on overdue ratio
    final overdueRatio = _totalOutstanding > 0 ? _totalOverdue / _totalOutstanding : 0.0;
    if (overdueRatio > 0.5) {
      _trend = 'UP'; // Getting worse
    } else if (overdueRatio < 0.3) {
      _trend = 'DOWN'; // Getting better
    } else {
      _trend = 'STABLE';
    }
  }

  void _applyFilter() {
    _filteredCustomers = _customers.where((c) {
      final q = _searchQuery.toLowerCase();
      final name = (c['customer_name'] ?? '').toString().toLowerCase();
      final phone = (c['customer_phone'] ?? '').toString().toLowerCase();
      final matchesSearch = q.isEmpty || name.contains(q) || phone.contains(q);
      
      if (!matchesSearch) return false;
      if (_activeFilter == 'OVERDUE') return c['is_overdue'] == true;
      if (_activeFilter == 'HIGH_BALANCE') return (c['total_balance'] as num? ?? 0) >= 1000;
      if (_activeFilter == 'HIGH_RISK') {
        final balance = (c['total_balance'] as num?)?.toDouble() ?? 0.0;
        final daysOverdue = (c['days_overdue'] as num?)?.toInt() ?? 0;
        return balance > 5000 || daysOverdue > 30;
      }
      return true;
    }).toList();

    // Apply sorting
    _applySorting();
  }

  void _showDeadlineModal(Map<String, dynamic> customer) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

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

  void _applySorting() {
    switch (_sortBy) {
      case 'BALANCE_DESC':
        _filteredCustomers.sort((a, b) => ((b['total_balance'] as num?)?.toDouble() ?? 0).compareTo((a['total_balance'] as num?)?.toDouble() ?? 0));
        break;
      case 'BALANCE_ASC':
        _filteredCustomers.sort((a, b) => ((a['total_balance'] as num?)?.toDouble() ?? 0).compareTo((b['total_balance'] as num?)?.toDouble() ?? 0));
        break;
      case 'OVERDUE_DESC':
        _filteredCustomers.sort((a, b) => ((b['days_overdue'] as num?)?.toInt() ?? 0).compareTo((a['days_overdue'] as num?)?.toInt() ?? 0));
        break;
      case 'NAME_ASC':
        _filteredCustomers.sort((a, b) => (a['customer_name'] ?? '').toString().compareTo((b['customer_name'] ?? '').toString()));
        break;
    }
  }

  Future<void> _callCustomer(String phone) async {
    final url = 'tel:${phone.replaceAll(RegExp(r'[^\d+]'), '')}';
    if (phone.isNotEmpty && await canLaunchUrlString(url)) await launchUrlString(url);
  }

  Future<void> _sendWhatsApp(Map<String, dynamic> customer) async {
    final prefs = await SharedPreferences.getInstance();
    final success = await WhatsAppMessageService.sendPaymentReminderWithUPI(
      phone: customer['customer_phone'] ?? '',
      customerName: customer['customer_name'] ?? 'Customer',
      pendingAmount: customer['total_balance'] ?? 0.0,
      shopName: prefs.getString('shop_name') ?? 'Shop',
      upiId: prefs.getString('upi_id') ?? '',
      dueDate: customer['earliest_due_date']?.toString() ?? 'ASAP',
    );
    if (success && mounted) _showToast('WhatsApp reminder sent!');
  }

  void _showPaymentModal(Map<String, dynamic> customer) {
    final amountController = TextEditingController(text: customer['total_balance']?.toString() ?? '0');
    String method = 'CASH';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Record Payment', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))
            ]),
            const SizedBox(height: 16),
            TextField(controller: amountController, keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Amount (₹)', prefixIcon: const Icon(Icons.currency_rupee), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'CASH', label: Text('CASH')), ButtonSegment(value: 'UPI', label: Text('UPI'))],
              selected: {method},
              onSelectionChanged: (s) => method = s.first,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountController.text) ?? 0;
                if (amt <= 0) return;
                final resp = await ApiClient.postJson('/api/khata/record-payment', {
                  'customer_phone': customer['customer_phone'], 'amount': amt, 'payment_method': method
                });
                if (resp.statusCode == 200) {
                  if (mounted) Navigator.pop(ctx);
                  _showToast('Payment recorded!');
                  _loadKhata();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _success, minimumSize: const Size(double.infinity, 50)),
              child: const Text('Record Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showToast(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xFF1E293B)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Khata & Udhar', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0, actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadKhata)]),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : RefreshIndicator(
              onRefresh: _loadKhata,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAnalyticsCard(),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    _buildFilterChips(),
                    const SizedBox(height: 16),
                    if (_filteredCustomers.isEmpty) _buildEmptyState()
                    else ..._filteredCustomers.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildCustomerCard(c))),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAnalyticsCard() {
    final trendColor = _trend == 'UP' ? _danger : (_trend == 'DOWN' ? _success : _warning);
    final trendIcon = _trend == 'UP' ? Icons.trending_up : (_trend == 'DOWN' ? Icons.trending_down : Icons.trending_flat);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF635BFF)]), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TOTAL OUTSTANDING', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
              const SizedBox(height: 4),
              Text('₹${_totalOutstanding.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
            ]),
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                child: Text('$_pendingCount Pending', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white))),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: trendColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                child: Row(children: [Icon(trendIcon, size: 14, color: trendColor), const SizedBox(width: 4), Text(_trend, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: trendColor))]),
              ),
            ]),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _buildMiniStat('Overdue', '₹${_totalOverdue.toStringAsFixed(0)}', _danger),
            _buildMiniStat('Due This Week', '₹${_dueThisWeek.toStringAsFixed(0)}', _warning),
            _buildMiniStat('Collected Today', '₹${_collectedToday.toStringAsFixed(0)}', _success),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _buildMiniStat('Avg Balance', '₹${_avgBalance.toStringAsFixed(0)}', _info),
            _buildMiniStat('High Risk', '$_highRiskCount', _danger),
          ]),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 4), Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white70))]),
      const SizedBox(height: 2),
      Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
    ]);
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() { _searchQuery = v; _applyFilter(); }),
      decoration: InputDecoration(
        hintText: 'Search customers...', prefixIcon: const Icon(Icons.search), fillColor: Colors.white, filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['ALL', 'OVERDUE', 'HIGH_BALANCE', 'HIGH_RISK'].map((f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f == 'ALL' ? 'All (${_customers.length})' : f),
                  selected: _activeFilter == f,
                  onSelected: (_) => setState(() { _activeFilter = f; _applyFilter(); }),
                  selectedColor: _primary.withValues(alpha: 0.15),
                  labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _activeFilter == f ? _primary : Colors.grey.shade600),
                ),
              )).toList(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort, size: 20),
          tooltip: 'Sort',
          onSelected: (value) => setState(() { _sortBy = value; _applyFilter(); }),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'BALANCE_DESC', child: Text('Balance: High to Low')),
            const PopupMenuItem(value: 'BALANCE_ASC', child: Text('Balance: Low to High')),
            const PopupMenuItem(value: 'OVERDUE_DESC', child: Text('Overdue Days')),
            const PopupMenuItem(value: 'NAME_ASC', child: Text('Name (A-Z)')),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> c) {
    final isOverdue = c['is_overdue'] == true;
    final balance = (c['total_balance'] as num?)?.toDouble() ?? 0.0;
    final daysOverdue = (c['days_overdue'] as num?)?.toInt() ?? 0;
    final invoices = List<Map<String, dynamic>>.from(c['invoices'] ?? []);
    final isHighRisk = balance > 5000 || daysOverdue > 30;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighRisk ? _danger : (isOverdue ? _warning.withValues(alpha: 0.5) : Colors.grey.shade200),
          width: isHighRisk ? 2 : 1,
        ),
        boxShadow: isHighRisk ? [BoxShadow(color: _danger.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))] : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: isHighRisk ? _danger.withValues(alpha: 0.1) : (isOverdue ? _warning.withValues(alpha: 0.1) : _primary.withValues(alpha: 0.1)),
                child: Text(
                  (c['customer_name'] ?? 'C')[0].toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.bold, color: isHighRisk ? _danger : (isOverdue ? _warning : _primary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(c['customer_name'] ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (isHighRisk) const SizedBox(width: 6),
                  if (isHighRisk) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _danger, borderRadius: BorderRadius.circular(4)), child: const Text('HIGH RISK', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold))),
                ]),
                if (c['customer_phone']?.isNotEmpty ?? false) Text(c['customer_phone'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Row(children: [
                  Text('${invoices.length} bill(s)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  if (daysOverdue > 0) ...[
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: _warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Text('$daysOverdue days overdue', style: const TextStyle(fontSize: 10, color: _warning, fontWeight: FontWeight.w600))),
                  ],
                ]),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₹${balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _primary)),
                if (c['earliest_due_date'] != null) Text('Due: ${c['earliest_due_date']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _buildAction(Icons.call, 'Call', Colors.blue, () => _callCustomer(c['customer_phone'] ?? '')),
            _buildAction(Icons.chat, 'WhatsApp', const Color(0xFF25D366), () => _sendWhatsApp(c)),
            _buildAction(Icons.check_circle, 'Pay', _success, () => _showPaymentModal(c)),
            _buildAction(Icons.calendar_month, 'Deadline', _warning, () => _showDeadlineModal(c)),
          ]),
        ],
      ),
    );
  }

  Widget _buildAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color))]));
  }

  Widget _buildEmptyState() {
    return const Center(child: Column(children: [SizedBox(height: 40), Icon(Icons.check_circle, size: 64, color: _success), SizedBox(height: 12), Text('All Udhar Clear!', style: TextStyle(fontWeight: FontWeight.bold)), Text('No pending balances found.', style: TextStyle(color: Colors.grey))]));
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';
import 'app_localizations.dart';
import 'local_storage_service.dart';
import 'secure_token_storage.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});
  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  static const Color _primary = Color(0xFF6366F1);

  bool _loading = true;
  List<dynamic> _all = [], _filtered = [];
  int? _userId;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(_filter);
    _init();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id') ?? prefs.getInt('userId');
    await _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = await SecureTokenStorage.getToken() ?? '';

      // 🔵 TRY BACKEND FIRST (if online with token)
      if (token.isNotEmpty) {
        try {
          if (kDebugMode) debugPrint('📡 Fetching customers from backend...');
          final path = (_userId != null && _userId! > 0)
              ? '/api/customers/?user_id=$_userId'
              : '/api/customers/';
          final response = await ApiClient.getJson(
            path,
            headers: {'Authorization': 'Bearer $token'},
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final responseBody = json.decode(response.body);
            List<dynamic> backendCustomers = [];
            if (responseBody is List) {
              backendCustomers = responseBody;
            } else if (responseBody is Map && responseBody['customers'] is List) {
              backendCustomers = responseBody['customers'];
            } else if (responseBody is Map && responseBody['results'] is List) {
              backendCustomers = responseBody['results'];
            }
            if (kDebugMode) debugPrint('✅ Downloaded ${backendCustomers.length} customers from backend');

            setState(() {
              _all = backendCustomers
                  .where((item) {
                    if (item is! Map<String, dynamic>) return false;
                    // FIX: IDOR Prevention - Verify ownership
                    final itemUserId = item['user_id'];
                    if (itemUserId != null && _userId != null && _userId! > 0) {
                      if (itemUserId.toString() != _userId.toString()) return false;
                    }
                    return true;
                  })
                  .cast<Map<String, dynamic>>()
                  .toList();
              _filtered = List.from(_all);
            });

            // Cache locally for offline access (scoped per user)
            if (_userId != null && _userId! > 0) {
              await prefs.setString(
                'backend_customers_$_userId',
                json.encode(_all),
              );
            }
            setState(() => _loading = false);
            return; // Success, exit early
          }
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Backend fetch failed: $e - Falling back to local data');
        }
      }

      // 🟡 FALLBACK 1: Use cached backend data if available (user-scoped)
      final cacheKey = (_userId != null && _userId! > 0)
          ? 'backend_customers_$_userId'
          : null;
      final cachedRaw = cacheKey != null ? prefs.getString(cacheKey) : null;
      if (cachedRaw != null && cachedRaw.isNotEmpty) {
        try {
          final cached = json.decode(cachedRaw) as List;
          setState(() {
            _all = cached.where((item) {
              if (item is! Map<String, dynamic>) return false;
              // FIX: IDOR Prevention
              final itemUserId = item['user_id'];
              if (itemUserId != null && _userId != null && _userId! > 0) {
                if (itemUserId.toString() != _userId.toString()) return false;
              }
              return true;
            }).cast<Map<String, dynamic>>().toList();
            _filtered = List.from(_all);
          });
          if (kDebugMode) debugPrint('💾 Loaded ${_all.length} customers from cache');
          setState(() => _loading = false);
          return;
        } catch (e) {
          if (kDebugMode) debugPrint('Error loading cached customers: $e');
        }
      }

      // 🟡 FALLBACK 2: Load from local sales data if no local customers saved
      final List<dynamic> localCustomers = await LocalStorageService.loadLocalCustomers();
      if (localCustomers.isNotEmpty) {
        setState(() {
          _all = localCustomers.where((item) {
            if (item is! Map<String, dynamic>) return false;
            // FIX: IDOR Prevention
            final itemUserId = item['user_id'];
            if (itemUserId != null && _userId != null && _userId! > 0) {
              if (itemUserId.toString() != _userId.toString()) return false;
            }
            return true;
          }).cast<Map<String, dynamic>>().toList();
          _filtered = List.from(_all);
        });
        setState(() => _loading = false);
        return;
      }

      // � FALLBACK 3: Extract customers from sales data
      final List<dynamic> sales = await LocalStorageService.loadSales();
      final List<dynamic> localInvoices = await LocalStorageService.loadLocalInvoices();

      final customersMap = <String, Map<String, dynamic>>{};

      for (var sale in sales) {
        final phone = sale['customer_phone']?.toString() ?? 'N/A';
        final name = sale['customer_name']?.toString() ?? 'Customer';

        final key = phone != 'N/A' ? phone : name;

        final saleDate = sale['sale_date'] != null
          ? DateTime.parse(sale['sale_date'] as String)
          : DateTime.now();

        if (!customersMap.containsKey(key)) {
          customersMap[key] = {
            'customer_name': name,
            'phone': phone,
            'email': '',
            'city': '',
            'credit_limit': 0.0,
            'credit_balance': 0.0,
            'total_purchases': 0.0,
            'last_purchase': saleDate.toIso8601String(),
            'purchase_count': 0,
          };
        }

        final amt = double.tryParse(sale['total']?.toString() ?? sale['total_amount']?.toString() ?? '0') ?? 0.0;
        final paid = double.tryParse(sale['paid_amount']?.toString() ?? sale['amount_paid']?.toString() ?? '0') ?? 0.0;
        final due = (amt - paid).clamp(0.0, double.infinity);

        customersMap[key]!['total_purchases'] = (customersMap[key]!['total_purchases'] as double) + amt;
        customersMap[key]!['purchase_count'] = (customersMap[key]!['purchase_count'] as int) + 1;
        customersMap[key]!['credit_limit'] = (customersMap[key]!['credit_limit'] as double) + amt;
        customersMap[key]!['credit_balance'] = (customersMap[key]!['credit_balance'] as double) + due;

        if (saleDate.isAfter(DateTime.parse(customersMap[key]!['last_purchase']))) {
           customersMap[key]!['last_purchase'] = saleDate.toIso8601String();
        }
      }

      for (var invoice in localInvoices) {
        final phone = invoice['customer_phone']?.toString() ?? invoice['phone']?.toString() ?? 'N/A';
        final name = invoice['customer_name']?.toString() ?? 'Customer';
        final key = phone != 'N/A' ? phone : name;
        final status = invoice['status']?.toString().toUpperCase() ?? 'UNPAID';
        if (!['UNPAID', 'PARTIAL'].contains(status)) continue;

        if (!customersMap.containsKey(key)) {
          customersMap[key] = {
            'customer_name': name,
            'phone': phone,
            'email': invoice['email']?.toString() ?? '',
            'city': invoice['city']?.toString() ?? '',
            'credit_limit': 0.0,
            'credit_balance': 0.0,
            'total_purchases': 0.0,
            'last_purchase': DateTime.now().toIso8601String(),
            'purchase_count': 0,
          };
        }

        final total = double.tryParse(invoice['total_amount']?.toString() ?? invoice['amount']?.toString() ?? '0') ?? 0.0;
        final paid = double.tryParse(invoice['paid_amount']?.toString() ?? '0') ?? 0.0;
        final due = (total - paid).clamp(0.0, double.infinity);

        customersMap[key]!['credit_balance'] = (customersMap[key]!['credit_balance'] as double) + due;
        customersMap[key]!['credit_limit'] = (customersMap[key]!['credit_limit'] as double) + total;
      }

      setState(() {
        _all = customersMap.values.whereType<Map<String, dynamic>>().toList();
        _filtered = List.from(_all);
        _loading = false;
      });

      // �🔧 FINAL FALLBACK: Ensure lists are never null
      setState(() {
        _all = [];
        _filtered = [];
        _loading = false;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Critical error in _fetch: $e');
      setState(() {
        _all = [];  // 🔧 FIXED: Ensure lists are initialized even on error
        _filtered = [];
        _loading = false;
      });
    }
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() => _filtered = _all.where((c) =>
        (c['customer_name'] ?? '').toLowerCase().contains(q) ||
        (c['phone'] ?? '').contains(q) ||
        (c['city'] ?? '').toLowerCase().contains(q)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).customers, style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch)],
      ),
      body: Column(children: [
        Container(
          color: _primary,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(children: [
            _chip('${_all.length}', AppLocalizations.of(context).total, Icons.people),
            const SizedBox(width: 10),
            _chip(
              '₹${_all.fold<double>(0, (s, c) => s + (double.tryParse(c['credit_balance']?.toString() ?? '0') ?? 0)).toStringAsFixed(0)}',
              'Total Owed', Icons.account_balance_wallet,
            ),
          ]),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search by name, phone or city...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty ? _emptyState() : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _filtered.length,
            itemBuilder: (_, i) => _customerCard(_filtered[i]),
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        onPressed: _showAddCustomerDialog,
        tooltip: 'Add Customer',
        child: const Icon(Icons.person_add_rounded),
      ),
    );
  }

  Widget _chip(String val, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(val, style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(label, style: GoogleFonts.poppins(
              fontSize: 10, color: Colors.white70)),
        ]),
      ]),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 120, height: 120,
              decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.people_outline, size: 54, color: _primary)),
          const SizedBox(height: 24),
          Text(AppLocalizations.of(context).noCustomersYet, style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text('Add your first customer by tapping the\n+ button below',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade600)),
        ]),
      ),
    );
  }

  Widget _customerCard(Map<String, dynamic> c) {
    final name = c['customer_name'] ?? 'N/A';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final credit = (c['credit_limit'] as num?)?.toStringAsFixed(0) ?? '0';
    final creditBalanceValue = (c['credit_balance'] as num?)?.toDouble() ?? 0.0;
    final creditBalance = creditBalanceValue.toStringAsFixed(0);
    final owesCredit = creditBalanceValue > 0;
    
    final colors = [
      Colors.purple, Colors.blue, Colors.teal,
      Colors.orange, Colors.pink, Colors.indigo,
    ];
    final color = colors[name.codeUnits.first % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              radius: 26,
              child: Text(initial,
                  style: TextStyle(color: color,
                      fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(name, style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (owesCredit) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Owes ₹$creditBalance',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (c['phone'] != null)
                Row(children: [
                  Icon(Icons.phone, size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(c['phone'], style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey.shade500)),
                ]),
              if (c['city'] != null && c['city'] != '')
                Row(children: [
                  Icon(Icons.location_on, size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(c['city'], style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey.shade400)),
                ]),
            ]),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₹$credit',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, color: _primary, fontSize: 13)),
                  Text('Limit', style: GoogleFonts.poppins(
                      fontSize: 9, color: Colors.grey.shade400)),
                ]),
                const SizedBox(width: 8),
                if (c['phone'] != 'N/A')
                  IconButton(
                    icon: const Icon(Icons.call, color: Color(0xFF10B981), size: 20),
                    onPressed: () => launchUrl(Uri.parse('tel:${c['phone']}')),
                  ),
              ],
            ),
            onTap: () => _showDetail(c),
          ),
          // Khata Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddCreditDialog(c),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Credit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      foregroundColor: const Color(0xFF6366F1),
                      textStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _sendWhatsappReminder(c),
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                      foregroundColor: const Color(0xFF10B981),
                      textStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCreditDialog(Map<String, dynamic> customer) {
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    bool isPayment = false;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Khata Entry',
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                customer['customer_name'] ?? 'Customer',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              // Toggle Credit / Payment
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDlgState(() => isPayment = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !isPayment ? const Color(0xFFEF4444) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Gave Credit',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: !isPayment ? Colors.white : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDlgState(() => isPayment = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isPayment ? const Color(0xFF10B981) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Got Payment',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isPayment ? Colors.white : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: amountC,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '0',
                  prefixIcon: Icon(Icons.currency_rupee, color: isPayment ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                  labelText: 'Amount (₹)',
                  labelStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isPayment ? const Color(0xFF10B981) : const Color(0xFFEF4444), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteC,
                decoration: InputDecoration(
                  hintText: 'Add a note (e.g. For Groceries)',
                  prefixIcon: const Icon(Icons.note_alt_outlined),
                  labelText: 'Remarks',
                  labelStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountC.text) ?? 0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount')),
                      );
                      return;
                    }
                    
                    final currentBalance = double.tryParse(customer['credit_balance']?.toString() ?? '0') ?? 0;
                    final newBalance = isPayment ? (currentBalance - amount) : (currentBalance + amount);
                    
                    // Update locally
                    final List<dynamic> localCustomers = await LocalStorageService.loadLocalCustomers();
                    final idx = localCustomers.indexWhere((c) => c['customer_name'] == customer['customer_name']);
                    
                    if (idx >= 0) {
                      localCustomers[idx]['credit_balance'] = newBalance;
                      localCustomers[idx]['last_khata_update'] = DateTime.now().toIso8601String();
                      await LocalStorageService.saveLocalCustomers(localCustomers);
                    } else {
                      // If not found in local list (e.g. came from backend/sales temporarily)
                      // We should ideally add them to local customers to track balance
                      customer['credit_balance'] = newBalance;
                      customer['last_khata_update'] = DateTime.now().toIso8601String();
                      localCustomers.add(customer);
                      await LocalStorageService.saveLocalCustomers(localCustomers);
                    }
                    
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      await _fetch();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isPayment 
                              ? '✅ Payment of ₹${amount.toStringAsFixed(0)} recorded' 
                              : '🔴 Credit of ₹${amount.toStringAsFixed(0)} added'),
                          backgroundColor: isPayment ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPayment ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                  child: Text(
                    isPayment ? 'SAVE PAYMENT' : 'ADD CREDIT',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendWhatsappReminder(Map<String, dynamic> customer) async {
    final phone = customer['phone']?.toString().replaceAll(RegExp(r'[^\d]'), '') ?? '';
    if (phone.isEmpty || phone == 'N/A') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ No phone number available for this customer')),
      );
      return;
    }
    
    final creditBalance = double.tryParse(customer['credit_balance']?.toString() ?? '0') ?? 0;
    if (creditBalance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ℹ️ This customer has no pending balance')),
      );
      return;
    }

    final String shopName = (await SharedPreferences.getInstance()).getString('shop_name') ?? 'our shop';
    
    final msg = 'Hello ${customer['customer_name']},\n\n'
               'This is a friendly reminder regarding your pending balance of *₹${creditBalance.toStringAsFixed(0)}* at *$shopName*. '
               'Kindly settle the amount at your earliest convenience.\n\n'
               'Thank you!';
    
    final encodedMsg = Uri.encodeComponent(msg);
    // WhatsApp URL using 91 as prefix (common in India, can be made dynamic later)
    final whatsappUrl = 'https://wa.me/91$phone?text=$encodedMsg';
    
    try {
      final appUrl = Uri.parse('whatsapp://send?phone=91$phone&text=$encodedMsg');
      final webUrl = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl, mode: LaunchMode.externalApplication);
        return;
      }
      // Fallback: WhatsApp Web also works when the native app URI isn't
      // exposed by Android package visibility or WhatsApp is not installed.
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        return;
      }
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open WhatsApp. Use this link manually if needed: $whatsappUrl')),
      );
    }
  }

  void _showAddCustomerDialog() {
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final emailC = TextEditingController();
    final cityC = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (_, ss) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 4, height: 28, color: _primary, margin: const EdgeInsets.only(right: 12)),
              Text('Add Customer', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 16),
            _inputField(nameC, 'Full Name *', Icons.person_rounded),
            _inputField(phoneC, 'Phone Number', Icons.phone_rounded, type: TextInputType.phone),
            _inputField(emailC, 'Email (optional)', Icons.email_rounded, type: TextInputType.emailAddress),
            _inputField(cityC, 'City', Icons.location_city_rounded),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (nameC.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter customer name')));
                    return;
                  }
                  final List<dynamic> customers = await LocalStorageService.loadLocalCustomers();
                  customers.add({
                    'customer_name': nameC.text.trim(),
                    'phone': phoneC.text.trim().isNotEmpty ? phoneC.text.trim() : 'N/A',
                    'email': emailC.text.trim(),
                    'city': cityC.text.trim(),
                    'credit_balance': 0.0,
                    'purchase_count': 0,
                    'user_id': _userId, // Set ownership
                  });
                  await LocalStorageService.saveLocalCustomers(customers);
                  if (mounted) Navigator.pop(context);
                  await _fetch();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('\u2705 Customer added!'),
                        backgroundColor: _primary));
                  }
                },
                child: Text('Add Customer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
          ]),
        ),
      )),
    );
  }

  Widget _inputField(TextEditingController c, String label, IconData icon, {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _primary, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
          filled: true, fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c['customer_name'] ?? '', style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700)),
          const Divider(height: 24),
          _detailRow(Icons.phone, 'Phone', c['phone'] ?? '--'),
          _detailRow(Icons.email, 'Email', c['email'] ?? '--'),
          _detailRow(Icons.location_city, 'City', c['city'] ?? '--'),
          _detailRow(Icons.credit_card, 'Credit Limit',
              '₹${c['credit_limit'] ?? 0}'),
          _detailRow(Icons.payment, 'Payment Terms',
              c['payment_terms'] ?? '--'),
          const SizedBox(height: 16),
          Text('Transaction History', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: _primary)),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _getCustomerHistory(c),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final history = snapshot.data!;
                if (history.isEmpty) return Center(child: Text('No transactions yet', style: GoogleFonts.poppins(color: Colors.grey)));
                
                return ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, i) {
                    final item = history[i];
                    final isPayment = item['type'] == 'PAYMENT';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(isPayment ? Icons.arrow_downward : Icons.arrow_upward, 
                                   color: isPayment ? Colors.green : Colors.red, size: 18),
                      title: Text(isPayment ? 'Payment Received' : 'Purchase / Credit', 
                                 style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(item['date']?.toString().substring(0, 10) ?? '', style: GoogleFonts.poppins(fontSize: 11)),
                      trailing: Text('₹${item['amount']}', 
                                   style: GoogleFonts.poppins(fontWeight: FontWeight.bold, 
                                                            color: isPayment ? Colors.green : Colors.red)),
                    );
                  },
                );
              }
            ),
          ),
        ]),
      ),
    );
  }

  Future<List<dynamic>> _getCustomerHistory(Map<String, dynamic> c) async {
    final phone = c['phone']?.toString() ?? '';
    final name = c['customer_name']?.toString() ?? '';
    
    final sales = await LocalStorageService.loadSales();
    final localInvs = await LocalStorageService.loadLocalInvoices();
    
    List<dynamic> history = [];
    
    for (var s in sales) {
      if (s['customer_phone'] == phone || s['customer_name'] == name) {
        history.add({
          'date': s['created_at'] ?? s['sale_date'],
          'amount': s['total'] ?? s['total_amount'],
          'type': 'SALE'
        });
      }
    }
    
    for (var inv in localInvs) {
      if (inv['customer_phone'] == phone || inv['customer_name'] == name) {
        history.add({
          'date': inv['created_at'] ?? inv['due_date'],
          'amount': inv['total_amount'],
          'type': inv['status'] == 'PAID' ? 'PAYMENT' : 'SALE'
        });
      }
    }
    
    history.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));
    return history;
  }

  Widget _detailRow(IconData icon, String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, size: 18, color: _primary),
        const SizedBox(width: 10),
        Text('$label: ', style: GoogleFonts.poppins(
            fontSize: 13, color: Colors.grey.shade600)),
        Expanded(child: Text(val, style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

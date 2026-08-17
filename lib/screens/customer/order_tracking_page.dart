import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api_client.dart';
import '../../pdf_invoice_service.dart';

class OrderTrackingPage extends StatefulWidget {
  const OrderTrackingPage({super.key});

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  String? _userName;
  Timer? _pollingTimer;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    // Poll every 15 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) => _fetchOrders(silent: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Customer';
    });
    await _fetchOrders();
  }

  Future<void> _fetchOrders({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final res = await ApiClient.getJson('/store/my-orders');
      if (res.statusCode == 200) {
        final List data = json.decode(res.body)['orders'] ?? json.decode(res.body);
        if (mounted) {
          // 🔧 FIX: Deduplicate orders by order_id to prevent duplicate entries
          final Set<String> seenOrderIds = {};
          final List<Map<String, dynamic>> deduplicatedOrders = [];
          
          for (var e in data) {
            final orderId = e['order_id']?.toString() ?? e['id']?.toString() ?? '';
            if (orderId.isNotEmpty && !seenOrderIds.contains(orderId)) {
              seenOrderIds.add(orderId);
              deduplicatedOrders.add(e as Map<String, dynamic>);
            }
          }
          
          setState(() {
            _orders = deduplicatedOrders;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch orders: $e');
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  void _downloadInvoice(Map<String, dynamic> order) async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating Invoice...')));
      
      final shopName = order['shop_name']?.toString() ?? 'Retail Mind Shop';
      final total = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
      final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
      
      await PdfInvoiceService.generateAndShareInvoice(
        shopName: shopName,
        customerName: _userName ?? 'Customer',
        items: items,
        totalAmount: total,
        paidAmount: total, // Assuming paid if delivered for simplicity
        paymentMethod: order['payment_status']?.toString() ?? 'Online/COD',
        date: DateTime.now(),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate invoice: $e')));
    }
  }

  Widget _buildStepper(String currentStatus) {
    final statuses = ['PENDING', 'ACCEPTED', 'DISPATCHED', 'DELIVERED'];
    if (currentStatus.toUpperCase() == 'REJECTED') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Center(child: Text('ORDER REJECTED', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
      );
    }

    int currentIndex = statuses.indexOf(currentStatus.toUpperCase());
    if (currentIndex == -1) currentIndex = 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(statuses.length, (index) {
          bool isActive = index <= currentIndex;
          bool isLast = index == statuses.length - 1;
          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? Colors.teal : Colors.grey.shade300,
                        border: Border.all(color: isActive ? Colors.teal : Colors.grey.shade400, width: 2),
                      ),
                      child: isActive ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statuses[index].substring(0, 4), // Shorten for UI
                      style: TextStyle(fontSize: 10, color: isActive ? Colors.teal.shade800 : Colors.grey, fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
                    )
                  ],
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isActive ? Colors.teal : Colors.grey.shade300,
                    ),
                  )
              ],
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('My Orders', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : RefreshIndicator(
              onRefresh: () => _fetchOrders(silent: false),
              color: Colors.teal,
              child: _orders.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Center(child: Text('No orders yet', style: GoogleFonts.poppins(fontSize: 20, color: Colors.grey.shade600, fontWeight: FontWeight.bold))),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final order = _orders[index];
                        final orderId = order['order_id']?.toString() ?? 'Unknown';
                        final status = order['status']?.toString() ?? 'PENDING';
                        final shopName = order['shop_name']?.toString() ?? 'Shop';
                        final total = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
                        final items = order['items'] as List? ?? [];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 3,
                          shadowColor: Colors.teal.withValues(alpha: 0.1),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Order #$orderId', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('₹${total.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.teal.shade700)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.storefront, size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 6),
                                    Text(shopName, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 6),
                                    Text('${items.length} items', style: TextStyle(color: Colors.grey.shade600)),
                                  ],
                                ),
                                const Divider(height: 30),
                                
                                // Beautiful Stepper
                                _buildStepper(status),
                                
                                // Invoice Download Action
                                if (status.toUpperCase() == 'DELIVERED') ...[
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _downloadInvoice(order),
                                      icon: const Icon(Icons.download_rounded, color: Colors.teal),
                                      label: Text('Download Invoice', style: GoogleFonts.poppins(color: Colors.teal, fontWeight: FontWeight.w600)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        side: BorderSide(color: Colors.teal.shade300),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  )
                                ]
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

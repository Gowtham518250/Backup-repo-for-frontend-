import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'api_client.dart';
import 'role_selection_page.dart';
import 'shop_browser_page.dart';

class CustomerDashboardPage extends StatefulWidget {
  final String phone;
  const CustomerDashboardPage({super.key, required this.phone});
  @override
  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends State<CustomerDashboardPage> {
  bool _loading = true;
  bool _loggingOut = false;
  List<dynamic> _orders = [];
  String _customerName = "Customer";

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('customer_token') ?? '';
    if (token.isNotEmpty) {
      try {
        final payload = jsonDecode(utf8.decode(base64.decode(base64.normalize(token.split('.')[1]))));
        if (mounted) {
          setState(() => _customerName = payload['name'] ?? 'Shopper');
        }
      } catch (_) {}
    }
  }

  Future<void> _fetchOrders() async {
    try {
      final historyResponse = await ApiClient.getJson(ApiClient.myOrders);
      if (historyResponse.statusCode == 200) {
        final data = jsonDecode(historyResponse.body);
        if (mounted) {
          setState(() => _orders = data is List ? data : (data['orders'] ?? []));
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return; // Prevent duplicate logout taps
    setState(() => _loggingOut = true);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('customer_token');
    await prefs.remove('customer_phone');
    
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RoleSelectionPage(email: '')), (route) => false);
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome back,', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16)),
          Text(_customerName, style: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopBrowserPage())),
            icon: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF4F46E5)),
            label: const Text('Shop Nearby', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final cats = [
      {'icon': Icons.local_grocery_store, 'label': 'Groceries', 'color': Colors.orange},
      {'icon': Icons.checkroom, 'label': 'Fashion', 'color': Colors.pink},
      {'icon': Icons.devices, 'label': 'Electronics', 'color': Colors.blue},
      {'icon': Icons.medical_services, 'label': 'Pharmacy', 'color': Colors.green},
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: cats.map((c) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: (c['color'] as Color).withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(c['icon'] as IconData, color: c['color'] as Color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(c['label'] as String, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12)),
        ],
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('AI Shop Pro', style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          _loggingOut
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(icon: const Icon(Icons.logout, color: Colors.black54), onPressed: _logout),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBanner(),
                  const SizedBox(height: 32),
                  Text('Categories', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildCategories(),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Orders', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(onPressed: (){}, child: const Text('View All')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _orders.isEmpty
                      ? Center(child: Text('No recent orders. Start shopping!', style: GoogleFonts.poppins(color: Colors.grey)))
                      : Column(
                          children: _orders.map((tx) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(12)),
                                    child: const Icon(Icons.receipt_long, color: Colors.indigo),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Order #${tx['id'] ?? tx['order_id'] ?? '??'}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text(tx['created_at']?.toString() ?? 'Online Order', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Text('Rs ${tx['total_amount'] ?? tx['amount'] ?? 0}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
    );
  }
}


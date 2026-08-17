import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'api_client.dart';
import 'sales_entry_page.dart';
import 'visual_widgets.dart';

class WhatsappOrdersPage extends StatefulWidget {
  const WhatsappOrdersPage({super.key});

  @override
  State<WhatsappOrdersPage> createState() => _WhatsappOrdersPageState();
}

class _WhatsappOrdersPageState extends State<WhatsappOrdersPage> {
  bool _isLoading = true;
  List<dynamic> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.getJson('${ApiClient.whatsappOrders}?status=PENDING');
      if (response.statusCode == 200) {
        setState(() {
          _orders = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch whatsapp orders: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectOrder(String orderId) async {
    try {
      final res = await ApiClient.putJson(ApiClient.whatsappOrderStatus(orderId), {'status': 'REJECTED'});
      if (res.statusCode == 200) {
        _fetchOrders();
      }
    } catch (e) {
      debugPrint('Error rejecting order: $e');
    }
  }

  void _processOrder(dynamic order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SalesEntryPage(
          pendingWhatsappText: order['raw_text'],
          pendingWhatsappOrderId: order['id'].toString(),
        ),
      ),
    ).then((_) => _fetchOrders());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'WhatsApp Pending Orders',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _fetchOrders,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No pending WhatsApp orders.',
                        style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[500]),
                      )
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    final date = DateTime.tryParse(order['created_at']) ?? DateTime.now();
                    final timeStr = DateFormat('MMM dd, hh:mm a').format(date);
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.chat, color: Colors.green, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'WhatsApp Order',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                                Text(
                                  timeStr,
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                order['raw_text'] ?? '',
                                style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _rejectOrder(order['id'].toString()),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Reject'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _processOrder(order),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Process Bill'),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

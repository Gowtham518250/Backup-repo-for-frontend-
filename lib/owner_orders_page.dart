import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'api_client.dart';

class OwnerOrdersPage extends StatefulWidget {
  const OwnerOrdersPage({super.key});
  @override
  State<OwnerOrdersPage> createState() => _OwnerOrdersPageState();
}

class _OwnerOrdersPageState extends State<OwnerOrdersPage> {
  bool _loading = true;
  List<dynamic> _orders = [];

  static const _bg = Color(0xFF0F0F1A);
  static const _card = Color(0xFF1A1A2E);
  static const _cardLight = Color(0xFF16213E);

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.getJson('/store/owner/orders');
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        setState(() => _orders = d is List ? d : (d['orders'] ?? []));
      }
    } catch (e) {
      debugPrint('Owner orders fetch error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateOrder(dynamic orderId, String action, {String? reason}) async {
    try {
      String url = '/store/owner/orders/$orderId/action?action=${action.toUpperCase()}';
      await ApiClient.postJson(url, {});
      await _fetchOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #$orderId ${action.toUpperCase()}!'),
            backgroundColor: action.toUpperCase() == 'ACCEPT' ? Colors.green : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint('Update order error: $e');
    }
  }

  // Send WhatsApp message to customer
  Future<void> _sendWhatsApp(String phone, String message) async {
    // Clean phone number - remove leading 0 or country code issues
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.startsWith('0')) cleanPhone = cleanPhone.substring(1);
    if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone'; // Add India country code
    }

    final encoded = Uri.encodeComponent(message);
    final waUrl = 'https://wa.me/$cleanPhone?text=$encoded';

    try {
      final uri = Uri.parse(waUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Cannot launch WhatsApp');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WhatsApp not available on this device.')),
          );
        }
      }
    } catch (e) {
      debugPrint('WhatsApp launch error: $e');
    }
  }

  Future<void> _handleAccept(dynamic order) async {
    final orderId = order['order_id'] ?? order['id'];
    final phone = order['customer_phone']?.toString() ?? '';
    final items = order['items'] as List<dynamic>? ?? [];
    final total = order['total_amount']?.toString() ?? '0';

    // Confirm
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '✅ Accept Order #$orderId?',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'The customer will be notified via WhatsApp that their order has been accepted.',
          style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Accept & Notify', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _updateOrder(orderId, 'ACCEPT');

    // Build item summary
    final itemSummary = items.map((it) =>
      '• ${it['product_name']} x${it['quantity']} — ₹${it['line_total']}'
    ).join('\n');

    // WhatsApp message
    if (phone.isNotEmpty) {
      final message =
          '✅ *Order Accepted!*\n\n'
          'Hello! Your order #$orderId has been *accepted* by the shop.\n\n'
          '🛒 *Items:*\n$itemSummary\n\n'
          '💰 *Total: ₹$total*\n\n'
          'We will prepare your order shortly. Thank you! 🙏';
      await _sendWhatsApp(phone, message);
    }
  }

  Future<void> _handleReject(dynamic order) async {
    final orderId = order['order_id'] ?? order['id'];
    final phone = order['customer_phone']?.toString() ?? '';
    final reasonController = TextEditingController();

    // Reject dialog with reason input
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '❌ Reject Order #$orderId',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a reason for rejection (customer will be notified):',
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Out of stock, Shop closed, Item unavailable...',
                hintStyle: GoogleFonts.poppins(color: Colors.white30, fontSize: 12),
                filled: true,
                fillColor: _cardLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text('Reject & Notify', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (reason == null) return; // User cancelled

    await _updateOrder(orderId, 'REJECT', reason: reason);

    // WhatsApp message with reason
    if (phone.isNotEmpty) {
      final reasonText = reason.isEmpty ? 'Operational issue at the shop.' : reason;
      final message =
          '❌ *Order Update*\n\n'
          'Sorry! Your order #$orderId has been *rejected* by the shop.\n\n'
          '📋 *Reason:* $reasonText\n\n'
          'We apologize for the inconvenience. Please try again or contact the shop directly. 🙏';
      await _sendWhatsApp(phone, message);
    }
  }

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'ACCEPTED': return Colors.greenAccent;
      case 'REJECTED': return Colors.redAccent;
      case 'DISPATCHED': return Colors.blueAccent;
      case 'DELIVERED': return Colors.tealAccent;
      default: return Colors.orangeAccent;
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toUpperCase()) {
      case 'ACCEPTED': return Icons.check_circle_rounded;
      case 'REJECTED': return Icons.cancel_rounded;
      case 'DISPATCHED': return Icons.delivery_dining_rounded;
      case 'DELIVERED': return Icons.done_all_rounded;
      default: return Icons.hourglass_top_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        title: Text(
          'Incoming Orders',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.orangeAccent),
            onPressed: _fetchOrders,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
          : RefreshIndicator(
              onRefresh: _fetchOrders,
              color: Colors.orangeAccent,
              child: _orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inbox_rounded, size: 80, color: Colors.white12),
                          const SizedBox(height: 16),
                          Text(
                            'No orders yet',
                            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Share your QR code to start receiving orders!',
                            style: GoogleFonts.poppins(color: Colors.white24, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      itemBuilder: (ctx, i) {
                        final o = _orders[i];
                        final status = (o['status'] ?? 'PENDING').toString().toUpperCase();
                        final isPending = status == 'PENDING';
                        final isAccepted = status == 'ACCEPTED';
                        final items = o['items'] as List<dynamic>? ?? [];
                        final orderId = o['id'] ?? o['order_id'] ?? i + 1;
                        final phone = o['customer_phone']?.toString() ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: _cardLight,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _statusColor(status).withValues(alpha: 0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _statusColor(status).withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Header
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Order #$orderId',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(_statusIcon(status), color: _statusColor(status), size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                            status,
                                            style: GoogleFonts.poppins(
                                              color: _statusColor(status),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Customer Info
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person_rounded, color: Colors.white38, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      o['customer_name']?.toString() ?? 'Guest Customer',
                                      style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13),
                                    ),
                                    if (phone.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.phone_rounded, color: Colors.white24, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        phone,
                                        style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Delivery address
                              if (o['delivery_address'] != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.location_on_rounded, color: Colors.white24, size: 14),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          o['delivery_address'].toString(),
                                          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Items List
                              if (items.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _card,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      children: items.map((it) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 3),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '• ${it['product_name']} x${it['quantity']}',
                                                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                                                ),
                                              ),
                                              Text(
                                                '₹${it['line_total']}',
                                                style: GoogleFonts.poppins(
                                                  color: Colors.orangeAccent,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),

                              // Total
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total Amount',
                                      style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13),
                                    ),
                                    Text(
                                      '₹${o['total_amount'] ?? 0}',
                                      style: GoogleFonts.poppins(
                                        color: Colors.orangeAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Action Buttons (only for PENDING)
                              if (isPending) ...[
                                const Divider(color: Colors.white12, height: 1),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _handleAccept(o),
                                          icon: const Icon(Icons.check_rounded, size: 16),
                                          label: Text(
                                            'Accept',
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _handleReject(o),
                                          icon: const Icon(Icons.close_rounded, size: 16),
                                          label: Text(
                                            'Reject',
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Dispatch button for ACCEPTED orders
                              if (isAccepted) ...[
                                const Divider(color: Colors.white12, height: 1),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      await _updateOrder(orderId, 'DISPATCH');
                                      // Notify customer
                                      if (phone.isNotEmpty) {
                                        final message =
                                          '🚚 *Order Dispatched!*\n\n'
                                          'Your order #$orderId is on the way! 🎉\n\n'
                                          'Please keep your phone handy for delivery. Thank you! 🙏';
                                        await _sendWhatsApp(phone, message);
                                      }
                                    },
                                    icon: const Icon(Icons.delivery_dining_rounded, size: 18),
                                    label: Text(
                                      'Mark as Dispatched & Notify',
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(double.infinity, 44),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:async';
import 'api_client.dart';

class CheckoutPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final String shopId;
  const CheckoutPage({super.key, required this.cartItems, required this.shopId});
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _addressC = TextEditingController();
  String _paymentMethod = 'CASH';
  bool _placing = false;

  double get _total => widget.cartItems.fold(0.0, (s, i) => s + ((i['price'] ?? 0) as num).toDouble() * ((i['quantity'] ?? 1) as num).toDouble());

  Future<void> _placeOrder() async {
    if (_addressC.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter delivery address')));
      return;
    }
    setState(() => _placing = true);
    try {
      final res = await ApiClient.postJson('/store/order', {
        'shop_id': widget.shopId,
        'items': widget.cartItems.map((i) => {'product_id': i['product_id'], 'quantity': i['quantity'], 'price': i['price']}).toList(),
        'delivery_address': _addressC.text,
        'payment_method': _paymentMethod,
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final orderId = data['order_id']?.toString() ?? data['id']?.toString() ?? '0';
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderTrackingPage(orderId: orderId)));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${jsonDecode(res.body)['detail'] ?? 'Error'}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(backgroundColor: Colors.indigo, title: Text('Checkout', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Order Summary', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...widget.cartItems.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(item['product_name']?.toString() ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w500))),
              Text('x${item['quantity']}', style: GoogleFonts.poppins(color: Colors.grey)),
              const SizedBox(width: 12),
              Text('Rs ${((item['price'] ?? 0) as num).toDouble() * ((item['quantity'] ?? 1) as num).toDouble()}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.indigo)),
            ]),
          )),
          const Divider(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Rs ${_total.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
          ]),
          const SizedBox(height: 24),
          TextField(
            controller: _addressC,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Delivery Address',
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.location_on),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
            items: const [
              DropdownMenuItem(value: 'CASH', child: Text('Cash on Delivery')),
              DropdownMenuItem(value: 'UPI', child: Text('UPI Payment')),
              DropdownMenuItem(value: 'ONLINE', child: Text('Online Payment')),
            ],
            onChanged: (v) => setState(() => _paymentMethod = v!),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton.icon(
              onPressed: _placing ? null : _placeOrder,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              icon: _placing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.shopping_bag),
              label: Text(_placing ? 'Placing...' : 'Place Order', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}

class OrderTrackingPage extends StatefulWidget {
  final String orderId;
  const OrderTrackingPage({super.key, required this.orderId});
  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  Timer? _timer;
  Map<String, dynamic> _order = {};
  bool _loading = true;

  final _steps = ['ORDER_PLACED', 'CONFIRMED', 'PREPARING', 'OUT_FOR_DELIVERY', 'DELIVERED'];
  final _stepLabels = ['Order Placed', 'Confirmed', 'Preparing', 'Out for Delivery', 'Delivered'];

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    try {
      final res = await ApiClient.getJson('/store/order/${widget.orderId}/track');
      if (res.statusCode == 200) {
        setState(() => _order = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Track error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _currentStep {
    final status = (_order['status'] ?? 'ORDER_PLACED').toString().toUpperCase();
    final idx = _steps.indexOf(status);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(backgroundColor: Colors.indigo, title: Text('Track Order #${widget.orderId}', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.local_shipping, size: 48, color: Colors.indigo),
                const SizedBox(height: 16),
                Text('Order Status', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Expanded(
                  child: Stepper(
                    currentStep: _currentStep,
                    controlsBuilder: (ctx, details) => const SizedBox.shrink(),
                    steps: List.generate(_steps.length, (i) => Step(
                      title: Text(_stepLabels[i], style: GoogleFonts.poppins(fontWeight: i <= _currentStep ? FontWeight.bold : FontWeight.normal, color: i <= _currentStep ? Colors.indigo : Colors.grey)),
                      content: const SizedBox.shrink(),
                      isActive: i <= _currentStep,
                      state: i < _currentStep ? StepState.complete : (i == _currentStep ? StepState.editing : StepState.indexed),
                    )),
                  ),
                ),
                Text('Auto-refreshes every 30s', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
              ]),
            ),
    );
  }
}

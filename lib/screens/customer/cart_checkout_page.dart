import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../visual_widgets.dart';
import '../../customer_shop_service.dart';
import '../../online_order_service.dart';

class CustomerCartPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final String shopId;
  final String shopName;

  const CustomerCartPage({
    super.key,
    required this.cartItems,
    this.shopId = '',
    this.shopName = 'Shop',
  });

  @override
  State<CustomerCartPage> createState() => _CustomerCartPageState();
}

class _CustomerCartPageState extends State<CustomerCartPage> {
  late List<Map<String, dynamic>> _items;
  bool _isPlacingOrder = false;
  String _paymentMode = 'upi';
  String? _shopUpi;
  bool _loadingUpi = true;

  @override
  void initState() {
    super.initState();
    _items = List<Map<String, dynamic>>.from(widget.cartItems);
    _loadUpi();
  }

  Future<void> _loadUpi() async {
    final upi = await OnlineOrderService.fetchShopUpi(widget.shopId);
    if (!mounted) return;
    setState(() {
      _shopUpi = upi;
      _loadingUpi = false;
      if (upi == null || upi.isEmpty) _paymentMode = 'cod';
    });
  }

  double get _totalAmount {
    return _items.fold(0.0, (sum, item) => sum + (item['price'] as num) * (item['qty'] as num));
  }

  String get _upiPayUri {
    final upi = _shopUpi ?? '';
    return 'upi://pay?pa=$upi&pn=${Uri.encodeComponent(widget.shopName)}'
        '&am=${_totalAmount.toStringAsFixed(2)}&cu=INR'
        '&tn=Order-${DateTime.now().millisecondsSinceEpoch % 100000}';
  }

  Future<void> _openUpiApp() async {
    final uri = Uri.parse(_upiPayUri);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _placeOrder() async {
    setState(() => _isPlacingOrder = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role');
      final String email = role == 'customer'
          ? (prefs.getString('customer_email') ??
              '${prefs.getString('customer_phone') ?? 'guest'}@customer.local')
          : (prefs.getString('customer_email') ?? 'guest@customer.local');

      final paymentStatus = _paymentMode == 'cod' ? 'cod' : 'pending';

      final orderId = await CustomerShopService.placeOrder(
        shopId: widget.shopId,
        shopName: widget.shopName,
        customerEmail: email,
        items: _items,
        totalAmount: _totalAmount,
        paymentMethod: _paymentMode,
        paymentStatus: paymentStatus,
      );

      await prefs.setString('last_online_order_id', orderId);

      if (!mounted) return;

      if (_paymentMode == 'upi' && _shopUpi != null && _shopUpi!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed! Pay via UPI — we will confirm when payment is received.'),
            duration: Duration(seconds: 4),
          ),
        );
      }

      Navigator.pushReplacementNamed(
        context,
        '/order-tracking',
        arguments: {'orderId': orderId},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order failed: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isPlacingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        title: const Text('Your Cart', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _items.isEmpty
          ? const Center(child: Text('Your cart is empty', style: TextStyle(color: Colors.white)))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ..._items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GlassContainer(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                _productThumb(item['image_url']?.toString()),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '₹${item['price']} x ${item['qty']}',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${(item['price'] as num) * (item['qty'] as num)}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      const Text('Payment method', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Pay via UPI'),
                              selected: _paymentMode == 'upi',
                              onSelected: _shopUpi == null
                                  ? null
                                  : (_) => setState(() => _paymentMode = 'upi'),
                              selectedColor: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Cash on delivery'),
                              selected: _paymentMode == 'cod',
                              onSelected: (_) => setState(() => _paymentMode = 'cod'),
                              selectedColor: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      if (_paymentMode == 'upi' && !_loadingUpi) ...[
                        const SizedBox(height: 16),
                        if (_shopUpi == null || _shopUpi!.isEmpty)
                          const Text(
                            'Shop has no UPI ID — use Cash on delivery.',
                            style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                          )
                        else ...[
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: QrImageView(
                                data: _upiPayUri,
                                size: 160,
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Scan & pay ₹${_totalAmount.toStringAsFixed(2)} to $_shopUpi',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          TextButton(
                            onPressed: _openUpiApp,
                            child: const Text('Open UPI app'),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(color: Colors.white, fontSize: 18)),
                          Text(
                            '₹${_totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isPlacingOrder ? null : _placeOrder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isPlacingOrder
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  _paymentMode == 'upi' ? 'Place order & pay UPI' : 'Place order (COD)',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _productThumb(String? url) {
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholderIcon(),
        ),
      );
    }
    return _placeholderIcon();
  }

  Widget _placeholderIcon() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.shopping_bag, color: AppColors.primary),
    );
  }
}

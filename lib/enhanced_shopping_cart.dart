import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Flipkart-level Enhanced Shopping Cart
/// Features: Smart cart, save for later, quantity management, price optimization, delivery estimates
class EnhancedShoppingCart extends StatefulWidget {
  const EnhancedShoppingCart({super.key});

  @override
  State<EnhancedShoppingCart> createState() => _EnhancedShoppingCartState();
}

class _EnhancedShoppingCartState extends State<EnhancedShoppingCart> {
  List<CartItem> _cartItems = [];
  List<CartItem> _savedForLater = [];
  double _totalAmount = 0.0;
  double _savingsAmount = 0.0;
  double _deliveryFee = 0.0;
  String _selectedDeliverySlot = 'Standard Delivery (3-5 days)';
  String _selectedPaymentMethod = 'UPI';
  bool _isProcessing = false;
  
  // Cart optimization suggestions
  List<CartSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _loadCartData();
  }

  Future<void> _loadCartData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load cart items
    final cartJson = prefs.getString('shopping_cart');
    if (cartJson != null) {
      final List<dynamic> decoded = json.decode(cartJson);
      setState(() {
        _cartItems = decoded.map((e) => CartItem.fromJson(e)).toList();
      });
    }

    // Load saved for later items
    final savedJson = prefs.getString('saved_for_later');
    if (savedJson != null) {
      final List<dynamic> decoded = json.decode(savedJson);
      setState(() {
        _savedForLater = decoded.map((e) => CartItem.fromJson(e)).toList();
      });
    }

    _calculateTotals();
    _generateSuggestions();
  }

  Future<void> _saveCartData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shopping_cart', json.encode(_cartItems.map((e) => e.toJson()).toList()));
    await prefs.setString('saved_for_later', json.encode(_savedForLater.map((e) => e.toJson()).toList()));
  }

  void _calculateTotals() {
    setState(() {
      _totalAmount = _cartItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
      _savingsAmount = _cartItems.fold(0.0, (sum, item) {
        final originalPrice = item.price / (1 - item.discount / 100);
        return sum + ((originalPrice - item.price) * item.quantity);
      });
      _deliveryFee = _totalAmount >= 500 ? 0.0 : 40.0;
    });
  }

  void _generateSuggestions() {
    setState(() {
      _suggestions = [
        if (_totalAmount < 500 && _totalAmount > 0)
          CartSuggestion(
            type: SuggestionType.delivery_saving,
            message: 'Add ₹${(500 - _totalAmount).toInt()} more for free delivery',
            action: 'Add more items',
          ),
        if (_cartItems.length >= 2 && !_cartItems.any((item) => item.brand == 'Apple'))
          CartSuggestion(
            type: SuggestionType.bundle_deal,
            message: 'Complete the look with accessories',
            action: 'View accessories',
          ),
        if (_cartItems.any((item) => item.discount >= 10))
          CartSuggestion(
            type: SuggestionType.discount_alert,
            message: 'You have items with great discounts!',
            action: 'View deals',
          ),
      ];
    });
  }

  Future<void> _updateQuantity(CartItem item, int newQuantity) async {
    if (newQuantity <= 0) {
      await _removeFromCart(item);
      return;
    }

    if (newQuantity > item.maxQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Only ${item.maxQuantity} items available')),
      );
      return;
    }

    setState(() {
      final index = _cartItems.indexWhere((cartItem) => cartItem.id == item.id);
      if (index != -1) {
        _cartItems[index] = item.copyWith(quantity: newQuantity);
        _calculateTotals();
        _generateSuggestions();
      }
    });

    await _saveCartData();
  }

  Future<void> _removeFromCart(CartItem item) async {
    setState(() {
      _cartItems.removeWhere((cartItem) => cartItem.id == item.id);
      _calculateTotals();
      _generateSuggestions();
    });

    await _saveCartData();
  }

  Future<void> _moveToSavedForLater(CartItem item) async {
    setState(() {
      _cartItems.removeWhere((cartItem) => cartItem.id == item.id);
      _savedForLater.add(item);
      _calculateTotals();
      _generateSuggestions();
    });

    await _saveCartData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Moved to Saved for Later')),
    );
  }

  Future<void> _moveToCart(CartItem item) async {
    setState(() {
      _savedForLater.removeWhere((savedItem) => savedItem.id == item.id);
      if (_cartItems.any((cartItem) => cartItem.id == item.id)) {
        final existingItem = _cartItems.firstWhere((cartItem) => cartItem.id == item.id);
        final updatedItem = existingItem.copyWith(
          quantity: existingItem.quantity + item.quantity,
        );
        _cartItems.removeWhere((cartItem) => cartItem.id == item.id);
        _cartItems.add(updatedItem);
      } else {
        _cartItems.add(item);
      }
      _calculateTotals();
      _generateSuggestions();
    });

    await _saveCartData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Moved to Cart')),
    );
  }

  Future<void> _processCheckout() async {
    setState(() => _isProcessing = true);
    
    try {
      // Simulate order processing
      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) return;
      
      // Clear cart after successful order
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('shopping_cart');
      
      setState(() {
        _cartItems.clear();
        _isProcessing = false;
      });

      if (mounted) {
        _showOrderSuccessDialog();
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout failed: $e')),
      );
    }
  }

  void _showOrderSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Text('Order Placed!', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Your order has been placed successfully', style: GoogleFonts.poppins()),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Icon(Icons.local_shipping, size: 32, color: Colors.green),
                  const SizedBox(height: 8),
                  Text(
                    'Estimated Delivery: 3-5 business days',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to previous screen
            },
            child: const Text('Continue Shopping'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              // Navigate to order tracking
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[600]),
            child: const Text('Track Order'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Shopping Cart', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (_cartItems.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _cartItems.clear();
                  _savedForLater.clear();
                  _calculateTotals();
                  _generateSuggestions();
                });
                _saveCartData();
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear'),
            ),
        ],
      ),
      body: _cartItems.isEmpty && _savedForLater.isEmpty
          ? _buildEmptyCart()
          : _buildCartContent(),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add items to get started',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[600]),
            child: const Text('Start Shopping'),
          ),
        ],
      ),
    );
  }

  Widget _buildCartContent() {
    return Column(
      children: [
        // Suggestions
        if (_suggestions.isNotEmpty)
          Container(
            color: Colors.orange[50],
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.orange[600]),
                    const SizedBox(width: 8),
                    Text('Suggestions', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ..._suggestions.map((suggestion) => _buildSuggestionItem(suggestion)),
              ],
            ),
          ),
        // Cart items
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_cartItems.isNotEmpty) ...[
                Text(
                  'Cart Items (${_cartItems.length})',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ..._cartItems.map((item) => _buildCartItem(item)),
              ],
              if (_savedForLater.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Saved for Later (${_savedForLater.length})',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ..._savedForLater.map((item) => _buildSavedItem(item)),
              ],
            ],
          ),
        ),
        // Checkout section
        _buildCheckoutSection(),
      ],
    );
  }

  Widget _buildSuggestionItem(CartSuggestion suggestion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              suggestion.message,
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () {
              // Handle suggestion action
            },
            child: Text(suggestion.action, style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange[600])),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: item.images.isNotEmpty
                  ? Image.network(item.images[0], fit: BoxFit.cover)
                  : Icon(Icons.image, color: Colors.grey[400]),
            ),
            const SizedBox(width: 12),
            // Product details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(item.brand, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '₹${item.price}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[600],
                        ),
                      ),
                      if (item.discount > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '₹${(item.price / (1 - item.discount / 100)).toInt()}',
                          style: GoogleFonts.poppins(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${item.discount}% OFF',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Quantity controls
            Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 16),
                        onPressed: () => _updateQuantity(item, item.quantity - 1),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      Text(
                        '${item.quantity}',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        onPressed: () => _updateQuantity(item, item.quantity + 1),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.bookmark_border, size: 20),
                  onPressed: () => _moveToSavedForLater(item),
                  tooltip: 'Save for later',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _removeFromCart(item),
                  tooltip: 'Remove',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedItem(CartItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product image
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: item.images.isNotEmpty
                  ? Image.network(item.images[0], fit: BoxFit.cover)
                  : Icon(Icons.image, color: Colors.grey[400]),
            ),
            const SizedBox(width: 12),
            // Product details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${item.price}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[600],
                    ),
                  ),
                ],
              ),
            ),
            // Move to cart button
            IconButton(
              icon: const Icon(Icons.add_shopping_cart, size: 20),
              onPressed: () => _moveToCart(item),
              tooltip: 'Move to cart',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price details
          _buildPriceDetail('Subtotal', _totalAmount),
          _buildPriceDetail('Savings', -_savingsAmount, isGreen: true),
          _buildPriceDetail('Delivery Fee', _deliveryFee),
          const Divider(height: 24),
          _buildPriceDetail('Total', _totalAmount + _deliveryFee, isBold: true),
          const SizedBox(height: 16),
          
          // Delivery slot selection
          Text('Delivery Slot', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedDeliverySlot,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'Standard Delivery (3-5 days)', child: Text('Standard Delivery (3-5 days)')),
                  DropdownMenuItem(value: 'Express Delivery (1-2 days)', child: Text('Express Delivery (1-2 days) - ₹99')),
                  DropdownMenuItem(value: 'Same Day Delivery', child: Text('Same Day Delivery - ₹149')),
                ],
                onChanged: (value) {
                  setState(() => _selectedDeliverySlot = value!);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Payment method selection
          Text('Payment Method', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildPaymentMethod('UPI', 'UPI'),
              _buildPaymentMethod('Credit/Debit Card', 'card'),
              _buildPaymentMethod('Net Banking', 'account_balance'),
              _buildPaymentMethod('Cash on Delivery', 'payments'),
            ],
          ),
          const SizedBox(height: 16),
          
          // Place order button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _cartItems.isEmpty ? null : _processCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'Place Order • ₹${(_totalAmount + _deliveryFee).toInt()}',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceDetail(String label, double amount, {bool isBold = false, bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            amount >= 0 ? '₹${amount.toInt()}' : '-₹${amount.abs().toInt()}',
            style: GoogleFonts.poppins(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isGreen ? Colors.green : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod(String label, String icon) {
    final isSelected = _selectedPaymentMethod == label;
    return FilterChip(
      label: Row(
        children: [
          Icon(_getPaymentIcon(icon), size: 16),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.poppins(fontSize: 12)),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedPaymentMethod = label);
      },
      selectedColor: Colors.orange[100],
      checkmarkColor: Colors.orange[900],
    );
  }

  IconData _getPaymentIcon(String icon) {
    switch (icon) {
      case 'UPI': return Icons.account_balance_wallet;
      case 'card': return Icons.credit_card;
      case 'account_balance': return Icons.account_balance;
      case 'payments': return Icons.payments;
      default: return Icons.payment;
    }
  }
}

// Models and supporting classes
class CartItem {
  final int id;
  final String name;
  final String brand;
  final double price;
  final int quantity;
  final int maxQuantity;
  final int discount;
  final List<String> images;
  final bool inStock;

  CartItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
    required this.quantity,
    this.maxQuantity = 10,
    this.discount = 0,
    required this.images,
    this.inStock = true,
  });

  CartItem copyWith({
    int? quantity,
  }) {
    return CartItem(
      id: id,
      name: name,
      brand: brand,
      price: price,
      quantity: quantity ?? this.quantity,
      maxQuantity: maxQuantity,
      discount: discount,
      images: images,
      inStock: inStock,
    );
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as int,
      name: json['name'] as String,
      brand: json['brand'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] as int,
      maxQuantity: json['maxQuantity'] as int? ?? 10,
      discount: json['discount'] as int? ?? 0,
      images: List<String>.from(json['images'] as List),
      inStock: json['inStock'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'price': price,
      'quantity': quantity,
      'maxQuantity': maxQuantity,
      'discount': discount,
      'images': images,
      'inStock': inStock,
    };
  }
}

class CartSuggestion {
  final SuggestionType type;
  final String message;
  final String action;

  CartSuggestion({
    required this.type,
    required this.message,
    required this.action,
  });
}

enum SuggestionType {
  delivery_saving,
  bundle_deal,
  discount_alert,
}
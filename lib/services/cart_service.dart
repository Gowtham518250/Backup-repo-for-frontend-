import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 🔧 FLIPKART-LEVEL: Cart Service
/// Manages shopping cart operations with persistence and sync
class CartService {
  static const String _cartKey = 'shopping_cart';
  static const String _cartSyncKey = 'cart_sync_timestamp';

  /// 🔧 FLIPKART-LEVEL: Get cart items
  static Future<List<Map<String, dynamic>>> getCartItems() async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString(_cartKey);
    
    if (cartJson == null) return [];
    
    try {
      final List<dynamic> decoded = json.decode(cartJson);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading cart: $e');
      return [];
    }
  }

  /// 🔧 FLIPKART-LEVEL: Save cart items
  static Future<void> saveCartItems(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = json.encode(items);
    await prefs.setString(_cartKey, cartJson);
    await prefs.setString(_cartSyncKey, DateTime.now().toIso8601String());
  }

  /// 🔧 FLIPKART-LEVEL: Add item to cart
  static Future<void> addToCart(Map<String, dynamic> product, {int quantity = 1}) async {
    final cartItems = await getCartItems();
    
    final productId = (product['id'] ?? product['product_id']).toString();
    final existingIndex = cartItems.indexWhere((item) => 
      (item['product_id'] ?? item['id']).toString() == productId
    );

    if (existingIndex != -1) {
      // Update quantity if item exists
      final currentQty = cartItems[existingIndex]['quantity'] ?? 1;
      cartItems[existingIndex]['quantity'] = currentQty + quantity;
    } else {
      // Add new item
      cartItems.add({
        'product_id': productId,
        'name': product['name'] ?? 'Unknown Product',
        'price': product['price'] ?? product['selling_price'] ?? 0,
        'quantity': quantity,
        'image_url': product['image_url'] ?? '',
        'stock': product['current_stock'] ?? product['stock'] ?? 0,
        'added_at': DateTime.now().toIso8601String(),
      });
    }

    await saveCartItems(cartItems);
  }

  /// 🔧 FLIPKART-LEVEL: Update item quantity
  static Future<void> updateQuantity(String productId, int quantity) async {
    final cartItems = await getCartItems();
    
    final index = cartItems.indexWhere((item) => 
      (item['product_id'] ?? item['id']).toString() == productId
    );

    if (index != -1) {
      if (quantity <= 0) {
        cartItems.removeAt(index);
      } else {
        cartItems[index]['quantity'] = quantity;
      }
      await saveCartItems(cartItems);
    }
  }

  /// 🔧 FLIPKART-LEVEL: Remove item from cart
  static Future<void> removeFromCart(String productId) async {
    final cartItems = await getCartItems();
    cartItems.removeWhere((item) => 
      (item['product_id'] ?? item['id']).toString() == productId
    );
    await saveCartItems(cartItems);
  }

  /// 🔧 FLIPKART-LEVEL: Clear entire cart
  static Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartKey);
    await prefs.remove(_cartSyncKey);
  }

  /// 🔧 FLIPKART-LEVEL: Get cart total
  static Future<double> getCartTotal() async {
    final cartItems = await getCartItems();
    double total = 0.0;
    
    for (var item in cartItems) {
      final price = item['price'] ?? 0;
      final quantity = item['quantity'] ?? 1;
      total += (price is num ? price.toDouble() : double.tryParse(price.toString()) ?? 0.0) * quantity;
    }
    
    return total;
  }

  /// 🔧 FLIPKART-LEVEL: Get cart item count
  static Future<int> getCartItemCount() async {
    final cartItems = await getCartItems();
    int count = 0;
    
    for (var item in cartItems) {
      count += (item['quantity'] ?? 1) as int;
    }
    
    return count;
  }

  /// 🔧 FLIPKART-LEVEL: Check if product is in cart
  static Future<bool> isInCart(String productId) async {
    final cartItems = await getCartItems();
    return cartItems.any((item) => 
      (item['product_id'] ?? item['id']).toString() == productId
    );
  }

  /// 🔧 FLIPKART-LEVEL: Get quantity of product in cart
  static Future<int> getProductQuantity(String productId) async {
    final cartItems = await getCartItems();
    final item = cartItems.firstWhere(
      (item) => (item['product_id'] ?? item['id']).toString() == productId,
      orElse: () => {},
    );
    return item['quantity'] ?? 0;
  }

  /// 🔧 FLIPKART-LEVEL: Validate cart stock availability
  static Future<Map<String, dynamic>> validateCartStock() async {
    final cartItems = await getCartItems();
    final outOfStockItems = <Map<String, dynamic>>[];
    
    for (var item in cartItems) {
      final requestedQty = item['quantity'] ?? 1;
      final availableStock = item['stock'] ?? 0;
      
      if (requestedQty > availableStock) {
        outOfStockItems.add({
          'product_id': item['product_id'],
          'name': item['name'],
          'requested': requestedQty,
          'available': availableStock,
        });
      }
    }
    
    return {
      'valid': outOfStockItems.isEmpty,
      'out_of_stock': outOfStockItems,
    };
  }

  /// 🔧 FLIPKART-LEVEL: Apply coupon code
  static Future<Map<String, dynamic>> applyCoupon(String couponCode, double cartTotal) async {
    // This would typically call an API to validate the coupon
    // For now, implementing basic coupon logic
    final coupons = {
      'SAVE10': 0.10, // 10% off
      'SAVE20': 0.20, // 20% off
      'FLAT50': 50.0, // Flat ₹50 off
      'FIRST100': 100.0, // Flat ₹100 off for first order
    };

    final discount = coupons[couponCode];
    if (discount == null) {
      return {
        'success': false,
        'message': 'Invalid coupon code',
        'discount': 0.0,
      };
    }

    double discountAmount = 0.0;
    if (discount is double && discount < 1.0) {
      // Percentage discount
      discountAmount = cartTotal * discount;
    } else {
      // Flat discount
      discountAmount = discount as double;
    }

    return {
      'success': true,
      'message': 'Coupon applied successfully',
      'discount': discountAmount,
      'final_total': cartTotal - discountAmount,
    };
  }

  /// 🔧 FLIPKART-LEVEL: Get cart sync timestamp
  static Future<DateTime?> getSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_cartSyncKey);
    if (timestamp == null) return null;
    return DateTime.tryParse(timestamp);
  }

  /// 🔧 FLIPKART-LEVEL: Sync cart with backend
  static Future<bool> syncCartWithBackend(String token) async {
    try {
      final cartItems = await getCartItems();
      if (cartItems.isEmpty) return true;

      // This would typically call an API to sync the cart
      // For now, just update the sync timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cartSyncKey, DateTime.now().toIso8601String());
      
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error syncing cart: $e');
      return false;
    }
  }

  /// 🔧 FLIPKART-LEVEL: Merge local cart with server cart
  static Future<void> mergeCarts(List<Map<String, dynamic>> serverCart) async {
    final localCart = await getCartItems();
    final mergedCart = <Map<String, dynamic>>[];
    
    // Create a map of server cart items for easy lookup
    final serverCartMap = <String, Map<String, dynamic>>{};
    for (var item in serverCart) {
      final productId = (item['product_id'] ?? item['id']).toString();
      serverCartMap[productId] = item;
    }

    // Merge local cart with server cart
    for (var localItem in localCart) {
      final productId = (localItem['product_id'] ?? localItem['id']).toString();
      
      if (serverCartMap.containsKey(productId)) {
        // Item exists in both carts, use the higher quantity
        final serverItem = serverCartMap[productId]!;
        final localQty = localItem['quantity'] ?? 1;
        final serverQty = serverItem['quantity'] ?? 1;
        
        mergedCart.add({
          ...serverItem,
          'quantity': localQty > serverQty ? localQty : serverQty,
        });
        serverCartMap.remove(productId);
      } else {
        // Item only in local cart
        mergedCart.add(localItem);
      }
    }

    // Add remaining server cart items
    mergedCart.addAll(serverCartMap.values);

    await saveCartItems(mergedCart);
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'secure_token_storage.dart';

/// 🛍️ Online Store Integration Service
/// PHASE 6 FIX: Added shop publication status toggle
/// Manages online orders, inventory, and customer interactions
class OnlineStoreService {
  /// PHASE 6 FIX: Enable/Disable shop online publishing
  static Future<Map<String, dynamic>> setShopOnlineStatus(bool isOnline) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        return {'success': false, 'error': 'NOT_AUTHENTICATED'};
      }
      
      final response = await ApiClient.putJson(
        '/api/shop/publish-status',
        {'is_published': isOnline},
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Save to local preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('shop_published_online', isOnline);
        
        if (kDebugMode) {
          debugPrint('✅ Shop online status updated: $isOnline');
        }
        
        return {
          'success': true,
          'is_published': isOnline,
          'message': isOnline 
            ? 'Shop is now visible on Retail Mind marketplace' 
            : 'Shop is now hidden from Retail Mind marketplace',
          'timestamp': data['timestamp'],
        };
      } else {
        if (kDebugMode) debugPrint('⚠️ Failed to update shop online status: ${response.statusCode}');
        return {
          'success': false,
          'error': 'BACKEND_ERROR',
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Shop online status error: $e');
      return {
        'success': false,
        'error': 'NETWORK_ERROR',
        'message': e.toString(),
      };
    }
  }
  
  /// PHASE 6 FIX: Get shop online status
  static Future<bool> getShopOnlineStatus() async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        // Return local cached value if available
        final prefs = await SharedPreferences.getInstance();
        return prefs.getBool('shop_published_online') ?? false;
      }
      
      final response = await ApiClient.getJson(
        '/api/shop/publish-status',
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final isPublished = data['is_published'] ?? false;
        
        // Cache locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('shop_published_online', isPublished);
        
        return isPublished;
      }
      
      // Fallback to cached value
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('shop_published_online') ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to get shop online status: $e');
      // Return cached value on error
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('shop_published_online') ?? false;
    }
  }
  
  /// PHASE 6 FIX: Publish shop to marketplace with location services
  static Future<Map<String, dynamic>> publishShopToMarketplace({
    required double latitude,
    required double longitude,
    String? addressNickname,
    String? operatingHours,
    List<String>? categories,
    bool enableDelivery = false,
    int deliveryRadiusKm = 5,
  }) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        return {'success': false, 'error': 'NOT_AUTHENTICATED'};
      }
      
      final response = await ApiClient.postJson(
        '/api/shop/publish-marketplace',
        {
          'latitude': latitude,
          'longitude': longitude,
          'address_nickname': addressNickname ?? 'Shop Location',
          'operating_hours': operatingHours,
          'categories': categories ?? [],
          'enable_delivery': enableDelivery,
          'delivery_radius_km': deliveryRadiusKm,
        },
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        
        // Save status
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('shop_published_online', true);
        
        if (kDebugMode) {
          debugPrint('✅ Shop published to marketplace');
          debugPrint('   Latitude: $latitude');
          debugPrint('   Longitude: $longitude');
          debugPrint('   Delivery: $enableDelivery');
        }
        
        return {
          'success': true,
          'shop_id': data['shop_id'],
          'marketplace_url': data['marketplace_url'],
          'published_at': data['published_at'],
          'message': 'Your shop is now visible to customers nearby!',
        };
      } else {
        return {
          'success': false,
          'error': 'BACKEND_ERROR',
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Shop marketplace publication error: $e');
      return {
        'success': false,
        'error': 'NETWORK_ERROR',
        'message': e.toString(),
      };
    }
  }
  
  /// PHASE 6 FIX: Unpublish shop from marketplace
  static Future<Map<String, dynamic>> unpublishShopFromMarketplace() async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        return {'success': false, 'error': 'NOT_AUTHENTICATED'};
      }
      
      final response = await ApiClient.deleteJson(
        '/api/shop/publish-marketplace',
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        // Save status
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('shop_published_online', false);
        
        if (kDebugMode) {
          debugPrint('✅ Shop unpublished from marketplace');
        }
        
        return {
          'success': true,
          'message': 'Your shop is no longer visible to customers.',
        };
      } else {
        return {
          'success': false,
          'error': 'BACKEND_ERROR',
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Shop marketplace unpublication error: $e');
      return {
        'success': false,
        'error': 'NETWORK_ERROR',
        'message': e.toString(),
      };
    }
  }
  
  /// Register customer for online store
  static Future<Map<String, dynamic>?> registerCustomer({
    required String phone,
    required String email,
    required String name,
    String? address,
  }) async {
    try {
      final body = {
        'phone': phone,
        'email': email,
        'name': name,
        if (address != null) 'address': address,
      };

      final response = await ApiClient.postJson('/store/customer/register', body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }

      if (kDebugMode) debugPrint('❌ Customer registration failed: ${response.statusCode}');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Customer registration error: $e');
      return null;
    }
  }

  /// Login to online store
  static Future<OnlineCustomerSession?> loginCustomer({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await ApiClient.postJson('/store/customer/login', {
        'phone': phone,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return OnlineCustomerSession.fromJson(data);
      }

      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Customer login error: $e');
      return null;
    }
  }

  /// PHASE 6 FIX: Find nearby shops - only returns published shops
  static Future<List<ShopInfo>> findNearbyShops({
    required double latitude,
    required double longitude,
    int radiusKm = 10,
    int limit = 20,
  }) async {
    try {
      final response = await ApiClient.getJson(
        '/store/shops/nearby?lat=$latitude&lon=$longitude&radius=$radiusKm&limit=$limit&published=true',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['shops'] ?? data['items'] ?? [];

        // Filter out unpublished shops
        final publishedShops = items
            .where((item) => item['published'] == true || item['is_published'] == true)
            .map((item) => ShopInfo.fromJson(item))
            .toList();

        if (kDebugMode) {
          debugPrint('✅ Found ${publishedShops.length} nearby shops');
        }

        return publishedShops;
      }

      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Find nearby shops error: $e');
      return [];
    }
  }

  /// Get shop products
  static Future<List<ShopProduct>> getShopProducts(
    int shopId, {
    String? category,
    int limit = 100,
  }) async {
    try {
      final query = category != null
          ? '/store/shops/$shopId/products?category=$category&limit=$limit'
          : '/store/shops/$shopId/products?limit=$limit';

      final response = await ApiClient.getJson(query);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['products'] ?? data['items'] ?? [];

        return items.map((item) => ShopProduct.fromJson(item)).toList();
      }

      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Get shop products error: $e');
      return [];
    }
  }

  /// Place order
  static Future<OnlineOrder?> placeOrder({
    required int shopId,
    required int customerId,
    required List<OrderItem> items,
    String? deliveryAddress,
    String? notes,
  }) async {
    try {
      final body = {
        'shop_id': shopId,
        'customer_id': customerId,
        'items': items.map((item) => item.toJson()).toList(),
        if (deliveryAddress != null) 'delivery_address': deliveryAddress,
        if (notes != null) 'notes': notes,
      };

      final response = await ApiClient.postJson('/store/order', body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return OnlineOrder.fromJson(json.decode(response.body));
      }

      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Place order error: $e');
      return null;
    }
  }

  /// Get customer orders
  static Future<List<OnlineOrder>> getCustomerOrders(int customerId) async {
    try {
      final response = await ApiClient.getJson('/store/my-orders?customer_id=$customerId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['orders'] ?? data['items'] ?? [];

        return items.map((item) => OnlineOrder.fromJson(item)).toList();
      }

      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Get customer orders error: $e');
      return [];
    }
  }

  /// Track order
  static Future<OrderTracking?> trackOrder(int orderId) async {
    try {
      final response = await ApiClient.getJson('/store/order/$orderId/track');

      if (response.statusCode == 200) {
        return OrderTracking.fromJson(json.decode(response.body));
      }

      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Track order error: $e');
      return null;
    }
  }

  /// Get incoming orders (for shop owner)
  static Future<List<OnlineOrder>> getIncomingOrders() async {
    try {
      final response = await ApiClient.getJson('/store/owner/orders');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['orders'] ?? data['items'] ?? [];

        return items.map((item) => OnlineOrder.fromJson(item)).toList();
      }

      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Get incoming orders error: $e');
      return [];
    }
  }

  /// Update order status
  static Future<bool> updateOrderStatus(
    int orderId,
    String newStatus, {
    String? notes,
  }) async {
    try {
      final body = {
        'status': newStatus,
        if (notes != null) 'notes': notes,
      };

      final response = await ApiClient.putJson(
        '/store/owner/orders/$orderId/action',
        body,
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Update order status error: $e');
      return false;
    }
  }
}

/// Online Customer Session
class OnlineCustomerSession {
  final int customerId;
  final String name;
  final String phone;
  final String email;
  final String token;

  OnlineCustomerSession({
    required this.customerId,
    required this.name,
    required this.phone,
    required this.email,
    required this.token,
  });

  factory OnlineCustomerSession.fromJson(Map<String, dynamic> json) {
    return OnlineCustomerSession(
      customerId: json['customer_id'] ?? json['id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      token: json['token'] ?? json['access_token'] ?? '',
    );
  }
}

/// Shop Info
class ShopInfo {
  final int shopId;
  final String shopName;
  final String category;
  final String address;
  final double latitude;
  final double longitude;
  final double? distance;
  final String? phone;
  final String? openingHours;

  ShopInfo({
    required this.shopId,
    required this.shopName,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.distance,
    this.phone,
    this.openingHours,
  });

  factory ShopInfo.fromJson(Map<String, dynamic> json) {
    return ShopInfo(
      shopId: json['shop_id'] ?? json['id'] ?? 0,
      shopName: json['shop_name'] ?? json['name'] ?? '',
      category: json['category'] ?? '',
      address: json['address'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      distance: json['distance'] != null ? (json['distance'] as num).toDouble() : null,
      phone: json['phone'],
      openingHours: json['opening_hours'],
    );
  }
}

/// Shop Product
class ShopProduct {
  final int productId;
  final String productName;
  final double price;
  final int stock;
  final String? image;
  final String category;
  final String? description;

  ShopProduct({
    required this.productId,
    required this.productName,
    required this.price,
    required this.stock,
    this.image,
    required this.category,
    this.description,
  });

  factory ShopProduct.fromJson(Map<String, dynamic> json) {
    return ShopProduct(
      productId: json['product_id'] ?? json['id'] ?? 0,
      productName: json['product_name'] ?? json['name'] ?? '',
      price: (json['price'] ?? json['unit_price'] ?? 0).toDouble(),
      stock: json['stock'] ?? json['current_stock'] ?? 0,
      image: json['image'],
      category: json['category'] ?? '',
      description: json['description'],
    );
  }
}

/// Order Item
class OrderItem {
  final int productId;
  final int quantity;
  final double price;

  OrderItem({
    required this.productId,
    required this.quantity,
    required this.price,
  });

  toJson() => {
    'product_id': productId,
    'quantity': quantity,
    'price': price,
  };
}

/// Online Order
class OnlineOrder {
  final int orderId;
  final int shopId;
  final int customerId;
  final String status;
  final double totalAmount;
  final DateTime createdAt;
  final List<OrderItem> items;

  OnlineOrder({
    required this.orderId,
    required this.shopId,
    required this.customerId,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    required this.items,
  });

  factory OnlineOrder.fromJson(Map<String, dynamic> json) {
    final List itemsList = json['items'] ?? [];
    return OnlineOrder(
      orderId: json['order_id'] ?? json['id'] ?? 0,
      shopId: json['shop_id'] ?? 0,
      customerId: json['customer_id'] ?? 0,
      status: json['status'] ?? 'pending',
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toString()),
      items: itemsList.map((item) => OrderItem(
        productId: item['product_id'] ?? 0,
        quantity: item['quantity'] ?? 0,
        price: (item['price'] ?? 0).toDouble(),
      )).toList(),
    );
  }
}

/// Order Tracking
class OrderTracking {
  final int orderId;
  final String currentStatus;
  final List<TrackingEvent> events;
  final String? estimatedDelivery;

  OrderTracking({
    required this.orderId,
    required this.currentStatus,
    required this.events,
    this.estimatedDelivery,
  });

  factory OrderTracking.fromJson(Map<String, dynamic> json) {
    final List eventsList = json['events'] ?? [];
    return OrderTracking(
      orderId: json['order_id'] ?? json['id'] ?? 0,
      currentStatus: json['status'] ?? 'pending',
      events: eventsList.map((event) => TrackingEvent.fromJson(event)).toList(),
      estimatedDelivery: json['estimated_delivery'],
    );
  }
}

/// Tracking Event
class TrackingEvent {
  final String status;
  final DateTime timestamp;
  final String? message;

  TrackingEvent({
    required this.status,
    required this.timestamp,
    this.message,
  });

  factory TrackingEvent.fromJson(Map<String, dynamic> json) {
    return TrackingEvent(
      status: json['status'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toString()),
      message: json['message'],
    );
  }
}

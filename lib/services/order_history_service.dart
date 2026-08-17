import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 🔧 FLIPKART-LEVEL: Order History Service
/// Manages order history, tracking, and status updates
class OrderHistoryService {
  static const String _ordersKey = 'order_history';
  static const String _ordersSyncKey = 'orders_sync_timestamp';

  /// 🔧 FLIPKART-LEVEL: Order status enum
  static const List<String> orderStatuses = [
    'PLACED',
    'CONFIRMED',
    'PROCESSING',
    'SHIPPED',
    'OUT_FOR_DELIVERY',
    'DELIVERED',
    'CANCELLED',
    'RETURNED',
    'REFUNDED',
  ];

  /// 🔧 FLIPKART-LEVEL: Get all orders
  static Future<List<Map<String, dynamic>>> getAllOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final ordersJson = prefs.getString(_ordersKey);
    
    if (ordersJson == null) return [];
    
    try {
      final List<dynamic> decoded = json.decode(ordersJson);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading orders: $e');
      return [];
    }
  }

  /// 🔧 FLIPKART-LEVEL: Save orders
  static Future<void> saveOrders(List<Map<String, dynamic>> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final ordersJson = json.encode(orders);
    await prefs.setString(_ordersKey, ordersJson);
    await prefs.setString(_ordersSyncKey, DateTime.now().toIso8601String());
  }

  /// 🔧 FLIPKART-LEVEL: Add new order
  static Future<void> addOrder(Map<String, dynamic> order) async {
    final orders = await getAllOrders();
    
    // Add order with timestamp
    order['order_id'] = order['order_id'] ?? 'ORD${DateTime.now().millisecondsSinceEpoch}';
    order['created_at'] = order['created_at'] ?? DateTime.now().toIso8601String();
    order['updated_at'] = DateTime.now().toIso8601String();
    order['status'] = order['status'] ?? 'PLACED';
    
    orders.insert(0, order); // Add to beginning
    await saveOrders(orders);
  }

  /// 🔧 FLIPKART-LEVEL: Update order status
  static Future<void> updateOrderStatus(String orderId, String status) async {
    final orders = await getAllOrders();
    
    for (var order in orders) {
      if (order['order_id'] == orderId) {
        order['status'] = status;
        order['updated_at'] = DateTime.now().toIso8601String();
        
        // Add status history
        final statusHistory = order['status_history'] as List<dynamic>? ?? [];
        statusHistory.add({
          'status': status,
          'timestamp': DateTime.now().toIso8601String(),
        });
        order['status_history'] = statusHistory;
        
        break;
      }
    }
    
    await saveOrders(orders);
  }

  /// 🔧 FLIPKART-LEVEL: Get order by ID
  static Future<Map<String, dynamic>?> getOrderById(String orderId) async {
    final orders = await getAllOrders();
    
    for (var order in orders) {
      if (order['order_id'] == orderId) {
        return order;
      }
    }
    
    return null;
  }

  /// 🔧 FLIPKART-LEVEL: Get orders by status
  static Future<List<Map<String, dynamic>>> getOrdersByStatus(String status) async {
    final orders = await getAllOrders();
    return orders.where((order) => order['status'] == status).toList();
  }

  /// 🔧 FLIPKART-LEVEL: Get orders by date range
  static Future<List<Map<String, dynamic>>> getOrdersByDateRange(DateTime startDate, DateTime endDate) async {
    final orders = await getAllOrders();
    
    return orders.where((order) {
      final createdAt = DateTime.tryParse(order['created_at'] ?? '');
      if (createdAt == null) return false;
      return createdAt.isAfter(startDate) && createdAt.isBefore(endDate);
    }).toList();
  }

  /// 🔧 FLIPKART-LEVEL: Cancel order
  static Future<bool> cancelOrder(String orderId) async {
    final order = await getOrderById(orderId);
    if (order == null) return false;
    
    final currentStatus = order['status'] as String?;
    if (currentStatus == null) return false;
    
    // Can only cancel orders in certain statuses
    final cancellableStatuses = ['PLACED', 'CONFIRMED', 'PROCESSING'];
    if (!cancellableStatuses.contains(currentStatus)) return false;
    
    await updateOrderStatus(orderId, 'CANCELLED');
    return true;
  }

  /// 🔧 FLIPKART-LEVEL: Return order
  static Future<bool> returnOrder(String orderId, String reason) async {
    final order = await getOrderById(orderId);
    if (order == null) return false;
    
    final currentStatus = order['status'] as String?;
    if (currentStatus != 'DELIVERED') return false;
    
    await updateOrderStatus(orderId, 'RETURNED');
    
    // Add return reason
    final orders = await getAllOrders();
    for (var ord in orders) {
      if (ord['order_id'] == orderId) {
        ord['return_reason'] = reason;
        ord['return_requested_at'] = DateTime.now().toIso8601String();
        break;
      }
    }
    await saveOrders(orders);
    
    return true;
  }

  /// 🔧 FLIPKART-LEVEL: Get order tracking timeline
  static Future<List<Map<String, dynamic>>> getOrderTracking(String orderId) async {
    final order = await getOrderById(orderId);
    if (order == null) return [];
    
    final statusHistory = order['status_history'] as List<dynamic>? ?? [];
    final currentStatus = order['status'] as String?;
    
    // Build timeline from status history
    final timeline = <Map<String, dynamic>>[];
    
    for (var entry in statusHistory) {
      timeline.add({
        'status': entry['status'],
        'timestamp': entry['timestamp'],
        'completed': true,
      });
    }
    
    // Add current status if not in history
    if (currentStatus != null && (timeline.isEmpty || timeline.last['status'] != currentStatus)) {
      timeline.add({
        'status': currentStatus,
        'timestamp': order['updated_at'],
        'completed': true,
      });
    }
    
    // Add future statuses
    final statusIndex = orderStatuses.indexOf(currentStatus ?? 'PLACED');
    if (statusIndex != -1 && statusIndex < orderStatuses.length - 1) {
      for (int i = statusIndex + 1; i < orderStatuses.length; i++) {
        timeline.add({
          'status': orderStatuses[i],
          'timestamp': null,
          'completed': false,
        });
      }
    }
    
    return timeline;
  }

  /// 🔧 FLIPKART-LEVEL: Get order statistics
  static Future<Map<String, dynamic>> getOrderStatistics() async {
    final orders = await getAllOrders();
    
    int totalOrders = orders.length;
    int deliveredOrders = 0;
    int cancelledOrders = 0;
    int returnedOrders = 0;
    double totalSpent = 0.0;
    
    for (var order in orders) {
      final status = order['status'] as String?;
      final total = order['total'] ?? order['amount'] ?? 0;
      
      if (status == 'DELIVERED') {
        deliveredOrders++;
        totalSpent += total is num ? total.toDouble() : double.tryParse(total.toString()) ?? 0.0;
      } else if (status == 'CANCELLED') {
        cancelledOrders++;
      } else if (status == 'RETURNED') {
        returnedOrders++;
      }
    }
    
    return {
      'total_orders': totalOrders,
      'delivered_orders': deliveredOrders,
      'cancelled_orders': cancelledOrders,
      'returned_orders': returnedOrders,
      'total_spent': totalSpent,
      'delivery_rate': totalOrders > 0 ? (deliveredOrders / totalOrders * 100).toStringAsFixed(1) : '0.0',
    };
  }

  /// 🔧 FLIPKART-LEVEL: Search orders
  static Future<List<Map<String, dynamic>>> searchOrders(String query) async {
    final orders = await getAllOrders();
    final lowerQuery = query.toLowerCase();
    
    return orders.where((order) {
      final orderId = (order['order_id'] ?? '').toString().toLowerCase();
      final customerName = (order['customer_name'] ?? '').toString().toLowerCase();
      final customerPhone = (order['customer_phone'] ?? '').toString().toLowerCase();
      
      return orderId.contains(lowerQuery) ||
             customerName.contains(lowerQuery) ||
             customerPhone.contains(lowerQuery);
    }).toList();
  }

  /// 🔧 FLIPKART-LEVEL: Get sync timestamp
  static Future<DateTime?> getSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_ordersSyncKey);
    if (timestamp == null) return null;
    return DateTime.tryParse(timestamp);
  }

  /// 🔧 FLIPKART-LEVEL: Sync orders with backend
  static Future<bool> syncOrdersWithBackend(String token) async {
    try {
      // This would typically call an API to sync orders
      // For now, just update the sync timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ordersSyncKey, DateTime.now().toIso8601String());
      
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error syncing orders: $e');
      return false;
    }
  }
}

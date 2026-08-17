/// Feature 10: Home Delivery Tracking
/// Order intake, status tracking (Pending → Out → Delivered)
/// WhatsApp customer at each step, auto-create sale on delivery

import 'dart:convert';
import 'api_client.dart';
import 'package:flutter/material.dart';

class DeliveryTrackingService {
  
  /// Create delivery order
  static Future<int?> createDelivery({
    required int customerId,
    required int invoiceId,
    required String deliveryAddress,
    required String? deliveryDate,
    required String? specialInstructions,
  }) async {
    try {
      final response = await ApiClient.postJson('/api/delivery/create', {
        'customer_id': customerId,
        'invoice_id': invoiceId,
        'delivery_address': deliveryAddress,
        'delivery_date': deliveryDate,
        'special_instructions': specialInstructions,
      });
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['delivery_id'];
      }
      return null;
    } catch (e) {
      print('Error creating delivery: $e');
      return null;
    }
  }
  
  /// Update delivery status
  static Future<bool> updateDeliveryStatus({
    required int deliveryId,
    required String status, // PENDING, OUT, DELIVERED, FAILED
    required String? notes,
  }) async {
    try {
      final response = await ApiClient.postJson(
        '/api/delivery/$deliveryId/update-status',
        {
          'status': status,
          'notes': notes,
        }
      );
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// Get today's deliveries
  static Future<List<Map<String, dynamic>>> getTodayDeliveries() async {
    try {
      final response = await ApiClient.getJson('/api/delivery/today');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['deliveries'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  
  /// Get delivery status
  static Future<Map<String, dynamic>?> getDeliveryStatus(int deliveryId) async {
    try {
      final response = await ApiClient.getJson('/api/delivery/$deliveryId/status');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}


/// Feature 11: Multi-Staff Billing Counters
/// Each worker: 4-digit PIN, counter number
/// Dashboard: per-staff sales breakdown

class BillingCounterService {
  
  /// Authenticate staff with PIN
  static Future<Map<String, dynamic>?> authenticateCounter(String pin) async {
    try {
      final response = await ApiClient.postJson('/api/counter/authenticate', {
        'billing_pin': pin,
      });
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Tag sale to counter/staff
  static Future<bool> tagSaleToCounter({
    required int invoiceId,
    required String staffName,
    required int counterNumber,
    required double saleAmount,
  }) async {
    try {
      final response = await ApiClient.postJson('/api/counter/tag-sale', {
        'invoice_id': invoiceId,
        'staff_name': staffName,
        'counter_number': counterNumber,
        'sale_amount': saleAmount,
      });
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// Get counter sales breakdown for today
  static Future<List<Map<String, dynamic>>> getCountersSummary() async {
    try {
      final response = await ApiClient.getJson('/api/counter/summary-today');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['counters'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  
  /// Get specific counter daily sales
  static Future<Map<String, dynamic>?> getCounterDailySales(int counterId) async {
    try {
      final response = await ApiClient.getJson('/api/counter/$counterId/daily-sales');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}


/// Feature 15: Profit Margin Per Product
/// Show margin % (green/amber/red) on product card
/// Dashboard: "top margin products"

class ProfitMarginService {
  
  /// Calculate margin for product
  static double calculateMargin(double sellingPrice, double costPrice) {
    if (costPrice <= 0) return 0;
    return ((sellingPrice - costPrice) / costPrice) * 100;
  }
  
  /// Get margin color (green/amber/red)
  static Color getMarginColor(double marginPercent) {
    if (marginPercent >= 40) return Colors.green;
    if (marginPercent >= 20) return Colors.orange;
    return Colors.red;
  }
  
  /// Get margin badge text
  static String getMarginBadge(double marginPercent) {
    if (marginPercent >= 40) return '💚 High';
    if (marginPercent >= 20) return '⚠️ Medium';
    return '❌ Low';
  }
  
  /// Get top margin products from dashboard
  static Future<List<Map<String, dynamic>>> getTopMarginProducts() async {
    try {
      final response = await ApiClient.getJson('/api/products/top-margin');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['products'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

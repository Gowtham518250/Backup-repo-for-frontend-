import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'api_client.dart';

/// 📊 Low Stock Alerts Service
/// Monitors inventory and alerts when stock falls below threshold
class LowStockAlertsService {
  static const Duration _checkInterval = Duration(hours: 1);
  static DateTime? _lastChecked;

  /// Get all low stock products
  static Future<List<LowStockProduct>> getLowStockProducts({
    int limit = 50,
  }) async {
    try {
      final response = await ApiClient.getJson('/api/inventory/low-stock?limit=$limit');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['low_stock_products'] ?? data['items'] ?? [];
        
        return items
            .map((item) => LowStockProduct.fromJson(item))
            .toList();
      }
      
      if (kDebugMode) debugPrint('⚠️ Failed to fetch low stock: ${response.statusCode}');
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Low stock fetch error: $e');
      return [];
    }
  }

  /// Check if we should refresh low stock list
  static bool shouldRefreshLowStock() {
    if (_lastChecked == null) return true;
    return DateTime.now().difference(_lastChecked!).inMinutes >= 60;
  }

  /// Mark last check time
  static void markChecked() {
    _lastChecked = DateTime.now();
  }

  /// Get stock alert details for a product
  static Future<StockAlertDetails?> getStockAlert(int productId) async {
    try {
      final response = await ApiClient.getJson('/api/inventory/stock-alerts?product_id=$productId');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return StockAlertDetails.fromJson(data);
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Stock alert details error: $e');
      return null;
    }
  }

  /// Create purchase order from low stock products
  static Future<bool> createPurchaseOrderFromLowStock({
    required int productId,
    required int quantity,
    int? supplierId,
  }) async {
    try {
      final body = {
        'product_id': productId,
        'quantity': quantity,
        if (supplierId != null) 'supplier_id': supplierId,
      };

      final response = await ApiClient.postJson(
        '/api/inventory/generate-purchase-orders',
        body,
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Purchase order creation error: $e');
      return false;
    }
  }
}

/// Low Stock Product Model
class LowStockProduct {
  final int productId;
  final String productName;
  final String sku;
  final int currentStock;
  final int minStock;
  final int reorderLevel;
  final int maxStock;
  final double unitPrice;
  final String category;
  final int daysUntilStockout;

  LowStockProduct({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.currentStock,
    required this.minStock,
    required this.reorderLevel,
    required this.maxStock,
    required this.unitPrice,
    required this.category,
    required this.daysUntilStockout,
  });

  factory LowStockProduct.fromJson(Map<String, dynamic> json) {
    return LowStockProduct(
      productId: json['id'] ?? json['product_id'] ?? 0,
      productName: json['product_name'] ?? json['name'] ?? '',
      sku: json['sku'] ?? '',
      currentStock: json['current_stock'] ?? json['stock'] ?? 0,
      minStock: json['min_stock'] ?? 0,
      reorderLevel: json['reorder_level'] ?? 0,
      maxStock: json['max_stock'] ?? 0,
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      category: json['category'] ?? '',
      daysUntilStockout: json['days_until_stockout'] ?? 0,
    );
  }

  // Calculate urgency
  String get urgencyLevel {
    if (currentStock <= minStock) return 'CRITICAL';
    if (currentStock <= reorderLevel) return 'HIGH';
    return 'MEDIUM';
  }

  Color get urgencyColor {
    switch (urgencyLevel) {
      case 'CRITICAL': return const Color(0xFFDC2626);  // Red
      case 'HIGH': return const Color(0xFFF97316);      // Orange
      default: return const Color(0xFFFBBF24);          // Yellow
    }
  }

  // Calculate order quantity
  int get suggestedOrderQuantity {
    return (maxStock * 1.5).toInt() - currentStock;
  }

  // Estimate stockout date
  int get daysUntilEmpty {
    if (currentStock == 0) return 0;
    return daysUntilStockout;
  }
}

/// Stock Alert Details
class StockAlertDetails {
  final int productId;
  final String productName;
  final int currentStock;
  final int minStock;
  final int reorderLevel;
  final DateTime? lastRestockDate;
  final double dailyConsumption;
  final int estimatedRestockDays;

  StockAlertDetails({
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.minStock,
    required this.reorderLevel,
    this.lastRestockDate,
    required this.dailyConsumption,
    required this.estimatedRestockDays,
  });

  factory StockAlertDetails.fromJson(Map<String, dynamic> json) {
    return StockAlertDetails(
      productId: json['id'] ?? json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      currentStock: json['current_stock'] ?? 0,
      minStock: json['min_stock'] ?? 0,
      reorderLevel: json['reorder_level'] ?? 0,
      lastRestockDate: json['last_restock_date'] != null
          ? DateTime.parse(json['last_restock_date'])
          : null,
      dailyConsumption: (json['daily_consumption'] ?? 0).toDouble(),
      estimatedRestockDays: json['estimated_restock_days'] ?? 0,
    );
  }

  String get alertMessage {
    if (currentStock <= minStock) {
      return 'CRITICAL: Only $currentStock units left. Will stockout in $estimatedRestockDays days!';
    }
    if (currentStock <= reorderLevel) {
      return 'LOW: Only $currentStock units left. Reorder soon.';
    }
    return 'Monitor: Consider reordering to maintain optimal stock.';
  }
}

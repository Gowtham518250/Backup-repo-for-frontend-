import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'api_client.dart';
import 'notification_service.dart';

class StockAlertService {
  /// Track inventory and alert on low stock when sales are recorded
  /// Call this right after recording a sale
  static Future<void> checkAndAlertLowStock({
    required String productName,
    required int quantitySold,
    required int productId,
  }) async {
    try {
      if (kDebugMode) debugPrint('📦 Checking stock after sale: $productName (-$quantitySold units)');

      // Fetch current stock from backend
      final response = await ApiClient.getJson(
        '${ApiClient.inventoryPrefix}/products/$productId',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final currentStock = data['current_stock'] ?? 0;
        final minStock = data['min_stock'] ?? 10;

        if (kDebugMode) debugPrint('📊 Current stock: $currentStock, Min: $minStock');

        // Check if stock is below minimum
        if (currentStock < minStock) {
          await _triggerLowStockAlert(
            productName: productName,
            currentStock: currentStock,
            minStock: minStock,
            productId: productId,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error checking stock: $e');
    }
  }

  /// Trigger low stock alert and save to local history
  static Future<void> _triggerLowStockAlert({
    required String productName,
    required int currentStock,
    required int minStock,
    required int productId,
  }) async {
    // Show in-app notification
    try {
      NotificationService().showDownloadNotification(
        '⚠️ Low Stock Alert',
        '$productName: Only $currentStock units left (Min: $minStock)',
        'low_stock_$productId',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Notification failed: $e');
    }

    // Save to local history for dashboard
    await _saveAlertToHistory(
      productId: productId,
      productName: productName,
      currentStock: currentStock,
      minStock: minStock,
    );

    // Notify backend (for email to admin)
    await _notifyBackendOfAlert(
      productId: productId,
      productName: productName,
      currentStock: currentStock,
      minStock: minStock,
    );

    if (kDebugMode) debugPrint('🚨 Low stock alert: $productName ($currentStock/$minStock)');
  }

  /// Get all products with low stock
  static Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    try {
      final response = await ApiClient.getJson(
        '${ApiClient.inventoryPrefix}/low-stock',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> lowStockList = data['low_stock_products'] ?? [];
        
        return List<Map<String, dynamic>>.from(lowStockList);
      }
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error fetching low stock: $e');
      return [];
    }
  }

  /// Get stock level for specific product
  static Future<Map<String, dynamic>> getProductStockLevel(int productId) async {
    try {
      final response = await ApiClient.getJson(
        '${ApiClient.inventoryPrefix}/products/$productId',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'productName': data['product_name'] ?? 'Unknown',
          'currentStock': data['current_stock'] ?? 0,
          'minStock': data['min_stock'] ?? 10,
          'maxStock': data['max_stock'] ?? 100,
          'isLow': (data['current_stock'] ?? 0) < (data['min_stock'] ?? 10),
        };
      }
      return {'success': false};
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error fetching product stock: $e');
      return {'success': false};
    }
  }

  /// Get alert history (local storage)
  static Future<List<Map<String, dynamic>>> getAlertHistory({int limit = 50}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alertsJson = prefs.getStringList('stock_alerts') ?? [];

      return alertsJson
          .reversed
          .take(limit)
          .map((alert) => Map<String, dynamic>.from(json.decode(alert)))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error fetching alert history: $e');
      return [];
    }
  }

  /// Save alert to local history
  static Future<void> _saveAlertToHistory({
    required int productId,
    required String productName,
    required int currentStock,
    required int minStock,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final alert = {
        'productId': productId,
        'productName': productName,
        'currentStock': currentStock,
        'minStock': minStock,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final alertsJson = prefs.getStringList('stock_alerts') ?? [];
      alertsJson.add(json.encode(alert));

      // Keep last 100 alerts
      if (alertsJson.length > 100) {
        alertsJson.removeRange(0, alertsJson.length - 100);
      }

      await prefs.setStringList('stock_alerts', alertsJson);
      if (kDebugMode) debugPrint('📝 Alert saved to history');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error saving alert: $e');
    }
  }

  /// Notify backend to send email alert
  static Future<void> _notifyBackendOfAlert({
    required int productId,
    required String productName,
    required int currentStock,
    required int minStock,
  }) async {
    try {
      // Send to backend for email notification
      await ApiClient.postJson(
        '${ApiClient.inventoryPrefix}/alerts/trigger',
        {
          'product_id': productId,
          'product_name': productName,
          'current_stock': currentStock,
          'min_stock': minStock,
          'alert_type': 'LOW_STOCK',
        },
      );
      if (kDebugMode) debugPrint('✉️ Backend notified for email alert');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Backend notification failed: $e');
      // Don't fail the main process if backend notification fails
    }
  }

  /// Clear alert history
  static Future<void> clearAlertHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('stock_alerts');
      if (kDebugMode) debugPrint('🗑️ Alert history cleared');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error clearing history: $e');
    }
  }

  /// Get inventory dashboard summary
  static Future<Map<String, dynamic>> getInventorySummary() async {
    try {
      final response = await ApiClient.getJson(
        '${ApiClient.inventoryPrefix}/analytics/inventory-status',
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false};
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error fetching summary: $e');
      return {'success': false};
    }
  }
}


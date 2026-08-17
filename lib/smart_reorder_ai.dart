/// Feature 2: Smart Reorder AI Service
/// Calculate daily sales velocity, predict stockout days
/// Show alerts for items running out in <5 days

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class SmartReorderAIService {
  static const String _salesHistoryKey = 'daily_sales_history';
  
  /// Record daily sales for a product
  static Future<void> recordSale({
    required int productId,
    required String productName,
    required int quantity,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      Map<String, int> dailySales = {};
      final existing = prefs.getString('$_salesHistoryKey\_$dateKey');
      
      if (existing != null) {
        dailySales = Map<String, int>.from(jsonDecode(existing));
      }
      
      dailySales[productName] = (dailySales[productName] ?? 0) + quantity;
      
      await prefs.setString('$_salesHistoryKey\_$dateKey', jsonEncode(dailySales));
    } catch (e) {
      print('Error recording sale: $e');
    }
  }
  
  /// Calculate daily sales velocity (avg qty/day for last 7 days)
  static Future<double> calculateVelocity(String productName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      
      int totalQty = 0;
      int daysWithSales = 0;
      
      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final data = prefs.getString('$_salesHistoryKey\_$dateKey');
        
        if (data != null) {
          final daily = Map<String, int>.from(jsonDecode(data));
          if (daily.containsKey(productName)) {
            totalQty += daily[productName] ?? 0;
            daysWithSales++;
          }
        }
      }
      
      return totalQty / 7.0;
    } catch (e) {
      return 0;
    }
  }
  
  /// Predict days until stockout
  static Future<int?> predictStockoutDays({
    required String productName,
    required int currentStock,
  }) async {
    final velocity = await calculateVelocity(productName);
    
    if (velocity <= 0) return null;
    
    return (currentStock / velocity).ceil();
  }
  
  /// Get reorder alerts (<5 days to stockout)
  static Future<List<Map<String, dynamic>>> getReorderAlerts({
    required List<Map<String, dynamic>> inventory,
  }) async {
    List<Map<String, dynamic>> alerts = [];
    
    for (var product in inventory) {
      final productName = (product['name'] ?? product['product_name'] ?? '').toString();
      final currentStock = int.tryParse((product['stock'] ?? product['current_stock'] ?? 0).toString()) ?? 0;
      final stockoutDays = await predictStockoutDays(
        productName: productName,
        currentStock: currentStock,
      );
      
      if (stockoutDays != null && stockoutDays < 5 && stockoutDays > 0) {
        alerts.add({
          'product_name': productName,
          'current_stock': currentStock,
          'daily_velocity': await calculateVelocity(productName),
          'days_until_stockout': stockoutDays,
          'suggested_reorder_qty': (stockoutDays * (await calculateVelocity(productName)) * 1.2).toInt(),
          'supplier_whatsapp': product['supplier_whatsapp'],
        });
      }
    }
    
    return alerts;
  }
  
  /// Generate WhatsApp reorder message to supplier
  static String generateReorderMessage({
    required String productName,
    required int suggestedQty,
    required String shopName,
  }) {
    return '📦 Reorder Request\n\n'
        'Product: $productName\n'
        'Suggested Qty: $suggestedQty units\n'
        'From: $shopName\n\n'
        'Please confirm availability and pricing.\n'
        'Thanks! 🙏';
  }
}

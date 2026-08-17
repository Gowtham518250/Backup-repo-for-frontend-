import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'notification_service.dart';

/// Smart Notifications System for Local Shops
/// - Daily sales summary
/// - Stock alerts
/// - Payment reminders
/// - Staff commission updates
/// - Customer loyalty milestones
class SmartNotificationsService {
  static const String _tag = '🔔 SMART_NOTIF';
  static const String _dailySummaryKey = 'daily_summary_sent';
  static const String _stockAlertKey = 'stock_alerts_sent';
  static const String _lastNotificationTime = 'last_notif_time';
  
  static Timer? _dailyTimer;
  static bool _initialized = false;
  
  /// Initialize smart notifications
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    
    if (kDebugMode) debugPrint('$_tag Initializing Smart Notifications Service');
    
    _startDailySummaryTimer();
    _startStockAlertTimer();
    _startLoyaltyMilestoneTimer();
  }
  
  /// Send daily sales summary at 9 PM (21:00)
  static void _startDailySummaryTimer() {
    _dailyTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      final now = DateTime.now();
      
      // Check if it's 9 PM (21:00) and haven't sent today
      if (now.hour == 21 && now.minute == 0) {
        await _sendDailySummarySafe();
      }
    });
  }
  
  /// Send stock alerts every 2 hours
  static void _startStockAlertTimer() {
    Timer.periodic(const Duration(hours: 2), (_) async {
      await _checkAndSendStockAlertsSafe();
    });
  }
  
  /// Check loyalty milestones every 30 minutes
  static void _startLoyaltyMilestoneTimer() {
    Timer.periodic(const Duration(minutes: 30), (_) async {
      await _checkLoyaltyMilestonesSafe();
    });
  }
  
  /// Send daily summary notification
  static Future<void> _sendDailySummarySafe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final lastSent = prefs.getString(_dailySummaryKey) ?? '';
      
      if (lastSent == today.toString().split(' ')[0]) {
        if (kDebugMode) debugPrint('$_tag Daily summary already sent today');
        return;
      }
      
      // Get sales data from today
      final totalSales = await _getTodaySales();
      final orderCount = await _getTodayOrderCount();
      final avgOrderValue = orderCount > 0 ? totalSales / orderCount : 0;
      
      // Format currency
      final formatter = NumberFormat('₹#,##,##0.00', 'en_IN');
      final totalText = formatter.format(totalSales);
      final avgText = formatter.format(avgOrderValue);
      
      final title = '📊 Today\'s Summary';
      final body = 'Sales: $totalText | Orders: $orderCount | Avg: $avgText';
      
      await NotificationService.show(title, body);
      
      // Save timestamp
      await prefs.setString(_dailySummaryKey, today.toString().split(' ')[0]);
      
      if (kDebugMode) debugPrint('$_tag Daily summary sent: $body');
    } catch (e) {
      if (kDebugMode) debugPrint('$_tag Error sending daily summary: $e');
    }
  }
  
  /// Check and send stock alerts
  static Future<void> _checkAndSendStockAlertsSafe() async {
    try {
      final lowStockItems = await _getLowStockItems();
      
      if (lowStockItems.isEmpty) {
        if (kDebugMode) debugPrint('$_tag No low stock items');
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final lastAlertTime = prefs.getInt(_lastNotificationTime) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Don't spam alerts - max every 2 hours
      if (now - lastAlertTime < 2 * 60 * 60 * 1000) {
        if (kDebugMode) debugPrint('$_tag Stock alerts already sent recently');
        return;
      }
      
      final itemList = lowStockItems
          .map((item) => '${item['name']} (${item['stock']} left)')
          .join('\n');
      
      final title = '⚠️ Low Stock Alert';
      final body = 'Items to reorder:\n$itemList';
      
      await NotificationService.show(title, body);
      
      await prefs.setInt(_lastNotificationTime, now);
      
      if (kDebugMode) debugPrint('$_tag Stock alerts sent');
    } catch (e) {
      if (kDebugMode) debugPrint('$_tag Error checking stock: $e');
    }
  }
  
  /// Check loyalty milestones
  static Future<void> _checkLoyaltyMilestonesSafe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if any customer reached milestone (100, 500, 1000 points)
      final milestones = [100, 500, 1000, 5000];
      
      for (final milestone in milestones) {
        final reachedKey = 'loyalty_milestone_$milestone';
        if (!prefs.containsKey(reachedKey)) {
          // Check if customer has this many points
          final topCustomers = await _getTopLoyaltyCustomers();
          
          for (final customer in topCustomers) {
            if (customer['points'] >= milestone && !customer['milestone_notified_$milestone']) {
              final title = '🎉 Loyalty Milestone!';
              final body = '${customer['name']} reached $milestone points! Time to redeem.';
              
              await NotificationService.show(title, body);
              
              if (kDebugMode) debugPrint('$_tag Loyalty milestone sent for ${customer['name']}');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('$_tag Error checking milestones: $e');
    }
  }
  
  /// Payment reminder notification
  static Future<void> sendPaymentReminder({
    required String customerName,
    required double amount,
    required int daysOverdue,
  }) async {
    try {
      final title = '💰 Payment Due: $customerName';
      final body = '₹${amount.toStringAsFixed(2)} overdue for $daysOverdue days';
      
      await NotificationService.show(title, body);
      
      if (kDebugMode) debugPrint('$_tag Payment reminder sent');
    } catch (e) {
      if (kDebugMode) debugPrint('$_tag Error sending payment reminder: $e');
    }
  }
  
  /// Staff commission notification
  static Future<void> sendCommissionNotification({
    required String staffName,
    required double amount,
    required int ordersCount,
  }) async {
    try {
      final title = '💳 Commission Earned!';
      final body = '$staffName earned ₹${amount.toStringAsFixed(2)} ($ordersCount orders)';
      
      await NotificationService.show(title, body);
      
      if (kDebugMode) debugPrint('$_tag Commission notification sent');
    } catch (e) {
      if (kDebugMode) debugPrint('$_tag Error sending commission notification: $e');
    }
  }
  
  // Helper methods
  static Future<double> _getTodaySales() async {
    try {
      // This would integrate with your sales tracking
      final prefs = await SharedPreferences.getInstance();
      final todayKey = 'daily_sales_${DateTime.now().toString().split(' ')[0]}';
      return prefs.getDouble(todayKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }
  
  static Future<int> _getTodayOrderCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = 'daily_orders_${DateTime.now().toString().split(' ')[0]}';
      return prefs.getInt(todayKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }
  
  static Future<List<Map<String, dynamic>>> _getLowStockItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final inventoryJson = prefs.getString('inventory_cache') ?? '[]';
      final items = List<Map<String, dynamic>>.from(
        (jsonDecode(inventoryJson) as List).map((x) => Map<String, dynamic>.from(x as Map))
      );
      
      return items
          .where((item) => (item['stock'] ?? 0) < (item['reorder_level'] ?? 10))
          .toList();
    } catch (_) {
      return [];
    }
  }
  
  static Future<List<Map<String, dynamic>>> _getTopLoyaltyCustomers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loyaltyJson = prefs.getString('loyalty_customers') ?? '[]';
      final customers = List<Map<String, dynamic>>.from(
        (jsonDecode(loyaltyJson) as List).map((x) => Map<String, dynamic>.from(x as Map))
      );
      
      return customers..sort((a, b) => (b['points'] as num).compareTo(a['points'] as num));
    } catch (_) {
      return [];
    }
  }
  
  /// Dispose resources
  static Future<void> dispose() async {
    _dailyTimer?.cancel();
    _initialized = false;
  }
}

// Helper for formatting
class NumberFormat {
  final String pattern;
  final String locale;
  
  NumberFormat(this.pattern, this.locale);
  
  String format(num value) {
    return '₹${value.toStringAsFixed(2)}';
  }
}

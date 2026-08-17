import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// Staff Commission Tracking & Payout System
class CommissionTrackingService {
  static const String _tag = '💳 COMMISSION';
  static const String _commissionsKey = 'staff_commissions_v1';
  static const String _payoutsKey = 'staff_payouts_v1';
  
  // Commission rates (%)
  static const double defaultCommissionRate = 5.0;      // 5% of sales
  static const double premiumCommissionRate = 7.5;      // 7.5% for high performers
  static const double bonusThreshold = 10000.0;         // Bonus if daily sales > ₹10k
  static const double bonusAmount = 500.0;              // ₹500 bonus
  
  /// Record sale and calculate commission
  static Future<Map<String, dynamic>> recordSaleWithCommission({
    required String staffId,
    required String staffName,
    required String saleId,
    required double saleAmount,
    required bool isPremiumStaff,
  }) async {
    try {
      final commissionRate = isPremiumStaff ? premiumCommissionRate : defaultCommissionRate;
      final baseCommission = (saleAmount * commissionRate) / 100.0;
      
      // Check for bonus
      final dailySales = await _getTodaysSalesForStaff(staffId);
      final dailyBonus = (dailySales + saleAmount) > bonusThreshold ? bonusAmount : 0.0;
      
      final totalCommission = baseCommission + dailyBonus;
      
      // Save commission entry
      final commission = {
        'id': 'COMM_${DateTime.now().millisecondsSinceEpoch}',
        'staffId': staffId,
        'staffName': staffName,
        'saleId': saleId,
        'saleAmount': saleAmount,
        'commissionRate': commissionRate,
        'baseCommission': baseCommission,
        'bonus': dailyBonus,
        'totalCommission': totalCommission,
        'timestamp': DateTime.now().toIso8601String(),
        'payoutStatus': 'PENDING',
      };
      
      await _saveCommission(commission);
      
      if (kDebugMode) {
        debugPrint('$_tag Commission recorded: $staffName earned ₹${totalCommission.toStringAsFixed(2)}');
      }
      
      return {
        'success': true,
        'commissionId': commission['id'],
        'amount': totalCommission,
        'breakdown': {
          'base': baseCommission,
          'bonus': dailyBonus,
        },
      };
    } catch (e) {
      if (kDebugMode) debugPrint('$_tag Error recording commission: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// Get pending payouts for staff member
  static Future<List<Map<String, dynamic>>> getPendingCommissions(String staffId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_commissionsKey) ?? '[]';
      final commissions = List<Map<String, dynamic>>.from(
        (jsonDecode(json) as List).map((x) => Map<String, dynamic>.from(x as Map))
      );
      
      return commissions
          .where((c) => c['staffId'] == staffId && c['payoutStatus'] == 'PENDING')
          .toList();
    } catch (_) {
      return [];
    }
  }
  
  /// Get staff dashboard metrics
  static Future<Map<String, dynamic>> getStaffMetrics(String staffId) async {
    try {
      final pending = await getPendingCommissions(staffId);
      final totalEarned = pending.fold<double>(0, (sum, c) => sum + (c['totalCommission'] as num).toDouble());
      
      final today = DateTime.now().toString().split(' ')[0];
      final todayCommissions = pending.where((c) {
        final cDate = (c['timestamp'] as String).split('T')[0];
        return cDate == today;
      }).toList();
      
      final todayEarned = todayCommissions.fold<double>(0, (sum, c) => sum + (c['totalCommission'] as num).toDouble());
      
      return {
        'pendingCount': pending.length,
        'pendingAmount': totalEarned,
        'todayCount': todayCommissions.length,
        'todayEarned': todayEarned,
        'lastCommission': pending.isNotEmpty ? pending.last['timestamp'] : null,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('$_tag Error getting metrics: $e');
      return {};
    }
  }
  
  /// Mark commission as paid out
  static Future<bool> markAsPaidOut(List<String> commissionIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_commissionsKey) ?? '[]';
      var commissions = List<Map<String, dynamic>>.from(
        (jsonDecode(json) as List).map((x) => Map<String, dynamic>.from(x as Map))
      );
      
      for (var commission in commissions) {
        if (commissionIds.contains(commission['id'])) {
          commission['payoutStatus'] = 'PAID';
          commission['paidAt'] = DateTime.now().toIso8601String();
        }
      }
      
      await prefs.setString(_commissionsKey, jsonEncode(commissions));
      
      if (kDebugMode) debugPrint('$_tag ${commissionIds.length} commissions marked as paid');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('$_tag Error marking paid: $e');
      return false;
    }
  }
  
  /// Request payout for staff
  static Future<Map<String, dynamic>> requestPayout({
    required String staffId,
    required String staffName,
    required String bankAccount,
    required double amount,
  }) async {
    try {
      final payout = {
        'id': 'PAYOUT_${DateTime.now().millisecondsSinceEpoch}',
        'staffId': staffId,
        'staffName': staffName,
        'bankAccount': bankAccount,
        'amount': amount,
        'status': 'PENDING',
        'requestedAt': DateTime.now().toIso8601String(),
      };
      
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_payoutsKey) ?? '[]';
      var payouts = List<Map<String, dynamic>>.from(
        (jsonDecode(json) as List).map((x) => Map<String, dynamic>.from(x as Map))
      );
      
      payouts.add(payout);
      await prefs.setString(_payoutsKey, jsonEncode(payouts));
      
      if (kDebugMode) debugPrint('$_tag Payout requested: ${payout['id']}');
      
      return {'success': true, 'payoutId': payout['id']};
    } catch (e) {
      if (kDebugMode) debugPrint('$_tag Error requesting payout: $e');
      return {'success': false};
    }
  }
  
  // Helpers
  static Future<double> _getTodaysSalesForStaff(String staffId) async {
    // This would integrate with sales tracking
    // For now, return 0
    return 0.0;
  }
  
  static Future<void> _saveCommission(Map<String, dynamic> commission) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_commissionsKey) ?? '[]';
      var commissions = List<Map<String, dynamic>>.from(
        (jsonDecode(json) as List).map((x) => Map<String, dynamic>.from(x as Map))
      );
      
      commissions.add(commission);
      await prefs.setString(_commissionsKey, jsonEncode(commissions));
    } catch (e) {
      if (kDebugMode) debugPrint('$_tag Error saving: $e');
    }
  }
}

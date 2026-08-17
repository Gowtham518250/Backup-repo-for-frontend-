import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// Advanced Loyalty Program System
/// - Points per purchase
/// - Redemption options
/// - Tier-based benefits
/// - Referral rewards
class LoyaltyProgramService {
  static const String _tag = '🎁 LOYALTY';
  static const String _customersKey = 'loyalty_customers_v2';
  static const String _transactionsKey = 'loyalty_transactions';
  
  // Points configuration
  static const double pointsPerRupee = 1.0; // 1 point per ₹1
  static const double premiumPointsMultiplier = 1.5; // 1.5x for premium members
  static const int pointsPerReferral = 100;
  static const int pointsRedeemThreshold = 100;
  static const double redeemValuePerPoint = 0.50; // ₹0.50 per point
  
  // Tier thresholds
  static const int silverThreshold = 1000;
  static const int goldThreshold = 5000;
  static const int platinumThreshold = 10000;
  
  /// Add points to customer
  static Future<void> addPoints({
    required String customerId,
    required String customerName,
    required double amount,
    required String transactionId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get or create customer
      var customer = await _getCustomer(customerId) ?? {
        'id': customerId,
        'name': customerName,
        'points': 0,
        'tier': 'silver',
        'totalSpent': 0,
        'transactions': [],
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      // Calculate points
      final tier = customer['tier'] ?? 'silver';
      final multiplier = tier == 'platinum' ? premiumPointsMultiplier : 1.0;
      final pointsEarned = (amount * pointsPerRupee * multiplier).toInt();
      
      // Update customer
      customer['points'] = (customer['points'] ?? 0) + pointsEarned;
      customer['totalSpent'] = (customer['totalSpent'] ?? 0) + amount;
      customer['tier'] = _calculateTier(customer['points']);
      
      // Add transaction
      final transaction = {
        'id': transactionId,
        'type': 'purchase',
        'points': pointsEarned,
        'amount': amount,
        'timestamp': DateTime.now().toIso8601String(),
        'tier': tier,
      };
      
      customer['transactions'] = [
        ...(customer['transactions'] ?? []),
        transaction,
      ];
      
      // Save customer
      await _saveCustomer(customer);
      
      if (kDebugMode) {
        debugPrint('$_tag $customerName earned $pointsEarned points (Total: ${customer['points']})');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('$_tag Error adding points: $e');
    }
  }
  
  /// Redeem points for discount
  static Future<Map<String, dynamic>?> redeemPoints({
    required String customerId,
    required int pointsToRedeem,
  }) async {
    try {
      final customer = await _getCustomer(customerId);
      if (customer == null) {
        if (kDebugMode) debugPrint('$_tag Customer not found');
        return null;
      }
      
      final currentPoints = customer['points'] ?? 0;
      if (currentPoints < pointsToRedeem) {
        if (kDebugMode) debugPrint('$_tag Insufficient points: $currentPoints < $pointsToRedeem');
        return null;
      }
      
      final redemptionValue = pointsToRedeem * redeemValuePerPoint;
      
      // Deduct points
      customer['points'] = currentPoints - pointsToRedeem;
      
      // Add redemption transaction
      final transaction = {
        'id': 'redeem_${DateTime.now().millisecondsSinceEpoch}',
        'type': 'redemption',
        'points': -pointsToRedeem,
        'value': redemptionValue,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      customer['transactions'] = [
        ...(customer['transactions'] ?? []),
        transaction,
      ];
      
      await _saveCustomer(customer);
      
      if (kDebugMode) {
        debugPrint('$_tag Redeemed $pointsToRedeem points for ₹${redemptionValue.toStringAsFixed(2)}');
      }
      
      return {
        'success': true,
        'pointsRedeemed': pointsToRedeem,
        'discountAmount': redemptionValue,
        'remainingPoints': customer['points'],
      };
    } catch (e) {
      if (kDebugMode) debugPrint('$_tag Error redeeming points: $e');
      return null;
    }
  }
  
  /// Get customer loyalty details
  static Future<Map<String, dynamic>?> getCustomerDetails(String customerId) async {
    try {
      final customer = await _getCustomer(customerId);
      if (customer == null) return null;
      
      return {
        'id': customer['id'],
        'name': customer['name'],
        'points': customer['points'],
        'tier': customer['tier'],
        'totalSpent': customer['totalSpent'],
        'redeemValue': (customer['points'] ?? 0) * redeemValuePerPoint,
        'tierBenefits': _getTierBenefits(customer['tier']),
        'nextTier': _getNextTier(customer['tier']),
        'pointsToNextTier': _getPointsToNextTier(customer['points'] ?? 0),
        'lastTransaction': customer['transactions']?.isNotEmpty == true 
            ? customer['transactions'][customer['transactions'].length - 1]['timestamp']
            : null,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('$_tag Error getting customer details: $e');
      return null;
    }
  }
  
  /// Get all loyalty customers
  static Future<List<Map<String, dynamic>>> getAllCustomers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_customersKey) ?? '[]';
      final customers = List<Map<String, dynamic>>.from(
        (jsonDecode(json) as List).map((x) => Map<String, dynamic>.from(x as Map))
      );
      
      customers.sort((a, b) => (b['points'] as num).compareTo(a['points'] as num));
      return customers;
    } catch (e) {
      if (kDebugMode) debugPrint('$_tag Error getting customers: $e');
      return [];
    }
  }
  
  /// Get loyalty leaderboard
  static Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 10}) async {
    try {
      final customers = await getAllCustomers();
      return customers.take(limit).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('$_tag Error getting leaderboard: $e');
      return [];
    }
  }
  
  /// Add referral points
  static Future<void> addReferralBonus({
    required String referrerId,
    required String newCustomerId,
  }) async {
    try {
      final referrer = await _getCustomer(referrerId);
      if (referrer == null) return;
      
      referrer['points'] = (referrer['points'] ?? 0) + pointsPerReferral;
      
      final transaction = {
        'id': 'referral_$newCustomerId',
        'type': 'referral',
        'points': pointsPerReferral,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      referrer['transactions'] = [...(referrer['transactions'] ?? []), transaction];
      await _saveCustomer(referrer);
      
      if (kDebugMode) debugPrint('$_tag Referral bonus added to ${referrer['name']}');
    } catch (e) {
      if (kDebugMode) debugPrint('$_tag Error adding referral: $e');
    }
  }
  
  /// Birthday bonus points
  static Future<void> checkAndAwardBirthdayBonus() async {
    try {
      final today = DateTime.now();
      final customers = await getAllCustomers();
      
      for (final customer in customers) {
        final createdAt = DateTime.parse(customer['createdAt'] as String);
        
        // Simple check: same day and month (not year)
        if (createdAt.month == today.month && createdAt.day == today.day) {
          final birthdayBonus = 50;
          customer['points'] = (customer['points'] ?? 0) + birthdayBonus;
          
          final transaction = {
            'id': 'birthday_${today.toString()}',
            'type': 'birthday_bonus',
            'points': birthdayBonus,
            'timestamp': DateTime.now().toIso8601String(),
          };
          
          customer['transactions'] = [...(customer['transactions'] ?? []), transaction];
          await _saveCustomer(customer);
          
          if (kDebugMode) debugPrint('$_tag Birthday bonus awarded to ${customer['name']}');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('$_tag Error checking birthday: $e');
    }
  }
  
  // Helper methods
  static String _calculateTier(int points) {
    if (points >= platinumThreshold) return 'platinum';
    if (points >= goldThreshold) return 'gold';
    if (points >= silverThreshold) return 'silver';
    return 'bronze';
  }
  
  static String _getNextTier(String currentTier) {
    final tiers = ['bronze', 'silver', 'gold', 'platinum'];
    final currentIndex = tiers.indexOf(currentTier);
    if (currentIndex >= tiers.length - 1) return 'platinum';
    return tiers[currentIndex + 1];
  }
  
  static int _getPointsToNextTier(int currentPoints) {
    if (currentPoints >= platinumThreshold) return 0;
    if (currentPoints >= goldThreshold) return (platinumThreshold - currentPoints).toInt();
    if (currentPoints >= silverThreshold) return (goldThreshold - currentPoints).toInt();
    return (silverThreshold - currentPoints).toInt();
  }
  
  static Map<String, dynamic> _getTierBenefits(String tier) {
    const benefits = {
      'bronze': {
        'pointsMultiplier': 1.0,
        'discount': 0,
        'freeDelivery': false,
        'birthdayBonus': 25,
      },
      'silver': {
        'pointsMultiplier': 1.2,
        'discount': 5,
        'freeDelivery': true,
        'birthdayBonus': 50,
      },
      'gold': {
        'pointsMultiplier': 1.5,
        'discount': 10,
        'freeDelivery': true,
        'birthdayBonus': 100,
        'dedicatedManager': true,
      },
      'platinum': {
        'pointsMultiplier': 2.0,
        'discount': 15,
        'freeDelivery': true,
        'birthdayBonus': 200,
        'dedicatedManager': true,
        'priority': true,
      },
    };
    
    return benefits[tier] ?? benefits['bronze']!;
  }
  
  static Future<Map<String, dynamic>?> _getCustomer(String customerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_customersKey) ?? '[]';
      final customers = List<Map<String, dynamic>>.from(
        (jsonDecode(json) as List).map((x) => Map<String, dynamic>.from(x as Map))
      );
      
      return customers.firstWhere(
        (c) => c['id'] == customerId,
        orElse: () => {},
      ).isEmpty ? null : customers.firstWhere((c) => c['id'] == customerId);
    } catch (_) {
      return null;
    }
  }
  
  static Future<void> _saveCustomer(Map<String, dynamic> customer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_customersKey) ?? '[]';
      var customers = List<Map<String, dynamic>>.from(
        (jsonDecode(json) as List).map((x) => Map<String, dynamic>.from(x as Map))
      );
      
      final index = customers.indexWhere((c) => c['id'] == customer['id']);
      if (index >= 0) {
        customers[index] = customer;
      } else {
        customers.add(customer);
      }
      
      await prefs.setString(_customersKey, jsonEncode(customers));
    } catch (e) {
      if (kDebugMode) debugPrint('$_tag Error saving customer: $e');
    }
  }
}

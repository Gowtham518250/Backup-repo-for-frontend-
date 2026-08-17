/// Feature 7: Customer Loyalty Points Service
/// ₹100 = 1 point. Tiers: Bronze/Silver/Gold

import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_client.dart';

class CustomerLoyaltyService {
  
  /// Get customer loyalty status
  static Future<Map<String, dynamic>?> getLoyaltyStatus(int customerId) async {
    try {
      final response = await ApiClient.getJson('/api/loyalty/status/$customerId');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }
  
  /// Earn points from sale (₹100 = 1 point)
  static Future<void> earnPoints(int customerId, double saleAmount) async {
    try {
      await ApiClient.postJson('/api/loyalty/earn', {
        'customer_id': customerId,
        'amount': saleAmount,
      });
    } catch (e) {
      print('Error earning points: $e');
    }
  }
  
  /// Redeem points for discount
  static Future<Map<String, dynamic>?> redeemPoints({
    required int customerId,
    required int points,
  }) async {
    try {
      final response = await ApiClient.postJson('/api/loyalty/redeem', {
        'customer_id': customerId,
        'points': points,
      });
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }
  
  /// Get tier info with discount percentage
  static Future<Map<String, dynamic>?> getTierInfo(int customerId) async {
    try {
      final response = await ApiClient.getJson('/api/loyalty/tier/$customerId');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}


/// Feature 13: Customer Credit Scoring
/// Score 0-100 based on payment history
/// Badges: Trusted/Regular/Caution

class CustomerCreditScoreService {
  
  /// Get credit score and suggested limit
  static Future<Map<String, dynamic>?> getCreditScore(int customerId) async {
    try {
      final response = await ApiClient.getJson('/api/credit-score/$customerId');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Get credit score color based on badge
  static Color getBadgeColor(String badge) {
    switch (badge.toUpperCase()) {
      case 'TRUSTED':
        return Colors.green;
      case 'REGULAR':
        return Colors.orange;
      case 'CAUTION':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  /// Get credit score icon
  static IconData getBadgeIcon(String badge) {
    switch (badge.toUpperCase()) {
      case 'TRUSTED':
        return Icons.verified;
      case 'REGULAR':
        return Icons.schedule;
      case 'CAUTION':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }
}


/// Feature 14: Customer Occasion Service
/// Track birthdays, send auto-discount WhatsApp messages

class CustomerOccasionService {
  
  /// Get today's occasions (birthdays, anniversaries)
  static Future<List<Map<String, dynamic>>> getTodayOccasions() async {
    try {
      final response = await ApiClient.getJson('/api/occasions/today');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['occasions'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  
  /// Send occasion WhatsApp message
  static Future<bool> sendOccasionMessage(int occasionId) async {
    try {
      final response = await ApiClient.postJson(
        '/api/occasions/send/$occasionId',
        {}
      );
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// Get upcoming occasions (next 30 days)
  static Future<List<Map<String, dynamic>>> getUpcomingOccasions() async {
    try {
      final response = await ApiClient.getJson('/api/occasions/upcoming');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['occasions'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}


/// Feature 8 + 16 combined: UPI Collections Dashboard + Daily Report
class CollectionsAndReportService {
  
  /// Get today's UPI vs cash summary
  static Future<Map<String, dynamic>?> getTodayCollectionsSummary() async {
    try {
      final response = await ApiClient.getJson('/api/collections/today-summary');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Get today's daily report
  static Future<Map<String, dynamic>?> getDailyReport() async {
    try {
      final response = await ApiClient.getJson('/api/reports/daily');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Send daily report via WhatsApp (scheduled for evening)
  static Future<bool> sendDailyReportWhatsApp() async {
    try {
      final response = await ApiClient.postJson(
        '/api/reports/send-whatsapp',
        {}
      );
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// Get unmatched UPI payments
  static Future<List<Map<String, dynamic>>> getUnmatchedPayments() async {
    try {
      final response = await ApiClient.getJson('/api/collections/unmatched');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['payments'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

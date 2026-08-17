import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'local_storage_service.dart';

/// 📊 LTV Analytics Service
/// Tracks cohort retention, calculates LTV:CAC ratio, identifies churn risk
/// Data persists locally for offline-first operation

class LTVAnalyticsService {
  /// Get or create shop cohort (signup date tracking)
  static Future<Map<String, dynamic>> getOrCreateCohort() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? prefs.getInt('userId');
    
    if (userId == null) return {};

    final cohortKey = 'cohort_${userId}_metadata';
    final existing = prefs.getString(cohortKey);
    
    if (existing != null) {
      return json.decode(existing);
    }

    // Create new cohort for this shop (first login)
    final now = DateTime.now();
    final cohortData = {
      'shop_id': userId,
      'signup_date': now.toIso8601String(),
      'cohort_month': '${now.year}-${now.month.toString().padLeft(2, '0')}',
      'first_sale_date': null,
      'active_status': 'ACTIVE', // ACTIVE, CHURNED, TRIAL
    };

    await prefs.setString(cohortKey, json.encode(cohortData));
    return cohortData;
  }

  /// 💰 Calculate LTV (Lifetime Value) for a shop
  /// LTV = Total Revenue - Chargeback/Refunds
  static Future<double> calculateShopLTV(int userId) async {
    try {
      final sales = await LocalStorageService.loadSales();
      
      double totalRevenue = 0;
      for (var sale in sales) {
        // Only count completed/paid sales
        final status = sale['payment_status']?.toString() ?? 'PAID';
        if (status == 'PAID' || status == 'PARTIAL') {
          final amount = double.tryParse(sale['total']?.toString() ?? '0') ?? 0;
          totalRevenue += amount;
        }
      }

      return totalRevenue;
    } catch (e) {
      return 0.0;
    }
  }

  /// 📈 Calculate Retention (Days 1, 7, 30, 60)
  /// Retention = "Active on day X after signup"
  /// Activity = at least 1 sale or inventory check
  static Future<Map<String, bool>> calculateRetention(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cohortKey = 'cohort_${userId}_metadata';
      final cohortJson = prefs.getString(cohortKey);
      
      if (cohortJson == null) {
        return {
          'day_1': false,
          'day_7': false,
          'day_30': false,
          'day_60': false,
        };
      }

      final cohort = json.decode(cohortJson);
      final signupDate = DateTime.parse(cohort['signup_date']);
      
      final sales = await LocalStorageService.loadSales();
      
      // Get dates when sales occurred
      final activeDates = <DateTime>{};
      for (var sale in sales) {
        final saleDate = sale['sale_date'] ?? sale['created_at'];
        if (saleDate != null) {
          try {
            activeDates.add(DateTime.parse(saleDate.toString()).toUtc());
          } catch (_) {}
        }
      }

      // Check retention at each milestone
      final now = DateTime.now().toUtc();
      return {
        'day_1': _isActiveOnDay(activeDates, signupDate, 1),
        'day_7': _isActiveOnDay(activeDates, signupDate, 7),
        'day_30': _isActiveOnDay(activeDates, signupDate, 30),
        'day_60': _isActiveOnDay(activeDates, signupDate, 60),
      };
    } catch (e) {
      return {
        'day_1': false,
        'day_7': false,
        'day_30': false,
        'day_60': false,
      };
    }
  }

  /// Check if user was active on a specific day
  static bool _isActiveOnDay(Set<DateTime> activeDates, DateTime signupDate, int dayOffset) {
    final targetDate = signupDate.add(Duration(days: dayOffset));
    final dayStart = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return activeDates.any((date) => date.isAfter(dayStart) && date.isBefore(dayEnd));
  }

  /// 📊 Detect Churn Risk (no activity for 7+ days)
  static Future<bool> isChurnRisk() async {
    try {
      final sales = await LocalStorageService.loadSales();
      
      if (sales.isEmpty) return true; // No sales = high churn risk

      // Get last sale date
      DateTime lastSaleDate = DateTime(2000);
      for (var sale in sales) {
        final saleDate = sale['sale_date'] ?? sale['created_at'];
        if (saleDate != null) {
          try {
            final date = DateTime.parse(saleDate.toString());
            if (date.isAfter(lastSaleDate)) {
              lastSaleDate = date;
            }
          } catch (_) {}
        }
      }

      // If last sale > 7 days ago, mark as churn risk
      final daysSinceLastSale = DateTime.now().difference(lastSaleDate).inDays;
      return daysSinceLastSale > 7;
    } catch (e) {
      return false;
    }
  }

  /// 💳 Estimate CAC (Customer Acquisition Cost)
  /// Estimations: Free trial = ₹0, Paid campaign = ₹500-2000
  static double estimateCAC({
    required bool wasFreeTrial,
    required bool wasReferral,
    required bool paidCampaign,
  }) {
    if (wasFreeTrial) return 0;
    if (wasReferral) return 200; // Referral bonus typical cost
    if (paidCampaign) return 1000; // Average paid acquisition
    return 300; // Default channel mix
  }

  /// 🎯 Calculate LTV:CAC Ratio (Series A metric)
  /// Healthy ratio: >3x means business is profitable at scale
  static Future<double> calculateLTVToCACRatio(
    int userId, {
    double estimatedCAC = 500,
  }) async {
    final ltv = await calculateShopLTV(userId);
    if (estimatedCAC <= 0) return 0;
    return ltv / estimatedCAC;
  }

  /// 📋 Generate Series A Report Card
  static Future<Map<String, dynamic>> generateSeriesAMetrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0;
      
      if (userId <= 0) return {};

      final ltv = await calculateShopLTV(userId);
      final retention = await calculateRetention(userId);
      final isChurned = await isChurnRisk();
      final ltvCacRatio = await calculateLTVToCACRatio(userId);

      return {
        'shop_id': userId,
        'ltv': ltv,
        'ltv_formatted': '₹${ltv.toStringAsFixed(0)}',
        'retention_day_1': retention['day_1'] ?? false,
        'retention_day_7': retention['day_7'] ?? false,
        'retention_day_30': retention['day_30'] ?? false,
        'retention_day_60': retention['day_60'] ?? false,
        'is_churn_risk': isChurned,
        'ltv_cac_ratio': ltvCacRatio,
        'ltv_cac_ratio_formatted': ltvCacRatio.toStringAsFixed(1),
        'rating': _rateShop(ltv, ltvCacRatio, retention),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {};
    }
  }

  /// ⭐ Rate shop health (0-100 for investor pitch)
  static String _rateShop(
    double ltv,
    double ltvCacRatio,
    Map<String, bool> retention,
  ) {
    int score = 0;

    // LTV score (0-25)
    if (ltv > 50000) score += 25;
    else if (ltv > 20000) score += 20;
    else if (ltv > 5000) score += 15;
    else if (ltv > 0) score += 10;

    // LTV:CAC score (0-25)
    if (ltvCacRatio > 5) score += 25;
    else if (ltvCacRatio > 3) score += 20;
    else if (ltvCacRatio > 1) score += 15;

    // Retention score (0-25)
    final retentionDays = [
      retention['day_1'],
      retention['day_7'],
      retention['day_30'],
      retention['day_60'],
    ].where((r) => r == true).length;

    score += (retentionDays * 6);

    // Activity score (0-25)
    if (retention['day_60'] == true) score += 25;
    else if (retention['day_30'] == true) score += 20;
    else if (retention['day_7'] == true) score += 15;

    if (score > 100) score = 100;

    if (score >= 80) return 'A - Excellent';
    if (score >= 60) return 'B - Good';
    if (score >= 40) return 'C - Fair';
    if (score >= 20) return 'D - Poor';
    return 'F - Churned';
  }

  /// 📥 Export all cohorts for Series A pitch
  static Future<List<Map<String, dynamic>>> exportAllCohorts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      final cohorts = <Map<String, dynamic>>[];
      
      // Find all cohort metadata entries
      for (final key in allKeys) {
        if (key.startsWith('cohort_') && key.endsWith('_metadata')) {
          final cohortJson = prefs.getString(key);
          if (cohortJson != null) {
            cohorts.add(json.decode(cohortJson));
          }
        }
      }

      return cohorts;
    } catch (e) {
      return [];
    }
  }

  /// 🔄 Update cohort status (Inactive/Churned tracking)
  static Future<void> updateCohortStatus(int userId, String newStatus) async {
    final prefs = await SharedPreferences.getInstance();
    final cohortKey = 'cohort_${userId}_metadata';
    final existing = prefs.getString(cohortKey);

    if (existing != null) {
      final cohort = json.decode(existing);
      cohort['active_status'] = newStatus;
      cohort['status_updated_at'] = DateTime.now().toIso8601String();
      await prefs.setString(cohortKey, json.encode(cohort));
    }
  }
}

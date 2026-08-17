import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Tier-based benefits service with lock-in mechanism
/// Manages tier benefits, progression, and lock-in lifecycle
/// Creates retention moat through: tier progression, exclusive benefits, and switching costs
class TierBenefitsService {
  static const String _tierProgressKey = 'tier_progress_data';
  static const String _benefitEnrollmentKey = 'benefit_enrollment';
  static const String _tierHistoryKey = 'tier_history';

  // ==========================================
  // 1. TIER PROGRESSION & UPGRADES
  // ==========================================

  /// Get current tier and progress to next tier
  /// Returns: {current_tier, points_progress, next_tier, points_to_next}
  static Future<Map<String, dynamic>> getTierProgress(int customerId) async {
    final prefs = await SharedPreferences.getInstance();
    final progressKey = '${_tierProgressKey}_$customerId';
    final data = prefs.getString(progressKey);

    if (data == null) {
      // First tier assessment
      return {
        'current_tier': 'BRONZE',
        'tier_level': 1,
        'total_points': 0,
        'points_progress': 0,
        'next_tier': 'SILVER',
        'points_to_next': 500,
        'tier_history': [],
      };
    }

    final progress = json.decode(data) as Map<String, dynamic>;
    return progress;
  }

  /// Simulate tier upgrade check and update lock-in
  static Future<Map<String, dynamic>> checkTierUpgrade(
    int customerId,
    int newPoints,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final progressKey = '${_tierProgressKey}_$customerId';
    
    final current = await getTierProgress(customerId);
    final oldTier = current['current_tier'] as String;
    final totalPoints = (current['total_points'] as int) + newPoints;

    // Determine new tier
    String newTier;
    int tierLevel;
    
    if (totalPoints >= 1000) {
      newTier = 'GOLD';
      tierLevel = 3;
    } else if (totalPoints >= 500) {
      newTier = 'SILVER';
      tierLevel = 2;
    } else {
      newTier = 'BRONZE';
      tierLevel = 1;
    }

    // Check if upgraded
    final upgraded = newTier != oldTier;

    // Update progress
    final nextTierPoints = newTier == 'GOLD'
        ? 9999 // Max out at Gold
        : (newTier == 'SILVER'
            ? 1000
            : 500);

    final updatedProgress = {
      'customer_id': customerId,
      'current_tier': newTier,
      'tier_level': tierLevel,
      'total_points': totalPoints,
      'points_progress': totalPoints,
      'next_tier': newTier == 'GOLD' ? null : (newTier == 'SILVER' ? 'GOLD' : 'SILVER'),
      'points_to_next': newTier == 'GOLD' ? 0 : (nextTierPoints - totalPoints),
      'tier_updated_at': DateTime.now().toIso8601String(),
      'tier_history': current['tier_history'] ?? [],
    };

    // Add to history if upgraded
    if (upgraded) {
      final history = updatedProgress['tier_history'] as List? ?? [];
      history.add({
        'from_tier': oldTier,
        'to_tier': newTier,
        'upgraded_at': DateTime.now().toIso8601String(),
        'total_points': totalPoints,
      });
      updatedProgress['tier_history'] = history;
    }

    await prefs.setString(progressKey, json.encode(updatedProgress));

    return {
      'status': upgraded ? 'UPGRADED' : 'NO_CHANGE',
      'old_tier': oldTier,
      'new_tier': newTier,
      'total_points': totalPoints,
      'new_benefits_unlocked': upgraded ? _getBenefitsForTier(newTier) : [],
      'lock_enabled': upgraded,
      'lock_duration_days': _getLockDurationDays(newTier),
      'tier_progress': updatedProgress,
    };
  }

  /// Get tier history for customer (progression timeline)
  static Future<List<Map<String, dynamic>>> getTierHistory(int customerId) async {
    final prefs = await SharedPreferences.getInstance();
    final progress = await getTierProgress(customerId);
    final history = progress['tier_history'] ?? [];
    return List<Map<String, dynamic>>.from(history.cast<Map<String, dynamic>>());
  }

  // ==========================================
  // 2. BENEFIT ENROLLMENT & TRACKING
  // ==========================================

  /// Enroll in tier benefits (automatic on upgrade)
  static Future<Map<String, dynamic>> enrollInBenefits(
    int customerId,
    String tier,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final enrollmentKey = '${_benefitEnrollmentKey}_$customerId';

    final benefits = _getBenefitsForTier(tier);
    final enrollmentData = {
      'customer_id': customerId,
      'tier': tier,
      'enrolled_at': DateTime.now().toIso8601String(),
      'benefits': benefits,
      'active_benefits': benefits.map((b) => b['id']).toList(),
      'redemption_count': 0,
    };

    await prefs.setString(enrollmentKey, json.encode(enrollmentData));

    return {
      'status': 'ENROLLED',
      'tier': tier,
      'benefits_count': benefits.length,
      'benefits': benefits,
    };
  }

  /// Get active benefit enrollments
  static Future<Map<String, dynamic>> getActiveEnrollments(int customerId) async {
    final prefs = await SharedPreferences.getInstance();
    final enrollmentKey = '${_benefitEnrollmentKey}_$customerId';
    final data = prefs.getString(enrollmentKey);

    if (data == null) {
      return {
        'status': 'NOT_ENROLLED',
        'tier': 'BRONZE',
        'benefits': [],
      };
    }

    return json.decode(data) as Map<String, dynamic>;
  }

  /// Redeem a specific benefit
  static Future<Map<String, dynamic>> redeemBenefit(
    int customerId,
    String benefitId,
    String benefitType, // e.g., "DISCOUNT", "BONUS_POINTS", "PRIORITY_SUPPORT"
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final enrollmentKey = '${_benefitEnrollmentKey}_$customerId';
    final enrollment = prefs.getString(enrollmentKey);

    if (enrollment == null) {
      return {'success': false, 'error': 'No active enrollment'};
    }

    final enrollmentData = json.decode(enrollment) as Map<String, dynamic>;
    final activeBenefits = List<String>.from(enrollmentData['active_benefits'] as List? ?? []);

    if (!activeBenefits.contains(benefitId)) {
      return {'success': false, 'error': 'Benefit not available'};
    }

    // Track redemption
    final redemptionKey = 'benefit_redemptions_$customerId';
    final redemptions = prefs.getString(redemptionKey);
    final redemptionList = redemptions != null
        ? (json.decode(redemptions) as List).cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];

    redemptionList.add({
      'benefit_id': benefitId,
      'benefit_type': benefitType,
      'redeemed_at': DateTime.now().toIso8601String(),
      'value': _getBenefitValue(benefitId),
    });

    await prefs.setString(redemptionKey, json.encode(redemptionList));

    // Update enrollment count
    enrollmentData['redemption_count'] = (enrollmentData['redemption_count'] as int? ?? 0) + 1;
    await prefs.setString(enrollmentKey, json.encode(enrollmentData));

    return {
      'success': true,
      'benefit_id': benefitId,
      'value': _getBenefitValue(benefitId),
      'redeemed_at': DateTime.now().toIso8601String(),
      'redemptions_this_month': redemptionList.length,
    };
  }

  /// Get benefit redemption history
  static Future<List<Map<String, dynamic>>> getBenefitRedemptions(int customerId) async {
    final prefs = await SharedPreferences.getInstance();
    final redemptionKey = 'benefit_redemptions_$customerId';
    final redemptions = prefs.getString(redemptionKey);

    if (redemptions == null) return [];

    final redemptionList = (json.decode(redemptions) as List).cast<Map<String, dynamic>>();
    return redemptionList.reversed.toList();
  }

  // ==========================================
  // 3. RETENTION MOAT ANALYSIS
  // ==========================================

  /// Calculate retention moat strength for customer
  /// Returns: {moat_score, factors, switching_cost, locked_benefits, days_remaining}
  static Future<Map<String, dynamic>> analyzeRetentionMoat(
    int customerId,
  ) async {
    final progress = await getTierProgress(customerId);
    final enrollment = await getActiveEnrollments(customerId);
    final history = await getTierHistory(customerId);
    final redemptions = await getBenefitRedemptions(customerId);

    final tier = progress['current_tier'] as String;
    final totalPoints = progress['total_points'] as int;
    final tierLevel = progress['tier_level'] as int;

    // Calculate moat factors
    final tierDepth = tierLevel == 3 ? 30 : (tierLevel == 2 ? 20 : 10);
    final benefitDepth = (enrollment['active_benefits'] as List? ?? []).length * 5;
    final investmentDepth = (history.length * 15) + (redemptions.length * 10);
    final pointsDepth = (totalPoints ~/ 100).clamp(0, 20);

    final moatScore = tierDepth + benefitDepth + investmentDepth + pointsDepth;

    // Lock status
    final lockExpires = _getLockExpireDate(tier);
    final daysRemaining = lockExpires.difference(DateTime.now()).inDays;

    return {
      'moat_score': moatScore,
      'moat_strength': _getMoatStrength(moatScore),
      'tier': tier,
      'tier_depth_points': tierDepth,
      'benefit_depth_points': benefitDepth,
      'investment_depth_points': investmentDepth,
      'points_depth_points': pointsDepth,
      'factors': {
        'tier_locked': tier.toUpperCase() != 'BRONZE',
        'benefits_active': (enrollment['active_benefits'] as List? ?? []).isNotEmpty,
        'tier_history': history.length,
        'points_invested': totalPoints,
        'redemptions': redemptions.length,
      },
      'lock_expires_at': lockExpires.toIso8601String(),
      'lock_days_remaining': daysRemaining,
      'switching_cost': _calculateSwitchingCost(tier, totalPoints),
    };
  }

  static String _getMoatStrength(int score) {
    if (score >= 100) return 'VERY_STRONG';
    if (score >= 70) return 'STRONG';
    if (score >= 40) return 'MODERATE';
    return 'WEAK';
  }

  static int _calculateSwitchingCost(String tier, int points) {
    final tierPenalty = tier == 'GOLD'
        ? 500
        : (tier == 'SILVER'
            ? 250
            : 0);
    return tierPenalty + (points ~/ 10);
  }

  // ==========================================
  // 4. TIER BENEFITS DEFINITIONS
  // ==========================================

  /// Get all benefits for a tier (public wrapper)
  static Future<List<Map<String, dynamic>>> getTierBenefits(String tier) async {
    return _getBenefitsForTier(tier);
  }

  static List<Map<String, dynamic>> _getBenefitsForTier(String tier) {
    final tierUpper = tier.toUpperCase();

    switch (tierUpper) {
      case 'GOLD':
        return [
          {'id': 'gold_no_fee', 'name': 'No Transfer Fee', 'value': 0, 'type': 'DISCOUNT'},
          {'id': 'gold_2x', 'name': '2x Loyalty Points', 'value': 2, 'type': 'MULTIPLIER'},
          {'id': 'gold_bday', 'name': 'Birthday 500 Points', 'value': 500, 'type': 'BONUS'},
          {'id': 'gold_tier_lock', 'name': '60-Day Tier Lock', 'value': 60, 'type': 'LOCK'},
          {'id': 'gold_vip', 'name': 'VIP Customer Support', 'value': 24, 'type': 'SERVICE'},
          {'id': 'gold_early_access', 'name': 'Early Sale Access', 'value': 7, 'type': 'EXCLUSIVE'},
        ];

      case 'SILVER':
        return [
          {'id': 'silver_1pct_fee', 'name': '1% Transfer Fee', 'value': 1, 'type': 'DISCOUNT'},
          {'id': 'silver_1_5x', 'name': '1.5x Loyalty Points', 'value': 1.5, 'type': 'MULTIPLIER'},
          {'id': 'silver_bday', 'name': 'Birthday 250 Points', 'value': 250, 'type': 'BONUS'},
          {'id': 'silver_tier_lock', 'name': '30-Day Tier Lock', 'value': 30, 'type': 'LOCK'},
        ];

      default: // BRONZE
        return [
          {'id': 'bronze_access', 'name': 'Network Access', 'value': 0, 'type': 'ACCESS'},
          {'id': 'bronze_2pct_fee', 'name': '2% Transfer Fee', 'value': 2, 'type': 'DISCOUNT'},
          {'id': 'bronze_tier_lock', 'name': '7-Day Tier Lock', 'value': 7, 'type': 'LOCK'},
        ];
    }
  }

  static int _getBenefitValue(String benefitId) {
    final benefitMap = {
      'gold_no_fee': 0,
      'gold_2x': 200,
      'gold_bday': 500,
      'silver_1pct_fee': 50,
      'silver_1_5x': 150,
      'silver_bday': 250,
      'bronze_access': 0,
      'bronze_2pct_fee': 25,
    };
    return benefitMap[benefitId] ?? 0;
  }

  static int _getLockDurationDays(String tier) {
    switch (tier.toUpperCase()) {
      case 'GOLD':
        return 60;
      case 'SILVER':
        return 30;
      default:
        return 7;
    }
  }

  static DateTime _getLockExpireDate(String tier) {
    final days = _getLockDurationDays(tier);
    return DateTime.now().add(Duration(days: days));
  }
}

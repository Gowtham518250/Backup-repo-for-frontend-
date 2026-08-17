import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'ltv_analytics_service.dart';

/// 📊 Cohort Analytics Aggregator
/// Aggregates retention, LTV, and churn metrics across all shops
/// Used to generate Series A investor metrics

class CohortAnalyticsService {
  /// 📈 Get aggregated cohort retention curve (for investor pitch)
  /// Returns: % of shops retained at Days 1, 7, 30, 60
  static Future<Map<String, double>> getCohortRetentionCurve() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      int totalShops = 0;
      int retained1 = 0, retained7 = 0, retained30 = 0, retained60 = 0;

      // Iterate through all shop cohort data
      for (final key in allKeys) {
        if (key.startsWith('cohort_') && key.endsWith('_metadata')) {
          totalShops++;
          
          // Extract shop_id from key: "cohort_{shop_id}_metadata"
          final parts = key.split('_');
          if (parts.length >= 2) {
            try {
              final shopId = int.parse(parts[1]);
              final retention = await LTVAnalyticsService.calculateRetention(shopId);
              
              if (retention['day_1'] == true) retained1++;
              if (retention['day_7'] == true) retained7++;
              if (retention['day_30'] == true) retained30++;
              if (retention['day_60'] == true) retained60++;
            } catch (_) {}
          }
        }
      }

      if (totalShops == 0) {
        return {
          'day_1': 0,
          'day_7': 0,
          'day_30': 0,
          'day_60': 0,
          'total_shops': 0,
        };
      }

      return {
        'day_1': (retained1 / totalShops) * 100,
        'day_7': (retained7 / totalShops) * 100,
        'day_30': (retained30 / totalShops) * 100,
        'day_60': (retained60 / totalShops) * 100,
        'total_shops': totalShops.toDouble(),
      };
    } catch (e) {
      return {};
    }
  }

  /// 💰 Get LTV distribution (for investor pitch)
  /// Returns: Count of shops in each LTV bracket
  static Future<Map<String, dynamic>> getLTVDistribution() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      final distribution = {
        'bracket_0_5k': 0,
        'bracket_5_10k': 0,
        'bracket_10_25k': 0,
        'bracket_25_50k': 0,
        'bracket_50k_plus': 0,
      };

      double totalLTV = 0;
      int totalShops = 0;

      for (final key in allKeys) {
        if (key.startsWith('cohort_') && key.endsWith('_metadata')) {
          final parts = key.split('_');
          if (parts.length >= 2) {
            try {
              final shopId = int.parse(parts[1]);
              final ltv = await LTVAnalyticsService.calculateShopLTV(shopId);
              
              totalShops++;
              totalLTV += ltv;

              if (ltv < 5000) {
                distribution['bracket_0_5k'] = (distribution['bracket_0_5k'] as int? ?? 0) + 1;
              } else if (ltv < 10000) {
                distribution['bracket_5_10k'] = (distribution['bracket_5_10k'] as int? ?? 0) + 1;
              } else if (ltv < 25000) {
                distribution['bracket_10_25k'] = (distribution['bracket_10_25k'] as int? ?? 0) + 1;
              } else if (ltv < 50000) {
                distribution['bracket_25_50k'] = (distribution['bracket_25_50k'] as int? ?? 0) + 1;
              } else {
                distribution['bracket_50k_plus'] = (distribution['bracket_50k_plus'] as int? ?? 0) + 1;
              }
            } catch (_) {}
          }
        }
      }

      final avgLTV = totalShops > 0 ? totalLTV / totalShops : 0;

      return {
        ...distribution,
        'total_shops': totalShops,
        'total_ltv': totalLTV,
        'average_ltv': avgLTV,
        'average_ltv_formatted': '₹${avgLTV.toStringAsFixed(0)}',
      };
    } catch (e) {
      return {};
    }
  }

  /// 📊 Get Churn Rate (shops inactive > 7 days)
  static Future<Map<String, dynamic>> getChurnMetrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      int active = 0;
      int churnRisk = 0;
      int totalShops = 0;

      for (final key in allKeys) {
        if (key.startsWith('cohort_') && key.endsWith('_metadata')) {
          final parts = key.split('_');
          if (parts.length >= 2) {
            try {
              final shopId = int.parse(parts[1]);
              totalShops++;
              
              final isChurn = await LTVAnalyticsService.isChurnRisk();
              if (isChurn) {
                churnRisk++;
              } else {
                active++;
              }
            } catch (_) {}
          }
        }
      }

      final churnRate = totalShops > 0 ? (churnRisk / totalShops) * 100 : 0;
      final retentionRate = 100 - churnRate;

      return {
        'total_shops': totalShops,
        'active_shops': active,
        'churn_risk_shops': churnRisk,
        'churn_rate_percent': churnRate,
        'retention_rate_percent': retentionRate,
        'churn_rate_formatted': churnRate.toStringAsFixed(1),
        'retention_rate_formatted': retentionRate.toStringAsFixed(1),
      };
    } catch (e) {
      return {};
    }
  }

  /// 🎯 Get LTV:CAC Ratio Distribution
  static Future<Map<String, dynamic>> getLTVCACDistribution() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      final ratios = <double>[];

      for (final key in allKeys) {
        if (key.startsWith('cohort_') && key.endsWith('_metadata')) {
          final parts = key.split('_');
          if (parts.length >= 2) {
            try {
              final shopId = int.parse(parts[1]);
              final ratio = await LTVAnalyticsService.calculateLTVToCACRatio(shopId);
              if (ratio > 0) ratios.add(ratio);
            } catch (_) {}
          }
        }
      }

      if (ratios.isEmpty) {
        return {
          'shops_with_profitable_ltv_cac': 0,
          'avg_ltv_cac_ratio': 0,
          'median_ltv_cac_ratio': 0,
          'percent_profitable': 0,
        };
      }

      final profitable = ratios.where((r) => r >= 3).length;
      final avg = ratios.reduce((a, b) => a + b) / ratios.length;
      
      ratios.sort();
      final median = ratios.length % 2 == 0
          ? (ratios[ratios.length ~/ 2 - 1] + ratios[ratios.length ~/ 2]) / 2
          : ratios[ratios.length ~/ 2];

      return {
        'total_analyzed': ratios.length,
        'shops_with_profitable_ltv_cac': profitable,
        'percent_profitable': (profitable / ratios.length) * 100,
        'avg_ltv_cac_ratio': avg,
        'median_ltv_cac_ratio': median,
        'min_ltv_cac_ratio': ratios.first,
        'max_ltv_cac_ratio': ratios.last,
      };
    } catch (e) {
      return {};
    }
  }

  /// 🏆 Generate Series A Pitch Deck Metrics
  static Future<Map<String, dynamic>> generatePitchDeckMetrics() async {
    try {
      final retention = await getCohortRetentionCurve();
      final ltv = await getLTVDistribution();
      final churn = await getChurnMetrics();
      final ltvCac = await getLTVCACDistribution();

      return {
        'timestamp': DateTime.now().toIso8601String(),
        'retention_curve': retention,
        'ltv_distribution': ltv,
        'churn_metrics': churn,
        'ltv_cac_metrics': ltvCac,
        'headline_metrics': {
          'summary': _generateHeadline(retention, ltv, churn, ltvCac),
          'total_shops': ltv['total_shops'] ?? 0,
          'total_revenue': ltv['total_ltv'] ?? 0,
          'average_ltv': ltv['average_ltv'] ?? 0,
          'retention_60_day': '${(retention['day_60'] ?? 0).toStringAsFixed(1)}%',
          'churn_rate': '${(churn['churn_rate_percent'] ?? 0).toStringAsFixed(1)}%',
          'ltv_cac_multiple': '${(ltvCac['avg_ltv_cac_ratio'] ?? 0).toStringAsFixed(1)}x',
        },
      };
    } catch (e) {
      return {};
    }
  }

  /// 📝 Generate one-liner headline for investor pitch
  static String _generateHeadline(
    Map<String, dynamic> retention,
    Map<String, dynamic> ltv,
    Map<String, dynamic> churn,
    Map<String, dynamic> ltvCac,
  ) {
    final shopCount = ltv['total_shops'] ?? 0;
    final day30 = (retention['day_30'] ?? 0).toStringAsFixed(0);
    final avgLtv = (ltv['average_ltv'] ?? 0).toStringAsFixed(0);
    final retentionRate = (100 - (churn['churn_rate_percent'] ?? 0)).toStringAsFixed(0);

    return '$shopCount shops | $day30% new user retention | ₹$avgLtv avg LTV | $retentionRate% retention rate';
  }

  /// 🎯 Identify at-risk shops for proactive retention
  static Future<List<int>> getAtRiskShops() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      final atRisk = <int>[];

      for (final key in allKeys) {
        if (key.startsWith('cohort_') && key.endsWith('_metadata')) {
          final parts = key.split('_');
          if (parts.length >= 2) {
            try {
              final shopId = int.parse(parts[1]);
              final isChurn = await LTVAnalyticsService.isChurnRisk();
              if (isChurn) {
                atRisk.add(shopId);
              }
            } catch (_) {}
          }
        }
      }

      return atRisk;
    } catch (e) {
      return [];
    }
  }
}

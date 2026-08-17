import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'api_client.dart';

/// 🇮🇳 GST Compliance & Export Service
/// Generates GST returns and exports for tax filing
class GstExportService {
  /// Export GSTR-1 (Sales) return
  static Future<String?> exportGstr1({
    required DateTime fromDate,
    required DateTime toDate,
    String? gstinSeller,
  }) async {
    try {
      final body = {
        'from_date': fromDate.toIso8601String().split('T')[0],
        'to_date': toDate.toIso8601String().split('T')[0],
        if (gstinSeller != null) 'gstin_seller': gstinSeller,
      };

      final response = await ApiClient.postJson('/gst/export-gstr1', body);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['file_path'] ?? data['export_data'];
      }

      if (kDebugMode) debugPrint('❌ GST export failed: ${response.statusCode}');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ GST export error: $e');
      return null;
    }
  }

  /// Export GSTR-2 (Purchases) return
  static Future<String?> exportGstr2({
    required DateTime fromDate,
    required DateTime toDate,
    String? gstinBuyer,
  }) async {
    try {
      final body = {
        'from_date': fromDate.toIso8601String().split('T')[0],
        'to_date': toDate.toIso8601String().split('T')[0],
        if (gstinBuyer != null) 'gstin_buyer': gstinBuyer,
      };

      final response = await ApiClient.postJson('/gst/export-gstr2', body);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['file_path'] ?? data['export_data'];
      }

      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ GST export error: $e');
      return null;
    }
  }

  /// Calculate GST summary
  static Future<GstSummary?> calculateGstSummary({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final query = '/api/reports/gst-summary?from=${fromDate.toIso8601String().split('T')[0]}&to=${toDate.toIso8601String().split('T')[0]}';
      
      final response = await ApiClient.getJson(query);

      if (response.statusCode == 200) {
        return GstSummary.fromJson(json.decode(response.body));
      }

      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ GST summary error: $e');
      return null;
    }
  }

  /// Get tax rate for item
  static Future<int?> getTaxRate(String? hsnCode) async {
    try {
      if (hsnCode == null || hsnCode.isEmpty) return 18; // Default GST

      final response = await ApiClient.getJson('/api/gst-rates?hsn=$hsnCode');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['tax_rate'] ?? data['gst_rate'] ?? 18;
      }

      return 18;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Tax rate fetch error, using default 18%');
      return 18;
    }
  }
}

/// GST Summary Model
class GstSummary {
  final double totalSales;
  final double totalGstCollected;
  final double totalPurchases;
  final double totalGstPaid;
  final double gstPayable;
  final DateTime periodStart;
  final DateTime periodEnd;
  final Map<int, GstRateSummary> gstByRate;

  GstSummary({
    required this.totalSales,
    required this.totalGstCollected,
    required this.totalPurchases,
    required this.totalGstPaid,
    required this.gstPayable,
    required this.periodStart,
    required this.periodEnd,
    required this.gstByRate,
  });

  factory GstSummary.fromJson(Map<String, dynamic> json) {
    final Map<int, GstRateSummary> rateMap = {};
    
    if (json['by_rate'] is Map) {
      (json['by_rate'] as Map).forEach((key, value) {
        final rate = int.tryParse(key.toString()) ?? 0;
        rateMap[rate] = GstRateSummary.fromJson(value);
      });
    }

    return GstSummary(
      totalSales: (json['total_sales'] ?? 0).toDouble(),
      totalGstCollected: (json['total_gst_collected'] ?? 0).toDouble(),
      totalPurchases: (json['total_purchases'] ?? 0).toDouble(),
      totalGstPaid: (json['total_gst_paid'] ?? 0).toDouble(),
      gstPayable: (json['gst_payable'] ?? 0).toDouble(),
      periodStart: DateTime.parse(json['period_start'] ?? DateTime.now().toString()),
      periodEnd: DateTime.parse(json['period_end'] ?? DateTime.now().toString()),
      gstByRate: rateMap,
    );
  }

  String get gstPayableFormatted => '₹${gstPayable.toStringAsFixed(2)}';
  String get totalSalesFormatted => '₹${totalSales.toStringAsFixed(2)}';
  String get totalGstCollectedFormatted => '₹${totalGstCollected.toStringAsFixed(2)}';
}

/// GST Rate-wise Summary
class GstRateSummary {
  final int rate;
  final double sales;
  final double gstOnSales;
  final double purchases;
  final double gstOnPurchases;
  final double netGst;

  GstRateSummary({
    required this.rate,
    required this.sales,
    required this.gstOnSales,
    required this.purchases,
    required this.gstOnPurchases,
    required this.netGst,
  });

  factory GstRateSummary.fromJson(Map<String, dynamic> json) {
    return GstRateSummary(
      rate: json['rate'] ?? 0,
      sales: (json['sales'] ?? 0).toDouble(),
      gstOnSales: (json['gst_on_sales'] ?? 0).toDouble(),
      purchases: (json['purchases'] ?? 0).toDouble(),
      gstOnPurchases: (json['gst_on_purchases'] ?? 0).toDouble(),
      netGst: (json['net_gst'] ?? 0).toDouble(),
    );
  }

  String get netGstFormatted => '₹${netGst.toStringAsFixed(2)}';
}

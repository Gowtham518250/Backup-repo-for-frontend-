import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'api_client.dart';

/// 📦 Batch Tracking Service
/// Manages product batches, expiry dates, and batch-specific inventory
class BatchTrackingService {
  /// Create a new batch for a product
  static Future<int?> createBatch({
    required int productId,
    required String batchNumber,
    required int quantity,
    required DateTime expiryDate,
    DateTime? manufacturingDate,
    String? supplier,
  }) async {
    try {
      final body = {
        'product_id': productId,
        'batch_number': batchNumber,
        'quantity': quantity,
        'expiry_date': expiryDate.toIso8601String().split('T')[0],
        if (manufacturingDate != null)
          'manufacturing_date': manufacturingDate.toIso8601String().split('T')[0],
        if (supplier != null) 'supplier': supplier,
      };

      final response = await ApiClient.postJson('/api/inventory/batches', body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['id'] ?? data['batch_id'];
      }

      if (kDebugMode) debugPrint('❌ Batch creation failed: ${response.statusCode}');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Batch creation error: $e');
      return null;
    }
  }

  /// Get all batches for a product
  static Future<List<ProductBatch>> getBatchesForProduct(int productId) async {
    try {
      final response = await ApiClient.getJson(
        '/api/inventory/batches/$productId',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['batches'] ?? data['items'] ?? [];

        return items.map((item) => ProductBatch.fromJson(item)).toList();
      }

      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Get batches error: $e');
      return [];
    }
  }

  /// Get all expiring batches (expiring within days)
  static Future<List<ProductBatch>> getExpiringBatches({
    int withinDays = 30,
    int limit = 100,
  }) async {
    try {
      final response = await ApiClient.getJson(
        '/api/inventory/expiring-batches?days=$withinDays&limit=$limit',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['expiring_batches'] ?? data['batches'] ?? data['items'] ?? [];

        return items.map((item) => ProductBatch.fromJson(item)).toList();
      }

      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Get expiring batches error: $e');
      return [];
    }
  }

  /// Update batch quantity (usually when used/sold)
  static Future<bool> updateBatchQuantity({
    required int batchId,
    required int newQuantity,
  }) async {
    try {
      final body = {'quantity': newQuantity};

      final response = await ApiClient.putJson(
        '/api/inventory/batches/$batchId',
        body,
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Update batch quantity error: $e');
      return false;
    }
  }

  /// Mark batch as expired/unusable
  static Future<bool> markBatchExpired(int batchId) async {
    try {
      final response = await ApiClient.putJson(
        '/api/inventory/batches/$batchId/expire',
        {},
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Mark batch expired error: $e');
      return false;
    }
  }

  /// Delete batch
  static Future<bool> deleteBatch(int batchId) async {
    try {
      final response = await ApiClient.deleteJson(
        '/api/inventory/batches/$batchId',
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Delete batch error: $e');
      return false;
    }
  }
}

/// Product Batch Model
class ProductBatch {
  final int id;
  final int productId;
  final String productName;
  final String batchNumber;
  final int quantity;
  final int? quantityUsed;
  final DateTime expiryDate;
  final DateTime? manufacturingDate;
  final String? supplier;
  final DateTime createdAt;

  ProductBatch({
    required this.id,
    required this.productId,
    required this.productName,
    required this.batchNumber,
    required this.quantity,
    this.quantityUsed,
    required this.expiryDate,
    this.manufacturingDate,
    this.supplier,
    required this.createdAt,
  });

  factory ProductBatch.fromJson(Map<String, dynamic> json) {
    return ProductBatch(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      batchNumber: json['batch_number'] ?? json['batch'] ?? '',
      quantity: json['quantity'] ?? 0,
      quantityUsed: json['quantity_used'],
      expiryDate: DateTime.parse(json['expiry_date']),
      manufacturingDate: json['manufacturing_date'] != null
          ? DateTime.parse(json['manufacturing_date'])
          : null,
      supplier: json['supplier'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toString()),
    );
  }

  int get remainingQuantity => quantity - (quantityUsed ?? 0);

  Duration get daysUntilExpiry {
    return expiryDate.difference(DateTime.now());
  }

  bool get isExpired => daysUntilExpiry.inDays <= 0;

  bool get isExpiringWithin30Days => daysUntilExpiry.inDays <= 30 && !isExpired;

  String get expiryStatus {
    if (isExpired) return '❌ EXPIRED';
    if (daysUntilExpiry.inDays <= 7) return '🚨 EXPIRING SOON (${daysUntilExpiry.inDays}d)';
    if (isExpiringWithin30Days) return '⚠️ EXPIRING (${daysUntilExpiry.inDays}d)';
    return '✅ OK (${daysUntilExpiry.inDays}d)';
  }

  Color get expiryColor {
    if (isExpired) return const Color(0xFFDC2626);  // Red
    if (daysUntilExpiry.inDays <= 7) return const Color(0xFFDC2626);  // Red
    if (isExpiringWithin30Days) return const Color(0xFFF97316);  // Orange
    return const Color(0xFF16A34A);  // Green
  }

  DateTime get batchAge {
    if (manufacturingDate == null) return createdAt;
    return manufacturingDate!;
  }

  int get ageInDays {
    return DateTime.now().difference(batchAge).inDays;
  }
}

// Import for Color extension
extension ColorUtility on String {
  Color toColor() => const Color(0xFF000000);
}

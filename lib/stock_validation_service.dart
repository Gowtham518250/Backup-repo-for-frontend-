import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'api_client.dart';

/// Stock Validation Service
/// Validates inventory availability before allowing sales
class StockValidationService {
  static StockValidationService? _instance;
  
  StockValidationService._();
  
  static StockValidationService get instance {
    _instance ??= StockValidationService._();
    return _instance!;
  }
  
  /// Validate single item stock availability
  Future<StockValidationResult> validateItemStock({
    required String itemName,
    required int requestedQuantity,
  }) async {
    try {
      // 🔒 BUG FIX: API endpoint is already correct: /api/products?name=$itemName
      final response = await ApiClient.getJson('/api/products?name=$itemName');
      
      if (response.statusCode == 200) {
        final productData = json.decode(response.body);
        final currentStock = (productData['current_stock'] as num?)?.toInt() ?? 0;
        
        if (currentStock < requestedQuantity) {
          return StockValidationResult(
            isValid: false,
            availableStock: currentStock,
            requestedQuantity: requestedQuantity,
            shortage: (requestedQuantity - currentStock).toInt(),
            message: 'Insufficient stock for $itemName. Available: $currentStock, Requested: $requestedQuantity',
          );
        }
        
        return StockValidationResult(
          isValid: true,
          availableStock: currentStock,
          requestedQuantity: requestedQuantity,
          shortage: 0,
          message: 'Stock available for $itemName',
        );
      } else {
        // If product not found or API error, allow with warning
        if (kDebugMode) debugPrint('⚠️ Could not validate stock for $itemName: API returned ${response.statusCode}');
        return StockValidationResult(
          isValid: true, // Allow sale but with warning
          availableStock: -1, // Unknown
          requestedQuantity: requestedQuantity,
          shortage: 0,
          message: 'Could not validate stock for $itemName. Proceed with caution.',
          requiresManualConfirmation: true,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Stock validation error for $itemName: $e');
      // Allow sale with warning if validation fails
      return StockValidationResult(
        isValid: true,
        availableStock: -1, // Unknown
        requestedQuantity: requestedQuantity,
        shortage: 0,
        message: 'Stock validation failed for $itemName. Proceed with caution.',
        requiresManualConfirmation: true,
      );
    }
  }
  
  /// Validate multiple items stock availability
  Future<StockValidationResult> validateBatchStock(List<StockCheckItem> items) async {
    bool allValid = true;
    String combinedMessage = '';
    int totalShortage = 0;
    
    for (final item in items) {
      final result = await validateItemStock(
        itemName: item.itemName,
        requestedQuantity: item.quantity,
      );
      
      if (!result.isValid) {
        allValid = false;
        combinedMessage += '${result.message}\n';
        totalShortage += result.shortage;
      } else if (result.requiresManualConfirmation) {
        combinedMessage += '${result.message}\n';
      }
    }
    
    return StockValidationResult(
      isValid: allValid,
      availableStock: -1, // Not applicable for batch
      requestedQuantity: items.fold<int>(0, (sum, item) => sum + item.quantity),
      shortage: totalShortage,
      message: allValid ? 'All items have sufficient stock' : combinedMessage.trim(),
      requiresManualConfirmation: combinedMessage.isNotEmpty && allValid,
    );
  }
  
  /// Check if stock is below minimum threshold
  Future<bool> isLowStock(String itemName, {int threshold = 10}) async {
    try {
      final response = await ApiClient.getJson('/api/products?name=$itemName');
      
      if (response.statusCode == 200) {
        final productData = json.decode(response.body);
        final currentStock = productData['current_stock'] ?? 0;
        return currentStock <= threshold;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Low stock check error for $itemName: $e');
      return false;
    }
  }
}

/// Stock validation result
class StockValidationResult {
  final bool isValid;
  final int availableStock;
  final int requestedQuantity;
  final int shortage;
  final String message;
  final bool requiresManualConfirmation;
  
  StockValidationResult({
    required this.isValid,
    required this.availableStock,
    required this.requestedQuantity,
    required this.shortage,
    required this.message,
    this.requiresManualConfirmation = false,
  });
  
  @override
  String toString() {
    return 'StockValidationResult(isValid: $isValid, message: $message)';
  }
}
/// Item for stock checking
class StockCheckItem {
  final String itemName;
  final int quantity;
  
  StockCheckItem({
    required this.itemName,
    required this.quantity,
  });
}

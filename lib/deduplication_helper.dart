import 'package:crypto/crypto.dart';
import 'dart:convert' show json, utf8;

/// Deduplication helper to prevent duplicate records
class DeduplicationHelper {
  
  /// Generate unique hash for customer (phone + name combo)
  static String getCustomerHash(String phone, String name) {
    if (phone.isEmpty) return '';
    // Primary key is phone, secondary is name
    final key = '$phone:${name.toLowerCase().trim()}';
    return sha256.convert(utf8.encode(key)).toString();
  }

  /// Generate unique hash for product (SKU/barcode primary)
  static String getProductHash(String sku) {
    if (sku.isEmpty) return '';
    final key = sku.toUpperCase().trim();
    return sha256.convert(utf8.encode(key)).toString();
  }

  /// Generate transaction ID for sales (prevent duplicate submissions)
  static String getTransactionId(String items, String customer, String total) {
    final key = '$items:$customer:$total:${DateTime.now().millisecond}';
    return sha256.convert(utf8.encode(key)).toString();
  }

  /// Check if customer already exists by phone
  static bool customerExists(List<Map<String, dynamic>> customers, String phone) {
    if (phone.isEmpty) return false;
    return customers.any((c) {
      final existingPhone = c['phone']?.toString() ?? '';
      return _normalizePhone(existingPhone) == _normalizePhone(phone);
    });
  }

  /// Get existing customer by phone
  static Map<String, dynamic>? getCustomerByPhone(List<Map<String, dynamic>> customers, String phone) {
    if (phone.isEmpty) return null;
    try {
      return customers.firstWhere((c) {
        final existingPhone = c['phone']?.toString() ?? '';
        return _normalizePhone(existingPhone) == _normalizePhone(phone);
      });
    } catch (e) {
      return null;
    }
  }

  /// Check if product already exists by SKU/barcode
  static bool productExists(List<Map<String, dynamic>> products, String? sku) {
    if (sku == null || sku.isEmpty) return false;
    final normalizedSku = _normalizeSku(sku);
    return products.any((p) {
      final existingSku = p['sku']?.toString() ?? p['barcode']?.toString() ?? '';
      return _normalizeSku(existingSku) == normalizedSku;
    });
  }

  /// Get existing product by SKU/barcode
  static Map<String, dynamic>? getProductBySku(List<Map<String, dynamic>> products, String? sku) {
    if (sku == null || sku.isEmpty) return null;
    final normalizedSku = _normalizeSku(sku);
    try {
      return products.firstWhere((p) {
        final existingSku = p['sku']?.toString() ?? p['barcode']?.toString() ?? '';
        return _normalizeSku(existingSku) == normalizedSku;
      });
    } catch (e) {
      return null;
    }
  }

  /// Check if sale item already exists (for deduplication)
  static bool saleItemExists(List<Map<String, dynamic>> items, String productName, double price) {
    return items.any((i) {
      final itemName = (i['product'] as String?)?.toLowerCase().trim() ?? '';
      final itemPrice = (i['price'] as num?)?.toDouble() ?? 0.0;
      return itemName == productName.toLowerCase().trim() && itemPrice == price;
    });
  }

  /// Normalize phone number for comparison (remove special characters, spaces)
  static String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d]'), '').trim();
  }

  /// Normalize SKU for comparison (uppercase, remove spaces)
  static String _normalizeSku(String sku) {
    return sku.toUpperCase().replaceAll(RegExp(r'\s+'), '').trim();
  }

  /// Check if item is already in sync queue
  static bool isInQueue(List<Map<String, dynamic>> queue, String action, Map<String, dynamic> data) {
    try {
      return queue.any((item) {
        if (item['action'] != action) return false;
        
        // For customers: check phone
        if (action == 'save_customer') {
          final existingPhone = (item['data']['phone'] as String?)?.toString() ?? '';
          final newPhone = (data['phone'] as String?)?.toString() ?? '';
          if (_normalizePhone(existingPhone) == _normalizePhone(newPhone)) return true;
        }
        
        // For products: check SKU
        if (action == 'save_product') {
          final existingSku = (item['data']['sku'] as String?)?.toString() ?? '';
          final newSku = (data['sku'] as String?)?.toString() ?? '';
          if (_normalizeSku(existingSku) == _normalizeSku(newSku)) return true;
        }
        
        // For sales: check unique sale ID
        if (action == 'save_sale') {
          final existingId = item['data']['sale_id']?.toString() ?? item['data']['invoice_payload']?['invoice_number']?.toString() ?? '';
          final newId = data['sale_id']?.toString() ?? data['invoice_payload']?['invoice_number']?.toString() ?? '';
          if (existingId.isNotEmpty && existingId == newId) return true;
        }
        
        return false;
      });
    } catch (e) {
      print('⚠️ Error checking queue duplicates: $e');
      return false;
    }
  }

  /// Format duplicate warning message
  static String getDuplicateMessage(String type, String identifier) {
    switch (type) {
      case 'customer':
        return '⚠️ Customer with phone $identifier already exists!\nTap to edit existing customer.';
      case 'product':
        return '⚠️ Product with SKU $identifier already exists!\nYou can edit the existing product instead.';
      case 'sale':
        return '⚠️ This sale appears to already be submitted.\nCheck your recent transactions.';
      default:
        return '⚠️ This item already exists in your records.';
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

/// Payment Idempotency Service
/// Prevents duplicate payment processing through idempotency keys
class PaymentIdempotencyService {
  static PaymentIdempotencyService? _instance;
  static const String _storageKey = 'payment_idempotency_keys_v2';

  Future<String> _scopedStorageKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0;
    final shopId = prefs.getInt('active_shop_id') ?? prefs.getInt('shop_id') ?? 0;
    return '${_storageKey}_${userId}_$shopId';
  }

  String generateStableKey({String? customerId, String? phone, required double amount, String? note}) {
    final normalizedCustomer = (customerId ?? '').trim().isNotEmpty ? customerId!.trim() : (phone ?? '').trim();
    final normalizedNote = (note ?? '').trim().toLowerCase();
    final basis = '$normalizedCustomer|${amount.toStringAsFixed(2)}|$normalizedNote';
    return 'payment_${base64Url.encode(utf8.encode(basis)).replaceAll('=', '')}';
  }
  static const Duration _keyExpiry = Duration(hours: 24);
  
  PaymentIdempotencyService._();
  
  static PaymentIdempotencyService get instance {
    _instance ??= PaymentIdempotencyService._();
    return _instance!;
  }
  
  /// Generate a unique idempotency key for a payment
  String generateIdempotencyKey() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(1000000);
    return 'payment_${timestamp}_$random';
  }
  
  /// Check if an idempotency key has been used
  Future<bool> isKeyUsed(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keysJson = prefs.getString(await _scopedStorageKey()) ?? '{}';
      final keys = Map<String, int>.from(
        // Safe JSON parsing
        _parseJson(keysJson) as Map? ?? {}
      );
      
      return keys.containsKey(key);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error checking idempotency key: $e');
      return false;
    }
  }
  
  /// Mark an idempotency key as used
  Future<void> markKeyUsed(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keysJson = prefs.getString(await _scopedStorageKey()) ?? '{}';
      final keys = Map<String, int>.from(
        _parseJson(keysJson) as Map? ?? {}
      );
      
      keys[key] = DateTime.now().millisecondsSinceEpoch;
      
      // Clean up expired keys
      _cleanExpiredKeys(keys);
      
      await prefs.setString(await _scopedStorageKey(), _encodeJson(keys));
      if (kDebugMode) debugPrint('✅ Marked idempotency key as used: $key');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error marking idempotency key: $e');
    }
  }
  
  /// Clean up expired idempotency keys
  void _cleanExpiredKeys(Map<String, int> keys) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiryThreshold = now - _keyExpiry.inMilliseconds;
    
    keys.removeWhere((key, timestamp) => timestamp < expiryThreshold);
  }
  
  /// Clean all idempotency keys (for testing or reset)
  Future<void> clearAllKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(await _scopedStorageKey());
      if (kDebugMode) debugPrint('✅ Cleared all idempotency keys');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error clearing idempotency keys: $e');
    }
  }
  
  /// Safe JSON parsing
  dynamic _parseJson(String jsonString) {
    try {
      return json.decode(jsonString);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ JSON parsing error: $e');
      return <String, dynamic>{};
    }
  }
  
  /// Safe JSON encoding
  String _encodeJson(Map<String, int> data) {
    try {
      return json.encode(data);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ JSON encoding error: $e');
      return '{}';
    }
  }
}

/// Payment operation guard to prevent double-tap
class PaymentOperationGuard {
  bool _isProcessing = false;
  String? _currentOperationId;
  
  /// Check if a payment operation can be started
  bool canStartOperation(String operationId) {
    if (_isProcessing) {
      if (kDebugMode) debugPrint('⚠️ Payment operation already in progress: $_currentOperationId');
      return false;
    }
    
    _isProcessing = true;
    _currentOperationId = operationId;
    return true;
  }
  
  /// Mark the current operation as complete
  void completeOperation() {
    _isProcessing = false;
    _currentOperationId = null;
    if (kDebugMode) debugPrint('✅ Payment operation completed');
  }
  
  /// Mark the current operation as failed
  void failOperation() {
    _isProcessing = false;
    _currentOperationId = null;
    if (kDebugMode) debugPrint('⚠️ Payment operation failed');
  }
  
  /// Get current operation ID
  String? get currentOperationId => _currentOperationId;
  
  /// Check if an operation is in progress
  bool get isProcessing => _isProcessing;
}
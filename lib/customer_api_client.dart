import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CustomerAPIClient {
  static const String baseUrl = 'https://retail-mind-vkbp.onrender.com/api';
  static const String wsUrl = 'wss://retail-mind-vkbp.onrender.com/ws';

  // 🔒 SECURITY FIX: Use SecureStorage instead of static variables
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _tokenKey = 'customer_token_enc';
  static const String _customerIdKey = 'customer_id_enc';

  static Future<void> initialize({
    required String customerToken,
    required String customerId,
  }) async {
    // Store token and customer ID in encrypted secure storage
    await _secureStorage.write(key: _tokenKey, value: customerToken);
    await _secureStorage.write(key: _customerIdKey, value: customerId);
  }

  static Future<void> reset() async {
    // Securely clear customer session
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _customerIdKey);
  }

  static Future<String?> _getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  static Future<String?> _getCustomerId() async {
    return await _secureStorage.read(key: _customerIdKey);
  }

  static Future<Map<String, String>> get _headers async {
    final token = await _getToken();
    return {
      'Authorization': 'Bearer ${token ?? ''}',
      'Content-Type': 'application/json',
    };
  }

  // ===== BILLS API =====

  /// Get all bills for customer
  static Future<List<Map<String, dynamic>>> getBills({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final customerId = await _getCustomerId();
      if (customerId == null) {
        throw Exception('Customer not authenticated');
      }
      final headers = await _headers;
      final res = await http.get(
        Uri.parse('$baseUrl/customers/$customerId/bills?limit=$limit&offset=$offset'),
        headers: headers,
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return List<Map<String, dynamic>>.from(data['bills'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get specific bill details
  static Future<Map<String, dynamic>?> getBillDetail(String billId) async {
    try {
      final customerId = await _getCustomerId();
      if (customerId == null) throw Exception('Not auth');
      final res = await http.get(
        Uri.parse('$baseUrl/customers/$customerId/bills/$billId'),
        headers: await _headers,
      );

      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Download bill as PDF
  static Future<String?> downloadBillPDF(String billId) async {
    try {
      final customerId = await _getCustomerId();
      if (customerId == null) throw Exception('Not auth');
      final res = await http.get(
        Uri.parse('$baseUrl/customers/$customerId/bills/$billId/pdf'),
        headers: await _headers,
      );

      if (res.statusCode == 200) {
        return res.body;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ===== ORDERS API =====

  /// Get all orders for customer
  static Future<List<Map<String, dynamic>>> getOrders({
    String? status, // PENDING, IN_TRANSIT, DELIVERED, CANCELLED
  }) async {
    try {
      final customerId = await _getCustomerId();
      if (customerId == null) throw Exception('Not auth');
      final queryStr = status != null ? '?status=$status' : '';
      final res = await http.get(
        Uri.parse('$baseUrl/customers/$customerId/orders$queryStr'),
        headers: await _headers,
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return List<Map<String, dynamic>>.from(data['orders'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get real-time order tracking
  static Future<Map<String, dynamic>?> getOrderTracking(String orderId) async {
    try {
      final customerId = await _getCustomerId();
      if (customerId == null) throw Exception('Not auth');
      final res = await http.get(
        Uri.parse('$baseUrl/orders/$orderId/tracking'),
        headers: await _headers,
      );

      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ===== LOYALTY API =====

  /// Get customer loyalty information
  static Future<Map<String, dynamic>?> getLoyaltyInfo() async {
    try {
      final customerId = await _getCustomerId();
      if (customerId == null) throw Exception('Not auth');
      final res = await http.get(
        Uri.parse('$baseUrl/customers/$customerId/loyalty'),
        headers: await _headers,
      );

      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get loyalty transaction history
  static Future<List<Map<String, dynamic>>> getLoyaltyTransactions() async {
    try {
      final customerId = await _getCustomerId();
      if (customerId == null) throw Exception('Not auth');
      final res = await http.get(
        Uri.parse('$baseUrl/customers/$customerId/loyalty/transactions'),
        headers: await _headers,
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return List<Map<String, dynamic>>.from(data['transactions'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get available birthday discounts
  static Future<List<Map<String, dynamic>>> getBirthdayOffers() async {
    try {
      final customerId = await _getCustomerId();
      if (customerId == null) throw Exception('Not auth');
      final res = await http.get(
        Uri.parse('$baseUrl/customers/$customerId/birthday-offers'),
        headers: await _headers,
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return List<Map<String, dynamic>>.from(data['offers'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ===== PAYMENT API =====

  /// Process payment
  static Future<Map<String, dynamic>> processPayment({
    required String billId,
    required double amount,
    required String paymentMethod, // CASH, UPI, CARD, BANK_TRANSFER
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final customerId = await _getCustomerId();
      if (customerId == null) throw Exception('Not auth');
      final res = await http.post(
        Uri.parse('$baseUrl/customers/$customerId/payments'),
        headers: await _headers,
        body: json.encode({
          'bill_id': billId,
          'amount': amount,
          'payment_method': paymentMethod,
          'metadata': metadata,
        }),
      );

      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
      return {'success': false, 'error': 'Payment failed'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get payment history
  static Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    try {
      final customerId = await _getCustomerId();
      if (customerId == null) throw Exception('Not auth');
      final res = await http.get(
        Uri.parse('$baseUrl/customers/$customerId/payments'),
        headers: await _headers,
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return List<Map<String, dynamic>>.from(data['payments'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ===== CUSTOMER PROFILE API =====

  /// Get customer profile
  static Future<Map<String, dynamic>?> getProfile() async {
    try {
      final customerId = await _getCustomerId();
      if (customerId == null) throw Exception('Not auth');
      final res = await http.get(
        Uri.parse('$baseUrl/customers/$customerId/profile'),
        headers: await _headers,
      );

      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Update customer profile
  static Future<bool> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? pincode,
  }) async {
    try {
      final customerId = await _getCustomerId();
      if (customerId == null) throw Exception('Not auth');
      final res = await http.put(
        Uri.parse('$baseUrl/customers/$customerId/profile'),
        headers: await _headers,
        body: json.encode({
          if (name != null) 'name': name,
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
          if (address != null) 'address': address,
          if (city != null) 'city': city,
          if (pincode != null) 'pincode': pincode,
        }),
      );

      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ===== NOTIFICATION PREFERENCES =====

  /// Update notification preferences
  static Future<bool> updateNotificationPreferences({
    required bool smsEnabled,
    required bool emailEnabled,
    required bool whatsappEnabled,
  }) async {
    try {
      final customerId = await _getCustomerId();
      if (customerId == null) throw Exception('Not auth');
      final res = await http.put(
        Uri.parse('$baseUrl/customers/$customerId/notification-preferences'),
        headers: await _headers,
        body: json.encode({
          'sms_enabled': smsEnabled,
          'email_enabled': emailEnabled,
          'whatsapp_enabled': whatsappEnabled,
        }),
      );

      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

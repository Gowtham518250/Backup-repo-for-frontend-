import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'api_client.dart';
import 'secure_token_storage.dart';
import 'payment_event.dart';

/// Online orders: analytics, UPI matching, notifications helpers.
class OnlineOrderService {
  static const _orders = 'orders';

  /// Shop UPI for customer checkout — Firestore only (never owner prefs.upi_id).
  static Future<String?> fetchShopUpi(String shopId) async {
    if (shopId.isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance.collection('shops').doc(shopId).get();
      final upi = doc.data()?['upi_id']?.toString().trim();
      if (upi != null && upi.isNotEmpty) return upi;
    } catch (e) {
      if (kDebugMode) debugPrint('fetchShopUpi Firestore: $e');
    }
    return null;
  }

  static Future<void> syncShopUpiToFirestore(String shopId) async {
    if (shopId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final upi = prefs.getString('upi_id');
    if (upi == null || upi.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('shops').doc(shopId).set(
        {'upi_id': upi},
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('syncShopUpi: $e');
    }
  }

  /// Online metrics from the canonical FastAPI owner-order source.
  /// Firestore remains available for customer-store UPI configuration, but
  /// owner analytics must come from the same backend that drives order status.
  static Future<Map<String, dynamic>> getAnalytics(String shopId) async {
    if (shopId.isEmpty || shopId == '0') {
      return {'pending': 0, 'todayCount': 0, 'todayRevenue': 0.0, 'paidCount': 0, 'totalCount': 0};
    }

    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        return {'pending': 0, 'todayCount': 0, 'todayRevenue': 0.0, 'paidCount': 0, 'totalCount': 0};
      }

      const statuses = <String>['PENDING', 'ACCEPTED', 'DISPATCHED', 'DELIVERED'];
      final ordersById = <String, Map<String, dynamic>>{};
      for (final status in statuses) {
        try {
          final response = await ApiClient.getJson(
            '/store/owner/orders?status=$status',
            headers: {'Authorization': 'Bearer $token'},
          ).timeout(const Duration(seconds: 10));
          if (response.statusCode != 200) continue;
          final body = jsonDecode(response.body);
          final raw = body is Map ? body['orders'] : body;
          if (raw is! List) continue;
          for (final item in raw) {
            if (item is! Map) continue;
            final order = Map<String, dynamic>.from(item);
            final id = (order['order_id'] ?? order['id'] ?? '').toString();
            if (id.isNotEmpty) ordersById[id] = order;
          }
        } catch (e) {
          if (kDebugMode) debugPrint('getAnalytics $status: $e');
        }
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      int pending = 0;
      int todayCount = 0;
      int paidCount = 0;
      double todayRevenue = 0.0;

      for (final order in ordersById.values) {
        final status = (order['status'] ?? order['order_status'] ?? '').toString().toUpperCase();
        if (status == 'PENDING') pending++;
        final rawDate = order['created_at'] ?? order['timestamp'] ?? order['placed_at'];
        final dt = rawDate == null ? null : DateTime.tryParse(rawDate.toString())?.toLocal();
        if (dt != null && DateTime(dt.year, dt.month, dt.day) == today && status != 'REJECTED') {
          todayCount++;
          todayRevenue += (order['total_amount'] as num?)?.toDouble() ?? double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0.0;
          final paymentStatus = (order['payment_status'] ?? '').toString().toUpperCase();
          if (paymentStatus == 'PAID' || status == 'DELIVERED') paidCount++;
        }
      }

      return {
        'pending': pending,
        'todayCount': todayCount,
        'todayRevenue': todayRevenue,
        'paidCount': paidCount,
        'totalCount': ordersById.length,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('getAnalytics: $e');
      return {'pending': 0, 'todayCount': 0, 'todayRevenue': 0.0, 'paidCount': 0, 'totalCount': 0};
    }
  }

  /// Match incoming UPI to a pending online order (owner device).
  static Future<String?> tryMatchOnlineOrderPayment(
    PaymentEvent event,
    String shopId,
  ) async {
    if (shopId.isEmpty || event.isFailed || event.amount <= 0) return null;

    try {
      final snap = await FirebaseFirestore.instance
          .collection(_orders)
          .where('shop_id', isEqualTo: shopId)
          .where('payment_status', isEqualTo: 'pending')
          .where('payment_method', isEqualTo: 'upi')
          .limit(20)
          .get();

      for (final doc in snap.docs) {
        final expected = (doc.data()['total_amount'] as num?)?.toDouble() ?? 0;
        if ((event.amount - expected).abs() > 1.0) continue;

        await doc.reference.update({
          'payment_status': 'paid',
          'paid_at': FieldValue.serverTimestamp(),
          'payment_reference': event.referenceId ?? event.id,
          'payment_amount': event.amount,
        });

        await NotificationService.show(
          'Online payment received',
          '₹${event.amount.toStringAsFixed(0)} matched to order #${doc.id.substring(0, 8)}',
        );
        return doc.id;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('tryMatchOnlineOrderPayment: $e');
    }
    return null;
  }

  static Future<void> notifyOrderStatusChange({
    required String orderId,
    required String status,
    required String shopName,
    required double total,
  }) async {
    await NotificationService.show(
      'Order update — $shopName',
      '#${orderId.substring(0, 8)}: $status · ₹${total.toStringAsFixed(0)}',
    );
  }

  static Future<void> notifyNewOrderForOwner({
    required String orderId,
    required double total,
    required String customerEmail,
  }) async {
    await NotificationService.show(
      'New online order',
      '₹${total.toStringAsFixed(0)} from $customerEmail · Tap Online Store',
    );
  }
}

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'online_order_service.dart';
import 'payment_detection_service.dart';
import 'payment_event.dart';

/// Background listeners: new orders (owner) + UPI payment matching.
class OnlineOrdersListener {
  static final OnlineOrdersListener instance = OnlineOrdersListener._();
  OnlineOrdersListener._();

  StreamSubscription<QuerySnapshot>? _ordersSub;
  StreamSubscription<PaymentEvent>? _paymentSub;
  final Set<String> _notifiedOrderIds = {};
  String _shopId = '';
  bool _started = false;

  Future<void> stop() async {
    await _ordersSub?.cancel();
    await _paymentSub?.cancel();
    _ordersSub = null;
    _paymentSub = null;
    _notifiedOrderIds.clear();
    _shopId = '';
    _started = false;
    if (kDebugMode) debugPrint('🛑 OnlineOrdersListener stopped');
  }

  /// Call after login or account switch (same app process).
  Future<void> restartForCurrentUser() async {
    await stop();
    await start();
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;

    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    if (role == 'customer') return;

    _shopId = (prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0).toString();
    if (_shopId.isEmpty || _shopId == '0') {
      _started = false;
      return;
    }

    await OnlineOrderService.syncShopUpiToFirestore(_shopId);

    _ordersSub = FirebaseFirestore.instance
        .collection('orders')
        .where('shop_id', isEqualTo: _shopId)
        .where('status', isEqualTo: 'Pending')
        .snapshots()
        .listen(_onPendingOrders);

    _paymentSub = PaymentDetectionService().onPaymentDetected.listen((event) {
      OnlineOrderService.tryMatchOnlineOrderPayment(event, _shopId);
    });

    if (kDebugMode) debugPrint('✅ OnlineOrdersListener started for shop $_shopId');
  }

  void _onPendingOrders(QuerySnapshot snap) {
    for (final doc in snap.docChanges) {
      if (doc.type != DocumentChangeType.added) continue;
      final id = doc.doc.id;
      if (_notifiedOrderIds.contains(id)) continue;
      _notifiedOrderIds.add(id);

      final d = doc.doc.data() as Map<String, dynamic>?;
      if (d == null) continue;

      final total = (d['total_amount'] as num?)?.toDouble() ?? 0;
      final email = d['customer_email']?.toString() ?? 'Customer';
      unawaited(OnlineOrderService.notifyNewOrderForOwner(
        orderId: id,
        total: total,
        customerEmail: email,
      ));
    }
  }

  void dispose() {
    unawaited(stop());
  }
}

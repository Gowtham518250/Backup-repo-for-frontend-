import 'dart:async';
import 'package:flutter/foundation.dart';

/// Delivery status enum
enum DeliveryStatus {
  pending,      // Order placed, not yet dispatched
  dispatched,   // Order on the way
  delivered,    // Delivered to customer
  paid,         // Payment received
  cancelled,
}

/// Delivery entry model
class DeliveryEntry {
  final String orderId;
  final String? whatsappMessage;
  final String? customerPhone;
  final String? customerAddress;
  final double orderAmount;
  final DateTime createdAt;
  final DateTime? dispatchedAt;
  final DateTime? deliveredAt;
  final DateTime? paidAt;
  DeliveryStatus status;
  
  DeliveryEntry({
    required this.orderId,
    this.whatsappMessage,
    this.customerPhone,
    this.customerAddress,
    required this.orderAmount,
    required this.createdAt,
    this.dispatchedAt,
    this.deliveredAt,
    this.paidAt,
    this.status = DeliveryStatus.pending,
  });
  
  bool get isPaymentWatchActive {
    return status == DeliveryStatus.delivered &&
        paidAt == null &&
        DateTime.now().difference(deliveredAt!).inMinutes < 30;
  }
  
  int get minutesSinceDelivery {
    if (deliveredAt == null) return 0;
    return DateTime.now().difference(deliveredAt!).inMinutes;
  }
}

/// Delivery Tracking Service
class DeliveryTrackingService {
  static const String _tag = '🚚 DELIVERY_TRACKING';
  static const int paymentWatchWindowMinutes = 30;
  static const double paymentTolerance = 5.0;  // ±₹5 tolerance
  
  final List<DeliveryEntry> activeDeliveries = [];
  final Map<String, Timer> paymentWatchers = {};
  
  // Callbacks
  Function(DeliveryEntry)? onStatusChanged;
  Function(DeliveryEntry, double)? onPaymentDetected;
  
  /// Mark order as dispatched
  Future<void> markDispatched(DeliveryEntry delivery) async {
    delivery.status = DeliveryStatus.dispatched;
    onStatusChanged?.call(delivery);
    debugPrint('$_tag Marked dispatched: ${delivery.orderId}');
  }
  
  /// Mark order as delivered
  Future<void> markDelivered(DeliveryEntry delivery) async {
    delivery.status = DeliveryStatus.delivered;
    onStatusChanged?.call(delivery);
    
    // Start payment watch
    await _startPaymentWatch(delivery);
    debugPrint('$_tag Marked delivered: ${delivery.orderId}, watching for payment...');
  }
  
  /// Mark order as paid
  Future<void> markPaid(DeliveryEntry delivery, double paidAmount) async {
    delivery.status = DeliveryStatus.paid;
    onStatusChanged?.call(delivery);
    
    // Stop payment watch
    _stopPaymentWatch(delivery.orderId);
    
    debugPrint('$_tag Marked paid: ${delivery.orderId}, amount: ₹$paidAmount');
  }
  
  /// Check if payment matches order amount (with tolerance)
  bool isPaymentMatching(double detectedAmount, double orderAmount) {
    final diff = (detectedAmount - orderAmount).abs();
    return diff <= paymentTolerance;
  }
  
  /// Start watching for payment for 30 minutes
  Future<void> _startPaymentWatch(DeliveryEntry delivery) async {
    // Kill any existing watcher
    _stopPaymentWatch(delivery.orderId);
    
    final timer = Timer(Duration(minutes: paymentWatchWindowMinutes), () async {
      if (delivery.status == DeliveryStatus.delivered && delivery.paidAt == null) {
        debugPrint('$_tag Payment window expired for ${delivery.orderId}');
        onStatusChanged?.call(delivery);
      }
    });
    
    paymentWatchers[delivery.orderId] = timer;
  }
  
  /// Stop watching for payment
  void _stopPaymentWatch(String orderId) {
    paymentWatchers[orderId]?.cancel();
    paymentWatchers.remove(orderId);
  }
  
  /// Process detected payment
  Future<void> processPaymentDetected(
    String detectedUTR,
    double detectedAmount,
  ) async {
    for (final delivery in activeDeliveries) {
      if (delivery.status == DeliveryStatus.delivered &&
          delivery.paidAt == null &&
          delivery.isPaymentWatchActive) {
        
        if (isPaymentMatching(detectedAmount, delivery.orderAmount)) {
          debugPrint('$_tag Payment matched for ${delivery.orderId}: ₹$detectedAmount');
          
          await markPaid(delivery, detectedAmount);
          onPaymentDetected?.call(delivery, detectedAmount);
          return;
        }
      }
    }
  }
  
  /// Get active on-the-way deliveries
  List<DeliveryEntry> getActiveDeliveries() {
    return activeDeliveries
        .where((d) => d.status == DeliveryStatus.dispatched ||
            (d.status == DeliveryStatus.delivered && d.paidAt == null))
        .toList();
  }
  
  /// Get payment-pending deliveries
  List<DeliveryEntry> getPaymentPendingDeliveries() {
    return activeDeliveries
        .where((d) => d.status == DeliveryStatus.delivered &&
            d.paidAt == null &&
            !d.isPaymentWatchActive)
        .toList();
  }
  
  /// Cleanup
  void dispose() {
    for (final timer in paymentWatchers.values) {
      timer.cancel();
    }
    paymentWatchers.clear();
  }
}

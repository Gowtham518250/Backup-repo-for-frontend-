// FIX-7: State Management — Replace raw setState with ChangeNotifier
// This prevents full-screen rebuilds and enables granular updates

import 'package:flutter/foundation.dart';
import '../payment_event.dart';

/// Manages payment state with minimal rebuilds
class PaymentStateNotifier extends ChangeNotifier {
  final List<PaymentEvent> _payments = [];
  
  List<PaymentEvent> get payments => List.unmodifiable(_payments);
  
  double get todayTotal => _payments
      .where((p) => _isToday(p.timestamp))  // Use timestamp, not detectedAt
      .fold(0.0, (sum, p) => sum + p.amount);

  /// Add new payment (inserts at top for chronological order)
  void addPayment(PaymentEvent payment) {
    _payments.insert(0, payment);
    notifyListeners();
  }

  /// Update existing payment
  void updatePayment(String id, PaymentEvent updated) {
    final idx = _payments.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    _payments[idx] = updated;
    notifyListeners();
  }

  /// Remove payment
  void removePayment(String id) {
    _payments.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  /// Clear all payments
  void clear() {
    _payments.clear();
    notifyListeners();
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }
}

/// Manages payment decision state (CONFIRMED, LIKELY, REJECTED, etc.)
class PaymentDecisionStateNotifier extends ChangeNotifier {
  Map<String, PaymentDecision> _decisions = {};

  PaymentDecision? getDecision(String id) => _decisions[id];

  void setDecision(String id, PaymentDecision decision) {
    _decisions[id] = decision;
    notifyListeners();
  }

  void clear() {
    _decisions.clear();
    notifyListeners();
  }

  int get confirmedCount => _decisions.values.where((d) => d == PaymentDecision.confirmed).length;
  int get likelyCount => _decisions.values.where((d) => d == PaymentDecision.likely).length;
  int get rejectedCount => _decisions.values.where((d) => d == PaymentDecision.rejected).length;
}

enum PaymentDecision { confirmed, likely, tentative, suspicious, rejected }

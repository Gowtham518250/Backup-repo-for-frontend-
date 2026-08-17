import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A single logged payment against a worker (advance, salary, bonus, etc.)
class WorkerPayment {
  final String id;
  final int workerId;
  final double amount;
  final String note;
  final String type; // 'Salary' | 'Advance' | 'Bonus' | 'Other'
  final DateTime date;

  WorkerPayment({
    required this.id,
    required this.workerId,
    required this.amount,
    required this.note,
    required this.type,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'workerId': workerId,
        'amount': amount,
        'note': note,
        'type': type,
        'date': date.toIso8601String(),
      };

  factory WorkerPayment.fromJson(Map<String, dynamic> j) => WorkerPayment(
        id: j['id'] as String,
        workerId: j['workerId'] as int,
        amount: (j['amount'] as num).toDouble(),
        note: j['note'] as String? ?? '',
        type: j['type'] as String? ?? 'Other',
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
      );
}

/// PaymentHistoryStorage - local-only payment log, mirrors the pattern used
/// by WorkerLocalStorage. Keyed per shopkeeper so payments never leak across
/// accounts on a shared device.
class PaymentHistoryStorage {
  static String _key(int shopkeeperId) => 'worker_payments_$shopkeeperId';

  static Future<List<WorkerPayment>> fetchAll(int shopkeeperId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(shopkeeperId));
      if (raw == null) return [];
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded
          .map((p) => WorkerPayment.fromJson(p as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      print('❌ Error fetching payment history: $e');
      return [];
    }
  }

  static Future<List<WorkerPayment>> fetchForWorker(
      int shopkeeperId, int workerId) async {
    final all = await fetchAll(shopkeeperId);
    return all.where((p) => p.workerId == workerId).toList();
  }

  static Future<void> addPayment(int shopkeeperId, WorkerPayment payment) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = await fetchAll(shopkeeperId);
      all.add(payment);
      await prefs.setString(
          _key(shopkeeperId), jsonEncode(all.map((p) => p.toJson()).toList()));
    } catch (e) {
      print('❌ Error saving payment: $e');
    }
  }

  static Future<void> deletePayment(int shopkeeperId, String paymentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = await fetchAll(shopkeeperId);
      all.removeWhere((p) => p.id == paymentId);
      await prefs.setString(
          _key(shopkeeperId), jsonEncode(all.map((p) => p.toJson()).toList()));
    } catch (e) {
      print('❌ Error deleting payment: $e');
    }
  }

  /// Total paid to a worker in the current calendar month.
  static Future<double> monthTotalForWorker(
      int shopkeeperId, int workerId) async {
    final now = DateTime.now();
    final payments = await fetchForWorker(shopkeeperId, workerId);
    return payments
        .where((p) => p.date.year == now.year && p.date.month == now.month)
        .fold<double>(0, (sum, p) => sum + p.amount);
  }
}

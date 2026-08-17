import 'package:flutter/foundation.dart';
import 'providers/payment_state.dart';
import 'providers/invoice_state.dart';
import 'providers/worker_state.dart';

/// Clears in-memory Provider state on logout / account switch.
class AppStateReset {
  static PaymentStateNotifier? payment;
  static PaymentDecisionStateNotifier? paymentDecision;
  static InvoiceStateNotifier? invoice;
  static WorkerStateNotifier? worker;

  static void register({
    PaymentStateNotifier? paymentNotifier,
    PaymentDecisionStateNotifier? paymentDecisionNotifier,
    InvoiceStateNotifier? invoiceNotifier,
    WorkerStateNotifier? workerNotifier,
  }) {
    if (paymentNotifier != null) payment = paymentNotifier;
    if (paymentDecisionNotifier != null) paymentDecision = paymentDecisionNotifier;
    if (invoiceNotifier != null) invoice = invoiceNotifier;
    if (workerNotifier != null) worker = workerNotifier;
  }

  static void resetAll() {
    payment?.clear();
    paymentDecision?.clear();
    invoice?.clear();
    worker?.clear();
    if (kDebugMode) debugPrint('🧹 AppStateReset: provider caches cleared');
  }
}

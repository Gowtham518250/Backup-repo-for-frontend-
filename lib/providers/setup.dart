// FIX-7: Provider Configuration — Setup for main.dart
// This replaces raw setState with ChangeNotifier pattern

import 'package:provider/provider.dart';
import '../app_state_reset.dart';
import 'payment_state.dart';
import 'invoice_state.dart';
import 'worker_state.dart';

/// Create all providers — use this in main.dart
List<ChangeNotifierProvider> createAppProviders() {
  final payment = PaymentStateNotifier();
  final paymentDecision = PaymentDecisionStateNotifier();
  final invoice = InvoiceStateNotifier();
  final worker = WorkerStateNotifier();
  AppStateReset.register(
    paymentNotifier: payment,
    paymentDecisionNotifier: paymentDecision,
    invoiceNotifier: invoice,
    workerNotifier: worker,
  );
  return [
    ChangeNotifierProvider<PaymentStateNotifier>(create: (_) => payment),
    ChangeNotifierProvider<PaymentDecisionStateNotifier>(create: (_) => paymentDecision),
    ChangeNotifierProvider<InvoiceStateNotifier>(create: (_) => invoice),
    ChangeNotifierProvider<WorkerStateNotifier>(create: (_) => worker),
  ];
}

/// Helper to use in main.dart:
/// Example integration in main.dart:
///
/// void main() {
///   runApp(
///     MultiProvider(
///       providers: createAppProviders(),
///       child: const MyApp(),
///     ),
///   );
/// }
///
/// Usage in widgets:
///
/// // Read (one-way, immutable data):
/// final payments = context.read<PaymentStateNotifier>().payments;
///
/// // Watch (rebuild when data changes):
/// final invoices = context.watch<InvoiceStateNotifier>().invoices;
///
/// // Update:
/// context.read<PaymentStateNotifier>().addPayment(payment);
/// context.read<InvoiceStateNotifier>().updateInvoiceStatus(invNum, 'PAID');
/// context.read<WorkerStateNotifier>().recordActivity(workerId);

// FIX-7: Invoice State Management — Granular updates without full rebuilds

import 'package:flutter/foundation.dart';

/// Represents an invoice in the state
class InvoiceState {
  final String number;
  final String customer;
  final double totalAmount;
  final String paymentStatus; // UNPAID, PARTIAL, PAID
  final DateTime createdDate;
  final DateTime? paidDate;

  InvoiceState({
    required this.number,
    required this.customer,
    required this.totalAmount,
    required this.paymentStatus,
    required this.createdDate,
    this.paidDate,
  });

  InvoiceState copyWith({
    String? paymentStatus,
    DateTime? paidDate,
  }) => InvoiceState(
    number: number,
    customer: customer,
    totalAmount: totalAmount,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    createdDate: createdDate,
    paidDate: paidDate ?? this.paidDate,
  );
}

/// Manages invoice state — prevents deletion, tracks updates
class InvoiceStateNotifier extends ChangeNotifier {
  final Map<String, InvoiceState> _invoices = {};

  List<InvoiceState> get invoices => _invoices.values.toList();
  
  InvoiceState? getInvoice(String number) => _invoices[number];

  /// Add new invoice
  void addInvoice(InvoiceState invoice) {
    _invoices[invoice.number] = invoice;
    notifyListeners();
  }

  /// Set invoices from list of maps
  void setInvoices(List<Map<String, dynamic>> invoicesList) {
    _invoices.clear();
    for (final inv in invoicesList) {
      final invoice = InvoiceState(
        number: inv['number'] ?? '',
        customer: inv['customer'] ?? 'Guest',
        totalAmount: (inv['totalAmount'] as num?)?.toDouble() ?? 0.0,
        paymentStatus: inv['paymentStatus'] ?? 'UNPAID',
        createdDate: inv['createdDate'] is DateTime 
            ? inv['createdDate'] as DateTime 
            : DateTime.now(),
        paidDate: inv['paidDate'] is DateTime ? inv['paidDate'] as DateTime : null,
      );
      _invoices[invoice.number] = invoice;
    }
    notifyListeners();
  }

  /// Update invoice status (NEVER delete)
  void updateInvoiceStatus(String invoiceNumber, String newStatus, [DateTime? paidDate]) {
    final invoice = _invoices[invoiceNumber];
    if (invoice == null) return;
    _invoices[invoiceNumber] = invoice.copyWith(
      paymentStatus: newStatus,
      paidDate: newStatus == 'PAID' ? paidDate ?? DateTime.now() : paidDate,
    );
    notifyListeners();
  }

  double get totalPendingAmount => _invoices.values
      .where((i) => i.paymentStatus == 'UNPAID' || i.paymentStatus == 'PARTIAL')
      .fold(0.0, (sum, i) => sum + i.totalAmount);

  double get totalPaidAmount => _invoices.values
      .where((i) => i.paymentStatus == 'PAID')
      .fold(0.0, (sum, i) => sum + i.totalAmount);

  int get unpaidCount => _invoices.values.where((i) => i.paymentStatus == 'UNPAID').length;
  int get paidCount => _invoices.values.where((i) => i.paymentStatus == 'PAID').length;
  int get totalCount => _invoices.length;

  void clear() {
    _invoices.clear();
    notifyListeners();
  }
}

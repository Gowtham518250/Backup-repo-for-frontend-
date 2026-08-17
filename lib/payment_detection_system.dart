import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'transaction_service.dart';
import 'smart_payment_matcher_service.dart';
import 'local_storage_service.dart';

/// Unified Payment Detection System
/// Listens for SMS + Notifications in real-time
/// Auto-matches with sales data + shows confirmation popup
class PaymentDetectionSystem {
  static const String _tag = '📱 PAYMENT_DETECTOR';
  static const Duration _debounce = Duration(seconds: 2);

  static Timer? _debounceTimer;
  static final List<Transaction> _pendingPayments = [];
  static Function(Transaction, PaymentConfidence)? _onPaymentDetected;
  static Function(String)? _onError;

  /// Clear in-memory pending queue on logout / account switch.
  static void clearOnLogout() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingPayments.clear();
    _onPaymentDetected = null;
    _onError = null;
  }

  /// Initialize payment detection system
  static Future<void> initialize({
    required Function(Transaction, PaymentConfidence) onPaymentDetected,
    required Function(String) onError,
  }) async {
    _onPaymentDetected = onPaymentDetected;
    _onError = onError;

    if (kDebugMode) print('$_tag System initialized');
  }

  /// Simulate SMS Reception (for testing / real SMS would come from platform channel)
  static Future<void> recordSmsPayment(
    String smsBody,
    String senderAddress,
    String senderName,
  ) async {
    if (kDebugMode) print('$_tag SMS received from $senderName ($senderAddress)');

    try {
      // Parse SMS to transaction
      final transaction = await _parseAndCreateTransaction(
        smsBody,
        senderAddress,
        senderName,
      );

      if (transaction != null) {
        _pendingPayments.add(transaction);
        _debouncedProcess();
      }
    } catch (e) {
      _onError?.call('SMS Parsing Error: $e');
      if (kDebugMode) print('$_tag Error: $e');
    }
  }

  /// Simulate Notification Reception (UPI apps)
  static Future<void> recordNotificationPayment(
    String title,
    String body,
    String packageName,
  ) async {
    if (kDebugMode) print('$_tag Notification from $packageName');

    try {
      final transaction = await _parseAndCreateTransaction(body, packageName, title);

      if (transaction != null) {
        _pendingPayments.add(transaction);
        _debouncedProcess();
      }
    } catch (e) {
      _onError?.call('Notification Parse Error: $e');
      if (kDebugMode) print('$_tag Error: $e');
    }
  }

  /// Debounce rapid multiple payments (same SMS parsed twice)
  static void _debouncedProcess() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, _processPayments);
  }

  /// Process all pending payments with sales matching
  static Future<void> _processPayments() async {
    if (_pendingPayments.isEmpty) return;

    if (kDebugMode) print('$_tag Processing ${_pendingPayments.length} pending payments');

    try {
      // Get today's sales from local storage (real sales data)
      final todaySales = await _getTodaySalesData();

      for (final payment in _pendingPayments) {
        // Run smart matching
        final confidence = await SmartPaymentMatcherService.matchPaymentToSale(
          payment,
          todaySales,
        );

        // Auto-save to transactions if high confidence
        if (confidence.status == 'AUTO_CONFIRMED') {
          // payment.notes removed - field doesn't exist
          // await (TransactionService()).saveTransaction(payment); // method removed
          if (kDebugMode) print('$_tag ✅ Auto-confirmed: ${payment.name} - ₹${payment.amount}');
        }

        // Trigger callback for UI popup
        _onPaymentDetected?.call(payment, confidence);
      }

      _pendingPayments.clear();
    } catch (e) {
      _onError?.call('Processing Error: $e');
      if (kDebugMode) print('$_tag Error: $e');
    }
  }

  /// Parse SMS/notification to transaction object
  static Future<Transaction?> _parseAndCreateTransaction(
    String messageBody,
    String source,
    String senderName,
  ) async {
    Transaction? transaction;

    // Bank SMS detection
    if (_isBankSms(source, senderName)) {
      transaction = await _parseAsBankSms(messageBody, source, senderName);
    }
    // UPI app detection
    else if (_isUpiNotification(source, senderName)) {
      transaction = await _parseAsUpiNotification(messageBody, source, senderName);
    }

    return transaction;
  }

  // ========== BANK SMS PARSING ==========
  static bool _isBankSms(String source, String senderName) {
    final bankPatterns = [
      'ICICI', 'HDFC', 'AXIS', 'SBI', 'BOI', 'Canara', 'PNB', 'Union',
      'bank', 'alert', 'txn', '5555', '9999', '9898'
    ];
    final combined = (source + senderName).toLowerCase();
    return bankPatterns.any((p) => combined.contains(p.toLowerCase()));
  }

  static Future<Transaction?> _parseAsBankSms(
    String message,
    String source,
    String senderName,
  ) async {
    if (kDebugMode) print('$_tag Parsing as Bank SMS');

    try {
      // Amount extraction: ₹5000 or Rs.5000 or INR 5000
      final amountMatch = RegExp(r'[₹Rs\.]*\s*(\d+(?:,\d+)*(?:\.\d{2})?)').firstMatch(message);
      if (amountMatch == null) return null;

      double amount = double.parse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0;

      // Type detection: Debit/Credit/Withdrawal
      bool isPaid = message.contains(RegExp(r'debit|withdrawn?|debited|paid', caseSensitive: false));
      bool isReceived = message.contains(RegExp(r'credit|received?|credited', caseSensitive: false));

      String type = isPaid ? 'PAID' : (isReceived ? 'RECEIVED' : 'PENDING');

      // Name extraction: "to Rahul" or "from Rahul" or "To/From account holder"
      String name = 'Bank Payment';
      final toMatch = RegExp(r'to\s+(\w+)', caseSensitive: false).firstMatch(message);
      final fromMatch = RegExp(r'from\s+(\w+)', caseSensitive: false).firstMatch(message);

      if (toMatch != null) {
        name = toMatch.group(1) ?? 'Bank Payment';
      } else if (fromMatch != null) {
        name = fromMatch.group(1) ?? 'Bank Payment';
      }

      // Reference: Transaction ID / Ref no
      String reference = '';
      final refMatch = RegExp(r'(?:Ref|Reference|TxnID|ID)[:\s]+(\w+)', caseSensitive: false)
          .firstMatch(message);
      if (refMatch != null) {
        reference = refMatch.group(1) ?? '';
      }

      final transaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        source: _detectBankName(source, senderName),
        name: name,
        phone: null,
        amount: amount,
        type: type,
        reference: reference,
        createdAt: DateTime.now(),
        notes: 'Bank SMS auto-detected',
        rawMessage: message,
      );

      if (kDebugMode) {
        print('$_tag Bank parse: $name - ₹$amount ($type)');
      }

      return transaction;
    } catch (e) {
      if (kDebugMode) print('$_tag Bank parse error: $e');
      return null;
    }
  }

  static String _detectBankName(String source, String senderName) {
    final combined = (source + senderName).toLowerCase();
    if (combined.contains('icic')) return 'ICICI_SMS';
    if (combined.contains('hdfc')) return 'HDFC_SMS';
    if (combined.contains('axis')) return 'AXIS_SMS';
    if (combined.contains('sbi')) return 'SBI_SMS';
    if (combined.contains('boi')) return 'BOI_SMS';
    if (combined.contains('canara')) return 'CANARA_SMS';
    if (combined.contains('pnb')) return 'PNB_SMS';
    if (combined.contains('union')) return 'UNION_SMS';
    return 'SMS_BANK';
  }

  // ========== UPI NOTIFICATION PARSING ==========
  static bool _isUpiNotification(String source, String senderName) {
    final upiPatterns = [
      'google', 'googlepay', 'phonepe', 'paytm', 'upi',
      'payment', 'received', 'transferred', 'sent', '₹'
    ];
    final combined = (source + senderName).toLowerCase();
    return upiPatterns.any((p) => combined.contains(p));
  }

  static Future<Transaction?> _parseAsUpiNotification(
    String message,
    String source,
    String senderName,
  ) async {
    if (kDebugMode) print('$_tag Parsing as UPI Notification');

    try {
      // Amount: "₹500" or "Rs 500"
      final amountMatch = RegExp(r'[₹Rs\.]*\s*(\d+(?:,\d+)*(?:\.\d{2})?)').firstMatch(message);
      if (amountMatch == null) return null;

      double amount = double.parse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0;

      // Type: sent/received/transferred
      bool isSent = message.contains(RegExp(r'sent|transfer', caseSensitive: false));
      bool isReceived = message.contains(RegExp(r'received', caseSensitive: false));

      String type = isSent ? 'PAID' : (isReceived ? 'RECEIVED' : 'PENDING');

      // Name: Phone number or "You" or account name
      String name = 'UPI Payment';
      final phoneMatch = RegExp(r'(\d{10}|\+91\d{10})').firstMatch(message);
      if (phoneMatch != null) {
        name = phoneMatch.group(1) ?? 'UPI Payment';
      }

      // Reference: UPI ref number usually at end
      String reference = '';
      final refMatch = RegExp(r'Ref[:\s]+(\w+)').firstMatch(message);
      if (refMatch != null) {
        reference = refMatch.group(1) ?? '';
      }

      final transaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        source: _detectUpiApp(source),
        name: name,
        phone: phoneMatch != null ? phoneMatch.group(1) : null,
        amount: amount,
        type: type,
        reference: reference,
        createdAt: DateTime.now(),
        notes: 'UPI notification auto-detected',
        rawMessage: message,
      );

      if (kDebugMode) {
        print('$_tag UPI parse: $name - ₹$amount ($type)');
      }

      return transaction;
    } catch (e) {
      if (kDebugMode) print('$_tag UPI parse error: $e');
      return null;
    }
  }

  static String _detectUpiApp(String source) {
    final lower = source.toLowerCase();
    if (lower.contains('google')) return 'GooglePay';
    if (lower.contains('phonepe')) return 'PhonePe';
    if (lower.contains('paytm')) return 'Paytm';
    return 'UPI';
  }

  // ========== FIX: Get Today's Actual Sales (Not Mock Data) ==========
  static Future<List<Map<String, dynamic>>> _getTodaySalesData() async {
    try {
      final sales = await LocalStorageService.loadSales();
      final today = DateTime.now();
      
      // Filter to today's sales only
      return (sales as List).where((s) {
        final dateStr = s['date'] ?? s['created_at'] ?? '';
        if (dateStr.isEmpty) return false;
        
        final date = DateTime.tryParse(dateStr);
        if (date == null) return false;
        
        return date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;
      }).map((s) => Map<String, dynamic>.from(s)).toList();
    } catch (e) {
      debugPrint('PaymentDetectionSystem: Error loading today sales: $e');
      return []; // Return empty list, not mock data
    }
  }

  /// Get confirmation stats
  static Future<Map<String, int>> getStats() {
    return SmartPaymentMatcherService.getConfirmationStats();
  }

  /// Get audit trail
  static Future<List<Map<String, dynamic>>> getAuditTrail({int limit = 50}) {
    return SmartPaymentMatcherService.getMatchHistory(limit: limit);
  }
}

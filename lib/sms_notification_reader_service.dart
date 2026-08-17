import 'dart:io';
import 'package:flutter/foundation.dart';
import 'transaction_service.dart';

/// SMS Notification Reader Service
/// Reads SMS messages and payment app notifications to extract transactions
class SmsNotificationReaderService {
  static const String _tag = '📱 SMS_READER';

  /// Parse SMS message and create transaction if it's a payment
  static Future<Transaction?> parseAndSaveFromSms(String smsBody, String senderAddress) async {
    try {
      if (kDebugMode) print('$_tag Parsing: $smsBody from $senderAddress');

      // Check if it's a bank SMS (typically from short codes like 9000, 9898, etc.)
      if (_isBankSms(senderAddress)) {
        final txn = TransactionService.parseSmsBanking(smsBody);
        if (txn != null) {
          await TransactionService.saveTransaction(txn);
          if (kDebugMode) print('$_tag ✅ Bank transaction saved: ${txn.name} - ₹${txn.amount}');
          return txn;
        }
      }

      // Check if it's a UPI app notification (Google Pay, PhonePe, Paytm, etc.)
      if (_isUpiNotification(senderAddress)) {
        // Payment app notification bodies
        final source = _detectPaymentApp(senderAddress);
        final txn = TransactionService.parseUpiNotification(smsBody, source);
        if (txn != null) {
          await TransactionService.saveTransaction(txn);
          if (kDebugMode) print('$_tag ✅ UPI transaction saved: ${txn.name} - ₹${txn.amount}');
          return txn;
        }
      }

      if (kDebugMode) print('$_tag ⚠️ Could not parse: $smsBody');
      return null;
    } catch (e) {
      if (kDebugMode) print('$_tag ❌ Error: $e');
      return null;
    }
  }

  /// Check if SMS is from a bank
  static bool _isBankSms(String sender) {
    final bankPatterns = [
      'bank',
      'hdfc',
      'icic',
      'axis',
      'sbi',
      'boi',
      'canara',
      'pnb',
      'union',
      '5555', // Common bank short code
      '9999',
      '9898',
      'alert',
      'txn',
    ];
    final lowerSender = sender.toLowerCase();
    return bankPatterns.any((pattern) => lowerSender.contains(pattern));
  }

  /// Check if SMS is from a UPI/payment app
  static bool _isUpiNotification(String sender) {
    final upiPatterns = [
      'google',
      'googlepay',
      'phonepe',
      'paytm',
      'phonepeapp',
      'upi',
      'payment',
      'received',
      'transferred',
      '₹',
    ];
    final lowerSender = sender.toLowerCase();
    return upiPatterns.any((pattern) => lowerSender.contains(pattern));
  }

  /// Detect which payment app sent the notification
  static String _detectPaymentApp(String sender) {
    final lowerSender = sender.toLowerCase();
    if (lowerSender.contains('google') || lowerSender.contains('googlepay')) {
      return 'GooglePay';
    } else if (lowerSender.contains('phonepe')) {
      return 'PhonePe';
    } else if (lowerSender.contains('paytm')) {
      return 'Paytm';
    }
    return 'UPI';
  }

  /// Batch parse multiple SMS messages
  static Future<List<Transaction>> parseMultipleSms(
    List<Map<String, String>> smsList,
  ) async {
    final transactions = <Transaction>[];
    for (var sms in smsList) {
      final sender = sms['sender'] ?? '';
      final body = sms['body'] ?? '';
      
      if (sender.isNotEmpty && body.isNotEmpty) {
        final txn = await parseAndSaveFromSms(body, sender);
        if (txn != null) {
          transactions.add(txn);
        }
      }
    }
    return transactions;
  }

  /// Get today's transactions from SMS history
  static Future<double> getTodayTransactionTotal() async {
    return await TransactionService.getTodayTotal();
  }

  /// Parse a raw WhatsApp message text
  static Future<Transaction?> parseWhatsAppMessage(
    String message,
    String senderName,
    String? senderPhone,
  ) async {
    try {
      if (kDebugMode) print('$_tag Parsing WhatsApp: "$message" from $senderName');

      // Pattern: "sent ₹500" or "paid ₹1000"
      final amountRegex = RegExp(r'₹\s*([\d,]+\.?\d*)');
      final amountMatch = amountRegex.firstMatch(message);
      
      if (amountMatch == null) return null;

      double amount = double.parse(amountMatch.group(1)!.replaceAll(',', ''));

      final type = message.toLowerCase().contains('received') ? 'RECEIVED' : 'PAID';

      final txn = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        source: 'WhatsApp',
        name: senderName,
        phone: senderPhone,
        amount: amount,
        type: type,
        createdAt: DateTime.now(),
        rawMessage: message,
      );

      await TransactionService.saveTransaction(txn);
      if (kDebugMode) print('$_tag ✅ WhatsApp transaction saved: $senderName - ₹$amount');
      return txn;
    } catch (e) {
      if (kDebugMode) print('$_tag ❌ WhatsApp parse error: $e');
      return null;
    }
  }
}

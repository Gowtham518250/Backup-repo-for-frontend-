import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'local_storage_service.dart';
import 'sync_service.dart';  // ✅ Added for getAuthoritativeTime()

/// Transaction type classification
enum TransactionType {
  confirmed,      // Real payment (SMS + bank verified, UTR present)
  partial,        // Partial payment (e.g., ₹750 of ₹1000 bill)
  likely,         // Probable payment (notification-only, no SMS confirmation)
  wallet_credit,  // Cashback/wallet load (NOT to be counted in revenue)
  pending,        // Payment initiated but not settled
  failed,         // Transaction failed or reversed
}

/// Transaction model
class Transaction {
  final String id;
  final String source; // SMS, UPI, Manual, WhatsApp, etc.
  final String? name;
  final String? phone;
  final double amount;
  final String type; // PAID, RECEIVED, PENDING (legacy), or use transactionType
  final TransactionType? transactionType; // New enum classification
  final String? reference; // Transaction ID from payment app
  final DateTime createdAt;
  final String? notes;
  final String? rawMessage;
  final bool isCashback; // Explicitly mark cashback to exclude from revenue
  final bool isWalletCredit; // Wallet top-up, not merchant revenue

  Transaction({
    required this.id,
    required this.source,
    this.name,
    this.phone,
    required this.amount,
    required this.type,
    this.transactionType = TransactionType.pending,
    this.reference,
    required this.createdAt,
    this.notes,
    this.rawMessage,
    this.isCashback = false,
    this.isWalletCredit = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'name': name,
    'phone': phone,
    'amount': amount, // Store as double — avoids locale-specific string parse errors
    'type': type,
    'transaction_type': transactionType?.toString(),
    'reference': reference,
    'created_at': createdAt.toIso8601String(),
    'notes': notes,
    'raw_message': rawMessage,
    'is_cashback': isCashback,
    'is_wallet_credit': isWalletCredit,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final txnTypeStr = json['transaction_type'] as String?;
    TransactionType? txnType;
    if (txnTypeStr != null) {
      // Handle both 'confirmed' and 'TransactionType.confirmed' formats
      final name = txnTypeStr.contains('.') ? txnTypeStr.split('.').last : txnTypeStr;
      try {
        txnType = TransactionType.values.byName(name);
      } catch (e) {
        // Leave null if unrecognized
      }
    }
    return Transaction(
      id: json['id'] as String,
      source: json['source'] as String? ?? 'Manual',
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      type: json['type'] as String? ?? 'PENDING',
      transactionType: txnType,
      reference: json['reference'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      notes: json['notes'] as String?,
      rawMessage: json['raw_message'] as String?,
      isCashback: json['is_cashback'] as bool? ?? false,
      isWalletCredit: json['is_wallet_credit'] as bool? ?? false,
    );
  }
}

/// Transaction Service - Handle storage and parsing
class TransactionService {
  static const String _transactionKey = 'transactions_v1';
  static const String _lastSyncKey = 'transactions_last_sync';

  /// Load all transactions
  static Future<List<Transaction>> loadTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_transactionKey) ?? '[]';
      final decoded = json.decode(raw) as List;
      return decoded
          .map((t) => Transaction.fromJson(t as Map<String, dynamic>))
          .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      if (kDebugMode) print('❌ Error loading transactions: $e');
      return [];
    }
  }

  /// Save transaction
  static Future<void> saveTransaction(Transaction txn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final transactions = await loadTransactions();
      
      // Deduplication: don't save if same reference exists
      if (txn.reference != null && transactions.any((t) => t.reference == txn.reference)) {
        if (kDebugMode) print('⚠️ Transaction already exists: ${txn.reference}');
        return;
      }

      transactions.insert(0, txn);
      final encoded = json.encode(transactions.map((t) => t.toJson()).toList());
      await prefs.setString(_transactionKey, encoded);
      
      if (kDebugMode) print('✅ Transaction saved: ${txn.name} - ₹${txn.amount}');
    } catch (e) {
      if (kDebugMode) print('❌ Error saving transaction: $e');
    }
  }

  /// Save multiple transactions
  static Future<void> saveTransactions(List<Transaction> txns) async {
    for (var txn in txns) {
      await saveTransaction(txn);
    }
  }

  /// Parse UPI notification (Google Pay, PhonePe, Paytm format)
  static Transaction? parseUpiNotification(String message, String source) {
    try {
      // Common formats:
      // "₹500 transferred to 8765432109"
      // "Payment received from Rahul - ₹1000"
      // "₹250 received to UPI ID"

      final amountRegex = RegExp(r'₹\s*([\d,]+\.?\d*)');
      final amountMatch = amountRegex.firstMatch(message);
      if (amountMatch == null) return null;

      double amount = double.parse(amountMatch.group(1)!.replaceAll(',', ''));

      // Extract phone/name pattern
      String? phone;
      String? name;

      // Pattern: "to 8765432109" or "from 8765432109"
      final phoneRegex = RegExp(r'(?:to|from|received from)\s*([0-9]{10})');
      final phoneMatch = phoneRegex.firstMatch(message);
      if (phoneMatch != null) {
        phone = phoneMatch.group(1);
      }

      // Pattern: "from Name" or "to Name"
      final nameRegex = RegExp(r'(?:from|to)\s+([A-Za-z\s]+)[\s-₹]');
      final nameMatch = nameRegex.firstMatch(message);
      if (nameMatch != null) {
        name = nameMatch.group(1)?.trim();
      }

      final type = message.toLowerCase().contains('received') ? 'RECEIVED' : 'PAID';

      return Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        source: source,
        name: name,
        phone: phone,
        amount: amount,
        type: type,
        reference: '$source-${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
        rawMessage: message,
      );
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to parse UPI: $e');
      return null;
    }
  }

  /// Parse SMS transaction (Bank notification)
  static Transaction? parseSmsBanking(String message) {
    try {
      // Format: "A/C xx1234 Debit ₹500 to MERCHANT SHOP - Ref: TXN123"
      // Format: "A/C xx1234 Credit ₹1000 from CUSTOMER"

      final amountRegex = RegExp(r'₹\s*([\d,]+\.?\d*)');
      final amountMatch = amountRegex.firstMatch(message);
      if (amountMatch == null) return null;

      double amount = double.parse(amountMatch.group(1)!.replaceAll(',', ''));

      final type = message.toLowerCase().contains('debit') ? 'PAID' : 'RECEIVED';

      // Extract name
      String? name;
      final nameRegex = RegExp(r'(?:to|from)\s+([A-Za-z\s]+)[\s-]');
      final nameMatch = nameRegex.firstMatch(message);
      if (nameMatch != null) {
        name = nameMatch.group(1)?.trim();
      }

      // Extract reference
      String? reference;
      final refRegex = RegExp(r'Ref\s*:\s*([A-Z0-9]+)');
      final refMatch = refRegex.firstMatch(message);
      if (refMatch != null) {
        reference = refMatch.group(1);
      }

      return Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        source: 'SMS_BANK',
        name: name,
        amount: amount,
        type: type,
        reference: reference,
        createdAt: DateTime.now(),
        rawMessage: message,
      );
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to parse SMS: $e');
      return null;
    }
  }

  /// Get today's transactions sum (excludes wallet credits and cashback)
  static Future<double> getTodayTotal() async {
    final txns = await loadTransactions();
    final now = DateTime.now();
    return txns
        .where((t) =>
            t.createdAt.year == now.year &&
            t.createdAt.month == now.month &&
            t.createdAt.day == now.day &&
            !t.isCashback &&
            !t.isWalletCredit)
        .fold(0.0, (sum, t) => sum + (t.amount ?? 0.0)) as double;
  }

  /// Get today's revenue (confirmed + partial payments only)
  static Future<double> getTodayRevenue() async {
    final txns = await loadTransactions();
    
    // ✅ FIX: Use server time instead of device time (prevents fraud)
    final now = await SyncService.getAuthoritativeTime();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    
    return txns
        .where((t) =>
            t.createdAt.isAfter(todayStart) &&
            t.createdAt.isBefore(todayEnd) &&
            (t.transactionType == TransactionType.confirmed ||
             t.transactionType == TransactionType.partial) &&
            !t.isCashback &&
            !t.isWalletCredit)
        .fold(0.0, (sum, t) => sum + t.amount) as double;
  }

  /// Get transactions by date range
  static Future<List<Transaction>> getTransactionsByRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final txns = await loadTransactions();
    return txns
        .where((t) => t.createdAt.isAfter(startDate) && t.createdAt.isBefore(endDate))
        .toList();
  }

  /// Delete transaction
  static Future<void> deleteTransaction(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final txns = await loadTransactions();
      txns.removeWhere((t) => t.id == id);
      final encoded = json.encode(txns.map((t) => t.toJson()).toList());
      await prefs.setString(_transactionKey, encoded);
      if (kDebugMode) print('✅ Transaction deleted: $id');
    } catch (e) {
      if (kDebugMode) print('❌ Error deleting transaction: $e');
    }
  }

  /// Update transaction — atomic in-place replace to avoid data loss
  static Future<void> updateTransaction(Transaction txn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final txns = await loadTransactions();
      final idx = txns.indexWhere((t) => t.id == txn.id);
      if (idx >= 0) {
        txns[idx] = txn; // replace in-place
      } else {
        txns.add(txn); // not found — append
      }
      final encoded = json.encode(txns.map((t) => t.toJson()).toList());
      await prefs.setString(_transactionKey, encoded);
      if (kDebugMode) print('✅ Transaction updated: ${txn.id}');
    } catch (e) {
      if (kDebugMode) print('❌ Error updating transaction: $e');
    }
  }
}

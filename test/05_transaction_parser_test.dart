import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/transaction_service.dart';

void main() {
  group('P1 Payment/transaction parsing', () {
    test('UPI notification extracts amount', () {
      final txn = TransactionService.parseUpiNotification(
        'Payment received from Rahul - ₹1,250',
        'UPI',
      );

      expect(txn, isNotNull);
      expect(txn!.amount, 1250);
    });

    test('UPI notification with no amount is rejected', () {
      final txn = TransactionService.parseUpiNotification(
        'Payment received successfully',
        'UPI',
      );

      expect(txn, isNull);
    });

    test('wallet/cashback flags are preserved in model serialization', () {
      final txn = Transaction(
        id: 'T1',
        source: 'UPI',
        amount: 50,
        type: 'RECEIVED',
        createdAt: DateTime.utc(2026, 8, 13),
        isCashback: true,
      );

      final json = txn.toJson();

      expect(json['is_cashback'], isTrue);
      expect(json['amount'], 50);
    });
  });
}

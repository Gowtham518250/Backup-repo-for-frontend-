import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/analytics_engine.dart';

void main() {
  final engine = AnalyticsEngine();

  group('P1 Product-name safety', () {
    test('common Indian retail names are real products', () {
      for (final name in [
        'Aashirvaad Atta',
        'Parle-G Biscuits',
        'Tata Salt',
        'Coca Cola 750ml',
        'Amul Milk',
        'Fortune Oil',
        'Bru Coffee',
        'Colgate 200g',
        'Britannia Bread',
        'Surf Excel',
        'Dettol Soap',
        'Thums Up',
        'Sprite',
        'Maggi Noodles',
        'Dove Soap',
        'Red Label Tea',
        'India Gate Basmati Rice',
        'Good Day Biscuits',
        'Clinic Plus Shampoo',
        'Lifebuoy Soap',
      ]) {
        expect(engine.isPlaceholderProductName(name), isFalse, reason: name);
      }
    });

    test('generated identity-like values are placeholders', () {
      for (final name in [
        'sale-1',
        'sale_2',
        'invoice_3',
        'transaction_4',
        'SALE-999',
        'INVOICE_999',
        'transaction-xyz',
      ]) {
        expect(engine.isPlaceholderProductName(name), isTrue, reason: name);
      }
    });

    test('normal user-entered labels are not placeholders', () {
      for (final name in [
        'Rice',
        'Oil',
        'Milk 1L',
        'Biscuit Packet',
        'Soap',
        'Pen',
        'Notebook',
        'Battery',
        'Tea Powder',
        'Sugar',
      ]) {
        expect(engine.isPlaceholderProductName(name), isFalse, reason: name);
      }
    });

    test('detector is deterministic', () {
      for (var i = 0; i < 100; i++) {
        expect(engine.isPlaceholderProductName('Aashirvaad Atta'), isFalse);
        expect(engine.isPlaceholderProductName('sale-17'), isTrue);
      }
    });

    test('case variations remain consistent for known placeholders', () {
      expect(engine.isPlaceholderProductName('sale-17'), isTrue);
      expect(engine.isPlaceholderProductName('SALE-17'), isTrue);
      expect(engine.isPlaceholderProductName('Sale-17'), isTrue);
    });

    test('empty value does not crash', () {
      expect(
        () => engine.isPlaceholderProductName(''),
        returnsNormally,
      );
    });

    test('whitespace-only value does not crash', () {
      expect(
        () => engine.isPlaceholderProductName('   '),
        returnsNormally,
      );
    });

    test('real product numbers do not automatically become placeholders', () {
      for (final name in [
        'Coca Cola 750ml',
        'Milk 1L',
        'Rice 5kg',
        'Soap 125g',
        'Oil 1L',
      ]) {
        expect(engine.isPlaceholderProductName(name), isFalse);
      }
    });
  });
}

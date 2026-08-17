import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/analytics_engine.dart';

void main() {
  group('P0/P1 Analytics integrity', () {
    test('placeholder product names are detected', () {
      final engine = AnalyticsEngine();

      expect(engine.isPlaceholderProductName('Product'), isTrue);
      expect(engine.isPlaceholderProductName('Unknown'), isTrue);
      expect(engine.isPlaceholderProductName('sale_123'), isTrue);
      expect(engine.isPlaceholderProductName('invoice_77'), isTrue);
      expect(engine.isPlaceholderProductName('Aashirvaad Atta'), isFalse);
    });

    test('same sale data produces expected lifetime totals', () {
      final engine = AnalyticsEngine();

      engine.recalculateAnalytics([
        {
          'sale_id': 'SALE-1',
          'business_date': '2026-08-13T10:00:00Z',
          'total': 10,
          'items': [
            {
              'product_id': 1,
              'product_name': 'Rice',
              'quantity': 1,
              'price': 10,
            }
          ],
        },
        {
          'sale_id': 'SALE-2',
          'business_date': '2026-08-13T11:00:00Z',
          'total': 20,
          'items': [
            {
              'product_id': 2,
              'product_name': 'Oil',
              'quantity': 1,
              'price': 20,
            }
          ],
        },
      ], 0);

      expect(engine.totalSales, 30);
      expect(engine.totalTransactions, 2);
    });

    test('four line items remain attached to one sale', () {
      final engine = AnalyticsEngine();

      engine.recalculateAnalytics([
        {
          'sale_id': 'SALE-4',
          'business_date': '2026-08-13T12:00:00Z',
          'total': 100,
          'items': [
            {'product_id': 1, 'product_name': 'A', 'quantity': 1, 'price': 10},
            {'product_id': 2, 'product_name': 'B', 'quantity': 1, 'price': 20},
            {'product_id': 3, 'product_name': 'C', 'quantity': 1, 'price': 30},
            {'product_id': 4, 'product_name': 'D', 'quantity': 1, 'price': 40},
          ],
        },
      ], 0);

      expect(engine.totalSales, 100);
      expect(engine.totalTransactions, 1);
    });
  });
}

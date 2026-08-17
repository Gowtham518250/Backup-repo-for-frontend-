import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/analytics_engine.dart';
import 'package:retail_mind/sales_dedup_helper.dart';

void main() {
  group('P1 Product naming regression', () {
    test('real product names are not placeholder values', () {
      final engine = AnalyticsEngine();

      for (final name in [
        'Aashirvaad Atta',
        'Parle-G Biscuits',
        'Tata Salt',
        'Coca Cola 750ml',
      ]) {
        expect(engine.isPlaceholderProductName(name), isFalse);
      }
    });

    test('sale and invoice IDs are not used as product names by placeholder detector', () {
      final engine = AnalyticsEngine();

      expect(engine.isPlaceholderProductName('sale-17'), isTrue);
      expect(engine.isPlaceholderProductName('sale_17'), isTrue);
      expect(engine.isPlaceholderProductName('invoice_17'), isTrue);
      expect(engine.isPlaceholderProductName('transaction_17'), isTrue);
    });

    test('identical content fingerprints are deterministic', () {
      final sale = {
        'business_date': '2026-08-13',
        'total': 50,
        'items': [
          {
            'product_name': 'Rice',
            'qty': 1,
            'price': 50,
          }
        ],
      };

      final fp1 = SalesDedupHelper.billContentFingerprint(sale);
      final fp2 = SalesDedupHelper.billContentFingerprint(
        Map<String, dynamic>.from(sale),
      );

      expect(fp1, fp2);
    });
  });
}

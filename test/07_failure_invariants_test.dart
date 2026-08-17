import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/sales_dedup_helper.dart';
import 'package:retail_mind/sale_service.dart';

void main() {
  group('Production financial invariants', () {
    test('one stable sale identity maps to one logical sale', () {
      final sales = [
        {
          'sale_id': 'SAME-1',
          'offline_id': 'SAME-1',
          'total': 100,
          'items': [
            {'product_name': 'A', 'qty': 1, 'price': 100}
          ],
        },
        {
          'sale_id': 'SAME-1',
          'offline_id': 'SAME-1',
          'total': 100,
          'items': [
            {'product_name': 'A', 'qty': 1, 'price': 100}
          ],
        },
      ];

      expect(SalesDedupHelper.dedupeBills(sales).length, 1);
    });

    test('different sale identities are never collapsed by content alone', () {
      final sales = [
        {
          'sale_id': 'SALE-A',
          'offline_id': 'SALE-A',
          'total': 100,
          'items': [
            {'product_name': 'A', 'qty': 1, 'price': 100}
          ],
        },
        {
          'sale_id': 'SALE-B',
          'offline_id': 'SALE-B',
          'total': 100,
          'items': [
            {'product_name': 'A', 'qty': 1, 'price': 100}
          ],
        },
      ];

      expect(SalesDedupHelper.dedupeBills(sales).length, 2);
    });

    test('financial state obeys paid + outstanding = grand total conceptually', () {
      const total = 100.0;
      const paid = 70.0;
      final outstanding = total - paid;

      expect(outstanding, 30);
      expect(SaleService.paymentStatusFor(paid, total), 'PARTIAL');
    });
  });
}

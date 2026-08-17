import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/sales_dedup_helper.dart';

void main() {
  group('P0 Restore line grouping', () {
    test('multiple backend line rows become one bill with multiple items', () {
      final result = SalesDedupHelper.groupApiLinesIntoBills([
        {
          'sale_id': 'INV-1',
          'product_name': 'Rice',
          'quantity': 1,
          'price': 50,
          'total': 50,
          'sale_date': '2026-08-13T10:00:00Z',
        },
        {
          'sale_id': 'INV-1',
          'product_name': 'Oil',
          'quantity': 2,
          'price': 25,
          'total': 50,
          'sale_date': '2026-08-13T10:00:00Z',
        },
      ]);

      expect(result.length, 1);
      expect(result.single['sale_id'], 'INV-1');
      final items = result.single['items'] as List;
      expect(items.length, 2);
      expect(result.single['total'], 100.0);
    });

    test('different sale IDs remain separate bills even with identical content', () {
      final result = SalesDedupHelper.groupApiLinesIntoBills([
        {
          'sale_id': 'INV-1',
          'product_name': 'Rice',
          'quantity': 1,
          'price': 50,
          'total': 50,
        },
        {
          'sale_id': 'INV-2',
          'product_name': 'Rice',
          'quantity': 1,
          'price': 50,
          'total': 50,
        },
      ]);

      expect(result.length, 2);
      expect(result.map((e) => e['sale_id']).toSet(),
          containsAll(<String>{'INV-1', 'INV-2'}));
    });
  });
}

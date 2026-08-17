import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/sales_dedup_helper.dart';

Map<String, dynamic> sale({
  required String id,
  double total = 100,
  String product = 'Rice',
  String date = '2026-08-14',
}) {
  return {
    'sale_id': id,
    'offline_id': id,
    'transaction_key': id,
    'business_date': date,
    'total': total,
    'items': [
      {'product_name': product, 'qty': 1, 'price': total},
    ],
  };
}

void main() {
  group('P0 Sales dedup deployment suite', () {
    test('duplicate stable identity collapses to one logical bill', () {
      final rows = [
        sale(id: 'SALE-1'),
        sale(id: 'SALE-1'),
        sale(id: 'SALE-1'),
      ];
      expect(SalesDedupHelper.dedupeBills(rows), hasLength(1));
    });

    test('different stable identities remain separate even when content is identical', () {
      final rows = [
        sale(id: 'SALE-A'),
        sale(id: 'SALE-B'),
        sale(id: 'SALE-C'),
      ];
      expect(SalesDedupHelper.dedupeBills(rows), hasLength(3));
    });

    test('100 unique sales remain 100 bills', () {
      final rows = List.generate(100, (i) => sale(id: 'SALE-$i'));
      expect(SalesDedupHelper.dedupeBills(rows), hasLength(100));
    });

    test('500 unique sales remain 500 bills', () {
      final rows = List.generate(500, (i) => sale(id: 'SALE-$i'));
      expect(SalesDedupHelper.dedupeBills(rows), hasLength(500));
    });

    test('duplicate storm does not multiply revenue-bearing records', () {
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < 50; i++) {
        for (var j = 0; j < 10; j++) {
          rows.add(sale(id: 'SALE-$i', total: 10 + i.toDouble()));
        }
      }
      expect(SalesDedupHelper.dedupeBills(rows), hasLength(50));
    });

    test('same content fingerprint is stable across equal maps', () {
      final a = sale(id: 'A', total: 50, product: 'Milk');
      final b = sale(id: 'A', total: 50, product: 'Milk');
      expect(
        SalesDedupHelper.billContentFingerprint(a),
        SalesDedupHelper.billContentFingerprint(b),
      );
    });

    test('different totals change the fingerprint', () {
      final a = sale(id: 'A', total: 50);
      final b = sale(id: 'A', total: 60);
      expect(
        SalesDedupHelper.billContentFingerprint(a),
        isNot(SalesDedupHelper.billContentFingerprint(b)),
      );
    });

    test('different products change the fingerprint', () {
      final a = sale(id: 'A', product: 'Rice');
      final b = sale(id: 'A', product: 'Oil');
      expect(
        SalesDedupHelper.billContentFingerprint(a),
        isNot(SalesDedupHelper.billContentFingerprint(b)),
      );
    });

    test('rapid repeated sales with identical values remain distinct when IDs differ', () {
      final rows = List.generate(
        20,
        (i) => sale(id: 'RAPID-$i', total: 100, product: 'Rice'),
      );
      expect(SalesDedupHelper.dedupeBills(rows), hasLength(20));
    });

    test('offline and server copies sharing identity dedupe safely', () {
      final rows = [
        sale(id: 'OFFLINE-123'),
        sale(id: 'OFFLINE-123'),
      ];
      expect(SalesDedupHelper.dedupeBills(rows), hasLength(1));
    });

    test('same identity with changed server amount still remains one logical bill', () {
      final rows = [
        sale(id: 'SYNC-1', total: 100),
        sale(id: 'SYNC-1', total: 105),
      ];
      expect(SalesDedupHelper.dedupeBills(rows), hasLength(1));
    });

    test('different date alone does not merge different identities', () {
      final rows = [
        sale(id: 'D1', date: '2026-08-13'),
        sale(id: 'D2', date: '2026-08-14'),
      ];
      expect(SalesDedupHelper.dedupeBills(rows), hasLength(2));
    });

    test('all generated identities are preserved', () {
      final rows = List.generate(250, (i) {
        return sale(id: 'ID-${i.toString().padLeft(4, '0')}', total: i + 1.0);
      });
      final result = SalesDedupHelper.dedupeBills(rows);
      expect(result.length, rows.length);
      final ids = result.map((e) => e['sale_id']).toSet();
      expect(ids.length, rows.length);
    });

    test('content fingerprint is deterministic across repeated calls', () {
      final s = sale(id: 'DET-1', total: 123.45, product: 'Aashirvaad Atta');
      final values = List.generate(
        50,
        (_) => SalesDedupHelper.billContentFingerprint(s),
      );
      expect(values.toSet(), hasLength(1));
    });

    test('invoice-style identities are supported as normal stable identifiers', () {
      final rows = [
        {...sale(id: 'INV-1001'), 'invoice_number': 'INV-1001'},
        {...sale(id: 'INV-1002'), 'invoice_number': 'INV-1002'},
      ];
      expect(SalesDedupHelper.dedupeBills(rows), hasLength(2));
    });

    test('sale IDs with punctuation remain stable identifiers', () {
      final rows = [
        sale(id: 'SALE/2026/08/14-001'),
        sale(id: 'SALE/2026/08/14-002'),
      ];
      expect(SalesDedupHelper.dedupeBills(rows), hasLength(2));
    });

    test('zero-value sale is not silently merged with a different identity', () {
      final rows = [
        sale(id: 'ZERO-A', total: 0),
        sale(id: 'ZERO-B', total: 0),
      ];
      expect(SalesDedupHelper.dedupeBills(rows), hasLength(2));
    });

    test('fractional amounts retain distinct fingerprints', () {
      final a = sale(id: 'F1', total: 10.01);
      final b = sale(id: 'F2', total: 10.02);
      expect(
        SalesDedupHelper.billContentFingerprint(a),
        isNot(SalesDedupHelper.billContentFingerprint(b)),
      );
    });

    test('customer-visible product changes cannot be hidden by same total', () {
      final rows = [
        sale(id: 'P1', product: 'Tata Salt', total: 20),
        sale(id: 'P2', product: 'Aashirvaad Atta', total: 20),
      ];
      expect(SalesDedupHelper.dedupeBills(rows), hasLength(2));
    });

    test('large duplicate batch stays bounded', () {
      final rows = <Map<String, dynamic>>[];
      for (var id = 0; id < 200; id++) {
        for (var copy = 0; copy < 20; copy++) {
          rows.add(sale(id: 'B$id', total: id + 0.5));
        }
      }
      expect(SalesDedupHelper.dedupeBills(rows), hasLength(200));
    });

    test('idempotent deduplication produces the same cardinality twice', () {
      final rows = List.generate(100, (i) => sale(id: i.isEven ? 'X' : 'Y'));
      final first = SalesDedupHelper.dedupeBills(rows);
      final second = SalesDedupHelper.dedupeBills(first);
      expect(first.length, second.length);
    });
  });
}

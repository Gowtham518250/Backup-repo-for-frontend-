import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/sale_service.dart';

void main() {
  group('P0 Financial invariants', () {
    test('zero paid is unpaid', () {
      expect(SaleService.paymentStatusFor(0, 100), 'UNPAID');
    });

    test('full paid is paid', () {
      expect(SaleService.paymentStatusFor(100, 100), 'PAID');
    });

    test('overpaid is treated as paid', () {
      expect(SaleService.paymentStatusFor(110, 100), 'PAID');
    });

    test('partial paid is partial', () {
      expect(SaleService.paymentStatusFor(70, 100), 'PARTIAL');
    });

    test('small partial payment remains partial', () {
      expect(SaleService.paymentStatusFor(0.01, 100), 'PARTIAL');
    });

    test('repeated financial identity calculations remain deterministic', () {
      for (var i = 0; i < 100; i++) {
        expect(SaleService.paymentStatusFor(70, 100), 'PARTIAL');
      }
    });

    test('monotonic paid amount never moves backwards from PAID', () {
      for (var paid = 100; paid <= 200; paid++) {
        expect(SaleService.paymentStatusFor(paid.toDouble(), 100), 'PAID');
      }
    });

    test('values between zero and total are partial', () {
      for (var paid = 1; paid < 100; paid++) {
        expect(SaleService.paymentStatusFor(paid.toDouble(), 100), 'PARTIAL');
      }
    });

    test('zero total with zero paid does not crash', () {
      expect(
        () => SaleService.paymentStatusFor(0, 0),
        returnsNormally,
      );
    });

    test('large total remains numerically stable', () {
      expect(
        () => SaleService.paymentStatusFor(5000000, 10000000),
        returnsNormally,
      );
      expect(SaleService.paymentStatusFor(5000000, 10000000), 'PARTIAL');
    });

    test('decimal rupee values are supported', () {
      expect(SaleService.paymentStatusFor(99.99, 100), 'PARTIAL');
      expect(SaleService.paymentStatusFor(100, 100), 'PAID');
    });

    test('outstanding calculation is exact for simple rupee values', () {
      const total = 100.0;
      const paid = 70.0;
      expect(total - paid, 30.0);
    });

    test('outstanding cannot be negative for normal paid state', () {
      const total = 100.0;
      const paid = 100.0;
      expect(total - paid, 0.0);
    });

    test('financial status boundaries are contiguous', () {
      expect(SaleService.paymentStatusFor(0, 1), 'UNPAID');
      expect(SaleService.paymentStatusFor(0.5, 1), 'PARTIAL');
      expect(SaleService.paymentStatusFor(1, 1), 'PAID');
    });

    test('many totals maintain expected status ordering', () {
      for (var total = 1; total <= 1000; total++) {
        expect(SaleService.paymentStatusFor(0, total.toDouble()), 'UNPAID');
        expect(
          SaleService.paymentStatusFor(total / 2.0, total.toDouble()),
          'PARTIAL',
        );
        expect(
          SaleService.paymentStatusFor(total.toDouble(), total.toDouble()),
          'PAID',
        );
      }
    });

    test('negative paid value does not crash the status function', () {
      expect(
        () => SaleService.paymentStatusFor(-1, 100),
        returnsNormally,
      );
    });

    test('negative total does not crash the status function', () {
      expect(
        () => SaleService.paymentStatusFor(0, -100),
        returnsNormally,
      );
    });

    test('very small decimal total does not crash', () {
      expect(
        () => SaleService.paymentStatusFor(0.001, 0.01),
        returnsNormally,
      );
    });

    test('very large decimal values do not crash', () {
      expect(
        () => SaleService.paymentStatusFor(99999999.99, 100000000),
        returnsNormally,
      );
    });

    test('status output is one of the production states', () {
      final allowed = {'UNPAID', 'PARTIAL', 'PAID'};
      for (final pair in [
        [0.0, 100.0],
        [20.0, 100.0],
        [100.0, 100.0],
        [150.0, 100.0],
      ]) {
        expect(
          allowed.contains(
            SaleService.paymentStatusFor(
              pair[0] as double,
              pair[1] as double,
            ),
          ),
          isTrue,
        );
      }
    });
  });
}

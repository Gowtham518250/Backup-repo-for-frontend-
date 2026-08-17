import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/sale_service.dart';

void main() {
  group('P0 Sale financial state', () {
    test('fully paid sale becomes PAID', () {
      expect(SaleService.paymentStatusFor(100, 100), 'PAID');
    });

    test('partial payment becomes PARTIAL', () {
      expect(SaleService.paymentStatusFor(30, 100), 'PARTIAL');
    });

    test('zero payment becomes UNPAID', () {
      expect(SaleService.paymentStatusFor(0, 100), 'UNPAID');
    });

    test('small floating point error does not create false outstanding balance', () {
      expect(SaleService.paymentStatusFor(99.995, 100), 'PAID');
    });

    test('real outstanding amount is not marked paid', () {
      expect(SaleService.paymentStatusFor(99, 100), 'PARTIAL');
    });
  });
}

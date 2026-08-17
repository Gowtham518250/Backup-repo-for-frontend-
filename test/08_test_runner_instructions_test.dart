import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Test suite inventory', () {
    const automatedFiles = [
      '01_sales_dedup_stress_test.dart',
      '02_financial_invariants_stress_test.dart',
      '03_product_name_regression_stress_test.dart',
      '04_voice_billing_regression_test.dart',
      '05_contract_level_stress_test.dart',
      '06_release_gate_checklist_test.dart',
    ];

    const manualFiles = [
      '07_manual_device_release_suite_test.dart',
    ];

    test('automated deployment suite is comprehensive', () {
      expect(automatedFiles.length, 6);
      expect(manualFiles.length, 1);
    });

    test('manual device suite is intentionally separated', () {
      expect(
        manualFiles.contains('07_manual_device_release_suite_test.dart'),
        isTrue,
      );
    });
  });
}

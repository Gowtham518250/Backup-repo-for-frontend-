import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'PAYMENT DETECTION: requires real Android notification/accessibility test',
    () {
      expect(true, isTrue);
    },
    skip: 'Run on a real Android device. Verify notification access, accessibility, background service, raw event reception, parser, deduplication, and invoice/Khata commit.',
  );
}

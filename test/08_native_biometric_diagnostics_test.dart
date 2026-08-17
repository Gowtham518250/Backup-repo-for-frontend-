import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'BIOMETRIC: requires real Android device/enrollment test',
    () {
      expect(true, isTrue);
    },
    skip: 'Run as a manual device test: enrolled fingerprint, no enrollment, PIN-only, release APK, and clear-app-data scenarios.',
  );
}

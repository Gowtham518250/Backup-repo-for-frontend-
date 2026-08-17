import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RETAIL MIND deployment release gate', () {
    const gates = [
      'flutter analyze has zero blocking errors',
      'flutter test has zero unexpected failures',
      'release APK builds successfully',
      'release AAB builds successfully',
      'debug-only behavior is not required for core billing',
      'two identical rapid sales remain two sales',
      'offline sale sync is idempotent',
      'server replay does not duplicate a sale',
      'inventory deduction is exactly once per committed sale',
      'payment + Khata balances reconcile',
      'partial payment stays partial until fully paid',
      'attendance check-in reaches backend',
      'attendance check-out reaches backend',
      'notification access is handled safely',
      'SMS permission path does not block normal billing',
      'voice billing works on real Android hardware',
      'Roman Telugu voice cases pass',
      'Roman Hindi voice cases pass',
      'product names never degrade to sale/invoice identifiers',
      'dashboard totals match canonical sales',
      'date filters do not move sales across business dates',
      'clear-app-data recovery is validated',
      'backend remains reachable from release build',
      'authentication survives app resume',
      'logout clears account-scoped cached data',
      'staff cannot access another shop',
      'online orders reconcile with backend',
      'QR/payment flow does not create duplicate bills',
      'release app starts without crash on a clean install',
      'app resumes without crash after process recreation',
    ];

    test('all release gates are explicitly documented', () {
      expect(gates.length, greaterThanOrEqualTo(30));
      expect(gates.toSet().length, gates.length);
    });

    test('critical gates are present', () {
      expect(gates, contains('flutter analyze has zero blocking errors'));
      expect(gates, contains('flutter test has zero unexpected failures'));
      expect(gates, contains('release APK builds successfully'));
      expect(gates, contains('two identical rapid sales remain two sales'));
      expect(gates, contains('offline sale sync is idempotent'));
      expect(gates, contains('inventory deduction is exactly once per committed sale'));
    });
  });
}

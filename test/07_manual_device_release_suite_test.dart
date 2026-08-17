import 'package:flutter_test/flutter_test.dart';

void main() {
  final manual = <String>[
    'Clean install: app launches to splash and reaches authentication without crash',
    'Already-authenticated launch: app reaches dashboard without crash',
    'Owner biometric: enrolled fingerprint succeeds',
    'Owner biometric: no biometric enrollment shows controlled fallback',
    'Owner biometric: PIN-only device remains usable',
    'Owner biometric: clear app data restores expected first-run state',
    'Payment detection: notification access enabled',
    'Payment detection: notification access denied',
    'Payment detection: background event is received',
    'Payment detection: duplicate notification does not duplicate sale',
    'Payment detection: valid payment updates invoice/Khata once',
    'Payment detection: malformed notification is ignored safely',
    'Voice billing: microphone permission granted',
    'Voice billing: microphone permission denied',
    'Voice billing: English locale',
    'Voice billing: Telugu locale',
    'Voice billing: Hindi locale',
    'Voice billing: Roman Telugu phrase',
    'Voice billing: Roman Hindi phrase',
    'Voice billing: mixed Telugu + English phrase',
    'Offline billing: create sale without network',
    'Offline billing: reconnect and sync exactly once',
    'Offline billing: repeated retry remains idempotent',
    'Inventory: one sale deducts stock once',
    'Inventory: duplicate sync does not deduct twice',
    'Khata: partial payment produces correct outstanding balance',
    'Khata: final payment clears outstanding balance',
    'Attendance: check-in reaches backend',
    'Attendance: check-out reaches backend',
    'Staff isolation: staff cannot access another shop',
    'Dashboard: today total matches canonical sales',
    'Dashboard: month total matches canonical sales',
    'Dashboard: online order total matches backend',
    'Dashboard: date filter does not cross local business date boundary',
    'Release APK: starts after install and process recreation',
    'Release APK: resumes after backgrounding',
    'Release APK: logout clears account-scoped local data',
  ];

  for (final scenario in manual) {
    test(
      'MANUAL DEVICE GATE: $scenario',
      () {},
      skip: 'Requires real Android device / release APK execution.',
    );
  }
}

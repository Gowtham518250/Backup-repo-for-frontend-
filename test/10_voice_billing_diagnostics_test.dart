import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'VOICE BILLING: requires real microphone/speech engine test',
    () {
      expect(true, isTrue);
    },
    skip: 'Run on a real Android device. Verify RECORD_AUDIO, speech engine, locale availability, recognized text, product matching, and sale creation.',
  );
}

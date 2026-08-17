import 'package:flutter_test/flutter_test.dart';
import '../lib/roman_indian_voice_normalizer.dart';

void main() {
  group('RomanIndianVoiceNormalizer', () {
    test('normalizes Roman Telugu quantity + unit + price', () {
      expect(RomanIndianVoiceNormalizer.normalize('rendu kilolu biyyam yaabhai'), '2 kg rice 50');
    });
    test('normalizes common STT unit spelling', () {
      expect(RomanIndianVoiceNormalizer.normalize('2 killolu rice 50'), '2 kg rice 50');
    });
    test('normalizes Telugu script', () {
      expect(RomanIndianVoiceNormalizer.normalize('రెండు కిలోల బియ్యం యాభై'), '2 kg rice 50');
    });
    test('normalizes mixed Telugu and English', () {
      expect(RomanIndianVoiceNormalizer.normalize('రెండు kg rice 50'), '2 kg rice 50');
    });
    test('normalizes Roman Hindi', () {
      expect(RomanIndianVoiceNormalizer.normalize('do kilo chawal pachaas'), '2 kg rice 50');
    });
    test('normalizes multi-item speech', () {
      expect(RomanIndianVoiceNormalizer.normalize('rendu kilo rice 50 moodu packetlu biscuit 100'), '2 kg rice 50 3 packet biscuit 100');
    });
    test('supports Telugu tens + units', () {
      expect(RomanIndianVoiceNormalizer.normalize('iravai rendu kilo'), '22 kg');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/roman_indian_voice_normalizer.dart';

void main() {
  group('P0/P1 Voice billing normalization', () {
    final cases = <String, String>{
      'rendu kilolu biyyam yaabhai': '2 kg rice 50',
      '2 killolu rice 50': '2 kg rice 50',
      'రెండు కిలోల బియ్యం యాభై': '2 kg rice 50',
      'రెండు kg rice 50': '2 kg rice 50',
      'do kilo chawal pachaas': '2 kg rice 50',
      'rendu kilo rice 50 moodu packetlu biscuit 100':
          '2 kg rice 50 3 packet biscuit 100',
      'iravai rendu kilo': '22 kg',
    };

    test('all known regression cases pass', () {
      for (final entry in cases.entries) {
        expect(
          RomanIndianVoiceNormalizer.normalize(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('normalization is deterministic', () {
      for (final entry in cases.entries) {
        final values = List.generate(
          25,
          (_) => RomanIndianVoiceNormalizer.normalize(entry.key),
        );
        expect(values.toSet(), hasLength(1));
      }
    });

    test('empty input does not crash', () {
      expect(
        () => RomanIndianVoiceNormalizer.normalize(''),
        returnsNormally,
      );
    });

    test('repeated whitespace does not crash', () {
      expect(
        () => RomanIndianVoiceNormalizer.normalize(
          'rendu    kilo    rice    50',
        ),
        returnsNormally,
      );
    });

    test('mixed English and Telugu script does not crash', () {
      expect(
        () => RomanIndianVoiceNormalizer.normalize('రెండు kg rice 50'),
        returnsNormally,
      );
    });

    test('Roman Hindi regression remains intact', () {
      expect(
        RomanIndianVoiceNormalizer.normalize('do kilo chawal pachaas'),
        '2 kg rice 50',
      );
    });

    test('multi-item regression remains intact', () {
      expect(
        RomanIndianVoiceNormalizer.normalize(
          'rendu kilo rice 50 moodu packetlu biscuit 100',
        ),
        '2 kg rice 50 3 packet biscuit 100',
      );
    });

    test('Telugu tens + unit regression remains intact', () {
      expect(
        RomanIndianVoiceNormalizer.normalize('iravai rendu kilo'),
        '22 kg',
      );
    });

    test('known inputs stay stable over 100 iterations', () {
      for (var i = 0; i < 100; i++) {
        expect(
          RomanIndianVoiceNormalizer.normalize('rendu kilolu biyyam yaabhai'),
          '2 kg rice 50',
        );
      }
    });
  });
}

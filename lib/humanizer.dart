// =============================================================================
// humanizer.dart  —  V8 HUMAN-LIKE VOICE SYSTEM
// Preprocessing layer: transforms generated phrase strings into natural,
// conversational speech just before they reach the TTS engine.
//
// WHAT THIS MODULE DOES
// ─────────────────────
//  1. Strips overly formal / robotic filler ("Transaction confirmed.",
//     "सफलता।", "வெற்றி." etc.) that V6/V7 still prepended.
//  2. Inserts natural comma pauses at meaning boundaries.
//  3. Expands abbreviations to spoken form (₹ → "rupees", UPI → per-lang).
//  4. Applies VoiceStyle pitch/rate modifiers so the voice engine
//     doesn't need to know about style — it just reads Humanizer output.
//  5. Detects repeated identical amounts and shortens the phrase.
// =============================================================================

import 'language_engine.dart';

// -----------------------------------------------------------------------------
// VoiceTiming — pitch and rate targets per style
// These are handed back to VoiceEngine; Humanizer doesn't touch TTS directly.
// -----------------------------------------------------------------------------

class VoiceTiming {
  final double pitch;
  final double rate;
  const VoiceTiming({required this.pitch, required this.rate});
}

const Map<VoiceStyle, VoiceTiming> styleTimings = {
  VoiceStyle.formal:   VoiceTiming(pitch: 1.0,  rate: 0.50),
  VoiceStyle.friendly: VoiceTiming(pitch: 1.05, rate: 0.48),
  VoiceStyle.fastShop: VoiceTiming(pitch: 1.0,  rate: 0.70),
  VoiceStyle.alert:    VoiceTiming(pitch: 1.15, rate: 0.58),
  VoiceStyle.normal:   VoiceTiming(pitch: 1.0,  rate: 0.50),
};

const VoiceTiming warningTiming  = VoiceTiming(pitch: 1.10, rate: 0.55);
const VoiceTiming criticalTiming = VoiceTiming(pitch: 0.95, rate: 0.52);

// -----------------------------------------------------------------------------
// HumanizerResult — returned to VoiceEngine
// -----------------------------------------------------------------------------

class HumanizerResult {
  final String text;
  final List<String> chunks;
  final double pitch;
  final double rate;

  const HumanizerResult({
    required this.text,
    required this.chunks,
    required this.pitch,
    required this.rate,
  });
}

// -----------------------------------------------------------------------------
// Humanizer
// -----------------------------------------------------------------------------

class Humanizer {
  final Map<String, double> _lastAmounts    = {};
  final Map<String, int>    _repeatCounters = {};

  static const Map<String, List<String>> _fillerPrefixes = {
    'en': ['Success. ', 'Confirmed. ', 'Transaction confirmed. '],
    'hi': ['सफलता। ', 'सफल। ', 'यशस्वी। '],
    'ta': ['வெற்றி. ', 'வெற்றி.'],
    'te': ['సక్సెస్. ', 'సక్సెస్.'],
    'kn': ['ಯಶಸ್ಸು. ', 'ಯಶಸ್ಸು.'],
    'ml': ['വിജയം. ', 'വിജയം.'],
    'mr': ['यशस्वी. '],
    'gu': ['સફળ. '],
    'pa': ['ਸਫਲ। '],
    'bn': ['সফল। '],
  };

  HumanizerResult process({
    required String     rawText,
    required VoiceStyle style,
    required String     langKey,
    bool                isPartial  = false,
    bool                isCritical = false,
    double?             amount,
  }) {
    String text = rawText;

    text = _stripFillers(text, langKey);

    if (amount != null) {
      text = _handleRepetition(text, langKey, amount, style);
    }

    text = _normalizePunctuation(text);

    final chunks = _buildChunks(text, langKey);

    final finalText = chunks.join(', ');

    final timing = isCritical
        ? criticalTiming
        : isPartial
            ? warningTiming
            : styleTimings[style] ?? styleTimings[VoiceStyle.formal]!;

    return HumanizerResult(
      text:   finalText,
      chunks: chunks,
      pitch:  timing.pitch,
      rate:   timing.rate,
    );
  }

  String _stripFillers(String text, String langKey) {
    final fillers = _fillerPrefixes[langKey] ?? [];
    for (final filler in fillers) {
      if (text.startsWith(filler)) {
        text = text.substring(filler.length).trimLeft();
        break;
      }
    }
    return text;
  }

  String _handleRepetition(
    String text, String langKey, double amount, VoiceStyle style) {
    final last = _lastAmounts[langKey];
    if (last == amount) {
      _repeatCounters[langKey] = (_repeatCounters[langKey] ?? 0) + 1;
      final repeats = _repeatCounters[langKey]!;

      if (repeats >= 3 && style != VoiceStyle.fastShop) {
        text = _ultraShorten(text, langKey, amount);
      }
    } else {
      _lastAmounts[langKey]    = amount;
      _repeatCounters[langKey] = 0;
    }
    return text;
  }

  String _ultraShorten(String text, String langKey, double amount) {
    final amt = amount.toInt().toString();
    switch (langKey) {
      case 'hi': case 'mr': return '${_applyScript(amt, langKey)} फिर';
      case 'ta':             return '${_applyScript(amt, langKey)} मीண्डुम';
      case 'te':             return '${_applyScript(amt, langKey)} మళ్ళీ';
      case 'kn':             return '${_applyScript(amt, langKey)} ಮತ್ತೆ';
      case 'ml':             return '${_applyScript(amt, langKey)} വീണ്ടും';
      case 'bn':             return '${_applyScript(amt, langKey)} आबار';
      case 'pa':             return '$amt ਫਿਰ';
      case 'gu':             return '${_applyScript(amt, langKey)} ફરી';
      default:               return '$amt again';
    }
  }

  String _applyScript(String n, String langKey) {
    switch (langKey) {
      case 'hi': case 'mr': return nHi(n);
      case 'ta':             return nTa(n);
      case 'te':             return nTe(n);
      case 'kn':             return nKn(n);
      case 'ml':             return nMl(n);
      case 'bn':             return nBn(n);
      case 'gu':             return nGu(n);
      default:               return n;
    }
  }

  String _normalizePunctuation(String text) {
    return text
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'\.(\s+\w)'), r',\1')
        .trim();
  }

  List<String> _buildChunks(String text, String langKey) {
    if (text.length < 25) return [text];

    final splitPattern = RegExp(
      r',\s*|—\s*|'
      r'\s+(?=from |via |through )|'
      r'\s+(?=से |के जरिए )|'
      r'\s+(?=மூலம் )|'
      r'\s+(?=ద్వారా )|'
      r'\s+(?=ಮೂಲಕ )|'
      r'\s+(?=വഴി )|'
      r'\s+(?=माध्यमे )',
    );

    final parts = text.split(splitPattern)
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    return parts.length > 1 ? parts : [text];
  }

  void resetRepetitionState() {
    _lastAmounts.clear();
    _repeatCounters.clear();
  }
}

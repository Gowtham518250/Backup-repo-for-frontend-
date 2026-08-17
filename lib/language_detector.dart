import 'voice_nlp_engine.dart' show VoiceNlpEngineV2, ParsedItemV2;

// -----------------------------------------------------------------------------
// language_detector.dart — multilingual voice detection engine
// -----------------------------------------------------------------------------
// Purpose:
//   Detect language at the token/segment level so voice input can be routed to
//   the correct langCode for parsing.
// -----------------------------------------------------------------------------

enum SupportedLang { en, hi, mr, ta, te, kn, ml, bn, gu, pa }

extension SupportedLangX on SupportedLang {
  String get code => switch (this) {
        SupportedLang.en => 'en',
        SupportedLang.hi => 'hi',
        SupportedLang.mr => 'mr',
        SupportedLang.ta => 'ta',
        SupportedLang.te => 'te',
        SupportedLang.kn => 'kn',
        SupportedLang.ml => 'ml',
        SupportedLang.bn => 'bn',
        SupportedLang.gu => 'gu',
        SupportedLang.pa => 'pa',
      };

  String get locale => switch (this) {
        SupportedLang.en => 'en-IN',
        SupportedLang.hi => 'hi-IN',
        SupportedLang.mr => 'mr-IN',
        SupportedLang.ta => 'ta-IN',
        SupportedLang.te => 'te-IN',
        SupportedLang.kn => 'kn-IN',
        SupportedLang.ml => 'ml-IN',
        SupportedLang.bn => 'bn-IN',
        SupportedLang.gu => 'gu-IN',
        SupportedLang.pa => 'pa-IN',
      };

  String get displayName => switch (this) {
        SupportedLang.en => 'English',
        SupportedLang.hi => 'Hindi',
        SupportedLang.mr => 'Marathi',
        SupportedLang.ta => 'Tamil',
        SupportedLang.te => 'Telugu',
        SupportedLang.kn => 'Kannada',
        SupportedLang.ml => 'Malayalam',
        SupportedLang.bn => 'Bengali',
        SupportedLang.gu => 'Gujarati',
        SupportedLang.pa => 'Punjabi',
      };

  static SupportedLang fromCode(String code) {
    final k = code.split('-').first.toLowerCase();
    return SupportedLang.values.firstWhere(
      (lang) => lang.code == k,
      orElse: () => SupportedLang.en,
    );
  }
}

class _Range {
  final int start;
  final int end;
  const _Range(this.start, this.end);

  bool contains(int rune) => rune >= start && rune <= end;
}

const Map<SupportedLang, _Range> _uniqueScriptRanges = {
  SupportedLang.ta: _Range(0x0B80, 0x0BFF),
  SupportedLang.te: _Range(0x0C00, 0x0C7F),
  SupportedLang.kn: _Range(0x0C80, 0x0CFF),
  SupportedLang.ml: _Range(0x0D00, 0x0D7F),
  SupportedLang.bn: _Range(0x0980, 0x09FF),
  SupportedLang.gu: _Range(0x0A80, 0x0AFF),
  SupportedLang.pa: _Range(0x0A00, 0x0A7F),
};

const _Range _devanagariRange = _Range(0x0900, 0x097F);

bool _isLatin(int rune) =>
    (rune >= 0x0041 && rune <= 0x005A) || (rune >= 0x0061 && rune <= 0x007A);

class _LangSignature {
  final Set<String> numbers;
  final Set<String> markers;
  const _LangSignature({required this.numbers, required this.markers});
}

final Map<SupportedLang, _LangSignature> _signatures = {
  SupportedLang.en: const _LangSignature(
    numbers: {
      'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
      'nine', 'ten', 'eleven', 'twelve', 'twenty', 'thirty', 'forty', 'fifty',
      'hundred', 'thousand', 'half', 'dozen', 'couple',
    },
    markers: {
      'the', 'is', 'are', 'want', 'need', 'give', 'me', 'please', 'and',
      'how', 'much', 'total', 'price', 'cost', 'rupees', 'add', 'bill',
      'this', 'that', 'for', 'with', 'have', 'kilo', 'liter', 'litre',
    },
  ),
  SupportedLang.hi: const _LangSignature(
    numbers: {
      'ek', 'do', 'teen', 'char', 'panch', 'chhe', 'che', 'saat', 'aath',
      'nau', 'das', 'gyarah', 'baarah', 'terah', 'chaudah', 'pandrah',
      'solah', 'sattarah', 'athaarah', 'unnees', 'bees', 'tees', 'chaalis',
      'pachaas', 'saath', 'sattar', 'assi', 'nabbe', 'sau', 'hazaar', 'lakh',
      'aadha', 'dedh', 'dhai',
      'एक', 'दो', 'तीन', 'चार', 'पांच', 'पाँच', 'छह', 'सात', 'आठ', 'नौ', 'दस',
      'सौ', 'हजार', 'आधा', 'डेढ़',
    },
    markers: {
      'hai', 'hain', 'chahiye', 'mujhe', 'tumhe', 'kitna', 'kitne', 'aur',
      'bhi', 'karo', 'mein', 'main', 'se', 'ko', 'wala', 'accha', 'thik',
      'nahi', 'haan', 'de', 'do', 'kya', 'kaisa',
      'है', 'हैं', 'चाहिए', 'मुझे', 'कितना', 'और', 'भी', 'करो', 'में', 'से',
      'को', 'वाला', 'अच्छा', 'ठीक', 'नहीं', 'हाँ', 'क्या',
    },
  ),
  SupportedLang.mr: const _LangSignature(
    numbers: {
      'ek', 'don', 'teen', 'char', 'pach', 'saha', 'saat', 'aath', 'nau',
      'daha', 'agyara', 'bara', 'tera', 'pandhra', 'sola', 'satra', 'vees',
      'tees', 'chalis', 'pannas', 'saath', 'sattar', 'aishi', 'navvad',
      'shambhar', 'hazaar',
      'एक', 'दोन', 'तीन', 'चार', 'पाच', 'सहा', 'सात', 'आठ', 'नऊ', 'दहा',
    },
    markers: {
      'ahe', 'nahi', 'pahije', 'zala', 'zali', 'tyala', 'mala', 'tumhala',
      'kiti', 'ani', 'karto', 'karte', 'yeto', 'aahe', 'kititla', 'kay',
      'आहे', 'नाही', 'पाहिजे', 'झाला', 'झाली', 'त्याला', 'मला', 'तुम्हाला',
      'किती', 'आणि', 'करतो', 'करते', 'येतो', 'काय',
    },
  ),
  SupportedLang.ta: const _LangSignature(
    numbers: {
      'onnu', 'rendu', 'moonu', 'moondru', 'naalu', 'anju', 'aaru', 'elu',
      'ezhu', 'ettu', 'onbathu', 'pathu', 'pathinonnu', 'panniranndu',
      'irupathu', 'muppathu', 'naarpathu', 'aimpathu',
    },
    markers: {
      'venum', 'irukku', 'illa', 'konjam', 'romba', 'epdi', 'vanga', 'seri',
      'dhaan', 'thaan', 'pannunga', 'kudu', 'vaangi', 'thevai', 'ippo',
      'anga', 'inga', 'enna', 'sollunga', 'poidalam', 'venam',
    },
  ),
  SupportedLang.te: const _LangSignature(
    numbers: {
      'okati', 'rendu', 'moodu', 'naalugu', 'aidu', 'aaru', 'edu', 'enimidi',
      'tommidi', 'padi', 'padakondu', 'pannendu', 'iravai', 'muppai',
      'nalabhai', 'yabhai',
    },
    markers: {
      'kavali', 'undi', 'ledu', 'enti', 'chala', 'cheppu', 'ivvu', 'ela',
      'ekkada', 'ippudu', 'bagundi', 'teesuko', 'kaani', 'cheyandi', 'chestha',
      'unna', 'nenu', 'meeku',
    },
  ),
  SupportedLang.kn: const _LangSignature(
    numbers: {
      'ondu', 'eradu', 'moru', 'muru', 'naalku', 'aidu', 'aaru', 'elu',
      'entu', 'ombattu', 'hattu', 'hannondu', 'hanneradu', 'ippattu',
      'moovattu', 'naalvattu', 'aivattu',
    },
    markers: {
      'beku', 'ide', 'illa', 'enu', 'thumba', 'kodi', 'barali', 'hege',
      'yenu', 'swalpa', 'tagond', 'madi', 'illave', 'nanage', 'neevu',
      'hogide',
    },
  ),
  SupportedLang.ml: const _LangSignature(
    numbers: {
      'onnu', 'randu', 'moonu', 'naalu', 'anju', 'aaru', 'ezhu', 'ettu',
      'ompathu', 'pathu', 'pathinonnu', 'irupathu', 'muppathu', 'nalpathu',
      'anpathu',
    },
    markers: {
      'venam', 'undu', 'illa', 'enthu', 'ippol', 'evide', 'kodukku', 'enik',
      'ninak', 'kore', 'adipoli', 'ithu', 'sheri', 'venda',
    },
  ),
  SupportedLang.bn: const _LangSignature(
    numbers: {
      'ek', 'dui', 'tin', 'char', 'panch', 'choy', 'chhoy', 'saat', 'aat',
      'noy', 'dosh', 'egaro', 'baro', 'tero', 'bish', 'trish', 'challish',
      'ponchash',
    },
    markers: {
      'chai', 'ache', 'nei', 'koto', 'dao', 'bhalo', 'ekta', 'tumi', 'ami',
      'korbo', 'lagbe', 'ekhon', 'ki', 'kotha',
    },
  ),
  SupportedLang.gu: const _LangSignature(
    numbers: {
      'ek', 'be', 'tran', 'char', 'panch', 'chha', 'saat', 'aath', 'nav',
      'dus', 'agiyar', 'baar', 'ter', 'chaud', 'vees', 'trees', 'chalis',
      'pachas',
    },
    markers: {
      'joiye', 'che', 'nathi', 'ketlu', 'aapo', 'tame', 'hun', 'karo',
      'saru', 'thodu', 'su', 'kem',
    },
  ),
  SupportedLang.pa: const _LangSignature(
    numbers: {
      'ikk', 'do', 'tinn', 'char', 'panj', 'chhe', 'satt', 'ath', 'nau',
      'das', 'gyaran', 'baran', 'teran', 'vih', 'chali', 'panjaah',
    },
    markers: {
      'chahida', 'nahi', 'kinna', 'tuhanu', 'mainu', 'changa', 'karo',
      'thoda', 'ki', 'hai', 'de',
    },
  ),
};

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final prev = List<int>.generate(b.length + 1, (i) => i);
  final curr = List<int>.filled(b.length + 1, 0);
  for (int i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (int j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      curr[j] = [
        curr[j - 1] + 1,
        prev[j] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    for (int j = 0; j <= b.length; j++) {
      prev[j] = curr[j];
    }
  }
  return prev[b.length];
}

double _fuzzyMatch(String token, Set<String> vocabulary) {
  if (vocabulary.contains(token)) return 1.0;
  final maxDist = token.length <= 4 ? 1 : (token.length <= 7 ? 2 : 3);
  for (final word in vocabulary) {
    if ((word.length - token.length).abs() > maxDist) {
      continue;
    }
    final distance = _levenshtein(token, word);
    if (distance <= maxDist) {
      return 1.0 - (distance / (maxDist + 1)) * 0.5;
    }
  }
  return 0.0;
}

class TokenTag {
  final String token;
  final SupportedLang? lang;
  final double weight;
  const TokenTag(this.token, this.lang, this.weight);
}

class LanguageSegment {
  final String text;
  final SupportedLang lang;
  final double confidence;
  const LanguageSegment(this.text, this.lang, this.confidence);

  String get langCode => lang.code;
  String get locale => lang.locale;
}

class LanguageDetectionResult {
  final SupportedLang dominant;
  final double confidence;
  final bool isCodeSwitched;
  final List<TokenTag> tokens;
  final List<LanguageSegment> segments;
  final Map<SupportedLang, double> scoreBreakdown;

  const LanguageDetectionResult({
    required this.dominant,
    required this.confidence,
    required this.isCodeSwitched,
    required this.tokens,
    required this.segments,
    required this.scoreBreakdown,
  });
}

class LanguageDetector {
  static final RegExp _tokenRe = RegExp(r"[\p{L}\p{M}]+", unicode: true);
  static final RegExp _digitRe = RegExp(r'^\d+\.?\d*$');
  static const double lowConfidenceThreshold = 0.35;
  static const double _segmentFlipThreshold = 1.4;

  static LanguageDetectionResult detect(
    String transcript, {
      String? sttLocaleHint,
    }) {
    final text = transcript.trim().toLowerCase();
    if (text.isEmpty) {
      final fallback = sttLocaleHint != null
          ? SupportedLangX.fromCode(sttLocaleHint)
          : SupportedLang.en;
      return LanguageDetectionResult(
        dominant: fallback,
        confidence: 0.0,
        isCodeSwitched: false,
        tokens: const [],
        segments: const [],
        scoreBreakdown: const {},
      );
    }

    final rawTokens = _tokenRe.allMatches(text).map((match) => match.group(0)!).toList();
    final tags = <TokenTag>[];
    final scores = <SupportedLang, double>{for (final lang in SupportedLang.values) lang: 0.0};

    for (final token in rawTokens) {
      if (_digitRe.hasMatch(token)) {
        tags.add(TokenTag(token, null, 0));
        continue;
      }

      final firstRune = token.runes.first;
      SupportedLang? uniqueScriptLang;
      for (final entry in _uniqueScriptRanges.entries) {
        if (entry.value.contains(firstRune)) {
          uniqueScriptLang = entry.key;
          break;
        }
      }
      if (uniqueScriptLang != null) {
        scores[uniqueScriptLang] = scores[uniqueScriptLang]! + 3.0;
        tags.add(TokenTag(token, uniqueScriptLang, 3.0));
        continue;
      }

      if (_devanagariRange.contains(firstRune)) {
        final isMarathiMarker = _signatures[SupportedLang.mr]!.markers.contains(token) ||
            _signatures[SupportedLang.mr]!.numbers.contains(token);
        final lang = isMarathiMarker ? SupportedLang.mr : SupportedLang.hi;
        final weight = isMarathiMarker ? 3.2 : 2.6;
        scores[lang] = scores[lang]! + weight;
        tags.add(TokenTag(token, lang, weight));
        continue;
      }

      if (!_isLatin(firstRune)) {
        tags.add(TokenTag(token, null, 0));
        continue;
      }

      final perLangScore = <SupportedLang, double>{};
      for (final entry in _signatures.entries) {
        final signature = entry.value;
        double score = 0.0;
        if (signature.numbers.contains(token)) {
          score = 2.2;
        } else if (signature.markers.contains(token)) {
          score = 1.8;
        } else if (token.length >= 3) {
          final numberFuzzy = _fuzzyMatch(token, signature.numbers);
          final markerFuzzy = _fuzzyMatch(token, signature.markers);
          score = (numberFuzzy > markerFuzzy ? numberFuzzy : markerFuzzy) * 1.3;
        }
        if (score > 0) {
          perLangScore[entry.key] = score;
        }
      }

      if (perLangScore.isNotEmpty) {
        final top = perLangScore.values.reduce((a, b) => a > b ? a : b);
        final tied = perLangScore.entries.where((entry) => entry.value == top).toList();
        final splitWeight = top / tied.length;
        for (final entry in tied) {
          scores[entry.key] = scores[entry.key]! + splitWeight;
        }
        tags.add(TokenTag(token, tied.first.key, splitWeight));
      } else {
        tags.add(TokenTag(token, null, 0));
      }
    }

    final totalScore = scores.values.fold(0.0, (a, b) => a + b);
    SupportedLang dominant;
    double confidence;

    if (totalScore <= 0) {
      dominant = sttLocaleHint != null
          ? SupportedLangX.fromCode(sttLocaleHint)
          : SupportedLang.en;
      confidence = 0.15;
    } else {
      final sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      dominant = sorted.first.key;
      confidence = (sorted.first.value / totalScore).clamp(0.0, 1.0);
    }

    final sortedScores = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final isMixed = totalScore > 0 &&
        sortedScores.length > 1 &&
        sortedScores[1].value >= 0.30 * sortedScores[0].value &&
        sortedScores[1].value > 1.0;

    final segments = _buildSegments(tags, dominant);

    return LanguageDetectionResult(
      dominant: dominant,
      confidence: confidence,
      isCodeSwitched: isMixed,
      tokens: tags,
      segments: segments,
      scoreBreakdown: scores,
    );
  }

  static List<LanguageSegment> _buildSegments(
    List<TokenTag> tags,
    SupportedLang fallback,
  ) {
    if (tags.isEmpty) return [];

    final segments = <LanguageSegment>[];
    final buffer = StringBuffer();
    SupportedLang? current;
    double currentWeightSum = 0.0;
    int currentCount = 0;

    void flush() {
      if (buffer.isEmpty) return;
      final lang = current ?? fallback;
      final conf = currentCount > 0
          ? (currentWeightSum / currentCount / 3.0).clamp(0.0, 1.0)
          : 0.3;
      segments.add(LanguageSegment(buffer.toString().trim(), lang, conf));
      buffer.clear();
      currentWeightSum = 0.0;
      currentCount = 0;
    }

    for (final tag in tags) {
      final shouldFlip = tag.lang != null &&
          tag.lang != current &&
          tag.weight >= _segmentFlipThreshold;

      if (current == null) {
        current = tag.lang ?? fallback;
      } else if (shouldFlip) {
        flush();
        current = tag.lang;
      }

      buffer.write('${tag.token} ');
      if (tag.lang != null) {
        currentWeightSum += tag.weight;
        currentCount++;
      }
    }
    flush();
    return segments;
  }

  static String pickSttLocale(String transcript, String currentLocale) {
    final result = detect(transcript, sttLocaleHint: currentLocale);
    if (result.confidence < 0.55) return currentLocale;
    if (result.dominant.locale == currentLocale) return currentLocale;
    return result.dominant.locale;
  }

  static SelfTestReport runSelfTest() {
    int passed = 0;
    final failures = <String>[];
    for (final testCase in _selfTestCases) {
      final result = detect(testCase.transcript);
      final ok = testCase.expectMixed
          ? result.isCodeSwitched
          : result.dominant == testCase.expected;
      if (ok) {
        passed++;
      } else if (testCase.expectMixed) {
        failures.add(
          '"${testCase.transcript}" -> expected code-switch to be detected, got isCodeSwitched=${result.isCodeSwitched}',
        );
      } else {
        failures.add(
          '"${testCase.transcript}" -> got ${result.dominant.code} (conf ${result.confidence.toStringAsFixed(2)}), expected ${testCase.expected!.code}',
        );
      }
    }
    return SelfTestReport(_selfTestCases.length, passed, failures);
  }
}

List<ParsedItemV2> parseMultilingualVoiceInput(
  String transcript, {
  List<Map<String, dynamic>>? catalog,
  String? sttLocaleHint,
}) {
  final detection = LanguageDetector.detect(transcript, sttLocaleHint: sttLocaleHint);
  if (detection.segments.isEmpty) return [];

  if (!detection.isCodeSwitched || detection.segments.length == 1) {
    return VoiceNlpEngineV2.parse(
      transcript,
      detection.dominant.code,
      catalog: catalog,
    );
  }

  final merged = <ParsedItemV2>[];
  for (final segment in detection.segments) {
    if (segment.text.trim().isEmpty) continue;
    final items = VoiceNlpEngineV2.parse(segment.text, segment.lang.code, catalog: catalog);
    for (final item in items) {
      final duplicateIndex = merged.indexWhere((entry) =>
          entry.name.toLowerCase() == item.name.toLowerCase() &&
          (entry.price - item.price).abs() < 1.0);
      if (duplicateIndex == -1) {
        merged.add(item);
      } else if (item.confidenceScore > merged[duplicateIndex].confidenceScore) {
        merged[duplicateIndex] = item;
      }
    }
  }
  return merged;
}

class SelfTestCase {
  final String transcript;
  final SupportedLang? expected;
  final bool expectMixed;
  const SelfTestCase(this.transcript, this.expected, {this.expectMixed = false});
}

class SelfTestReport {
  final int total;
  final int passed;
  final List<String> failures;
  double get accuracy => total == 0 ? 0 : passed / total;
  const SelfTestReport(this.total, this.passed, this.failures);

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Language detection self-test: $passed/$total passed '
        '(${(accuracy * 100).toStringAsFixed(1)}%)');
    for (final failure in failures) {
      buffer.writeln('  FAIL: $failure');
    }
    return buffer.toString();
  }
}

const List<SelfTestCase> _selfTestCases = [
  SelfTestCase('two kilo sugar sixty rupees', SupportedLang.en),
  SelfTestCase('give me one packet biscuit', SupportedLang.en),
  SelfTestCase('दो किलो चावल साठ रुपये', SupportedLang.hi),
  SelfTestCase('ek kilo chawal saath rupaye chahiye', SupportedLang.hi),
  SelfTestCase('मला दोन किलो साखर पाहिजे आहे', SupportedLang.mr),
  SelfTestCase('mala don kilo sakhar pahije ahe', SupportedLang.mr),
  SelfTestCase('எனக்கு ரெண்டு கிலோ அரிசி வேணும்', SupportedLang.ta),
  SelfTestCase('rendu kilo arisi venum ippo kudu', SupportedLang.ta),
  SelfTestCase('నాకు రెండు కిలో బియ్యం కావాలి', SupportedLang.te),
  SelfTestCase('naaku rendu kilo biyyam kavali ivvu', SupportedLang.te),
  SelfTestCase('ನನಗೆ ಎರಡು ಕಿಲೋ ಅಕ್ಕಿ ಬೇಕು', SupportedLang.kn),
  SelfTestCase('nanage eradu kilo akki beku swalpa', SupportedLang.kn),
  SelfTestCase('എനിക്ക് രണ്ട് കിലോ അരി വേണം', SupportedLang.ml),
  SelfTestCase('enik randu kilo ari venam ippol', SupportedLang.ml),
  SelfTestCase('আমার দুই কেজি চাল চাই', SupportedLang.bn),
  SelfTestCase('amar dui kg chal chai ekhon', SupportedLang.bn),
  SelfTestCase('મારે બે કિલો ચોખા જોઈએ', SupportedLang.gu),
  SelfTestCase('mare be kilo chokha joiye aapo', SupportedLang.gu),
  SelfTestCase('ਮੈਨੂੰ ਦੋ ਕਿਲੋ ਚੌਲ ਚਾਹੀਦੇ', SupportedLang.pa),
  SelfTestCase('mainu do kilo chawal chahida hai', SupportedLang.pa),
  SelfTestCase('rendu kilo sugar and one packet biscuit', null, expectMixed: true),
];

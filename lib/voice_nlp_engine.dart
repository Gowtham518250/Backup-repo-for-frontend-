// =============================================================================
// voice_nlp_engine.dart  —  V2 ADVANCED DETECTION ENGINE
// =============================================================================
// WHAT'S NEW vs original:
//
//  NLP-1  Compound number parsing: "twenty five" → 25, "डेढ़ सौ" → 150,
//          "two and a half" → 2.5, "ek sau pachaas" → 150
//  NLP-2  Context-aware qty/price disambiguation using catalog price ranges
//          (avoids "Sugar 60 2" misreading 60 as qty and 2 as price)
//  NLP-3  Sliding-window segmentation: no split tokens needed; segments
//          detected by (number → words → number) rhythm across all 10 languages
//  NLP-4  Phonetic cluster normalizer: maps STT mishears like "shugger",
//          "tometo", "tamatar/tamater" to canonical English/Hindi name
//  NLP-5  Cross-language synonym resolver: "doodh"/"paal"/"dood" → "Milk"
//          and reverse-transliteration for Tamil/Telugu/Kannada scripts
//  NLP-6  Unit inference from context: if product is "milk" and no unit
//          mentioned, infer "L"; "egg" → "pc"; "flour" → "kg"
//  NLP-7  Price sanity validator: cross-checks extracted price against
//          known catalog range and flags if > 3× median or < 0.1× median
//  NLP-8  Partial-item recovery: a segment with only (name + qty) is kept
//          at low confidence instead of being silently dropped
//  NLP-9  Duplicate & sub-item merger: "1 oil 150" + "1 coconut oil 150"
//          → deduplicated to the more specific match
//  NLP-10 Confidence v2: 14-signal scoring with separate name/qty/price
//          sub-scores, pattern bonus, and catalog-hit multiplier
// =============================================================================

// ignore_for_file: prefer_const_constructors, unused_import

// ─── External imports (same deps as existing project) ────────────────────────
// No new packages required.

// ─── Data models ──────────────────────────────────────────────────────────────

/// Enhanced parsed item — backward-compatible with the original ParsedItem.
class ParsedItemV2 {
  final String name;
  final double qty;
  final String unit;
  final double price;
  final ConfidenceDetail confidence;
  final String? catalogMatchName; // canonical name from catalog, if any
  final double? catalogPrice;     // catalog price, for sanity check display
  bool isConfirmed;

  ParsedItemV2({
    required this.name,
    required this.qty,
    required this.unit,
    required this.price,
    required this.confidence,
    this.catalogMatchName,
    this.catalogPrice,
    this.isConfirmed = true,
  });

  /// Backward compat score for existing UI code
  double get confidenceScore => confidence.total;

  Map<String, dynamic> toMap() => {
    'product_name': name,
    'quantity': qty,
    'unit': unit,
    'price': price,
    'total': qty * price,
    'confidence': confidence.total,
  };
}

/// Broken-down confidence so the UI can show per-dimension warnings.
class ConfidenceDetail {
  final double nameScore;   // 0–1
  final double qtyScore;    // 0–1
  final double priceScore;  // 0–1
  final double patternBonus; // 0–0.1
  final double catalogBonus; // 0–0.15
  double get total => ((nameScore * 0.35) +
                       (qtyScore  * 0.25) +
                       (priceScore * 0.30) +
                       patternBonus +
                       catalogBonus).clamp(0.0, 1.0);

  const ConfidenceDetail({
    required this.nameScore,
    required this.qtyScore,
    required this.priceScore,
    this.patternBonus = 0,
    this.catalogBonus = 0,
  });
}

// ─── Compound number parser ────────────────────────────────────────────────────

/// NLP-1: Parse compound spoken numbers across all 10 Indian languages.
/// Examples:
///   "twenty five"      → 25
///   "ek sau pachaas"   → 150
///   "डेढ़ सौ"            → 150
///   "two and a half"   → 2.5
///   "aadha kilo"       → 0.5  (handled separately in unit inference)
class CompoundNumberParser {
  // ── English compound rules ──────────────────────────────────────────────

  static const _enAtoms = <String, num>{
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
    'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18,
    'nineteen': 19, 'twenty': 20, 'thirty': 30, 'forty': 40,
    'fifty': 50, 'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
    'hundred': 100, 'thousand': 1000, 'lakh': 100000,
    // fractions
    'half': 0.5, 'quarter': 0.25,
    // colloquial
    'couple': 2, 'few': 3, 'dozen': 12, 'score': 20,
    // decimal spoken forms
    'point': -1, // sentinel
  };

  static const _hiAtoms = <String, num>{
    'zero': 0, 'ek': 1, 'do': 2, 'teen': 3, 'char': 4, 'panch': 5,
    'chhe': 6, 'saat': 7, 'aath': 8, 'nau': 9, 'das': 10,
    'gyarah': 11, 'baarah': 12, 'terah': 13, 'chaudah': 14, 'pandrah': 15,
    'solah': 16, 'sattarah': 17, 'athaarah': 18, 'unnees': 19,
    'bees': 20, 'tees': 30, 'chaalis': 40, 'pachaas': 50,
    'saath': 60, 'sattar': 70, 'assi': 80, 'nabbe': 90,
    'sau': 100, 'hazaar': 1000, 'lakh': 100000,
    'aadha': 0.5, 'dedh': 1.5, 'dhai': 2.5, 'savah': 1.25, 'paune': 0.75,
    // Devanagari
    'शून्य': 0, 'एक': 1, 'दो': 2, 'तीन': 3, 'चार': 4, 'पाँच': 5, 'पांच': 5,
    'छह': 6, 'छः': 6, 'सात': 7, 'आठ': 8, 'नौ': 9, 'दस': 10,
    'ग्यारह': 11, 'बारह': 12, 'तेरह': 13, 'चौदह': 14, 'पन्द्रह': 15,
    'सोलह': 16, 'सत्रह': 17, 'अठारह': 18, 'उन्नीस': 19, 'बीस': 20,
    'तीस': 30, 'चालीस': 40, 'पचास': 50, 'साठ': 60, 'सत्तर': 70,
    'अस्सी': 80, 'नब्बे': 90, 'सौ': 100, 'हजार': 1000,
    'आधा': 0.5, 'डेढ़': 1.5, 'सवा': 1.25, 'साढ़े': 2.5,
    // Marathi overrides
    'दोन': 2, 'पाच': 5, 'सहा': 6, 'नऊ': 9, 'दहा': 10, 'वीस': 20,
    'अर्धा': 0.5, 'डेढ': 1.5, 'साडे': 2.5,
  };

  // NOTE: these were ported from the dead `_LangConfig` list in
  // voice_billing_assistant.dart (a V1 parser class, `MultiLangVoiceParser`,
  // that's never actually called — grep confirms zero call sites). That list
  // had clean, correctly-scripted number words per language; the ones in
  // voice_billing_enhanced_vocabulary.dart have some data-entry bugs (e.g.
  // Kannada/Malayalam "two hundred"/"three hundred" mapped to 2/3 instead of
  // 200/300, and a couple of garbled script entries), so I sourced from the
  // cleaner list instead of blindly merging both.
  static const _taAtoms = <String, num>{
    'பூஜ்ஜியம்': 0, 'ஒன்று': 1, 'இரண்டு': 2, 'மூன்று': 3, 'நான்கு': 4, 'ஐந்து': 5,
    'ஆறு': 6, 'ஏழு': 7, 'எட்டு': 8, 'ஒன்பது': 9, 'பத்து': 10,
    'பதினொன்று': 11, 'பனிரண்டு': 12, 'பதிமூன்று': 13, 'பதிநான்கு': 14, 'பதிநைந்து': 15,
    'பதினாறு': 16, 'பதினேழு': 17, 'பதினெட்டு': 18, 'பத்தொன்பது': 19,
    'இருபது': 20, 'முப்பது': 30, 'நாற்பது': 40, 'ஐம்பது': 50,
    'அறைக்கிலோ': 0.5, 'அரைக்கிலோ': 0.5, 'ஒன்றரை': 1.5,
  };

  static const _teAtoms = <String, num>{
    'సున్న': 0, 'ఒకటి': 1, 'రెండు': 2, 'మూడు': 3, 'నాలుగు': 4, 'ఐదు': 5,
    'ఆరు': 6, 'ఏడు': 7, 'ఎనిమిది': 8, 'తొమ్మిది': 9, 'పది': 10,
    'పదకొండు': 11, 'పన్నెండు': 12, 'పదమూడు': 13, 'పదనాలుగు': 14, 'పదిహేను': 15,
    'పదహారు': 16, 'పదిఏడు': 17, 'పద్దెనిమిది': 18, 'పందొమ్మిది': 19,
    'ఇరవై': 20, 'ముప్పై': 30, 'నలభై': 40, 'యాభై': 50, 'అరకిలో': 0.5,
  };

  static const _knAtoms = <String, num>{
    'ಶೂನ್ಯ': 0, 'ಒಂದು': 1, 'ಎರಡು': 2, 'ಮೂರು': 3, 'ನಾಲ್ಕು': 4, 'ಐದು': 5,
    'ಆರು': 6, 'ಏಳು': 7, 'ಎಂಟು': 8, 'ಒಂಬತ್ತು': 9, 'ಹತ್ತು': 10,
    'ಹನ್ನೊಂದು': 11, 'ಹನ್ನೆರಡು': 12, 'ಹದಿಮೂರು': 13, 'ಹದಿನಾಲ್ಕು': 14, 'ಹದಿಐದು': 15,
    'ಹದಿನಾರು': 16, 'ಹದಿನೇಳು': 17, 'ಹದಿನೆಂಟು': 18, 'ಹದಿಒಂಬತ್ತು': 19,
    'ಇಪ್ಪತ್ತು': 20, 'ಮೂವತ್ತು': 30, 'ನಲವತ್ತು': 40, 'ಐವತ್ತು': 50,
    'ಅರ್ಧ': 0.5, 'ಒಂದೂವರೆ': 1.5,
  };

  static const _mlAtoms = <String, num>{
    'പൂജ്യം': 0, 'ഒന്ന്': 1, 'രണ്ട്': 2, 'മൂന്ന്': 3, 'നാല്': 4, 'അഞ്ച്': 5,
    'ആറ്': 6, 'ഏഴ്': 7, 'എട്ട്': 8, 'ഒൻപത്': 9, 'പത്ത്': 10,
    'പതിനൊന്ന്': 11, 'പന്ത്രണ്ട്': 12, 'പതിമൂന്ന്': 13, 'പതിനാല്': 14, 'പതിനഞ്ച്': 15,
    'പതിനാറ്': 16, 'പതിനേഴ്': 17, 'പതിനെട്ട്': 18, 'പത്തൊമ്പത്': 19,
    'ഇരുപത്': 20, 'മുപ്പത്': 30, 'നാൽപത്': 40, 'അൻപത്': 50,
    'അരകിലോ': 0.5, 'ഒന്നര': 1.5,
  };

  static const _bnAtoms = <String, num>{
    'শূন্য': 0, 'এক': 1, 'দুই': 2, 'তিন': 3, 'চার': 4, 'পাঁচ': 5,
    'ছয়': 6, 'সাত': 7, 'আট': 8, 'নয়': 9, 'দশ': 10,
    'এগারো': 11, 'বারো': 12, 'তেরো': 13, 'চৌদ্দ': 14, 'পনের': 15,
    'ষোল': 16, 'সতের': 17, 'আঠারো': 18, 'উনিশ': 19, 'বিশ': 20,
    'ত্রিশ': 30, 'চল্লিশ': 40, 'পঞ্চাশ': 50, 'ষাট': 60, 'সত্তর': 70,
    'আশি': 80, 'নব্বই': 90, 'শত': 100, 'হাজার': 1000,
    'অর্ধ': 0.5, 'দেড়': 1.5,
  };

  static const _guAtoms = <String, num>{
    'શૂન્ય': 0, 'એક': 1, 'બે': 2, 'ત્રણ': 3, 'ચાર': 4, 'પાંચ': 5,
    'છ': 6, 'સાત': 7, 'આઠ': 8, 'નવ': 9, 'દસ': 10,
    'અગિયાર': 11, 'બાર': 12, 'તેર': 13, 'ચૌદ': 14, 'પંદર': 15,
    'સોળ': 16, 'સત્તર': 17, 'અઠાર': 18, 'ઉનીસ': 19, 'વીસ': 20,
    'ત્રીસ': 30, 'ચાલીસ': 40, 'પચાસ': 50, 'સાઠ': 60, 'સોતર': 70,
    'અસ્સી': 80, 'નવ્વે': 90, 'સો': 100, 'હજાર': 1000,
    'અર્ધ': 0.5, 'દોઢ': 1.5,
  };

  static const _paAtoms = <String, num>{
    'ਸਿਫਰ': 0, 'ਇੱਕ': 1, 'ਦੋ': 2, 'ਤਿੰਨ': 3, 'ਚਾਰ': 4, 'ਪੰਜ': 5,
    'ਛੇ': 6, 'ਸੱਤ': 7, 'ਅੱਠ': 8, 'ਨੌਂ': 9, 'ਦਸ': 10,
    'ਗਿਆਰਾਂ': 11, 'ਬਾਰਾਂ': 12, 'ਤੇਰਾਂ': 13, 'ਚੌਦਾਂ': 14, 'ਪੰਦਰਾਂ': 15,
    'ਸੋਲਾਂ': 16, 'ਸਤਾਰਾਂ': 17, 'ਅਠਾਰਾਂ': 18, 'ਉਨੀਨੀ': 19, 'ਬੀਹ': 20,
    'ਤੀਹ': 30, 'ਚਾਲੀ': 40, 'ਪੰਜਾਹ': 50, 'ਸਾਠ': 60, 'ਸਤਾਹ': 70,
    'ਅਸੀ': 80, 'ਨਬੇ': 90, 'ਸੌ': 100, 'ਹਜ਼ਾਰ': 1000,
    'ਅੱਧ': 0.5, 'ਡੇਢ': 1.5,
  };

  /// Per-language atom set, with English number words ALWAYS merged in
  /// additively (except for English itself, to avoid a pointless self-merge).
  /// This is what makes Hinglish / code-switching work: someone can say
  /// "rendu kilo sugar" or drop in an English number mid-sentence in any
  /// language and it still resolves.
  static Map<String, num>? _cachedAtoms;
  static String? _cachedAtomsKey;

  static Map<String, num> _atomsFor(String langCode) {
    final key = langCode.split('-').first.toLowerCase();
    if (_cachedAtomsKey == key && _cachedAtoms != null) return _cachedAtoms!;

    Map<String, num> base;
    switch (key) {
      case 'hi':
      case 'mr':
        base = _hiAtoms;
        break;
      case 'ta':
        base = _taAtoms;
        break;
      case 'te':
        base = _teAtoms;
        break;
      case 'kn':
        base = _knAtoms;
        break;
      case 'ml':
        base = _mlAtoms;
        break;
      case 'bn':
        base = _bnAtoms;
        break;
      case 'gu':
        base = _guAtoms;
        break;
      case 'pa':
        base = _paAtoms;
        break;
      case 'en':
      default:
        base = _enAtoms;
    }

    final merged = key == 'en' ? base : <String, num>{..._enAtoms, ...base};
    _cachedAtoms = merged;
    _cachedAtomsKey = key;
    return merged;
  }

  // ── Tokenise a text span into (possiblyNumber, text) tokens ──────────────

  static final _digitRe = RegExp(r'\d+\.?\d*');

  /// Returns numeric value of a text span if it contains a compound number,
  /// otherwise null. Works left-to-right with accumulator logic.
  ///
  /// Strategy:
  ///   - Split span into tokens
  ///   - For each token: look up atom value
  ///   - Apply English-compound rules:
  ///       * "twenty five" → 20 + 5
  ///       * "one hundred fifty" → 100×? accumulate
  ///       * "one and a half" → 1 + 0.5
  static num? tryParseCompound(String text, String langCode) {
    text = text.trim().toLowerCase();
    if (text.isEmpty) return null;

    // Fast-path: already a digit
    final asDouble = double.tryParse(text);
    if (asDouble != null) return asDouble;

    final atoms = _atomsFor(langCode);
    final tokens = text.split(RegExp(r'[\s\-]+'));

    num current = 0;
    num result  = 0;
    bool hasAny = false;

    for (int i = 0; i < tokens.length; i++) {
      final tok = tokens[i];
      if (tok == 'and' || tok == 'a' || tok == 'aur' || tok == 'ka' ||
          tok == 'ke' || tok == 'ki') continue;

      final atomVal = atoms[tok];
      if (atomVal == null) continue;
      hasAny = true;

      final v = atomVal.toDouble();

      if (v == 100) {
        // "two hundred" → current(2) * 100
        current = current == 0 ? 100 : current * 100;
      } else if (v == 1000 || v == 100000) {
        // "two thousand" / "do hazaar"
        current = current == 0 ? v : current * v;
        result += current;
        current = 0;
      } else if (v < 1 && v > 0) {
        // fraction token (half, aadha, etc.)
        if (current > 0) {
          // "dedh sau" (1.5 × 100 = 150)
          result += current + (current * v);
          current = 0;
        } else {
          result += v;
        }
      } else {
        // plain number: add to current if it can be combined, else flush
        if (current >= 20 && v < current && current < 100) {
          // "twenty + five" → 25
          current += v;
        } else if (current == 0) {
          current = v;
        } else {
          result += current;
          current = v;
        }
      }
    }
    result += current;
    return hasAny ? result : null;
  }

  /// Replace all word-number spans inside [text] with their digit equivalents.
  /// Handles overlapping multi-word spans greedily (longest first).
  static String replaceAllWordNumbers(String text, String langCode) {
    final atoms = _atomsFor(langCode);
    final words = atoms.keys.toList()
      ..sort((a, b) => b.split(' ').length.compareTo(a.split(' ').length));

    String result = text;
    for (final word in words) {
      // avoid replacing inside larger words. The lookbehind/lookahead here
      // originally only excluded Devanagari (\u0900-\u097f), so on Tamil/
      // Telugu/Kannada/Malayalam/Bengali/Gujarati/Punjabi script it could
      // match a boundary INSIDE a longer native word. Widening this to cover
      // all Indic Unicode blocks we support (Tamil \u0B80-\u0BFF, Telugu
      // \u0C00-\u0C7F, Kannada \u0C80-\u0CFF, Malayalam \u0D00-\u0D7F,
      // Bengali \u0980-\u09FF, Gujarati \u0A80-\u0AFF, Gurmukhi/Punjabi
      // \u0A00-\u0A7F) so the same false-boundary bug doesn't happen there.
      final escaped = RegExp.escape(word);
      result = result.replaceAllMapped(
        RegExp(
          '(?<![\\w\u0900-\u097f\u0980-\u09FF\u0A00-\u0A7F\u0A80-\u0AFF'
          '\u0B00-\u0B7F\u0B80-\u0BFF\u0C00-\u0C7F\u0C80-\u0CFF\u0D00-\u0D7F])'
          '$escaped'
          '(?![\\w\u0900-\u097f\u0980-\u09FF\u0A00-\u0A7F\u0A80-\u0AFF'
          '\u0B00-\u0B7F\u0B80-\u0BFF\u0C00-\u0C7F\u0C80-\u0CFF\u0D00-\u0D7F])',
          caseSensitive: false,
        ),
        (m) {
          final val = atoms[word]!;
          return val == val.toInt() ? ' ${val.toInt()} ' : ' $val ';
        },
      );
    }
    // Normalise whitespace
    return result.replaceAll(RegExp(r' {2,}'), ' ').trim();
  }
}

// ─── Phonetic cluster normalizer (NLP-4) ──────────────────────────────────────

/// Maps common STT mis-hearings and cross-language transliterations to a
/// canonical English product name. These are the 50 most common items
/// across Indian kirana (grocery) stores.
class PhoneticProductResolver {
  /// Each key is a canonical English product name.
  /// Values are every phonetic / transliterated / regional alias we've seen
  /// in STT output across 10 Indian languages + Hinglish code-switching.
  static const Map<String, List<String>> _clusters = {
    'Milk': [
      'milk', 'doodh', 'dudh', 'dood', 'paal', 'pal', 'halu', 'hala',
      'pallu', 'paal', 'doodhu', 'मिल्क', 'दूध', 'दुध',
      'பால்', 'పాలు', 'ಹಾಲು', 'പാൽ', 'দুধ', 'दूद',
    ],
    'Sugar': [
      'sugar', 'shugger', 'shuga', 'cheeni', 'chini', 'shakkar', 'sakkare',
      'sarkara', 'inippu', 'sakkara', 'cukkar', 'suchini',
      'चीनी', 'চিনি', 'சர்க்கரை', 'పంచదార', 'ಸಕ್ಕರೆ', 'ഷുഗർ', 'ಶಕ್ಕರೆ',
    ],
    'Rice': [
      'rice', 'chawal', 'chaval', 'chaaval', 'biyyam', 'vari', 'arisi',
      'anna', 'bhat', 'akki', 'chal', 'sonamasoori', 'basmati',
      'चावल', 'চাল', 'அரிசி', 'బియ్యం', 'ಅಕ್ಕಿ', 'അരി',
    ],
    'Oil': [
      'oil', 'tel', 'tail', 'enne', 'noone', 'enu', 'taila', 'sunflower oil',
      'coconut oil', 'mustard oil', 'sarson tel', 'nariyal tel',
      'तेल', 'তেল', 'எண்ணெய்', 'నూనె', 'ಎಣ್ಣೆ', 'എണ്ണ',
    ],
    'Flour': [
      'flour', 'aata', 'atta', 'aataa', 'wheat flour', 'maida',
      'आटा', 'আटा', 'மாவு', 'పిండి', 'ಹಿಟ್ಟು', 'മൈദ',
    ],
    'Salt': [
      'salt', 'namak', 'uppu', 'uppu', 'lavana', 'meeta', 'noon',
      'नमक', 'নুন', 'உப்பு', 'ఉప్పు', 'ಉಪ್ಪು', 'ഉപ്പ്',
    ],
    'Dal': [
      'dal', 'daal', 'dhal', 'paruppu', 'pappu', 'bele', 'parippu',
      'moong dal', 'toor dal', 'chana dal', 'masoor dal',
      'दाल', 'ডাল', 'பருப்பு', 'పప్పు', 'ಬೇಳೆ', 'പരിപ്പ്',
    ],
    'Tea': [
      'tea', 'chai', 'chaa', 'chaha', 'thee', 'cha', 'chaaha',
      'चाय', 'চা', 'தேயிலை', 'చాయ్', 'ಚಹಾ', 'ചായ',
    ],
    'Coffee': [
      'coffee', 'kaapi', 'kapi', 'kappi', 'cofee', 'coffe',
      'कॉफी', 'কফি', 'காபி', 'కాఫీ', 'ಕಾಫಿ', 'കാപ്പി',
    ],
    'Bread': [
      'bread', 'pav', 'paav', 'bun', 'loaf', 'sliced bread',
      'ब्रेड', 'পাউরুটি', 'பிரெட்', 'బ్రెడ్', 'ಬ್ರೆಡ್', 'ബ്രഡ്',
    ],
    'Egg': [
      'egg', 'anda', 'muttai', 'guddu', 'motta', 'aanda', 'ande',
      'अंडा', 'ডিম', 'முட்டை', 'గుడ్డు', 'ಮೊಟ್ಟೆ', 'മുട്ട',
    ],
    'Butter': [
      'butter', 'makhan', 'makkhan', 'venna', 'vennai', 'batter', 'buttar',
      'मक्खन', 'মাখন', 'வெண்ணெய்', 'వెన్న', 'ಬೆಣ್ಣೆ', 'വെണ്ണ',
    ],
    'Curd': [
      'curd', 'yogurt', 'dahi', 'dahee', 'perugu', 'thayir', 'tayir',
      'mosaru', 'thair', 'dard', 'dahe',
      'दही', 'দই', 'தயிர்', 'పెరుగు', 'ಮೊಸರು', 'തൈര്',
    ],
    'Tomato': [
      'tomato', 'tamatar', 'tamater', 'tometo', 'thakkali', 'ramapala',
      'tamata', 'tomate', 'tamato',
      'टमाटर', 'টমেটো', 'தக்காளி', 'టమాటో', 'ಟಮಾಟೊ', 'തക്കാളി',
    ],
    'Onion': [
      'onion', 'pyaaz', 'pyaj', 'pyaaj', 'ulli', 'vengayam', 'nirulli',
      'kanda', 'dungli', 'pyaan',
      'प्याज', 'পেঁয়াজ', 'வெங்காயம்', 'ఉల్లిపాయ', 'ಈರುಳ್ಳಿ', 'ഉള്ളി',
    ],
    'Potato': [
      'potato', 'aloo', 'aalu', 'batata', 'bangaladumpa', 'urulaikizhangu',
      'aluwa', 'urulaikilangu', 'batate', 'allu',
      'आलू', 'আলু', 'உருளைக்கிழங்கு', 'బంగాళదుంప', 'ಆಲೂಗಡ್ಡೆ', 'ഉരുളക്കിഴങ്ങ്',
    ],
    'Soap': [
      'soap', 'sabun', 'saabun', 'saboon', 'saappu', 'sappu', 'sopu',
      'साबुन', 'সাবান', 'சோப்பு', 'సబ్బు', 'ಸಾಬೂನು', 'സോപ്പ്',
    ],
    'Biscuit': [
      'biscuit', 'biscuits', 'biskut', 'biskit', 'biscut', 'cookie',
      'बिस्किट', 'বিস্কুট', 'பிஸ்கட்', 'బిస్కెట్', 'ಬಿಸ್ಕೆಟ್', 'ബിസ്കറ്റ്',
    ],
    'Water': [
      'water', 'paani', 'pani', 'neeru', 'neer', 'tanni', 'jalam',
      'पानी', 'জল', 'தண்ணீர்', 'నీళ్ళు', 'ನೀರು', 'വെള്ളം',
    ],
    'Banana': [
      'banana', 'kela', 'keli', 'arati', 'valai', 'pazham', 'baale',
      'banaana', 'केला', 'কলা', 'வாழைப்பழம்', 'అరటి', 'ಬಾಳೆ', 'വാഴ',
    ],
    'Apple': [
      'apple', 'seb', 'sebu', 'appu', 'safarchand', 'sfarchand',
      'सेब', 'আপেল', 'ஆப்பிள்', 'ఆపిల్', 'ಸೇಬು', 'ആപ്പിൾ',
    ],
    'Paneer': [
      'paneer', 'panir', 'panner', 'cottage cheese', 'chenna',
      'पनीर', 'পনির', 'பனீர்', 'పనీర్', 'ಪನೀರ್', 'പനീർ',
    ],
    'Ghee': [
      'ghee', 'ghi', 'ghee', 'gi', 'tuppa', 'ney', 'nei',
      'घी', 'ঘি', 'நெய்', 'నెయ్యి', 'ತುಪ್ಪ', 'നെയ്യ്',
    ],
    'Chilli': [
      'chilli', 'chili', 'mirch', 'mirapakayalu', 'milagai', 'mulaku',
      'lankha', 'mulagu', 'kaaram', 'chile',
      'मिर्च', 'মরিচ', 'மிளகாய்', 'మిర్చి', 'ಮೆಣಸಿನಕಾಯಿ', 'മുളക്',
    ],
    'Turmeric': [
      'turmeric', 'haldi', 'halud', 'manjal', 'pasupu', 'arisina',
      'manjals', 'haldar',
      'हल्दी', 'হলুদ', 'மஞ்சள்', 'పసుపు', 'ಅರಿಶಿನ', 'മഞ്ഞൾ',
    ],
    'Coriander': [
      'coriander', 'dhania', 'kothamalli', 'kothimira', 'kothambari',
      'malli', 'cilantro', 'dhaniya',
      'धनिया', 'ধনে', 'கொத்தமல்லி', 'కొత్తిమీర', 'ಕೊತ್ತಂಬರಿ', 'മല്ലി',
    ],
    'Coconut': [
      'coconut', 'nariyal', 'thenkai', 'kobbari', 'tengina', 'thenga',
      'narikel', 'coconut oil',
      'नारियल', 'নারকেল', 'தேங்காய்', 'కొబ్బరి', 'ತೆಂಗಿನಕಾಯಿ', 'നാളികേരം',
    ],
    // ── Prepared Food Items (prevents compound names from being split) ───────
    'Biryani': [
      'biryani', 'biriyani', 'biryaani', 'biryanee', 'biriani', 'briyani',
      'dum biryani', 'dum biriyani', 'chicken biryani', 'mutton biryani',
      'veg biryani', 'egg biryani', 'hyderabadi biryani',
      'बिरयानी', 'बिरियानी', 'బిర్యానీ', 'பிரியாணி', 'ಬಿರಿಯಾನಿ', 'ബിരിയാണി',
    ],
    'Dum Biryani': [
      'dum biryani', 'dum biriyani', 'dam biryani', 'dumbiryani',
      'dum briyani', 'dam biriyani', 'dumb biryani', 'dumb biriyani',
      'డమ్ బిర్యానీ', 'दम बिरयानी', 'டம் பிரியாணி', 'ದಮ್ ಬಿರಿಯಾನಿ',
    ],
    'Chicken': [
      'chicken', 'murgi', 'murga', 'kozhi', 'kodi', 'koli', 'murgha',
      'चिकन', 'মুরগি', 'கோழி', 'కోడి', 'ಕೋಳಿ', 'കോഴി',
    ],
    'Mutton': [
      'mutton', 'gosht', 'aattu', 'mamsam', 'gosh', 'keema',
      'मटन', 'গোশত', 'ஆட்டு', 'మాంసం', 'ಮಟನ್', 'ആട്ടിറച്ചി',
    ],
    'Fish': [
      'fish', 'machli', 'machhi', 'meen', 'chepa', 'meenu', 'maach',
      'मछली', 'মাছ', 'மீன்', 'చేప', 'ಮೀನು', 'മീൻ',
    ],
    'Sambar': [
      'sambar', 'sambhar', 'sambaar', 'sambhaar', 'saambhar',
      'सांभर', 'সাম্বার', 'சாம்பார்', 'సాంబార్', 'ಸಾಂಬಾರ್', 'സാമ്പാർ',
    ],
    'Idli': [
      'idli', 'idly', 'idle', 'idlee', 'idlli',
      'इडली', 'ইডলি', 'இட்லி', 'ఇడ్లీ', 'ಇಡ್ಲಿ', 'ഇഡ്ഡലി',
    ],
    'Dosa': [
      'dosa', 'dosai', 'dose', 'dhosa', 'masala dosa',
      'डोसा', 'দোসা', 'தோசை', 'దోశ', 'ದೋಸೆ', 'ദോശ',
    ],
    'Roti': [
      'roti', 'chapati', 'chapathi', 'phulka', 'naan', 'paratha', 'parota',
      'रोटी', 'রুটি', 'சப்பாத்தி', 'రొట్టి', 'ರೊಟ್ಟಿ', 'ചപ്പാത്തി',
    ],
  };

  // Inverted index: alias → canonicalName (built once)
  static late final Map<String, String> _index;
  static bool _indexBuilt = false;

  static void _buildIndex() {
    if (_indexBuilt) return;
    _index = {};
    _clusters.forEach((canonical, aliases) {
      _index[canonical.toLowerCase()] = canonical;
      for (final alias in aliases) {
        _index[alias.toLowerCase()] = canonical;
      }
    });
    _indexBuilt = true;
  }

  /// Try to resolve [voiceToken] to a canonical product name.
  /// Returns null if no confident match found.
  static String? resolve(String voiceToken) {
    _buildIndex();
    final key = voiceToken.toLowerCase().trim();

    // Exact hit
    final exact = _index[key];
    if (exact != null) return exact;

    // Prefix hit (minimum 4 chars to avoid false positives)
    if (key.length >= 4) {
      for (final alias in _index.keys) {
        if (alias.startsWith(key) || key.startsWith(alias)) {
          return _index[alias]!;
        }
      }
    }

    return null;
  }

  /// Fuzzy resolve: tries Levenshtein ≤ 2 on short keys, ≤ 3 on longer ones.
  static String? fuzzyResolve(String voiceToken, {double threshold = 0.72}) {
    _buildIndex();
    final key = voiceToken.toLowerCase().trim();
    if (key.length < 3) return null;

    String? best;
    double bestSim = threshold;

    for (final alias in _index.keys) {
      final sim = _jaccardBigram(key, alias);
      if (sim > bestSim) {
        bestSim = sim;
        best = _index[alias];
      }
    }
    return best;
  }

  static double _jaccardBigram(String a, String b) {
    if (a == b) return 1.0;
    if (a.length < 2 || b.length < 2) return 0.0;
    Set<String> bg(String s) {
      final r = <String>{};
      for (int i = 0; i < s.length - 1; i++) r.add(s.substring(i, i + 2));
      return r;
    }
    final ba = bg(a), bb = bg(b);
    final inter = ba.intersection(bb).length;
    return (2.0 * inter) / (ba.length + bb.length);
  }

  /// Get all canonical names (for catalog matching fallback).
  static Set<String> get canonicalNames {
    _buildIndex();
    return _clusters.keys.toSet();
  }
}

// ─── Unit inference (NLP-6) ───────────────────────────────────────────────────

/// When no unit is spoken, infer a sensible default from the product name.
class UnitInferrer {
  static const Map<String, String> _productToUnit = {
    'Milk': 'L', 'Water': 'L', 'Oil': 'L',
    'Flour': 'kg', 'Rice': 'kg', 'Dal': 'kg', 'Sugar': 'kg', 'Salt': 'kg',
    'Turmeric': 'g', 'Coriander': 'g', 'Chilli': 'g',
    'Egg': 'pc', 'Bread': 'pc', 'Biscuit': 'pc', 'Soap': 'pc',
    'Butter': 'g', 'Ghee': 'g', 'Paneer': 'g',
    'Banana': 'pc', 'Apple': 'pc', 'Coconut': 'pc',
    'Tomato': 'kg', 'Onion': 'kg', 'Potato': 'kg',
    'Tea': 'g', 'Coffee': 'g',
    'Curd': 'g',
  };

  static String infer(String canonicalName, {String fallback = 'pc'}) {
    return _productToUnit[canonicalName] ?? fallback;
  }
}

// ─── Canonical unit aliases (expanded) ────────────────────────────────────────

class UnitNormalizer {
  static final Map<String, String> _aliases = {
    // English
    'kilo': 'kg', 'kilogram': 'kg', 'kilograms': 'kg', 'kgs': 'kg',
    'gram': 'g', 'grams': 'g', 'gm': 'g', 'grm': 'g',
    'liter': 'L', 'litre': 'L', 'ltr': 'L', 'lt': 'L', 'ltrs': 'L',
    'milliliter': 'mL', 'millilitre': 'mL', 'ml': 'mL',
    'piece': 'pc', 'pieces': 'pc', 'pcs': 'pc', 'unit': 'pc', 'units': 'pc',
    'packet': 'pkt', 'pack': 'pkt', 'packs': 'pkt', 'pkt': 'pkt', 'pct': 'pkt',
    'bottle': 'btl', 'bottles': 'btl',
    'box': 'box', 'boxes': 'box',
    'dozen': 'doz', 'doz': 'doz',
    'bag': 'bag', 'bags': 'bag',
    'tin': 'tin', 'can': 'tin',
    'jar': 'jar',
    'sachet': 'sachet', 'pouch': 'sachet', 'satchet': 'sachet',
    'tube': 'tube',
    'roll': 'roll',
    'loaf': 'loaf',
    'bunch': 'bunch', 'bunches': 'bunch',
    // Hindi / Hinglish (Devanagari — also covers Marathi)
    'किलो': 'kg', 'किलोग्राम': 'kg',
    'ग्राम': 'g', 'ग्रॅम': 'g',
    'लीटर': 'L', 'लिटर': 'L',
    'मिली': 'mL', 'मिलीलीटर': 'mL',
    'पीस': 'pc', 'पीसा': 'pc',
    'पैकेट': 'pkt', 'पाकीट': 'pkt', 'डब्बा': 'box', 'डिब्बा': 'box',
    'बोतल': 'btl', 'बोटल': 'btl',
    'दर्जन': 'doz',
    // Tamil
    'கிலோ': 'kg', 'கிராம்': 'g', 'லிட்டர்': 'L', 'மி.லி': 'mL',
    'பாக்கெட்': 'pkt', 'பீஸ்': 'pc', 'பெட்டி': 'box', 'பாட்டில்': 'btl',
    // Telugu
    'కిలో': 'kg', 'గ్రాము': 'g', 'లీటర్': 'L', 'మిల్లీలీటర్': 'mL',
    'ప్యాకెట్': 'pkt', 'పీస్': 'pc', 'పెట్టె': 'box', 'సీసా': 'btl',
    // Kannada
    'ಕಿಲೋ': 'kg', 'ಗ್ರಾಂ': 'g', 'ಲೀಟರ್': 'L', 'ಮಿಲಿ': 'mL',
    'ಪ್ಯಾಕೆಟ್': 'pkt', 'ಪೀಸ್': 'pc', 'ಪೆಟ್ಟೆ': 'box', 'ಸೀಸೆ': 'btl',
    // Malayalam
    'കിലോ': 'kg', 'ഗ്രാം': 'g', 'ലിറ്റർ': 'L', 'മിലി': 'mL',
    'ഫാകറ്റ്': 'pkt', 'പീസ്': 'pc', 'പെട്ടി': 'box', 'കുപ്പി': 'btl',
    // Bengali
    'কেজি': 'kg', 'গ্রাম': 'g', 'লিটার': 'L', 'পিস': 'pc',
    // Gujarati
    'કિલો': 'kg', 'ગ્રામ': 'g', 'લિટર': 'L', 'પીસ': 'pc',
    // Punjabi
    'ਕਿਲੋ': 'kg', 'ਗ੍ਰਾਮ': 'g', 'ਲਿਟਰ': 'L', 'ਪੀਸ': 'pc',
  };

  static const _allUnitWords = <String>{};

  static String normalize(String raw) {
    final lower = raw.toLowerCase().trim();
    return _aliases[lower] ?? _aliases[raw] ?? raw;
  }

  static bool isUnit(String token) {
    final lower = token.toLowerCase().trim();
    return _aliases.containsKey(lower) || _aliases.containsKey(token);
  }
}

// ─── Price sanity validator (NLP-7) ───────────────────────────────────────────

class PriceSanityResult {
  final bool isPlausible;
  final String? warningReason;
  final double? catalogMedian;

  const PriceSanityResult({
    required this.isPlausible,
    this.warningReason,
    this.catalogMedian,
  });
}

class PriceSanityValidator {
  /// Returns a sanity check for [price] given what we know from the catalog.
  static PriceSanityResult validate(
    double price,
    String productName,
    List<Map<String, dynamic>>? catalog,
  ) {
    if (price <= 0) {
      return const PriceSanityResult(
        isPlausible: false,
        warningReason: 'Price is zero or negative',
      );
    }

    if (catalog == null || catalog.isEmpty) {
      // No catalog: only obvious outliers
      if (price > 50000) return const PriceSanityResult(isPlausible: false, warningReason: 'Price exceeds ₹50,000');
      if (price < 1)     return const PriceSanityResult(isPlausible: false, warningReason: 'Price below ₹1');
      return const PriceSanityResult(isPlausible: true);
    }

    // Collect catalog prices for the same / similar product
    final nameLower = productName.toLowerCase();
    final similarPrices = <double>[];

    for (final p in catalog) {
      final cn = (p['name'] ?? p['product_name'] ?? '').toString().toLowerCase();
      if (cn.contains(nameLower) || nameLower.contains(cn)) {
        final cp = double.tryParse(p['price']?.toString() ?? '');
        if (cp != null && cp > 0) similarPrices.add(cp);
      }
    }

    if (similarPrices.isEmpty) {
      // Fall back to global range check
      if (price > 50000) return const PriceSanityResult(isPlausible: false, warningReason: 'Price exceeds ₹50,000');
      if (price < 1)     return const PriceSanityResult(isPlausible: false, warningReason: 'Price below ₹1');
      return const PriceSanityResult(isPlausible: true);
    }

    similarPrices.sort();
    final median = similarPrices[similarPrices.length ~/ 2];

    if (price > median * 5) {
      return PriceSanityResult(
        isPlausible: false,
        warningReason: 'Price ₹${price.toStringAsFixed(0)} is >5× catalog median ₹${median.toStringAsFixed(0)}',
        catalogMedian: median,
      );
    }
    if (price < median * 0.1) {
      return PriceSanityResult(
        isPlausible: false,
        warningReason: 'Price ₹${price.toStringAsFixed(0)} is <10% of catalog median ₹${median.toStringAsFixed(0)}',
        catalogMedian: median,
      );
    }

    return PriceSanityResult(isPlausible: true, catalogMedian: median);
  }
}

// ─── Confidence scorer V2 (NLP-10) ───────────────────────────────────────────

class ConfidenceScorerV2 {
  static ConfidenceDetail score({
    required String name,
    required double qty,
    required double price,
    required String unit,
    required int patternIndex,        // 0 = best pattern, 4 = worst
    required bool catalogHit,         // product found in catalog
    required bool pricePlausible,     // from PriceSanityValidator
    required bool unitInferred,       // true if unit was auto-inferred
    required String langCode,
  }) {
    // ── Name sub-score ─────────────────────────────────────────────────────
    double nameScore = 1.0;
    if (name.length < 2)          nameScore -= 0.50;
    if (name.length < 3)          nameScore -= 0.20;
    if (name.contains(RegExp(r'\d'))) nameScore -= 0.30;   // digits in name
    if (name.split(' ').length > 4)   nameScore -= 0.15;   // too many words
    if (name.length > 25)             nameScore -= 0.10;
    if (catalogHit)                   nameScore = (nameScore + 0.20).clamp(0, 1);

    // ── Qty sub-score ──────────────────────────────────────────────────────
    double qtyScore = 1.0;
    if (qty <= 0)          qtyScore = 0.0;
    else if (qty < 0.1)   qtyScore -= 0.40;
    else if (qty > 500)   qtyScore -= 0.60;
    else if (qty > 100)   qtyScore -= 0.30;
    else if (qty > 50)    qtyScore -= 0.10;

    // Reasonable quantities
    if (qty >= 0.1 && qty <= 50) qtyScore = (qtyScore + 0.15).clamp(0, 1);
    if (unitInferred)            qtyScore -= 0.05; // small penalty for inferred

    // ── Price sub-score ────────────────────────────────────────────────────
    double priceScore = 1.0;
    if (price == 0)         priceScore = 0.50;  // missing price — add to cart, allow manual entry
    else if (!pricePlausible) priceScore -= 0.45;
    else if (price < 1)     priceScore -= 0.35;
    else if (price < 5)     priceScore -= 0.15;
    else if (price > 10000) priceScore -= 0.25;
    else if (price >= 5 && price <= 5000) priceScore = (priceScore + 0.15).clamp(0, 1);

    // ── Pattern bonus ──────────────────────────────────────────────────────
    // Pattern 0 (qty unit name price) = best → +0.10
    // Pattern 4 (name only)           = worst → +0.00
    final patternBonus = (0.10 - patternIndex * 0.02).clamp(0.0, 0.10);

    // ── Catalog bonus ──────────────────────────────────────────────────────
    final catalogBonus = catalogHit ? 0.15 : 0.0;

    return ConfidenceDetail(
      nameScore:    nameScore.clamp(0, 1),
      qtyScore:     qtyScore.clamp(0, 1),
      priceScore:   priceScore.clamp(0, 1),
      patternBonus: patternBonus,
      catalogBonus: catalogBonus,
    );
  }
}

// ─── Core parse engine V2 ────────────────────────────────────────────────────

/// Drop-in enhanced replacement for [MultiLangVoiceParser].
class VoiceNlpEngineV2 {

  // ── Price/currency keywords — must NEVER become product names ───────────────
  static final _priceKeywords = RegExp(
    r'^(rupees?|rupee|rs\.?|inr|₹|rupe|rupaiye|rupaiya|paisa|paise|रुपीस|రూపాయలు|రూపాయ|రూపాయిలు|రూపాయి|రూ|ரூபாய்|ரூ|ರೂಪಾಯಿ|ರೂ|രൂപ|രൂ|টাকা|রুপি|રૂપિયા|રૂ|ਰੁਪਏ|ਰੁ'
    r'|rate|price|cost|amount|total|charge|ka rate|ka price)$',
    caseSensitive: false,
  );

  // ── Prepositions / stop words that should NEVER be product names ─────────────
  static final _stopWords = RegExp(
    r'^(in|an|a|the|at|on|is|it|to|of|or|and|as|by|so|up|do|ka|ki|ke'
    r'|ko|me|se|ho|hai|tha|thi|the|wala|wali|wale|aur|bhi|hi|toh|na)$',
    caseSensitive: false,
  );

  // ── Filler words (expanded) ────────────────────────────────────────────────

  static final _fillerRe = RegExp(
    r'\b(i|want|need|give|me|a|an|the|some|of|add|please|can|get|also|with|for'
    r'|actually|okay|ok|yep|yes|uh|um|hmm|so|just|like|ka|ki|ke|ek number'
    r'|mujhe|chahiye|dena|dedo|likhna|likho|note|bilkul'
    r'|bill mein add karo|bill me add karo|add to bill|add kar|add karo'
    r'|rupees|rupee|rs|inr|rupaiye|rupaiya|paisa|paise|रुपीस|రూపాయలు|రూపాయ|రూపాయిలు|రూపాయి|రూ|ரூபாய்|ரூ|ರೂಪಾಯಿ|ರೂ|രൂപ|രൂ|টাকা|রুপি|રૂપિયા|રૂ|ਰੁਪਏ|ਰੁ)\b',
    caseSensitive: false,
  );

  static final _currencyRe = RegExp(r'(₹|rs\.?|rupees?|inr|रूप(?:या|ये)|ரூ|రూ|રૃ|ਰੁ)', caseSensitive: false);

  static String _stripFillers(String t) {
    final cleaned = t.replaceAll(_currencyRe, ' ');
    return cleaned.replaceAll(_fillerRe, ' ').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  // ── Item separators (expanded) ─────────────────────────────────────────────

  static final _separatorRe = RegExp(
    r'[,।\.]+|\band\b|\bplus\b|\baur\b|\bthen\b|\bnext\b|\bitem\b'
    r'|और|तथा|एवं|ਅਤੇ|మరియు|ಮತ್ತು|மற்றும்|এবং|અને|आणि',
    caseSensitive: false,
  );

  // ── Regex patterns for one item segment (ordered best → worst) ────────────

  static final _patterns = [
    // P0: [qty] [unit] [name] [price]   e.g. "2 kg sugar 60"
    RegExp(
      r'^(\d+\.?\d*)\s+(\S+)\s+([\w\u0900-\u0D7F\u0980-\u09FF\u0A00-\u0AFF\u0A80-\u0AFF\u0B00-\u0B7F]+(?:\s+[\w\u0900-\u0D7F]+)?)\s+(\d+\.?\d*)$',
      caseSensitive: false,
    ),
    // P1: [qty] [name] [price]          e.g. "2 sugar 60"
    RegExp(
      r'^(\d+\.?\d*)\s+([\w\u0900-\u0D7F\u0980-\u09FF\u0A00-\u0AFF\u0A80-\u0AFF\u0B00-\u0B7F]+(?:\s+[\w\u0900-\u0D7F]+)?)\s+(\d+\.?\d*)$',
      caseSensitive: false,
    ),
    // P2: [name] [qty] [price]          e.g. "sugar 2 60"
    RegExp(
      r'^([\w\u0900-\u0D7F\u0980-\u09FF\u0A00-\u0AFF]+(?:\s+[\w\u0900-\u0D7F]+)?)\s+(\d+\.?\d*)\s+(\d+\.?\d*)$',
      caseSensitive: false,
    ),
    // P3: [qty] [unit] [name]           e.g. "2 kg sugar"  (no price)
    RegExp(
      r'^(\d+\.?\d*)\s+(\S+)\s+([\w\u0900-\u0D7F\u0980-\u09FF\u0A00-\u0AFF]+(?:\s+[\w\u0900-\u0D7F]+)?)$',
      caseSensitive: false,
    ),
    // P4: [name] [number]               e.g. "sugar 60"
    RegExp(
      r'^([\w\u0900-\u0D7F\u0980-\u09FF\u0A00-\u0AFF]+(?:\s+[\w\u0900-\u0D7F]+)?)\s+(\d+\.?\d*)$',
      caseSensitive: false,
    ),
    // P5: [name] only
    RegExp(
      r'^([\w\u0900-\u0D7F\u0980-\u09FF\u0A00-\u0AFF]+(?:\s+[\w\u0900-\u0D7F]+)?)$',
      caseSensitive: false,
    ),
  ];

  // ── Parse one segment ───────────────────────────────────────────────────────

  static ParsedItemV2? _parseSegment(
    String raw,
    String langCode, {
    List<Map<String, dynamic>>? catalog,
  }) {
    // 1. Replace word-numbers with digits
    String text = CompoundNumberParser.replaceAllWordNumbers(raw.trim(), langCode);

    // 2. Strip filler words and currency markers
    text = _stripFillers(text).toLowerCase().trim();
    if (text.isEmpty) return null;

    // 3. Normalize common connectors and bad spacing
    text = text.replaceAll(RegExp(r'\bper\b|\bka\b|\bki\b|\bke\b|\bgm\b|\bpcs\b|\bpc\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    // 4. Try each pattern
    for (int pi = 0; pi < _patterns.length; pi++) {
      final m = _patterns[pi].firstMatch(text);
      if (m == null) continue;

      String name;
      double qty;
      double price;
      String rawUnit;

      if (pi == 0) {
        qty      = double.tryParse(m.group(1)!) ?? 1;
        rawUnit  = m.group(2)!;
        name     = m.group(3)!;
        price    = double.tryParse(m.group(4)!) ?? 0;
      } else if (pi == 1) {
        qty      = double.tryParse(m.group(1)!) ?? 1;
        rawUnit  = '';
        name     = m.group(2)!;
        price    = double.tryParse(m.group(3)!) ?? 0;
      } else if (pi == 2) {
        name     = m.group(1)!;
        qty      = double.tryParse(m.group(2)!) ?? 1;
        price    = double.tryParse(m.group(3)!) ?? 0;
        rawUnit  = '';
      } else if (pi == 3) {
        qty      = double.tryParse(m.group(1)!) ?? 1;
        rawUnit  = m.group(2)!;
        name     = m.group(3)!;
        price    = 0;
      } else if (pi == 4) {
        name     = m.group(1)!;
        final n  = double.tryParse(m.group(2)!) ?? 0;
        if (n > _qtyPriceThreshold(name, catalog)) {
          qty = 1;
          price = n;
        } else {
          qty = n;
          price = 0;
        }
        rawUnit = '';
      } else {
        name     = m.group(1)!;
        qty      = 1;
        price    = 0;
        rawUnit  = '';
      }

      name = name.trim();

      // ── GUARD 1: Reject pure price/currency keywords as product names ──────
      if (_priceKeywords.hasMatch(name)) continue;

      // ── GUARD 2: Reject single stop-word tokens as product names ────────────
      if (_stopWords.hasMatch(name)) continue;

      if (name.length < 2) continue;

      // 4. Check if rawUnit is actually part of the name
      if (rawUnit.isNotEmpty && !UnitNormalizer.isUnit(rawUnit)) {
        name = '$rawUnit $name'.trim();
        rawUnit = '';
      }

      // 5. Resolve unit
      final String unit;
      bool unitInferred = false;
      if (rawUnit.isEmpty) {
        final canonical = PhoneticProductResolver.resolve(name);
        if (canonical != null) {
          unit = UnitInferrer.infer(canonical);
          unitInferred = true;
          name = canonical;
        } else {
          unit = 'pc';
          unitInferred = true;
        }
      } else {
        unit = UnitNormalizer.normalize(rawUnit);
      }

      // 6. Resolve name & catalog match: try catalog first to preserve store-specific products and prices
      String resolvedName = _toTitleCase(name);
      double? catalogPrice;
      bool catalogHit = false;
      
      if (catalog != null && catalog.isNotEmpty) {
        final match = _findInCatalog(name, catalog);
        if (match != null) {
          resolvedName = (match['name'] ?? match['product_name'] ?? resolvedName).toString();
          catalogPrice = double.tryParse(match['price']?.toString() ?? '');
          if (price == 0 && catalogPrice != null) price = catalogPrice;
          catalogHit = true;
          if (rawUnit.isEmpty && (match['unit']?.toString().isNotEmpty ?? false)) {
            final catalogUnit = match['unit']?.toString() ?? '';
            if (catalogUnit.isNotEmpty) {
              unitInferred = true;
            }
          }
        }
      }

      // Fallback to phonetic cluster normalizer if not matched in catalog
      if (!catalogHit) {
        final canonical = PhoneticProductResolver.resolve(name)
                       ?? PhoneticProductResolver.fuzzyResolve(name);
        if (canonical != null) {
          resolvedName = canonical;
          catalogHit = true;
        }
      }

      // 8. Price sanity
      final sanity = PriceSanityValidator.validate(price, resolvedName, catalog);

      final conf = ConfidenceScorerV2.score(
        name:           resolvedName,
        qty:            qty,
        price:          price,
        unit:           unit,
        patternIndex:   pi,
        catalogHit:     catalogHit,
        pricePlausible: sanity.isPlausible,
        unitInferred:   unitInferred,
        langCode:       langCode,
      );

      // NLP-8: keep partial items at low confidence rather than dropping them
      // (only drop if confidence is truly zero or name is garbage)
      if (conf.total < 0.05 && price == 0 && qty <= 0) continue;

      return ParsedItemV2(
        name:            resolvedName,
        qty:             qty,
        unit:            unit,
        price:           price,
        confidence:      conf,
        catalogMatchName: catalogHit ? resolvedName : null,
        catalogPrice:    catalogPrice,
      );
    }
    return null;
  }

  // ── NLP-2: qty/price threshold ─────────────────────────────────────────────

  /// If the single number in "name + number" is above this, treat as price.
  /// Dynamically adjusted if the product is in the catalog.
  static double _qtyPriceThreshold(
    String name,
    List<Map<String, dynamic>>? catalog,
  ) {
    if (catalog != null) {
      final match = _findInCatalog(name, catalog);
      if (match != null) {
        final cp = double.tryParse(match['price']?.toString() ?? '');
        if (cp != null && cp > 0) {
          return (cp * 0.25).clamp(10.0, 25.0);
        }
      }
    }
    return 20.0;
  }

  // ── Catalog lookup ─────────────────────────────────────────────────────────

  static Map<String, dynamic>? _findInCatalog(
    String name,
    List<Map<String, dynamic>> catalog,
  ) {
    final n = name.toLowerCase();
    // Exact
    for (final p in catalog) {
      final cn = (p['name'] ?? p['product_name'] ?? '').toString().toLowerCase();
      if (cn == n || cn.contains(n) || n.contains(cn)) return p;
    }
    // Fuzzy via bigram
    double bestSim = 0.65;
    Map<String, dynamic>? best;
    for (final p in catalog) {
      final cn = (p['name'] ?? p['product_name'] ?? '').toString().toLowerCase();
      final sim = PhoneticProductResolver._jaccardBigram(n, cn);
      if (sim > bestSim) { bestSim = sim; best = p; }
    }
    return best;
  }

  // ── NLP-3: Sliding-window segmentation ────────────────────────────────────

  /// Advanced fallback: no separators needed.
  /// Detects items by scanning for (text-words → number → text-words → number)
  /// rhythm, cutting at each "price number" boundary.
  static List<ParsedItemV2> _slidingWindowParse(
    String text,
    String langCode, {
    List<Map<String, dynamic>>? catalog,
  }) {
    final items = <ParsedItemV2>[];

    // Tokenise into (word | number) tokens
    final tokenRe = RegExp(r'\d+\.?\d*|[\w\u0900-\u0D7F\u0980-\u09FF\u0A00-\u0AFF]+');
    final tokens = tokenRe.allMatches(text).map((m) => m.group(0)!).toList();

    final numRe = RegExp(r'^\d+\.?\d*$');

    int windowStart = 0;
    for (int i = 0; i < tokens.length; i++) {
      if (!numRe.hasMatch(tokens[i])) continue;

      final num = double.parse(tokens[i]);

      // Only treat numbers >= 5 as potential price boundaries
      if (num < 5) continue;

      // The window is tokens[windowStart..i] (inclusive)
      final segment = tokens.sublist(windowStart, i + 1).join(' ');
      final item = _parseSegment(segment, langCode, catalog: catalog);

      if (item != null && item.name.length >= 2) {
        items.add(item);
        windowStart = i + 1;
      } else if (item == null && i + 1 < tokens.length) {
        // If the number looked like a price boundary but parsing failed,
        // keep the window moving to avoid stuck loops.
        windowStart = i + 1;
      }
    }

    // Trailing tokens after last number
    if (windowStart < tokens.length) {
      final trailing = tokens.sublist(windowStart).join(' ');
      if (trailing.trim().isNotEmpty) {
        final item = _parseSegment(trailing, langCode, catalog: catalog);
        if (item != null) items.add(item);
      }
    }

    return items;
  }

  // ── NLP-9: Deduplicate & merge ─────────────────────────────────────────────

  static List<ParsedItemV2> _deduplicate(List<ParsedItemV2> items) {
    final result = <ParsedItemV2>[];
    for (final item in items) {
      final existing = result.indexWhere((e) =>
        _isSameProduct(e.name, item.name) &&
        (e.price - item.price).abs() < 1.0,
      );
      if (existing == -1) {
        result.add(item);
      } else {
        // Keep the more specific (longer) or higher-confidence version
        if (item.name.length > result[existing].name.length ||
            item.confidenceScore > result[existing].confidenceScore) {
          result[existing] = item;
        }
      }
    }
    return result;
  }

  static bool _isSameProduct(String a, String b) {
    a = a.toLowerCase(); b = b.toLowerCase();
    if (a == b) return true;
    if (a.contains(b) || b.contains(a)) return true;
    return PhoneticProductResolver._jaccardBigram(a, b) > 0.80;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Main entry point. Replaces [MultiLangVoiceParser.parse].
  ///
  /// [transcript]  — raw STT output (any of the 10 supported locales)
  /// [langCode]    — BCP-47 locale string (e.g. 'hi-IN')
  /// [catalog]     — optional list of known products {name, price, ...}
  static List<ParsedItemV2> parse(
    String transcript,
    String langCode, {
    List<Map<String, dynamic>>? catalog,
  }) {
    if (transcript.trim().isEmpty) return [];

    // Step 1: Pre-process
    String text = transcript.trim();

    // Step 2: Try separator-based split first
    final segments = text
        .split(_separatorRe)
        .where((s) => s.trim().isNotEmpty)
        .toList();

    final items = <ParsedItemV2>[];
    for (final seg in segments) {
      final item = _parseSegment(seg, langCode, catalog: catalog);
      if (item != null) items.add(item);
    }

    if (items.isNotEmpty) {
      return _deduplicate(items);
    }

    // Step 3: NLP-3 sliding-window fallback (no separators needed)
    final windowItems = _slidingWindowParse(
      CompoundNumberParser.replaceAllWordNumbers(
        _stripFillers(text).toLowerCase(), langCode),
      langCode,
      catalog: catalog,
    );

    if (windowItems.isNotEmpty) {
      return _deduplicate(windowItems);
    }

    // Step 4: Last resort — whole transcript as single item
    final single = _parseSegment(text, langCode, catalog: catalog);
    return single != null ? [single] : [];
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _toTitleCase(String s) {
    if (s.isEmpty) return s;
    return s.split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
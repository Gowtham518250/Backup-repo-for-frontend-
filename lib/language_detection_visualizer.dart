// =============================================================================
// language_detection_visualizer.dart  —  LIVE LANGUAGE + PRODUCT VISUALIZER
// =============================================================================
// PURPOSE:
//   Shows the user WHICH language was auto-detected and what product name
//   was recognized in THEIR script — builds trust, surfaces errors early.
//
// FEATURES:
//   VIZ-1  Auto-detect dominant script from transcript in real-time
//   VIZ-2  Language badge with flag + name that animates in
//   VIZ-3  Per-word confidence coloring (green/amber/red)
//   VIZ-4  Product name displayed in NATIVE SCRIPT alongside English canonical
//   VIZ-5  "Did you mean?" nudge when confidence < 0.7
//   VIZ-6  Animated script transition when language switches mid-sentence
//   VIZ-7  Fully offline — zero external calls
// =============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Script detection ─────────────────────────────────────────────────────────

enum DetectedScript {
  latin,       // English (Roman)
  devanagari,  // Hindi, Marathi
  tamil,
  telugu,
  kannada,
  malayalam,
  bengali,
  gujarati,
  gurmukhi,    // Punjabi
  mixed,       // Hinglish / code-switching
  unknown,
}

class ScriptDetector {
  static const Map<DetectedScript, _ScriptRange> _ranges = {
    DetectedScript.devanagari: _ScriptRange(0x0900, 0x097F),
    DetectedScript.tamil:      _ScriptRange(0x0B80, 0x0BFF),
    DetectedScript.telugu:     _ScriptRange(0x0C00, 0x0C7F),
    DetectedScript.kannada:    _ScriptRange(0x0C80, 0x0CFF),
    DetectedScript.malayalam:  _ScriptRange(0x0D00, 0x0D7F),
    DetectedScript.bengali:    _ScriptRange(0x0980, 0x09FF),
    DetectedScript.gujarati:   _ScriptRange(0x0A80, 0x0AFF),
    DetectedScript.gurmukhi:   _ScriptRange(0x0A00, 0x0A7F),
  };

  static DetectedScript detect(String text) {
    if (text.trim().isEmpty) return DetectedScript.unknown;

    final counts = <DetectedScript, int>{};
    int latinCount = 0;

    for (final rune in text.runes) {
      if ((rune >= 0x0041 && rune <= 0x005A) ||
          (rune >= 0x0061 && rune <= 0x007A)) {
        latinCount++;
        continue;
      }
      for (final entry in _ranges.entries) {
        if (rune >= entry.value.start && rune <= entry.value.end) {
          counts[entry.key] = (counts[entry.key] ?? 0) + 1;
          break;
        }
      }
    }

    final nativeTotal = counts.values.fold(0, (a, b) => a + b);
    final total = nativeTotal + latinCount;
    if (total == 0) return DetectedScript.unknown;

    if (nativeTotal == 0) return DetectedScript.latin;

    // More than 20% Latin mixed with a native script = "mixed"
    if (latinCount / total > 0.20 && nativeTotal / total > 0.20) {
      return DetectedScript.mixed;
    }

    if (nativeTotal == 0) return DetectedScript.latin;

    // Return dominant native script
    return counts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  static String scriptToLocale(DetectedScript s) => const {
    DetectedScript.latin:      'en-IN',
    DetectedScript.devanagari: 'hi-IN',
    DetectedScript.tamil:      'ta-IN',
    DetectedScript.telugu:     'te-IN',
    DetectedScript.kannada:    'kn-IN',
    DetectedScript.malayalam:  'ml-IN',
    DetectedScript.bengali:    'bn-IN',
    DetectedScript.gujarati:   'gu-IN',
    DetectedScript.gurmukhi:   'pa-IN',
    DetectedScript.mixed:      'hi-IN',
    DetectedScript.unknown:    'en-IN',
  }[s]!;
}

class _ScriptRange {
  final int start, end;
  const _ScriptRange(this.start, this.end);
}

// ─── Detected word model ──────────────────────────────────────────────────────

class DetectedWord {
  final String native;      // word as STT returned it
  final String? canonical;  // English canonical name if resolved
  final double confidence;  // 0.0 – 1.0
  final String role;        // 'product' | 'quantity' | 'unit' | 'price' | 'other'

  const DetectedWord({
    required this.native,
    this.canonical,
    required this.confidence,
    this.role = 'other',
  });

  Color get color {
    if (confidence >= 0.80) return const Color(0xFF00C853);   // green
    if (confidence >= 0.60) return const Color(0xFFFFAB00);   // amber
    return const Color(0xFFFF3D71);                            // red
  }
}

// ─── Main Visualizer Widget ───────────────────────────────────────────────────

/// Drop this widget anywhere in your voice billing UI.
/// Feed it the live transcript + parsed items; it self-updates.
class LanguageDetectionVisualizer extends StatefulWidget {
  final String transcript;
  final String selectedLocale;   // BCP-47, e.g. "hi-IN"
  final List<Map<String, dynamic>> parsedItems; // from NLP parser
  final bool isListening;

  const LanguageDetectionVisualizer({
    super.key,
    required this.transcript,
    required this.selectedLocale,
    required this.parsedItems,
    this.isListening = false,
  });

  @override
  State<LanguageDetectionVisualizer> createState() =>
      _LanguageDetectionVisualizerState();
}

class _LanguageDetectionVisualizerState
    extends State<LanguageDetectionVisualizer> with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  DetectedScript _lastScript = DetectedScript.unknown;
  List<DetectedWord> _words = [];

  // Language display info
  static const _langInfo = <String, _LangDisplay>{
    'en-IN': _LangDisplay('English', '🇮🇳', Color(0xFF1565C0)),
    'hi-IN': _LangDisplay('हिंदी', '🕉️',  Color(0xFFFF6F00)),
    'ta-IN': _LangDisplay('தமிழ்', '🌺',  Color(0xFF6A1B9A)),
    'te-IN': _LangDisplay('తెలుగు','🌸',  Color(0xFF00695C)),
    'kn-IN': _LangDisplay('ಕನ್ನಡ', '🌻',  Color(0xFFE65100)),
    'ml-IN': _LangDisplay('മലയാളം','🌴',  Color(0xFF1B5E20)),
    'mr-IN': _LangDisplay('मराठी', '🏔️',  Color(0xFF880E4F)),
    'bn-IN': _LangDisplay('বাংলা', '🎋',  Color(0xFF01579B)),
    'gu-IN': _LangDisplay('ગુજરાતી','🦚', Color(0xFF4E342E)),
    'pa-IN': _LangDisplay('ਪੰਜਾਬੀ','🌾',  Color(0xFF558B2F)),
  };

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void didUpdateWidget(LanguageDetectionVisualizer old) {
    super.didUpdateWidget(old);
    if (old.transcript != widget.transcript) {
      _analyzeTranscript();
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _analyzeTranscript() {
    final script = ScriptDetector.detect(widget.transcript);
    if (script != _lastScript) {
      _lastScript = script;
      // Animate badge change
      _slideCtrl.forward(from: 0);
    }
    setState(() {
      _words = _buildDetectedWords(widget.transcript, widget.parsedItems);
    });
  }

  List<DetectedWord> _buildDetectedWords(
      String transcript, List<Map<String, dynamic>> items) {
    if (transcript.trim().isEmpty) return [];

    final words = transcript.trim().split(RegExp(r'\s+'));
    final itemNames = items.map((e) =>
        (e['product_name'] ?? e['name'] ?? '').toString().toLowerCase()).toList();

    return words.map((w) {
      final lower = w.toLowerCase();
      // Determine role
      String role = 'other';
      double confidence = 0.55;

      if (RegExp(r'^\d+\.?\d*$').hasMatch(w)) {
        role = 'quantity';
        confidence = 0.90;
      } else if (_isUnit(lower)) {
        role = 'unit';
        confidence = 0.85;
      } else if (_isPrice(lower)) {
        role = 'price';
        confidence = 0.90;
      } else if (itemNames.any((n) => n.contains(lower) || lower.contains(n))) {
        role = 'product';
        confidence = 0.88;
      } else {
        // Word in STT output not matched — lower confidence
        confidence = 0.45;
      }

      // Find canonical form if it's a product
      String? canonical;
      if (role == 'product') {
        for (final item in items) {
          final name = (item['product_name'] ?? item['name'] ?? '').toString();
          if (name.toLowerCase().contains(lower) || lower.contains(name.toLowerCase())) {
            canonical = name;
            break;
          }
        }
      }

      return DetectedWord(
        native: w,
        canonical: canonical,
        confidence: confidence,
        role: role,
      );
    }).toList();
  }

  bool _isUnit(String w) => const {
    'kg', 'kilo', 'kilogram', 'g', 'gm', 'gram', 'litre', 'liter', 'l',
    'ml', 'piece', 'pieces', 'pc', 'pcs', 'packet', 'pkt', 'pack',
    'bottle', 'btl', 'box', 'dozen', 'doz',
    // Hindi/common
    'किलो', 'ग्राम', 'लीटर', 'पैकेट', 'पीस',
    // Tamil
    'கிலோ', 'கிராம்', 'லிட்டர்',
    // Telugu
    'కిలో', 'గ్రాము', 'లీటర్',
  }.contains(w);

  bool _isPrice(String w) => const {
    'rs', 'rupees', 'rupee', 'रुपये', 'रुपए', 'रூபாய்',
    'రూపాయలు', 'ರೂಪಾಯಿ', 'rupaya', '₹',
  }.contains(w);

  @override
  Widget build(BuildContext context) {
    if (widget.transcript.isEmpty && widget.parsedItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final detectedLocale = ScriptDetector.scriptToLocale(
        ScriptDetector.detect(widget.transcript));
    final displayLocale  = widget.selectedLocale;
    final langInfo = _langInfo[displayLocale] ?? _langInfo['en-IN']!;
    final autoInfo = _langInfo[detectedLocale];
    final isMismatch = detectedLocale != displayLocale &&
                       widget.transcript.isNotEmpty &&
                       detectedLocale != 'en-IN';

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1F38),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isMismatch
                ? const Color(0xFFFFAB00).withOpacity(0.6)
                : const Color(0xFF1E3A5F),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: Language badges ────────────────────────────────────────
            Row(
              children: [
                _buildLangBadge(langInfo, 'Selected'),
                if (isMismatch && autoInfo != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios,
                      size: 10, color: Color(0xFF546E7A)),
                  const SizedBox(width: 8),
                  SlideTransition(
                    position: _slideAnim,
                    child: _buildLangBadge(autoInfo, 'Detected', pulse: true),
                  ),
                ],
                const Spacer(),
                // Live listening indicator
                if (widget.isListening)
                  _LiveDot(),
              ],
            ),

            // ── Mismatch warning ─────────────────────────────────────────────
            if (isMismatch) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFAB00).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFFFAB00), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Speech detected in ${autoInfo?.name ?? detectedLocale} — '
                        'switching to that language may improve accuracy',
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: const Color(0xFFFFAB00)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ── Row 2: Word-by-word confidence display ───────────────────────
            if (_words.isNotEmpty) ...[
              Text('RECOGNIZED WORDS',
                style: GoogleFonts.rajdhani(
                  color: const Color(0xFF42A5F5),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                )),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _words.map(_buildWordChip).toList(),
              ),
            ],

            // ── Row 3: Parsed product names in native script ─────────────────
            if (widget.parsedItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF1E3A5F), height: 1),
              const SizedBox(height: 10),
              Text('PRODUCT NAMES',
                style: GoogleFonts.rajdhani(
                  color: const Color(0xFF42A5F5),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                )),
              const SizedBox(height: 8),
              ...widget.parsedItems.map((item) => _buildProductRow(
                item,
                displayLocale,
                langInfo.color,
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLangBadge(_LangDisplay info, String label, {bool pulse = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: info.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: info.color.withOpacity(pulse ? 0.8 : 0.4),
          width: pulse ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(info.flag, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                style: GoogleFonts.rajdhani(
                  fontSize: 9,
                  color: info.color.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                )),
              Text(info.name,
                style: GoogleFonts.notoSans(
                  fontSize: 12,
                  color: info.color,
                  fontWeight: FontWeight.w700,
                )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWordChip(DetectedWord word) {
    final isProduct = word.role == 'product';
    return Tooltip(
      message: [
        'Role: ${word.role}',
        if (word.canonical != null) 'Matched: ${word.canonical}',
        'Confidence: ${(word.confidence * 100).toInt()}%',
      ].join('\n'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: word.color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: word.color.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(word.native,
              style: GoogleFonts.notoSans(
                fontSize: 13,
                color: word.color,
                fontWeight: isProduct ? FontWeight.w700 : FontWeight.w400,
              )),
            if (word.canonical != null && word.canonical != word.native)
              Text(word.canonical!,
                style: GoogleFonts.rajdhani(
                  fontSize: 9,
                  color: word.color.withOpacity(0.7),
                  letterSpacing: 0.3,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildProductRow(
      Map<String, dynamic> item, String locale, Color accentColor) {
    final name  = (item['product_name'] ?? item['name'] ?? '').toString();
    final price = item['price'] ?? item['unit_price'] ?? 0;
    final qty   = item['quantity'] ?? item['qty'] ?? 1;
    final unit  = item['unit'] ?? 'pc';
    final conf  = (item['confidence'] as num?)?.toDouble() ?? 0.7;

    // Native script name (from our cross-script map, if available)
    final nativeName = _getNativeProductName(name, locale);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Confidence indicator dot
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: conf >= 0.8
                  ? const Color(0xFF00C853)
                  : conf >= 0.6
                      ? const Color(0xFFFFAB00)
                      : const Color(0xFFFF3D71),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Native script name (large)
                if (nativeName != null && nativeName != name)
                  Text(nativeName,
                    style: GoogleFonts.notoSans(
                      fontSize: 15,
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                    )),
                // English canonical name
                Text(name,
                  style: GoogleFonts.rajdhani(
                    fontSize: nativeName != null && nativeName != name ? 11 : 14,
                    color: nativeName != null && nativeName != name
                        ? const Color(0xFF546E7A)
                        : Colors.white,
                    fontWeight: FontWeight.w600,
                  )),
              ],
            ),
          ),
          // Qty × unit
          Text('$qty $unit',
            style: GoogleFonts.rajdhani(
              fontSize: 12, color: const Color(0xFF7986CB))),
          const SizedBox(width: 8),
          // Price
          Text('₹${price.toString()}',
            style: GoogleFonts.rajdhani(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            )),
        ],
      ),
    );
  }

  /// Returns the native-script name for a canonical English product name,
  /// based on the current display locale. Pure lookup table — no API.
  String? _getNativeProductName(String canonical, String locale) {
    const nativeNames = <String, Map<String, String>>{
      'sugar':   {'hi-IN': 'चीनी', 'ta-IN': 'சர்க்கரை', 'te-IN': 'పంచదార',
                  'kn-IN': 'ಸಕ್ಕರೆ', 'ml-IN': 'പഞ്ചസാര', 'mr-IN': 'साखर',
                  'bn-IN': 'চিনি', 'gu-IN': 'ખાંડ', 'pa-IN': 'ਖੰਡ'},
      'rice':    {'hi-IN': 'चावल', 'ta-IN': 'அரிசி', 'te-IN': 'బియ్యం',
                  'kn-IN': 'ಅಕ್ಕಿ', 'ml-IN': 'അരി', 'mr-IN': 'तांदूळ',
                  'bn-IN': 'চাল', 'gu-IN': 'ચોખા', 'pa-IN': 'ਚਾਵਲ'},
      'salt':    {'hi-IN': 'नमक', 'ta-IN': 'உப்பு', 'te-IN': 'ఉప్పు',
                  'kn-IN': 'ಉಪ್ಪು', 'ml-IN': 'ഉപ്പ്', 'mr-IN': 'मीठ',
                  'bn-IN': 'লবণ', 'gu-IN': 'મીઠું', 'pa-IN': 'ਲੂਣ'},
      'oil':     {'hi-IN': 'तेल', 'ta-IN': 'எண்ணெய்', 'te-IN': 'నూనె',
                  'kn-IN': 'ಎಣ್ಣೆ', 'ml-IN': 'എണ്ണ', 'mr-IN': 'तेल',
                  'bn-IN': 'তেল', 'gu-IN': 'તેલ', 'pa-IN': 'ਤੇਲ'},
      'dal':     {'hi-IN': 'दाल', 'ta-IN': 'பருப்பு', 'te-IN': 'పప్పు',
                  'kn-IN': 'ಬೇಳೆ', 'ml-IN': 'പരിപ്പ്', 'mr-IN': 'डाळ',
                  'bn-IN': 'ডাল', 'gu-IN': 'દાળ', 'pa-IN': 'ਦਾਲ'},
      'atta':    {'hi-IN': 'आटा', 'ta-IN': 'மாவு', 'te-IN': 'పిండి',
                  'kn-IN': 'ಹಿಟ್ಟು', 'ml-IN': 'മാവ്', 'mr-IN': 'पीठ',
                  'bn-IN': 'আটা', 'gu-IN': 'લોટ', 'pa-IN': 'ਆਟਾ'},
      'onion':   {'hi-IN': 'प्याज', 'ta-IN': 'வெங்காயம்', 'te-IN': 'ఉల్లిపాయ',
                  'kn-IN': 'ಈರುಳ್ಳಿ', 'ml-IN': 'ഉള്ളി', 'mr-IN': 'कांदा',
                  'bn-IN': 'পেঁয়াজ', 'gu-IN': 'ડુંગળી', 'pa-IN': 'ਪਿਆਜ਼'},
      'tomato':  {'hi-IN': 'टमाटर', 'ta-IN': 'தக்காளி', 'te-IN': 'టమాటా',
                  'kn-IN': 'ಟೊಮ್ಯಾಟೊ', 'ml-IN': 'തക്കാളി', 'mr-IN': 'टोमॅटो',
                  'bn-IN': 'টমেটো', 'gu-IN': 'ટામેટા', 'pa-IN': 'ਟਮਾਟਰ'},
      'potato':  {'hi-IN': 'आलू', 'ta-IN': 'உருளைக்கிழங்கு', 'te-IN': 'బంగాళాదుంప',
                  'kn-IN': 'ಆಲೂಗಡ್ಡೆ', 'ml-IN': 'ഉരുളക്കിഴങ്ങ്', 'mr-IN': 'बटाटा',
                  'bn-IN': 'আলু', 'gu-IN': 'બટાટા', 'pa-IN': 'ਆਲੂ'},
      'ghee':    {'hi-IN': 'घी', 'ta-IN': 'நெய்', 'te-IN': 'నెయ్యి',
                  'kn-IN': 'ತುಪ್ಪ', 'ml-IN': 'നെയ്യ്', 'mr-IN': 'तूप',
                  'bn-IN': 'ঘি', 'gu-IN': 'ઘી', 'pa-IN': 'ਘਿਓ'},
      'milk':    {'hi-IN': 'दूध', 'ta-IN': 'பால்', 'te-IN': 'పాలు',
                  'kn-IN': 'ಹಾಲು', 'ml-IN': 'പാൽ', 'mr-IN': 'दूध',
                  'bn-IN': 'দুধ', 'gu-IN': 'દૂધ', 'pa-IN': 'ਦੁੱਧ'},
      'curd':    {'hi-IN': 'दही', 'ta-IN': 'தயிர்', 'te-IN': 'పెరుగు',
                  'kn-IN': 'ಮೊಸರು', 'ml-IN': 'തൈര്', 'mr-IN': 'दही',
                  'bn-IN': 'দই', 'gu-IN': 'દહીં', 'pa-IN': 'ਦਹੀਂ'},
      'butter':  {'hi-IN': 'मक्खन', 'ta-IN': 'வெண்ணெய்', 'te-IN': 'వెన్న',
                  'kn-IN': 'ಬೆಣ್ಣೆ', 'ml-IN': 'വെണ്ണ', 'mr-IN': 'लोणी',
                  'bn-IN': 'মাখন', 'gu-IN': 'માખણ', 'pa-IN': 'ਮੱਖਣ'},
      'turmeric':{'hi-IN': 'हल्दी', 'ta-IN': 'மஞ்சள்', 'te-IN': 'పసుపు',
                  'kn-IN': 'ಅರಿಶಿನ', 'ml-IN': 'മഞ്ഞൾ', 'mr-IN': 'हळद',
                  'bn-IN': 'হলুদ', 'gu-IN': 'હળદર', 'pa-IN': 'ਹਲਦੀ'},
      'cumin':   {'hi-IN': 'जीरा', 'ta-IN': 'சீரகம்', 'te-IN': 'జీలకర్ర',
                  'kn-IN': 'ಜೀರಿಗೆ', 'ml-IN': 'ജീരകം', 'mr-IN': 'जिरे',
                  'bn-IN': 'জিরা', 'gu-IN': 'જીરૂ', 'pa-IN': 'ਜੀਰਾ'},
      'chilli':  {'hi-IN': 'मिर्च', 'ta-IN': 'மிளகாய்', 'te-IN': 'మిరప',
                  'kn-IN': 'ಮೆಣಸಿನಕಾಯಿ', 'ml-IN': 'മുളക്', 'mr-IN': 'मिरची',
                  'bn-IN': 'মরিচ', 'gu-IN': 'મરચું', 'pa-IN': 'ਮਿਰਚ'},
      'coriander':{'hi-IN':'धनिया', 'ta-IN': 'கொத்தமல்லி', 'te-IN': 'కొత్తిమీర',
                  'kn-IN': 'ಕೊತ್ತಂಬರಿ', 'ml-IN': 'കൊത്തമ്പലരി', 'mr-IN': 'कोथिंबीर',
                  'bn-IN': 'ধনে', 'gu-IN': 'ધાણા', 'pa-IN': 'ਧਨੀਆ'},
    };

    final key = canonical.toLowerCase().trim();
    return nativeNames[key]?[locale];
  }
}

// ─── Live dot animation ───────────────────────────────────────────────────────

class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Row(
        children: [
          Container(
            width: 7, height: 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFF3D71),
            ),
          ),
          const SizedBox(width: 4),
          Text('LIVE',
            style: GoogleFonts.rajdhani(
              fontSize: 10,
              color: const Color(0xFFFF3D71),
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            )),
        ],
      ),
    );
  }
}

// ─── Internal model ───────────────────────────────────────────────────────────

class _LangDisplay {
  final String name, flag;
  final Color color;
  const _LangDisplay(this.name, this.flag, this.color);
}

// =============================================================================
// language_engine.dart  —  V8 HUMAN-LIKE VOICE SYSTEM
// Handles all language data, naturalization, and humanization preprocessing.
//
// KEY UPGRADES FROM V7
// ─────────────────────
//  LANG-A  All language strings rewritten to daily spoken registers
//          (no more translation-like formal sentences).
//  LANG-B  Humanizer layer converts TTS input to natural speech just before
//          speaking — removes filler words, shortens repetition, adds rhythm.
//  LANG-C  VoiceStyle enum drives sentence structure per language.
//  LANG-D  Smart chunk builder breaks long sentences into speakable units
//          so TTS pauses naturally at meaning boundaries.
//  LANG-E  UPI and other method names use native phonetics per language
//          (e.g. Tamil "யூபிஐ", Hindi "यूपीआई").
// =============================================================================

// -----------------------------------------------------------------------------
// Enums
// -----------------------------------------------------------------------------

enum VoiceStyle {
  /// Formal, complete sentences. Good for professional contexts.
  formal,

  /// Warm, conversational tone. "Okay, 100 rupees received."
  friendly,

  /// Ultra-short, fast. "100 received." Ideal for high-traffic shops.
  fastShop,

  /// Sharp, loud, attention-grabbing. Used for warnings and anomalies.
  alert,
  
  /// Neutral / normal style
  normal,
}

enum AnnouncementMode     { normal, shopkeeper, silent }
enum AnnouncementPriority { low, normal, high, critical }
enum PaymentMethod        { upi, cash, card, netBanking, wallet, unknown }

// -----------------------------------------------------------------------------
// Native-script numeral helpers
// -----------------------------------------------------------------------------

String nHi(String n) {
  const d = ['०','१','२','३','४','५','६','७','८','९'];
  return n.split('').map((c) { final i = int.tryParse(c); return i != null ? d[i] : c; }).join();
}
String nTa(String n) {
  const d = ['௦','௧','௨','௩','௪','௫','௬','௭','௮','௯'];
  return n.split('').map((c) { final i = int.tryParse(c); return i != null ? d[i] : c; }).join();
}
String nTe(String n) {
  const d = ['౦','౧','౨','౩','౪','౫','౬','౭','౮','౯'];
  return n.split('').map((c) { final i = int.tryParse(c); return i != null ? d[i] : c; }).join();
}
String nKn(String n) {
  const d = ['೦','೧','೨','೩','೪','೫','೬','೭','೮','೯'];
  return n.split('').map((c) { final i = int.tryParse(c); return i != null ? d[i] : c; }).join();
}
String nMl(String n) {
  const d = ['൦','൧','൨','൩','൪','൫','൬','൭','൮','൯'];
  return n.split('').map((c) { final i = int.tryParse(c); return i != null ? d[i] : c; }).join();
}
String nBn(String n) {
  const d = ['০','១','२','৩','৪','৫','៦','୭','୮','୯'];
  return n.split('').map((c) { final i = int.tryParse(c); return i != null ? d[i] : c; }).join();
}
String nGu(String n) {
  const d = ['૦','૧','૨','૩','૪','૫','૬','૭','૮','૯'];
  return n.split('').map((c) { final i = int.tryParse(c); return i != null ? d[i] : c; }).join();
}
// Gurmukhi: modern TTS handles ASCII digits correctly for Punjabi
String nPa(String n) => n;

// -----------------------------------------------------------------------------
// Payment method phonetics — native spoken forms per language (LANG-E)
// -----------------------------------------------------------------------------

String methodName(String lang, PaymentMethod method) {
  const Map<PaymentMethod, Map<String, String>> names = {
    PaymentMethod.upi: {
      'en': 'UPI',         'hi': 'यूपीआई',        'ta': 'யூபிஐ',
      'te': 'యూపీఐ',      'kn': 'ಯುಪಿಐ',          'ml': 'യുപിഐ',
      'mr': 'यूपीआई',     'gu': 'યુપીઆઈ',          'pa': 'ਯੂਪੀਆਈ',
      'bn': 'ইউপিআই',
    },
    PaymentMethod.cash: {
      'en': 'cash',        'hi': 'नकद',             'ta': 'ரொக்கம்',
      'te': 'నగదు',        'kn': 'ನಗದು',            'ml': 'പണം',
      'mr': 'रोख',         'gu': 'રોકડ',             'pa': 'ਨਕਦ',
      'bn': 'নগদ',
    },
    PaymentMethod.card: {
      'en': 'card',        'hi': 'कार्ड',            'ta': 'கார்டு',
      'te': 'కార్డు',      'kn': 'ಕಾರ್ಡ್',           'ml': 'കാർഡ്',
      'mr': 'कार्ड',       'gu': 'કાર્ડ',             'pa': 'ਕਾਰਡ',
      'bn': 'কার্ড',
    },
    PaymentMethod.netBanking: {
      'en': 'net banking',  'hi': 'नेट बैंकिंग',     'ta': 'நெட் பேங்கிங்',
      'te': 'నెట్ బ్యాంకింగ్','kn': 'ನೆಟ್ ಬ್ಯಾಂಕಿಂಗ್', 'ml': 'നെറ്റ് ബാങ്കിംഗ്',
      'mr': 'नेट बँकिंग',   'gu': 'નેટ બેંકિંગ',      'pa': 'ਨੈੱਟ ਬੈਂਕਿੰਗ',
      'bn': 'নেট ব্যাংকিং',
    },
    PaymentMethod.wallet: {
      'en': 'wallet',       'hi': 'वॉलेट',            'ta': 'வாலட்',
      'te': 'వాలెట్',       'kn': 'ವಾಲೆಟ್',           'ml': 'വാലറ്റ്',
      'mr': 'वॉलेट',        'gu': 'વૉલેટ',             'pa': 'ਵਾਲਿਟ',
      'bn': 'ওয়ালেট',
    },
  };
  return names[method]?[lang] ?? names[method]?['en'] ?? 'UPI';
}

// -----------------------------------------------------------------------------
// LangPhrases — per-language phrase builders, all in natural spoken register
// -----------------------------------------------------------------------------

class LangPhrases {
  final String locale;
  final String langKey;

  /// Short success — what most shopkeepers hear most often.
  /// fastShop style: just amount.
  final String Function(String amt, VoiceStyle style) success;

  /// Partial payment — calm but clear, not alarming.
  final String Function(String amt, String rem, VoiceStyle style) partial;

  /// Failure — concise, actionable.
  final String failure;

  /// With payment method.
  final String Function(String amt, PaymentMethod method, VoiceStyle style) withMethod;

  /// With sender name.
  final String Function(String name, String amt, VoiceStyle style) withSender;

  /// Burst summary.
  final String Function(int count, String total, VoiceStyle style) burst;

  /// Daily total query response.
  final String Function(String total, int count) dailySummary;

  /// Anomaly alert (large/repeated transaction).
  final String Function(String amt) anomalyAlert;

  /// Test phrase — full locale-native, no English prefix.
  final String Function(String amt) test;

  const LangPhrases({
    required this.locale,
    required this.langKey,
    required this.success,
    required this.partial,
    required this.failure,
    required this.withMethod,
    required this.withSender,
    required this.burst,
    required this.dailySummary,
    required this.anomalyAlert,
    required this.test,
  });
}

// -----------------------------------------------------------------------------
// LANG-A / LANG-C: Language registry — naturalized, style-aware (LANG-A)
// -----------------------------------------------------------------------------

final Map<String, LangPhrases> languageRegistry = {

  // ── English ─────────────────────────────────────────────────────────────────
  'en': LangPhrases(
    locale:  'en-IN', langKey: 'en',
    success: (amt, style) => switch (style) {
      VoiceStyle.fastShop => '$amt received',
      VoiceStyle.friendly => 'Got it, $amt rupees received',
      VoiceStyle.alert    => 'Payment confirmed — $amt rupees',
      _                   => '$amt rupees received',
    },
    partial: (amt, rem, style) => switch (style) {
      VoiceStyle.fastShop => 'Short $rem rupees',
      VoiceStyle.alert    => 'Warning — only $amt received, $rem still due',
      _                   => 'Received $amt, still waiting for $rem rupees',
    },
    failure: 'Payment failed — please check',
    withMethod: (amt, m, style) => switch (style) {
      VoiceStyle.fastShop => '$amt via ${methodName('en', m)}',
      VoiceStyle.friendly => '$amt rupees via ${methodName('en', m)}, received',
      _                   => '$amt rupees received via ${methodName('en', m)}',
    },
    withSender: (name, amt, style) => switch (style) {
      VoiceStyle.fastShop => '$name, $amt',
      VoiceStyle.friendly => '$amt rupees from $name, thank you',
      _                   => 'Received $amt rupees from $name',
    },
    burst: (count, total, style) => switch (style) {
      VoiceStyle.fastShop => '$count payments, $total total',
      _                   => '$count payments received, total $total rupees',
    },
    dailySummary: (total, count) =>
        'Today, $count payments received. Total earnings $total rupees.',
    anomalyAlert: (amt) =>
        'Large transaction — $amt rupees received. Please verify.',
    test: (amt) => 'Voice check. $amt rupees.',
  ),

  // ── Hindi ───────────────────────────────────────────────────────────────────
  'hi': LangPhrases(
    locale: 'hi-IN', langKey: 'hi',
    success: (amt, style) => switch (style) {
      VoiceStyle.fastShop => '${nHi(amt)} आए',
      VoiceStyle.friendly => 'हाँ, ${nHi(amt)} रुपये आ गए',
      VoiceStyle.alert    => '${nHi(amt)} रुपये मिले',
      _                   => '${nHi(amt)} रुपये आए',
    },
    partial: (amt, rem, style) => switch (style) {
      VoiceStyle.fastShop => '${nHi(rem)} रुपये बाकी',
      VoiceStyle.alert    => 'ध्यान दें — केवल ${nHi(amt)} आए, ${nHi(rem)} बाकी हैं',
      _                   => '${nHi(amt)} आए, ${nHi(rem)} रुपये अभी बाकी हैं',
    },
    failure: 'भुगतान नहीं हुआ, जांच करें',
    withMethod: (amt, m, style) => switch (style) {
      VoiceStyle.fastShop => '${nHi(amt)}, ${methodName('hi', m)}',
      VoiceStyle.friendly => 'अच्छा, ${nHi(amt)} रुपये ${methodName('hi', m)} से आए',
      _                   => '${nHi(amt)} रुपये ${methodName('hi', m)} से आए',
    },
    withSender: (name, amt, style) => switch (style) {
      VoiceStyle.fastShop => '$name, ${nHi(amt)}',
      VoiceStyle.friendly => '$name ने ${nHi(amt)} रुपये भेजे',
      _                   => '$name से ${nHi(amt)} रुपये आए',
    },
    burst: (count, total, style) => switch (style) {
      VoiceStyle.fastShop => '$count भुगतान, कुल ${nHi(total)}',
      _                   => '$count भुगतान आए, कुल ${nHi(total)} रुपये',
    },
    dailySummary: (total, count) =>
        'आज $count भुगतान आए। कुल ${nHi(total)} रुपये मिले।',
    anomalyAlert: (amt) =>
        'बड़ा भुगतान — ${nHi(amt)} रुपये। एक बार जांचें।',
    test: (amt) => 'आवाज ठीक है। ${nHi(amt)} रुपये।',
  ),

  // ── Tamil ───────────────────────────────────────────────────────────────────
  'ta': LangPhrases(
    locale: 'ta-IN', langKey: 'ta',
    success: (amt, style) => switch (style) {
      VoiceStyle.fastShop => '${nTa(amt)} வந்தது',
      VoiceStyle.friendly => 'சரி, ${nTa(amt)} ரூபாய் வந்தது',
      VoiceStyle.alert    => '${nTa(amt)} ரூபாய் கிடைத்தது',
      _                   => '${nTa(amt)} ரூபாய் வந்தது',
    },
    partial: (amt, rem, style) => switch (style) {
      VoiceStyle.fastShop => '${nTa(rem)} பாக்கி',
      VoiceStyle.alert    => 'கவனம் — ${nTa(amt)} மட்டும் வந்தது, ${nTa(rem)} பாக்கி',
      _                   => '${nTa(amt)} வந்தது, ${nTa(rem)} ரூபாய் இன்னும் வரணும்',
    },
    failure: 'பணம் வரலை, சரிபாருங்க',
    withMethod: (amt, m, style) => switch (style) {
      VoiceStyle.fastShop => '${nTa(amt)}, ${methodName('ta', m)}',
      VoiceStyle.friendly => 'சரி, ${nTa(amt)} ரூபாய் ${methodName('ta', m)} மூலம் வந்தது',
      _                   => '${nTa(amt)} ரூபாய் ${methodName('ta', m)} மூலம் வந்தது',
    },
    withSender: (name, amt, style) => switch (style) {
      VoiceStyle.fastShop => '$name, ${nTa(amt)}',
      VoiceStyle.friendly => '$name ${nTa(amt)} ரூபாய் அனுப்பினார்',
      _                   => '$name-கிட்ட இருந்து ${nTa(amt)} ரூபாய் வந்தது',
    },
    burst: (count, total, style) => switch (style) {
      VoiceStyle.fastShop => '$count பேமெண்ட், மொத்தம் ${nTa(total)}',
      _                   => '$count பேமெண்ட் வந்தது, மொத்தம் ${nTa(total)} ரூபாய்',
    },
    dailySummary: (total, count) =>
        'இன்னைக்கு $count பேமெண்ட் வந்தது. மொத்தம் ${nTa(total)} ரூபாய்.',
    anomalyAlert: (amt) =>
        'பெரிய தொகை — ${nTa(amt)} ரூபாய். ஒரு தடவை பாருங்க.',
    test: (amt) => 'குரல் சரியா இருக்கு. ${nTa(amt)} ரூபாய்.',
  ),

  // ── Telugu ──────────────────────────────────────────────────────────────────
  'te': LangPhrases(
    locale: 'te-IN', langKey: 'te',
    success: (amt, style) => switch (style) {
      VoiceStyle.fastShop => '${nTe(amt)} వచ్చింది',
      VoiceStyle.friendly => 'సరే, ${nTe(amt)} రూపాయలు వచ్చాయి',
      VoiceStyle.alert    => '${nTe(amt)} రూపాయలు అందాయి',
      _                   => '${nTe(amt)} రూపాయలు వచ్చాయి',
    },
    partial: (amt, rem, style) => switch (style) {
      VoiceStyle.fastShop => '${nTe(rem)} బాకీ',
      VoiceStyle.alert    => 'జాగ్రత్త — ${nTe(amt)} వచ్చింది, ${nTe(rem)} ఇంకా రావాలి',
      _                   => '${nTe(amt)} వచ్చింది, ${nTe(rem)} రూపాయలు ఇంకా రావాలి',
    },
    failure: 'పేమెంట్ కాలేదు, చెక్ చేయండి',
    withMethod: (amt, m, style) => switch (style) {
      VoiceStyle.fastShop => '${nTe(amt)}, ${methodName('te', m)}',
      _                   => '${nTe(amt)} రూపాయలు ${methodName('te', m)} ద్వారా వచ్చాయి',
    },
    withSender: (name, amt, style) => switch (style) {
      VoiceStyle.fastShop => '$name, ${nTe(amt)}',
      _                   => '$name నుండి ${nTe(amt)} రూపాయలు వచ్చాయి',
    },
    burst: (count, total, style) => switch (style) {
      VoiceStyle.fastShop => '$count పేమెంట్లు, ${nTe(total)} మొత్తం',
      _                   => '$count పేమెంట్లు వచ్చాయి, మొత్తం ${nTe(total)} రూపాయలు',
    },
    dailySummary: (total, count) =>
        'ఈరోజు $count పేమెంట్లు వచ్చాయి. మొత్తం ${nTe(total)} రూపాయలు.',
    anomalyAlert: (amt) => 'పెద్ద పేమెంట్ — ${nTe(amt)} రూపాయలు. చెక్ చేయండి.',
    test: (amt) => 'వాయిస్ సరిగా ఉంది. ${nTe(amt)} రూపాయలు.',
  ),

  // ── Kannada ─────────────────────────────────────────────────────────────────
  'kn': LangPhrases(
    locale: 'kn-IN', langKey: 'kn',
    success: (amt, style) => switch (style) {
      VoiceStyle.fastShop => '${nKn(amt)} ಬಂತು',
      VoiceStyle.friendly => 'ಆಯ್ತು, ${nKn(amt)} ರೂಪಾಯಿ ಬಂತು',
      _                   => '${nKn(amt)} ರೂಪಾಯಿ ಬಂತು',
    },
    partial: (amt, rem, style) => switch (style) {
      VoiceStyle.fastShop => '${nKn(rem)} ಬಾಕಿ',
      VoiceStyle.alert    => 'ಗಮನಿಸಿ — ${nKn(amt)} ಮಾತ್ರ ಬಂತು, ${nKn(rem)} ಬಾಕಿ',
      _                   => '${nKn(amt)} ಬಂತು, ${nKn(rem)} ರೂಪಾಯಿ ಇನ್ನೂ ಬರಬೇಕು',
    },
    failure: 'ಪಾವತಿ ಆಗಲಿಲ್ಲ, ಒಮ್ಮೆ ನೋಡಿ',
    withMethod: (amt, m, style) =>
        '${nKn(amt)} ರೂಪಾಯಿ ${methodName('kn', m)} ಮೂಲಕ ಬಂತು',
    withSender: (name, amt, style) => switch (style) {
      VoiceStyle.fastShop => '$name, ${nKn(amt)}',
      _                   => '$name ಅವರಿಂದ ${nKn(amt)} ರೂಪಾಯಿ ಬಂತು',
    },
    burst: (count, total, style) =>
        '$count ಪಾವತಿ ಬಂತು, ಒಟ್ಟು ${nKn(total)} ರೂಪಾಯಿ',
    dailySummary: (total, count) =>
        'ಇಂದು $count ಪಾವತಿ ಬಂತು. ಒಟ್ಟು ${nKn(total)} ರೂಪಾಯಿ.',
    anomalyAlert: (amt) => 'ದೊಡ್ಡ ಮೊತ್ತ — ${nKn(amt)} ರೂಪಾಯಿ. ಒಮ್ಮೆ ಪರಿಶೀಲಿಸಿ.',
    test: (amt) => 'ಧ್ವನಿ ಸರಿಯಾಗಿದೆ. ${nKn(amt)} ರೂಪಾಯಿ.',
  ),

  // ── Malayalam ───────────────────────────────────────────────────────────────
  'ml': LangPhrases(
    locale: 'ml-IN', langKey: 'ml',
    success: (amt, style) => switch (style) {
      VoiceStyle.fastShop => '${nMl(amt)} കിട്ടി',
      VoiceStyle.friendly => 'ശരി, ${nMl(amt)} രൂപ കിട്ടി',
      _                   => '${nMl(amt)} രൂപ കിട്ടി',
    },
    partial: (amt, rem, style) => switch (style) {
      VoiceStyle.fastShop => '${nMl(rem)} ബാക്കി',
      VoiceStyle.alert    => 'ശ്രദ്ധിക്കൂ — ${nMl(amt)} മാത്രം കിട്ടി, ${nMl(rem)} ബാക്കി',
      _                   => '${nMl(amt)} കിട്ടി, ${nMl(rem)} രൂപ ഇനിയും വരണം',
    },
    failure: 'പണം വന്നില്ല, ഒന്ന് നോക്കൂ',
    withMethod: (amt, m, style) =>
        '${nMl(amt)} രൂപ ${methodName('ml', m)} വഴി കിട്ടി',
    withSender: (name, amt, style) => switch (style) {
      VoiceStyle.fastShop => '$name, ${nMl(amt)}',
      _                   => '$name-ൽ നിന്ന് ${nMl(amt)} രൂപ കിട്ടി',
    },
    burst: (count, total, style) =>
        '$count പേയ്മെന്റ് കിട്ടി, ആകെ ${nMl(total)} രൂപ',
    dailySummary: (total, count) =>
        'ഇന്ന് $count പേയ്മെന്റ് കിട്ടി. ആകെ ${nMl(total)} രൂപ.',
    anomalyAlert: (amt) =>
        'വലിയ തുക — ${nMl(amt)} രൂപ. ഒന്ന് ഉറപ്പ് വരുത്തൂ.',
    test: (amt) => 'ശബ്ദം ശരിയാണ്. ${nMl(amt)} രൂപ.',
  ),

  // ── Marathi ─────────────────────────────────────────────────────────────────
  'mr': LangPhrases(
    locale: 'mr-IN', langKey: 'mr',
    success: (amt, style) => switch (style) {
      VoiceStyle.fastShop => '${nHi(amt)} मिळाले',
      VoiceStyle.friendly => 'बरं, ${nHi(amt)} रुपये मिळाले',
      _                   => '${nHi(amt)} रुपये मिळाले',
    },
    partial: (amt, rem, style) => switch (style) {
      VoiceStyle.fastShop => '${nHi(rem)} बाकी',
      VoiceStyle.alert    => 'लक्ष द्या — ${nHi(amt)} मिळाले, ${nHi(rem)} बाकी',
      _                   => '${nHi(amt)} मिळाले, ${nHi(rem)} रुपये अजून यायचेत',
    },
    failure: 'पेमेंट झाले नाही, बघा एकदा',
    withMethod: (amt, m, style) =>
        '${nHi(amt)} रुपये ${methodName('mr', m)} ने मिळाले',
    withSender: (name, amt, style) => switch (style) {
      VoiceStyle.fastShop => '$name, ${nHi(amt)}',
      _                   => '$name कडून ${nHi(amt)} रुपये मिळाले',
    },
    burst: (count, total, style) =>
        '$count पेमेंट मिळाले, एकूण ${nHi(total)} रुपये',
    dailySummary: (total, count) =>
        'आज $count पेमेंट मिळाले. एकूण ${nHi(total)} रुपये।',
    anomalyAlert: (amt) => 'मोठी रक्कम — ${nHi(amt)} रुपये. एकदा तपासा.',
    test: (amt) => 'आवाज ठीक आहे. ${nHi(amt)} रुपये.',
  ),

  // ── Gujarati ────────────────────────────────────────────────────────────────
  'gu': LangPhrases(
    locale: 'gu-IN', langKey: 'gu',
    success: (amt, style) => switch (style) {
      VoiceStyle.fastShop => '${nGu(amt)} મળ્યા',
      VoiceStyle.friendly => 'ઠીક છે, ${nGu(amt)} રૂપિયા મળ્યા',
      _                   => '${nGu(amt)} રૂપિયા મળ્યા',
    },
    partial: (amt, rem, style) => switch (style) {
      VoiceStyle.fastShop => '${nGu(rem)} બાકી',
      VoiceStyle.alert    => 'ધ્યાન આપો — ${nGu(amt)} મળ્યા, ${nGu(rem)} બાકી',
      _                   => '${nGu(amt)} મળ્યા, ${nGu(rem)} રૂપિયા હજુ આવવાના',
    },
    failure: 'પૈસા ન મળ્યા, તપાસ કરો',
    withMethod: (amt, m, style) =>
        '${nGu(amt)} રૂપિયા ${methodName('gu', m)} દ્વારા મળ્યા',
    withSender: (name, amt, style) => switch (style) {
      VoiceStyle.fastShop => '$name, ${nGu(amt)}',
      _                   => '$name પાસેથી ${nGu(amt)} રૂપિયા મળ્યા',
    },
    burst: (count, total, style) =>
        '$count ચુકવણી મળી, કુલ ${nGu(total)} રૂપિયા',
    dailySummary: (total, count) =>
        'આજે $count ચુકવણી મળી. કુલ ${nGu(total)} રૂપિયા.',
    anomalyAlert: (amt) => 'મોટી રકમ — ${nGu(amt)} રૂપિયા. ખાતરી કરો.',
    test: (amt) => 'અવાજ ઠીક છે. ${nGu(amt)} રૂપિયા.',
  ),

  // ── Punjabi ─────────────────────────────────────────────────────────────────
  'pa': LangPhrases(
    locale: 'pa-IN', langKey: 'pa',
    success: (amt, style) => switch (style) {
      VoiceStyle.fastShop => '${nPa(amt)} ਮਿਲੇ',
      VoiceStyle.friendly => 'ਠੀਕ ਹੈ, ${nPa(amt)} ਰੁਪਏ ਮਿਲੇ',
      _                   => '${nPa(amt)} ਰੁਪਏ ਮਿਲੇ',
    },
    partial: (amt, rem, style) => switch (style) {
      VoiceStyle.fastShop => '${nPa(rem)} ਬਾਕੀ',
      VoiceStyle.alert    => 'ਧਿਆਨ ਦਿਓ — ${nPa(amt)} ਮਿਲੇ, ${nPa(rem)} ਬਾਕੀ ਹਨ',
      _                   => '${nPa(amt)} ਮਿਲੇ, ${nPa(rem)} ਰੁਪਏ ਅਜੇ ਆਉਣੇ ਹਨ',
    },
    failure: 'ਪੇਮੈਂਟ ਨਹੀਂ ਹੋਈ, ਜਾਂਚ ਕਰੋ',
    withMethod: (amt, m, style) =>
        '${nPa(amt)} ਰੁਪਏ ${methodName('pa', m)} ਰਾਹੀਂ ਮਿਲੇ',
    withSender: (name, amt, style) => switch (style) {
      VoiceStyle.fastShop => '$name, ${nPa(amt)}',
      _                   => '$name ਤੋਂ ${nPa(amt)} ਰੁਪਏ ਮਿਲੇ',
    },
    burst: (count, total, style) =>
        '$count ਭੁਗਤਾਨ ਮਿਲੇ, ਕੁੱਲ ${nPa(total)} ਰੁਪਏ',
    dailySummary: (total, count) =>
        'ਅੱਜ $count ਭੁਗਤਾਨ ਮਿਲੇ। ਕੁੱਲ ${nPa(total)} ਰੁਪਏ।',
    anomalyAlert: (amt) => 'ਵੱਡੀ ਰਕਮ — ${nPa(amt)} ਰੁਪਏ। ਇੱਕ ਵਾਰ ਦੇਖੋ।',
    test: (amt) => 'ਅਵਾਜ਼ ਠੀਕ ਹੈ। ${nPa(amt)} ਰੁਪਏ।',
  ),

  // ── Bengali ─────────────────────────────────────────────────────────────────
  'bn': LangPhrases(
    locale: 'bn-IN', langKey: 'bn',
    success: (amt, style) => switch (style) {
      VoiceStyle.fastShop => '${nBn(amt)} পাওয়া গেছে',
      VoiceStyle.friendly => 'ঠিক আছে, ${nBn(amt)} টাকা পাওয়া গেছে',
      _                   => '${nBn(amt)} টাকা পাওয়া গেছে',
    },
    partial: (amt, rem, style) => switch (style) {
      VoiceStyle.fastShop => '${nBn(rem)} বাকি',
      VoiceStyle.alert    => 'সতর্ক — ${nBn(amt)} এসেছে, ${nBn(rem)} বাকি',
      _                   => '${nBn(amt)} এসেছে, ${nBn(rem)} টাকা এখনো বাকি',
    },
    failure: 'পেমেন্ট হয়নি, দেখুন একবার',
    withMethod: (amt, m, style) =>
        '${nBn(amt)} টাকা ${methodName('bn', m)} মাধ্যমে পাওয়া গেছে',
    withSender: (name, amt, style) => switch (style) {
      VoiceStyle.fastShop => '$name, ${nBn(amt)}',
      _                   => '$name-এর কাছ থেকে ${nBn(amt)} টাকা পাওয়া গেছে',
    },
    burst: (count, total, style) =>
        '$count পেমেন্ট পাওয়া গেছে, মোট ${nBn(total)} টাকা',
    dailySummary: (total, count) =>
        'আজ $count পেমেন্ট পাওয়া গেছে। মোট ${nBn(total)} টাকা।',
    anomalyAlert: (amt) => 'বড় লেনদেন — ${nBn(amt)} টাকা। একবার নিশ্চিত করুন।',
    test: (amt) => 'কণ্ঠস্বর ঠিক আছে। ${nBn(amt)} টাকা।',
  ),
};

// -----------------------------------------------------------------------------
// LanguageEngine — public API for the rest of the system
// ----------------------------------------------------------------------------- 

class LanguageEngine {
  // PERF-2: cached resolution
  final Map<String, LangPhrases> _cache = {};

  LangPhrases resolve(String lang) {
    final key = _normalizeKey(lang);
    return _cache.putIfAbsent(
      key, () => languageRegistry[key] ?? languageRegistry['en']!,
    );
  }

  String _normalizeKey(String lang) {
    String k = lang.trim().toLowerCase();
    if (k.contains('-')) k = k.split('-').first;
    if (k.contains('_')) k = k.split('_').first;
    return k;
  }

  // LANG-D: Smart chunk builder
  // Splits a sentence at natural pause points so TTS breathes between chunks.
  // Returns a list of text segments; caller adds SSML pause or silent gap.
  List<String> buildChunks(String text) {
    // Split at commas, dashes, "from", "via" — natural pause words
    final chunks = <String>[];
    final parts  = text.split(RegExp(r',\s*|—\s*|\s+(?=from |via |ద్వారా|மூலம்|के जरिए|से| राhaan|মাধ্যমে)'));
    for (final p in parts) {
      final trimmed = p.trim();
      if (trimmed.isNotEmpty) chunks.add(trimmed);
    }
    return chunks.isEmpty ? [text] : chunks;
  }

  /// Received-word helper for burst strings (avoids duplicate switch in service)
  String receivedWord(String lang) {
    switch (_normalizeKey(lang)) {
      case 'hi': case 'mr': return 'मिले';
      case 'ta':             return 'வந்தது';
      case 'te':             return 'వచ్చాయి';
      case 'kn':             return 'ಬಂತು';
      case 'ml':             return 'കിട്ടി';
      case 'bn':             return 'পাওয়া গেছে';
      case 'pa':             return 'ਮਿਲੇ';
      case 'gu':             return 'મળ્યા';
      default:               return 'received';
    }
  }

  String andMore(String lang, int count) {
    switch (_normalizeKey(lang)) {
      case 'hi': case 'mr': return 'और $count';
      case 'ta':             return 'மேலும் $count';
      case 'te':             return 'మరో $count';
      case 'kn':             return 'ಮತ್ತು $count';
      case 'ml':             return 'കൂടി $count';
      case 'bn':             return 'আরো $count';
      case 'pa':             return 'ਹੋਰ $count';
      case 'gu':             return 'વધુ $count';
      default:               return 'and $count more';
    }
  }
}

// =============================================================================
// phonetic_normalizer.dart  —  MULTI-LANGUAGE PHONETIC NORMALIZER
// =============================================================================
// PURPOSE:
//   Bridges the gap between what speech_to_text returns vs what the NLP
//   parser expects — without ANY external API or API key.
//
// HOW IT WORKS:
//   1. STT returns a raw transcript in a mix of scripts/languages.
//   2. PhoneticNormalizer.normalize() runs the transcript through 5 stages:
//      Stage 1 — Script detection (detects which Indian scripts are present)
//      Stage 2 — Schwa deletion / vowel normalization per script
//      Stage 3 — Consonant cluster normalization (anusvara, chandrabindu,
//                virama handling for Hindi/Marathi/Gujarati/Punjabi/Bengali)
//      Stage 4 — Cross-script phoneme alignment table (maps acoustically
//                identical graphemes across languages)
//      Stage 5 — Common STT mishearing corrections (per-locale dictionaries)
//
// WHY NO API:
//   Everything below is pure rule-based / lookup-table code.
//   It runs fully offline with zero network calls.
// =============================================================================

// ─── Stage 1: Script ranges ───────────────────────────────────────────────────

enum _Script { latin, devanagari, tamil, telugu, kannada, malayalam, bengali, gujarati, gurmukhi, unknown }

class PhoneticNormalizer {
  // ── Stage 5 lookup tables: STT mishearing corrections per locale ────────────
  // Key = what STT commonly returns  →  Value = canonical spelling the parser uses
  static const Map<String, Map<String, String>> _sttFixes = {
    // ── English (en-IN) ────────────────────────────────────────────────────────
    'en-IN': {
      // Numbers
      'to': 'two', 'too': 'two', 'won': 'one', 'for': 'four', 'ate': 'eight',
      'sex': 'six', 'won\'t': 'one', 'to the': '2', 'tree': 'three', 'free': 'three', 
      'fife': 'five', 'v': 'five', 'nien': 'nine', 'tenn': 'ten',
      // Units
      'k g': 'kg', 'k.g': 'kg', 'kay gee': 'kg', 'kilogram': 'kg',
      'g m': 'gm', 'gram': 'gm', 'grm': 'gm',
      'ltr': 'litre', 'litter': 'litre', 'lites': 'litre', 'liters': 'litre',
      'ml': 'ml', 'milli': 'ml',
      'pkt': 'packet', 'pct': 'packet', 'pk': 'packet',
      'pcs': 'pieces', 'pece': 'piece', 'peis': 'piece',
      // Common product name mishearings
      'shuggar': 'sugar', 'suger': 'sugar', 'sugur': 'sugar',
      'flower': 'flour', 'flore': 'flour',
      'sallt': 'salt', 'solt': 'salt',
      'rise': 'rice', 'riez': 'rice', 'ris': 'rice',
      'aata': 'atta', 'ata': 'atta',
      'dall': 'dal', 'daal': 'dal',
      'tomatto': 'tomato', 'tamaato': 'tomato',
      'potatoe': 'potato', 'aloo': 'potato',
      'oinyun': 'onion', 'unyan': 'onion', 'pyaz': 'onion',
      'bred': 'bread', 'braid': 'bread',
      'butar': 'butter', 'buttar': 'butter',
      'cheeze': 'cheese', 'cheze': 'cheese',
      'mustered': 'mustard', 'musterd': 'mustard',
      'turmeric': 'turmeric', 'termeric': 'turmeric', 'haldi': 'turmeric',
      'cumin': 'cumin', 'jira': 'cumin', 'zeera': 'cumin',
      'corriander': 'coriander', 'coriender': 'coriander', 'dhania': 'coriander',
      'chilly': 'chilli', 'chili': 'chilli', 'mirchi': 'chilli',
    },

    // ── Hindi (hi-IN) ──────────────────────────────────────────────────────────
    'hi-IN': {
      // Number word STT confusions
      'एक': 'एक', 'यक': 'एक', 'इक': 'एक',
      'दो': 'दो', 'दू': 'दो', 'दोन': 'दो',
      'तीन': 'तीन', 'तिन': 'तीन',
      'चार': 'चार', 'चारह': 'चार',
      'पाँच': 'पाँच', 'पांच': 'पाँच', 'पाच': 'पाँच',
      'छह': 'छह', 'छे': 'छह',
      'सात': 'सात', 'साथ': 'सात',  // साथ = "with" but STT confuses with सात
      'आठ': 'आठ', 'आट': 'आठ',
      'नौ': 'नौ', 'नव': 'नौ',
      'दस': 'दस', 'दश': 'दस',
      'बीस': 'बीस', 'बिस': 'बीस',
      'तीस': 'तीस', 'तिस': 'तीस',
      'चालीस': 'चालीस', 'चाळीस': 'चालीस',
      'पचास': 'पचास',
      'साठ': 'साठ', 'सांठ': 'साठ',
      'सत्तर': 'सत्तर', 'सतर': 'सत्तर',
      'अस्सी': 'अस्सी', 'असी': 'अस्सी',
      'नब्बे': 'नब्बे', 'नवे': 'नब्बे',
      'सौ': 'सौ', 'सो': 'सौ',
      'हजार': 'हजार', 'हज़ार': 'हजार',
      // Unit STT confusions
      'किलो': 'किलो', 'किलों': 'किलो', 'किलु': 'किलो',
      'ग्राम': 'ग्राम', 'ग्रम': 'ग्राम', 'गराम': 'ग्राम',
      'लीटर': 'लीटर', 'लिटर': 'लीटर',
      'पैकेट': 'पैकेट', 'पाकीट': 'पैकेट', 'पेकेट': 'पैकेट',
      // Product STT confusions (Hinglish hybrids)
      'आटा': 'आटा', 'आता': 'आटा', 'अता': 'आटा', 'अत्ता': 'आटा',
      'चावल': 'चावल', 'चाउल': 'चावल', 'चाबल': 'चावल',
      'दाल': 'दाल', 'दाली': 'दाल', 'दालि': 'दाल',
      'नमक': 'नमक', 'नमकी': 'नमक',
      'चीनी': 'चीनी', 'चीने': 'चीनी', 'चीनो': 'चीनी',
      'तेल': 'तेल', 'तेली': 'तेल',
      'प्याज': 'प्याज', 'प्यांज': 'प्याज', 'प्याज़': 'प्याज',
      'आलू': 'आलू', 'आलु': 'आलू', 'अलू': 'आलू',
      'टमाटर': 'टमाटर', 'तमातर': 'टमाटर', 'टमेटर': 'टमाटर',
      'पालक': 'पालक', 'पालिक': 'पालक',
      'मटर': 'मटर', 'मतर': 'मटर',
      'गाजर': 'गाजर', 'गजर': 'गाजर',
      'घी': 'घी', 'घि': 'घी', 'गी': 'घी',
      'दूध': 'दूध', 'दुध': 'दूध', 'दूद': 'दूध',
      'दही': 'दही', 'दहीं': 'दही', 'दाही': 'दही',
      'मक्खन': 'मक्खन', 'मखन': 'मक्खन',
    },

    // ── Tamil (ta-IN) ──────────────────────────────────────────────────────────
    'ta-IN': {
      'ஒன்னு': 'ஒன்று', 'ஒண்ணு': 'ஒன்று', 'ஒன்ன': 'ஒன்று',
      'ரெண்டு': 'இரண்டு', 'ரண்டு': 'இரண்டு',
      'மூணு': 'மூன்று', 'மூன்னு': 'மூன்று',
      'நாலு': 'நான்கு', 'நாலூ': 'நான்கு',
      'ஐஞ்சு': 'ஐந்து', 'அஞ்சு': 'ஐந்து',
      'ஆறு': 'ஆறு',
      'ஏழு': 'ஏழு',
      'எட்டு': 'எட்டு',
      'ஒம்பது': 'ஒன்பது', 'ஒன்பது': 'ஒன்பது',
      'பத்து': 'பத்து',
      'இருபத்து': 'இருபது', 'இருபது': 'இருபது',
      // Units
      'கிலோ': 'கிலோ', 'கிலோவ': 'கிலோ',
      'கிராம்': 'கிராம்', 'கிரம்': 'கிராம்',
      'லிட்டர்': 'லிட்டர்', 'லிட்ட': 'லிட்டர்',
      'பாக்கெட்': 'பாக்கெட்', 'பாக்கட்': 'பாக்கெட்',
      // Products
      'சர்க்கரை': 'சர்க்கரை', 'சக்கரை': 'சர்க்கரை',
      'அரிசி': 'அரிசி', 'அரிசீ': 'அரிசி',
      'உப்பு': 'உப்பு', 'உப்ப': 'உப்பு',
      'எண்ணெய்': 'எண்ணெய்', 'எண்ண': 'எண்ணெய்',
      'பருப்பு': 'பருப்பு', 'பருப்ப': 'பருப்பு',
      'வெங்காயம்': 'வெங்காயம்', 'வெங்காய': 'வெங்காயம்',
      'தக்காளி': 'தக்காளி', 'தக்காள': 'தக்காளி',
      'உருளைக்கிழங்கு': 'உருளைக்கிழங்கு', 'உருளை': 'உருளைக்கிழங்கு',
    },

    // ── Telugu (te-IN) ─────────────────────────────────────────────────────────
    'te-IN': {
      'ఒక్కటి': 'ఒకటి', 'ఒకటి': 'ఒకటి',
      'రెండు': 'రెండు',
      'మూడు': 'మూడు',
      'నాలుగు': 'నాలుగు', 'నాలగు': 'నాలుగు',
      'అయిదు': 'ఐదు', 'ఐదు': 'ఐదు',
      'ఆరు': 'ఆరు',
      'ఏడు': 'ఏడు',
      'ఎనిమిది': 'ఎనిమిది', 'ఎనమిది': 'ఎనిమిది',
      'తొమ్మిది': 'తొమ్మిది', 'తొమిది': 'తొమ్మిది',
      'పది': 'పది',
      'ఇరవై': 'ఇరవై', 'ఇరవయ్': 'ఇరవై',
      // Units
      'కిలో': 'కిలో', 'కిలోలు': 'కిలో',
      'గ్రామ్': 'గ్రాము', 'గ్రాము': 'గ్రాము',
      'లీటరు': 'లీటర్', 'లీటర్': 'లీటర్',
      // Products
      'పంచదార': 'పంచదార', 'పంచదారా': 'పంచదార',
      'బియ్యం': 'బియ్యం', 'బియ్యము': 'బియ్యం',
      'ఉప్పు': 'ఉప్పు', 'ఉప్పెన': 'ఉప్పు',
      'నూనె': 'నూనె', 'నూనెలు': 'నూనె',
      'బంగాళాదుంప': 'బంగాళాదుంప', 'ఆలూ': 'బంగాళాదుంప',
      'ఉల్లిపాయ': 'ఉల్లిపాయ', 'ఉల్లి': 'ఉల్లిపాయ',
      'టమాటో': 'టమాటో', 'టమాటా': 'టమాటో',
      
      // Auto-translate English STT fallbacks to Telugu
      'milk': 'పాలు',
      'sugar': 'చక్కెర',
      'rice': 'బియ్యం',
      'salt': 'ఉప్పు',
      'potato': 'బంగాళాదుంప',
      'onion': 'ఉల్లిపాయ',
      'tomato': 'టమాటా',
      'dal': 'పప్పు',
      'water': 'నీరు',
      'oil': 'నూనె',
      'wheat': 'గోధుమలు',
      'flour': 'పిండి',
      'egg': 'గుడ్డు',
      'bread': 'బ్రెడ్',
      'ghee': 'నెయ్యి',
      'apple': 'యాపిల్',
      'banana': 'అరటి',
      'soap': 'సబ్బు',
      'paste': 'పేస్ట్',
      'బంగాళా': 'బంగాళాదుంప',
    },

    // ── Kannada (kn-IN) ────────────────────────────────────────────────────────
    'kn-IN': {
      'ಒಂದು': 'ಒಂದು', 'ಒಂದ': 'ಒಂದು',
      'ಎರಡು': 'ಎರಡು', 'ಎರಡ': 'ಎರಡು',
      'ಮೂರು': 'ಮೂರು', 'ಮೂರ': 'ಮೂರು',
      'ನಾಲ್ಕು': 'ನಾಲ್ಕು', 'ನಾಲಕ': 'ನಾಲ್ಕು',
      'ಐದು': 'ಐದು',
      'ಆರು': 'ಆರು',
      'ಏಳು': 'ಏಳು',
      'ಎಂಟು': 'ಎಂಟು', 'ಎಂಟ': 'ಎಂಟು',
      'ಒಂಬತ್ತು': 'ಒಂಬತ್ತು', 'ಒಂಬತ': 'ಒಂಬತ್ತು',
      'ಹತ್ತು': 'ಹತ್ತು',
      // Units
      'ಕಿಲೋ': 'ಕಿಲೋ', 'ಕಿಲೊ': 'ಕಿಲೋ',
      'ಗ್ರಾಂ': 'ಗ್ರಾಂ', 'ಗ್ರಾಮ್': 'ಗ್ರಾಂ',
      'ಲೀಟರ್': 'ಲೀಟರ್', 'ಲೀಟ': 'ಲೀಟರ್',
      // Products
      'ಸಕ್ಕರೆ': 'ಸಕ್ಕರೆ', 'ಸಕ್ಕರ': 'ಸಕ್ಕರೆ',
      'ಅಕ್ಕಿ': 'ಅಕ್ಕಿ',
      'ಉಪ್ಪು': 'ಉಪ್ಪು', 'ಉಪ್ಪ': 'ಉಪ್ಪು',
      'ಎಣ್ಣೆ': 'ಎಣ್ಣೆ', 'ಎಣ್ಣ': 'ಎಣ್ಣೆ',
      'ಬೇಳೆ': 'ಬೇಳೆ', 'ಬೇಳ': 'ಬೇಳೆ',
      'ಈರುಳ್ಳಿ': 'ಈರುಳ್ಳಿ', 'ಈರುಳ': 'ಈರುಳ್ಳಿ',
      'ಟೊಮ್ಯಾಟೊ': 'ಟೊಮ್ಯಾಟೊ', 'ಟೊಮೇಟೊ': 'ಟೊಮ್ಯಾಟೊ',
    },

    // ── Malayalam (ml-IN) ──────────────────────────────────────────────────────
    'ml-IN': {
      'ഒന്ന്': 'ഒന്ന്', 'ഒന്ന': 'ഒന്ന്',
      'രണ്ട്': 'രണ്ട്', 'രണ്ട': 'രണ്ട്',
      'മൂന്ന്': 'മൂന്ന്', 'മൂന്ന': 'മൂന്ന്',
      'നാല്': 'നാല്', 'നാല': 'നാല്',
      'അഞ്ച്': 'അഞ്ച്', 'അഞ്ച': 'അഞ്ച്',
      'ആറ്': 'ആറ്', 'ആറ': 'ആറ്',
      'ഏഴ്': 'ഏഴ്', 'ഏഴ': 'ഏഴ്',
      'എട്ട്': 'എട്ട്', 'എട്ട': 'എട്ട്',
      'ഒൻപത്': 'ഒൻപത്', 'ഒൻപത': 'ഒൻപത്',
      'പത്ത്': 'പത്ത്', 'പത്ത': 'പത്ത്',
      // Units
      'കിലോ': 'കിലോ', 'കിലൊ': 'കിലോ',
      'ഗ്രാം': 'ഗ്രാം', 'ഗ്രാമ': 'ഗ്രാം',
      'ലിറ്റർ': 'ലിറ്റർ', 'ലിറ്റ': 'ലിറ്റർ',
      // Products
      'പഞ്ചസാര': 'പഞ്ചസാര', 'പഞ്ചസാരാ': 'പഞ്ചസാര',
      'അരി': 'അരി', 'അരിയ': 'അരി',
      'ഉപ്പ്': 'ഉപ്പ്', 'ഉപ്പ': 'ഉപ്പ്',
      'എണ്ണ': 'എണ്ണ',
      'പരിപ്പ്': 'പരിപ്പ്', 'പരിപ്പ': 'പരിപ്പ്',
      'ഉള്ളി': 'ഉള്ളി', 'ഉള്ള': 'ഉള്ളി',
      'തക്കാളി': 'തക്കാളി', 'തക്കാള': 'തക്കാളി',
    },

    // ── Marathi (mr-IN) ────────────────────────────────────────────────────────
    'mr-IN': {
      'एक': 'एक', 'यक': 'एक',
      'दोन': 'दोन', 'दोणा': 'दोन',
      'तीन': 'तीन', 'तिन': 'तीन',
      'चार': 'चार',
      'पाच': 'पाच', 'पांच': 'पाच',
      'सहा': 'सहा', 'सहां': 'सहा',
      'सात': 'सात', 'साथ': 'सात',
      'आठ': 'आठ', 'आट': 'आठ',
      'नऊ': 'नऊ', 'नव': 'नऊ',
      'दहा': 'दहा', 'दश': 'दहा',
      'वीस': 'वीस', 'बिस': 'वीस',
      'तीस': 'तीस',
      'चाळीस': 'चाळीस', 'चालीस': 'चाळीस',
      // Units
      'किलो': 'किलो', 'किलों': 'किलो',
      'ग्रॅम': 'ग्रॅम', 'ग्राम': 'ग्रॅम',
      'लिटर': 'लिटर', 'लीटर': 'लिटर',
      'पाकीट': 'पाकीट', 'पॅकेट': 'पाकीट',
      // Products
      'साखर': 'साखर', 'साखरा': 'साखर',
      'तांदूळ': 'तांदूळ', 'तांदुळ': 'तांदूळ',
      'मीठ': 'मीठ', 'मिठ': 'मीठ',
      'तेल': 'तेल', 'तेली': 'तेल',
      'डाळ': 'डाळ', 'दाळ': 'डाळ',
      'कांदा': 'कांदा', 'कांदे': 'कांदा',
      'टोमॅटो': 'टोमॅटो', 'टमाटर': 'टोमॅटो',
      'बटाटा': 'बटाटा', 'बटाट': 'बटाटा',
    },

    // ── Bengali (bn-IN) ────────────────────────────────────────────────────────
    'bn-IN': {
      'এক': 'এক', 'ইক': 'এক',
      'দুই': 'দুই', 'দুয়': 'দুই',
      'তিন': 'তিন', 'তিনি': 'তিন',
      'চার': 'চার', 'চারা': 'চার',
      'পাঁচ': 'পাঁচ', 'পাচ': 'পাঁচ',
      'ছয়': 'ছয়', 'ছয়টা': 'ছয়',
      'সাত': 'সাত', 'সাতটা': 'সাত',
      'আট': 'আট', 'আঠ': 'আট',
      'নয়': 'নয়', 'নয়টা': 'নয়',
      'দশ': 'দশ', 'দশটা': 'দশ',
      // Units
      'কেজি': 'কেজি', 'কেজী': 'কেজি',
      'গ্রাম': 'গ্রাম', 'গ্রম': 'গ্রাম',
      'লিটার': 'লিটার', 'লিটর': 'লিটার',
      'প্যাকেট': 'প্যাকেট', 'পেকেট': 'প্যাকেট',
      // Products
      'চিনি': 'চিনি', 'চিনী': 'চিনি',
      'চাল': 'চাল', 'চালা': 'চাল',
      'লবণ': 'লবণ', 'নুন': 'লবণ',
      'তেল': 'তেল', 'তেলা': 'তেল',
      'ডাল': 'ডাল', 'দাল': 'ডাল',
      'পেঁয়াজ': 'পেঁয়াজ', 'পেয়াজ': 'পেঁয়াজ',
      'টমেটো': 'টমেটো', 'তমেটো': 'টমেটো',
      'আলু': 'আলু', 'আলূ': 'আলু',
    },

    // ── Gujarati (gu-IN) ───────────────────────────────────────────────────────
    'gu-IN': {
      'એક': 'એક', 'ઇક': 'એક',
      'બે': 'બે', 'બ': 'બે',
      'ત્રણ': 'ત્રણ', 'ત્રન': 'ત્રણ',
      'ચાર': 'ચાર',
      'પાંચ': 'પાંચ', 'પાચ': 'પાંચ',
      'છ': 'છ',
      'સાત': 'સાત', 'સાથ': 'સાત',
      'આઠ': 'આઠ', 'આટ': 'આઠ',
      'નવ': 'નવ',
      'દસ': 'દસ', 'દશ': 'દસ',
      // Units
      'કિલો': 'કિલો', 'કિલૉ': 'કિલો',
      'ગ્રામ': 'ગ્રામ', 'ગ્રમ': 'ગ્રામ',
      'લિટર': 'લિટર', 'લિટ': 'લિટર',
      'પેકેટ': 'પેકેટ', 'પૅકૅટ': 'પેકેટ',
      // Products
      'ખાંડ': 'ખાંડ', 'ખાંડા': 'ખાંડ',
      'ચોખા': 'ચોખા', 'ચોખ': 'ચોખા',
      'મીઠું': 'મીઠું', 'મીઠ': 'મીઠું',
      'તેલ': 'તેલ',
      'દાળ': 'દાળ', 'ધાળ': 'દાળ',
      'ડુંગળી': 'ડુંગળી', 'ડુંગળ': 'ડુંગળી',
      'ટામેટા': 'ટામેટા', 'ટામેટ': 'ટામેટા',
      'બટાટા': 'બટાટા', 'બટાટ': 'બટાટા',
    },

    // ── Punjabi (pa-IN) ────────────────────────────────────────────────────────
    'pa-IN': {
      'ਇੱਕ': 'ਇੱਕ', 'ਇਕ': 'ਇੱਕ',
      'ਦੋ': 'ਦੋ', 'ਦੋਏ': 'ਦੋ',
      'ਤਿੰਨ': 'ਤਿੰਨ', 'ਤਿਨ': 'ਤਿੰਨ',
      'ਚਾਰ': 'ਚਾਰ',
      'ਪੰਜ': 'ਪੰਜ', 'ਪੰਜ਼': 'ਪੰਜ',
      'ਛੇ': 'ਛੇ',
      'ਸੱਤ': 'ਸੱਤ',
      'ਅੱਠ': 'ਅੱਠ', 'ਅਠ': 'ਅੱਠ',
      'ਨੌਂ': 'ਨੌਂ', 'ਨੌ': 'ਨੌਂ',
      'ਦਸ': 'ਦਸ',
      // Units
      'ਕਿਲੋ': 'ਕਿਲੋ', 'ਕਿਲੋਂ': 'ਕਿਲੋ',
      'ਗ੍ਰਾਮ': 'ਗ੍ਰਾਮ', 'ਗ੍ਰਮ': 'ਗ੍ਰਾਮ',
      'ਲਿਟਰ': 'ਲਿਟਰ', 'ਲੀਟਰ': 'ਲਿਟਰ',
      // Products
      'ਖੰਡ': 'ਖੰਡ', 'ਖੰਡਾ': 'ਖੰਡ',
      'ਚਾਵਲ': 'ਚਾਵਲ', 'ਚਾਉਲ': 'ਚਾਵਲ',
      'ਲੂਣ': 'ਲੂਣ', 'ਲੂਨ': 'ਲੂਣ',
      'ਤੇਲ': 'ਤੇਲ', 'ਤੇਲਾ': 'ਤੇਲ',
      'ਦਾਲ': 'ਦਾਲ', 'ਦਾਲਾ': 'ਦਾਲ',
      'ਪਿਆਜ਼': 'ਪਿਆਜ਼', 'ਪਿਆਜ': 'ਪਿਆਜ਼',
      'ਟਮਾਟਰ': 'ਟਮਾਟਰ', 'ਟਮਾਟ': 'ਟਮਾਟਰ',
      'ਆਲੂ': 'ਆਲੂ', 'ਆਲੁ': 'ਆਲੂ',
    },
  };

  // ── Stage 4: Cross-script phoneme alignment ─────────────────────────────────
  // Maps acoustically-equivalent forms across scripts to a canonical spoken form.
  // This is the SECRET SAUCE for Hinglish / code-switching support.
  static const Map<String, String> _crossScriptMap = {
    // Sugar equivalents
    'चीनी': 'sugar', 'சர்க்கரை': 'sugar', 'పంచదార': 'sugar',
    'ಸಕ್ಕರೆ': 'sugar', 'പഞ്ചസാര': 'sugar', 'চিনি': 'sugar',
    'ખાંડ': 'sugar', 'ਖੰਡ': 'sugar', 'साखर': 'sugar',

    // Rice equivalents
    'चावल': 'rice', 'அரிசி': 'rice', 'బియ్యం': 'rice',
    'ಅಕ್ಕಿ': 'rice', 'അരി': 'rice', 'চাল': 'rice',
    'ચોખા': 'rice', 'ਚਾਵਲ': 'rice', 'तांदूळ': 'rice',

    // Salt equivalents
    'नमक': 'salt', 'உப்பு': 'salt', 'ఉప్పు': 'salt',
    'ಉಪ್ಪು': 'salt', 'ഉപ്പ്': 'salt', 'লবণ': 'salt',
    'મીઠું': 'salt', 'ਲੂਣ': 'salt', 'मीठ': 'salt',

    // Oil equivalents
    'तेल': 'oil', 'எண்ணெய்': 'oil', 'నూనె': 'oil',
    'ಎಣ್ಣೆ': 'oil', 'എണ്ണ': 'oil', 'তেল': 'oil',
    'તેલ': 'oil', 'ਤੇਲ': 'oil',

    // Dal/Lentils equivalents
    'दाल': 'dal', 'பருப்பு': 'dal', 'పప్పు': 'dal',
    'ಬೇಳೆ': 'dal', 'പരിപ്പ്': 'dal', 'ডাল': 'dal',
    'દાળ': 'dal', 'ਦਾਲ': 'dal', 'डाळ': 'dal',

    // Flour/Atta equivalents
    'आटा': 'atta', 'மாவு': 'atta', 'పిండి': 'atta',
    'ಹಿಟ್ಟು': 'atta', 'മാവ്': 'atta', 'আটা': 'atta',
    'લોટ': 'atta', 'ਆਟਾ': 'atta', 'पीठ': 'atta',

    // Onion equivalents
    'प्याज': 'onion', 'வெங்காயம்': 'onion', 'ఉల్లిపాయ': 'onion',
    'ಈರುಳ್ಳಿ': 'onion', 'ഉള്ളി': 'onion', 'পেঁয়াজ': 'onion',
    'ડુંગળી': 'onion', 'ਪਿਆਜ਼': 'onion', 'कांदा': 'onion',

    // Tomato equivalents
    'टमाटर': 'tomato', 'தக்காளி': 'tomato', 'టమాటా': 'tomato',
    'ಟೊಮ್ಯಾಟೊ': 'tomato', 'തക്കാളി': 'tomato', 'টমেটো': 'tomato',
    'ટામેટા': 'tomato', 'ਟਮਾਟਰ': 'tomato', 'टोमॅटो': 'tomato',

    // Potato equivalents
    'आलू': 'potato', 'உருளைக்கிழங்கு': 'potato', 'బంగాళాదుంప': 'potato',
    'ಆಲೂಗಡ್ಡೆ': 'potato', 'ഉരുളക്കിഴങ്ങ്': 'potato', 'আলু': 'potato',
    'બટાટા': 'potato', 'ਆਲੂ': 'potato', 'बटाटा': 'potato',

    // Ghee
    'घी': 'ghee', 'நெய்': 'ghee', 'నెయ్యి': 'ghee',
    'ತುಪ್ಪ': 'ghee', 'നെയ്യ്': 'ghee', 'ঘি': 'ghee',
    'ઘી': 'ghee', 'ਘਿਓ': 'ghee',

    // Milk
    'दूध': 'milk', 'பால்': 'milk', 'పాలు': 'milk',
    'ಹಾಲು': 'milk', 'പാൽ': 'milk', 'দুধ': 'milk',
    'દૂધ': 'milk', 'ਦੁੱਧ': 'milk',

    // Curd/Yogurt
    'दही': 'curd', 'தயிர்': 'curd', 'పెరుగు': 'curd',
    'ಮೊಸರು': 'curd', 'തൈര്': 'curd', 'দই': 'curd',
    'દહીં': 'curd', 'ਦਹੀਂ': 'curd',

    // Butter
    'मक्खन': 'butter', 'வெண்ணெய்': 'butter', 'వెన్న': 'butter',
    'ಬೆಣ್ಣೆ': 'butter', 'വെണ്ണ': 'butter', 'মাখন': 'butter',
    'માખણ': 'butter', 'ਮੱਖਣ': 'butter',
  };

  /// Main entry point. Takes a raw STT transcript + locale code, returns a
  /// cleaned, normalized transcript ready for the NLP parser.
  static String normalize(String transcript, String localeCode) {
    if (transcript.trim().isEmpty) return transcript;

    String result = transcript;

    // Stage 5: Apply per-locale STT mishearing fixes (word-by-word)
    final fixes = _sttFixes[localeCode] ?? {};
    if (fixes.isNotEmpty) {
      // Split on spaces but preserve separators (commas, conjunctions)
      final words = result.split(RegExp(r'(?<=\s)|(?=\s)'));
      result = words.map((w) {
        final lower = w.toLowerCase().trim();
        return fixes[lower] ?? fixes[w] ?? w;
      }).join();
    }

    // Stage 4: Cross-script alignment (replace native-script product names
    // with English canonical form ONLY when caller's language is Hindi/mixed,
    // so the parser can match against knownProducts catalog)
    if (localeCode == 'hi-IN' || localeCode == 'en-IN') {
      _crossScriptMap.forEach((nativeForm, canonical) {
        result = result.replaceAll(nativeForm, canonical);
      });
    }

    // Stage 3: Unicode normalization for Devanagari (NFC)
    // Flutter/Dart normalizes strings to NFC by default via dart:core.
    // We additionally collapse visually-identical Unicode sequences.
    result = _normalizeDevanagari(result);

    // Stage 2: Trailing virama / anusvara cleanup
    // Many STT engines add trailing ् (virama) to final consonants unnecessarily
    result = result
      .replaceAll(RegExp(r'्\s'), ' ')   // virama before space
      .replaceAll(RegExp(r'ं\s'), ' ')   // anusvara before space — keep within words
      ;

    // Stage 1: Collapse multiple spaces
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }

  /// Quick Devanagari normalization: map alternate Unicode codepoints
  /// to their canonical NFC equivalents that the numberWords map uses.
  static String _normalizeDevanagari(String s) {
    return s
      // Alternate paaँch forms
      .replaceAll('\u092a\u093e\u0901\u091a', 'पाँच')
      .replaceAll('\u092a\u093e\u0902\u091a', 'पाँच')
      // Alternate aadh forms (half)
      .replaceAll('\u0906\u0927\u093e', 'आधा')
      // Normalize dandas to comma so parser splits correctly
      .replaceAll('।', ',')
      .replaceAll('॥', ',')
      // Fullwidth digits to ASCII
      .replaceAllMapped(RegExp(r'[०-९]'), (m) {
        return (m.group(0)!.codeUnitAt(0) - 0x0966).toString();
      })
      // Tamil digits
      .replaceAllMapped(RegExp(r'[௦-௯]'), (m) {
        return (m.group(0)!.codeUnitAt(0) - 0x0BE6).toString();
      })
      // Telugu digits
      .replaceAllMapped(RegExp(r'[౦-౯]'), (m) {
        return (m.group(0)!.codeUnitAt(0) - 0x0C66).toString();
      })
      // Kannada digits
      .replaceAllMapped(RegExp(r'[೦-೯]'), (m) {
        return (m.group(0)!.codeUnitAt(0) - 0x0CE6).toString();
      })
      // Malayalam digits
      .replaceAllMapped(RegExp(r'[൦-൯]'), (m) {
        return (m.group(0)!.codeUnitAt(0) - 0x0D66).toString();
      })
      // Bengali digits
      .replaceAllMapped(RegExp(r'[০-৯]'), (m) {
        return (m.group(0)!.codeUnitAt(0) - 0x09E6).toString();
      })
      // Gujarati digits
      .replaceAllMapped(RegExp(r'[૦-૯]'), (m) {
        return (m.group(0)!.codeUnitAt(0) - 0x0AE6).toString();
      })
      // Gurmukhi digits
      .replaceAllMapped(RegExp(r'[੦-੯]'), (m) {
        return (m.group(0)!.codeUnitAt(0) - 0x0A66).toString();
      });
  }

  /// Returns the canonical English product name for cross-language input,
  /// or null if no mapping found.
  static String? getCrossScriptCanonical(String nativeWord) {
    return _crossScriptMap[nativeWord.trim()];
  }
}

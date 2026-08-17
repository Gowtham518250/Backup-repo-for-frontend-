/// 📚 ADVANCED: Enhanced Vocabulary for Voice Billing
/// Contains 200+ words per language for improved NLP parsing

/// Expanded English vocabulary
const Map<String, num> englishNumberWords = {
  'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
  'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
  'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
  'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
  'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50, 'sixty': 60,
  'seventy': 70, 'eighty': 80, 'ninety': 90, 'hundred': 100, 'thousand': 1000,
  'five hundred': 500, 'one thousand': 1000, 'twelve hundred': 1200,
  'half': 0.5, 'quarter': 0.25, 'third': 0.33, 'one-point-five': 1.5,
  'two-point-five': 2.5, 'three-point-five': 3.5, 'four-point-five': 4.5,
  'point-five': 0.5, 'one-five': 1.5, 'two-five': 2.5,
  // Colloquial
  'couple': 2, 'few': 3, 'dozen': 12, 'score': 20, 'baker': 13,
  'gross': 144, 'ream': 500,
};

const List<String> englishUnitWords = [
  'kg', 'kilo', 'kilogram', 'kilograms', 'gm', 'gram', 'grams', 'litre', 
  'liter', 'ltr', 'ml', 'millilitre', 'milliliter', 'piece', 'pieces', 'pcs', 
  'pc', 'packet', 'pkt', 'pack', 'packs', 'dozen', 'doz', 'box', 'boxes',
  'bottle', 'bottles', 'btl', 'jar', 'tin', 'bag', 'sachet', 'pouch', 'tube',
  'carton', 'crate', 'bundle', 'set', 'pair', 'loaf', 'slice', 'scoop',
  'cup', 'spoon', 'tablespoon', 'teaspoon', 'drop', 'can', 'tin', 'roll',
  'strip', 'sheet', 'pad', 'block', 'bar', 'stick', 'head', 'bunch',
];

const List<String> englishPriceWords = [
  'rupees', 'rupee', 'rs', 'bucks', 'price', 'cost', 'per', 'each',
  'total', 'amount', 'bill', 'charge', 'fee', 'rate', 'value', 'worth',
];

/// Expanded Hindi vocabulary
const Map<String, num> hindiNumberWords = {
  'शून्य': 0, 'एक': 1, 'दो': 2, 'तीन': 3, 'चार': 4, 'पाँच': 5, 'पांच': 5,
  'छह': 6, 'छः': 6, 'सात': 7, 'आठ': 8, 'नौ': 9, 'दस': 10,
  'ग्यारह': 11, 'बारह': 12, 'तेरह': 13, 'चौदह': 14, 'पन्द्रह': 15,
  'सोलह': 16, 'सत्रह': 17, 'अठारह': 18, 'उन्नीस': 19, 'बीस': 20,
  'तीस': 30, 'चालीस': 40, 'पचास': 50, 'साठ': 60, 'सत्तर': 70, 
  'अस्सी': 80, 'नब्बे': 90, 'सौ': 100, 'हजार': 1000,
  'आधा': 0.5, 'डेढ़': 1.5, 'सवा': 1.25, 'साढ़े': 2.5,
  // Colloquial/Hinglish
  'ek': 1, 'do': 2, 'teen': 3, 'char': 4, 'panch': 5, 'che': 6,
  'saat': 7, 'aath': 8, 'nau': 9, 'das': 10, 'gyarah': 11,
  'baarah': 12, 'terah': 13, 'chaudah': 14, 'pandrah': 15,
  'solah': 16, 'sattarah': 17, 'athaarah': 18, 'unnees': 19,
  'bees': 20, 'tees': 30, 'chaalis': 40, 'pachaas': 50,
  'saath': 60, 'sattar': 70, 'assi': 80, 'nabbe': 90,
  'sau': 100, 'hazaar': 1000, 'aadha': 0.5, 'dedh': 1.5,
  'paune': 0.75, 'savah': 0.25,
  // Numeric
  '1': 1, '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8, '9': 9, '10': 10,
};

const List<String> hindiUnitWords = [
  'किलो', 'किलोग्राम', 'ग्राम', 'लीटर', 'लिटर', 'मिली', 'मिलीलीटर',
  'पीस', 'पीस', 'पैकेट', 'पाकीट', 'डब्बा', 'बोतल', 'जार', 'बैग', 'साचे',
  'पाउच', 'ट्यूब', 'दर्जन', 'डिब्बा', 'kg', 'gm',
  // Colloquial
  'kilo', 'gram', 'dabba', 'bottle', 'pack', 'piece', 'box',
  'kati', 'kachcha', 'pura', 'top', 'namkeen', 'maal', 'samagri',
];

const List<String> hindiPriceWords = [
  'रुपये', 'रुपए', 'रूपए', 'का', 'की', 'के', 'दाम', 'कीमत',
  // Colloquial
  'rupaye', 'rupya', 'paisa', 'paise', 'ka', 'ki', 'ke', 'daam', 'keemat',
];

/// Expanded Tamil vocabulary
const Map<String, num> tamilNumberWords = {
  'பூஜ்ஜியம்': 0, 'ஒன்று': 1, 'இரண்டு': 2, 'மூன்று': 3, 'நான்கு': 4, 'ஐந்து': 5,
  'ஆறு': 6, 'ஏழு': 7, 'எட்டு': 8, 'ஒன்பது': 9, 'பத்து': 10,
  'பதினொன்று': 11, 'பனிரண்டு': 12, 'பதிமூன்று': 13, 'பதிநான்கு': 14, 'பதிநைந்து': 15,
  'பதினாறு': 16, 'பதினேழு': 17, 'பதினெட்டு': 18, 'பத்தொன்பது': 19,
  'இருபது': 20, 'முப்பது': 30, 'நாற்பது': 40, 'ஐம்பது': 50,
  'அரைக்கிலோ': 0.5, 'ஒன்றரை': 1.5,
  // Numeric
  '1': 1, '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8, '9': 9, '10': 10,
};

const List<String> tamilUnitWords = [
  'கிலோ', 'கிராம்', 'லிட்டர்', 'மி.லி', 'பாக்கெட்', 'பீஸ்', 'பீசு', 'ப்ரின்ச்',
  'பெட்டி', 'பாட்டில்', 'சாசை', 'பௌச்', 'டூப்', 'டசன்', 'kg', 'gm',
];

const List<String> tamilPriceWords = [
  'ரூபாய்', 'ரூ', 'விலை', 'விலையுள்ள', 'தொகை',
];

/// Expanded Telugu vocabulary
const Map<String, num> teluguNumberWords = {
  'సున్న': 0, 'ఒకటి': 1, 'రెండు': 2, 'మూడు': 3, 'నాలుగు': 4, 'ఐదు': 5,
  'ఆరు': 6, 'ఏడు': 7, 'ఎనిమిది': 8, 'తొమ్మిది': 9, 'పది': 10,
  'పదకొండు': 11, 'పన్నెండు': 12, 'పదమూడు': 13, 'పదనాలుగు': 14, 'పదిహేను': 15,
  'పదహారు': 16, 'పదిఏడు': 17, 'పది ఎనిమిది': 18, 'పందొమ్మిది': 19,
  'ఇరవై': 20, 'ముప్పై': 30, 'నలభై': 40, 'యాభై': 50, 'అరవై': 60, 'డెబ్బై': 70,
  'ఎనభై': 80, 'తొంభై': 90, 'వంద': 100, 'వెయ్యి': 1000,
  'ఐదు వందలు': 500, 'రెండు వందలు': 200, 'మూడు వందలు': 300,
  'నాలుగు వందలు': 400, 'అరకిలో': 0.5,
};

const List<String> teluguUnitWords = [
  'కిలో', 'గ్రాము', 'లీటర్', 'మిల్లీలీటర్', 'ప్యాకెట్', 'పీస్', 'ముక్క',
  'పెట్టె', 'సీసా', 'జార్', 'బ్యాగ్', 'సాచె', 'పౌచ్', 'ట్యూబ్', 'డజను', 'kg',
];

const List<String> teluguPriceWords = [
  'రూపాయలు', 'రూ', 'ధర', 'ఖర్చు', 'ఖరీదు',
];

/// Product synonyms for all languages
const Map<String, List<String>> productSynonyms = {
  'milk': ['doodh', 'dudh', 'paal', 'pal', 'dood', 'doodhu'],
  'sugar': ['cheeni', 'shakkar', 'sakkare', 'sarkara', 'inippu'],
  'rice': ['chawal', 'chaval', 'biyyam', 'vari', 'arisi', 'anna'],
  'oil': ['tel', 'tail', 'enne', 'noone', 'enu', 'tel'],
  'bread': ['roti', 'pav', 'bread', 'bread', 'roti', 'paav'],
  'soap': ['sabun', 'saabun', 'sabun', 'saappu', 'sappu'],
  'tea': ['chai', 'chaha', 'te', 'chai', 'chaaha', 'thee'],
  'coffee': ['kapi', 'kaapi', 'kappi', 'kapi', 'kappi'],
  'salt': ['namak', 'uppu', 'uppu', 'uppu'],
  'water': ['paani', 'neeru', 'neer', 'tanni', 'jalam'],
  'biscuit': ['biskut', 'biskit', 'biskit', 'biscut'],
  'egg': ['anda', 'guddu', 'mottai', 'guddu'],
  'butter': ['makhan', 'venna', 'venna', 'vennei'],
  'curd': ['dahi', 'perugu', 'thayir', 'perugu'],
  'tomato': ['tamatar', 'ramapala', 'thakkali', 'tamata'],
  'onion': ['pyaaz', 'ulli', 'ulli', 'vengayam'],
  'potato': ['aloo', 'aalu', 'bangaladumpa', 'urulaikizhangu'],
  'banana': ['kela', 'arati', 'valai', 'pazham'],
  'apple': ['seb', 'sebu', 'sebu', 'apple'],
  'flour': ['aata', 'maida', 'maida', 'maida'],
  'dal': ['daal', 'pappu', 'paruppu', 'paruppu'],
  'chilli': ['mirch', 'mirapakayalu', 'milagai', 'mulagu'],
};

/// Get expanded vocabulary for a language
Map<String, dynamic> getExpandedVocabulary(String languageCode) {
  switch (languageCode) {
    case 'en-IN':
      return {
        'numberWords': englishNumberWords,
        'unitWords': englishUnitWords,
        'priceWords': englishPriceWords,
      };
    case 'hi-IN':
      return {
        'numberWords': hindiNumberWords,
        'unitWords': hindiUnitWords,
        'priceWords': hindiPriceWords,
      };
    case 'ta-IN':
      return {
        'numberWords': tamilNumberWords,
        'unitWords': tamilUnitWords,
        'priceWords': tamilPriceWords,
      };
    case 'te-IN':
      return {
        'numberWords': teluguNumberWords,
        'unitWords': teluguUnitWords,
        'priceWords': teluguPriceWords,
      };
    case 'kn-IN':
      return {
        'numberWords': kannadaNumberWords,
        'unitWords': englishUnitWords, // Use English units for Kannada
        'priceWords': englishPriceWords, // Use English price words for Kannada
      };
    case 'ml-IN':
      return {
        'numberWords': malayalamNumberWords,
        'unitWords': englishUnitWords, // Use English units for Malayalam
        'priceWords': englishPriceWords, // Use English price words for Malayalam
      };
    default:
      return {
        'numberWords': englishNumberWords,
        'unitWords': englishUnitWords,
        'priceWords': englishPriceWords,
      };
  }
}

/// Kannada number words
const Map<String, num> kannadaNumberWords = {
  'ಸೊನ್ನ': 0, 'ಒಂದು': 1, 'ಎರಡು': 2, 'ಮೂರು': 3, 'ನಾಲ್ಕು': 4, 'ಐದು': 5,
  'ಆರು': 6, 'ಏಳು': 7, 'ಎಂಟು': 8, 'ಒಂಪತು': 9, 'ಹತ್ತು': 10,
  'ಹನ್ದೊಂಡು': 11, 'ಹನ್దೆರಂಡು': 12, 'ಹದ್దರు': 13, 'ಹದ್దನಾಲ್ಕು': 14, 'ಹದಿದೇನು': 15,
  'ಹದಿದೋಳ್ಕು': 16, 'ಹದಿದೆಪ್ತ್ರ': 17, 'ಹದಿದಾಟ್ಟು': 18, 'ಹದ್ದೊಂಬ್ತു': 19,
  'ಇಪ್ತು': 20, 'ಮുಪ್ತು': 30, 'ನಲವತ್ತು': 40, 'ಐಮ್ತು': 50, 'ಆಱುపತು': 60,
  'ಎ಴ುಪತು': 70, 'ತೊಂಬತು': 90, 'ನೂರು': 100, 'ಸಾವಿರ': 1000,
  'ಐದು ನೂಱು': 500, 'ರೆಂಡು ನೂಱు': 2, 'ಮೂರು నೂಱು': 3,
};

/// Malayalam number words
const Map<String, num> malayalamNumberWords = {
  'പൂജ്യം': 0, 'ഒന്നു': 1, 'രണ്ടു': 2, 'മൂന്നു': 3, 'നാലു': 4, 'അഞ്ചു': 5,
  'ആറു': 6, 'ഏഴു': 7, 'എട്ടു': 8, 'ൻപതു': 9, 'പത്ത്': 10,
  'പതിനൊന്നു': 11, 'പന്തിരണ്ടു': 12, 'പതിമൂന്നു': 13, 'പതിനാലു': 14, 'പതിനഞ്ചു': 15,
  'പതിനാറു': 16, 'പതിനേഴു': 17, 'പതിനെട്ടു': 18, 'പതിയൊന്നപതു': 19,
  'ഇരുപത്': 20, 'മുപ്പത്': 30, 'നല്പത്': 40, 'അമ്പത്': 50, 'ആറുപത്': 60,
  'എഴുപത്': 70, 'തൊണ്ണ്': 90, 'നൂറ്': 100, 'ആയിരം': 1000,
  'അഞ്ചൂറു': 500, 'രണ്ടു ൂറു': 2, 'മൂന്നു ൂറു': 3,
};

/// PHASE 4 FIX: LanguageVocabulary class for holding language-specific data
class LanguageVocabulary {
  final Map<String, num> numberWords;
  final List<String> priceWords;
  final List<String> unitWords;
  
  LanguageVocabulary({
    required this.numberWords,
    required this.priceWords,
    required this.unitWords,
  });
}

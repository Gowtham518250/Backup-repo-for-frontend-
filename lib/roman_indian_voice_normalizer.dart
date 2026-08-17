// =============================================================================
// roman_indian_voice_normalizer.dart
// Production-friendly normalization for Indian retail speech.
//
// Purpose:
//   Bridge STT output such as:
//     "rendu kilolu biyyam yaabhai"
//     "2 killolu rice 50"
//     "दो किलो चावल पचास"
//   into stable billing tokens that the existing parsers can already handle.
//
// This is intentionally lightweight and offline. It does NOT replace the
// existing STT, NLP, catalog matching, confidence, or billing validation.
// =============================================================================

class RomanIndianVoiceNormalizer {
  const RomanIndianVoiceNormalizer._();

  static final Map<String, String> _aliases = <String, String>{
    // -------------------------------------------------------------------------
    // English / common ASR variants
    // -------------------------------------------------------------------------
    'to': '2',
    'too': '2',
    'won': '1',
    'for': '4',
    'tree': '3',
    'free': '3',
    'fife': '5',
    'nien': '9',
    'to the': '2',

    'two': '2',
    'one': '1',
    'three': '3',
    'four': '4',
    'five': '5',
    'six': '6',
    'seven': '7',
    'eight': '8',
    'nine': '9',
    'ten': '10',
    'twenty': '20',
    'thirty': '30',
    'forty': '40',
    'fifty': '50',
    'sixty': '60',
    'seventy': '70',
    'eighty': '80',
    'ninety': '90',
    'hundred': '100',
    'thousand': '1000',
    'half': '0.5',
    'quarter': '0.25',

    // -------------------------------------------------------------------------
    // Telugu native + Roman Telugu
    // -------------------------------------------------------------------------
    'సున్న': '0',
    'ఒకటి': '1',
    'ఒక్కటి': '1',
    'రెండు': '2',
    'మూడు': '3',
    'నాలుగు': '4',
    'నాలగు': '4',
    'ఐదు': '5',
    'అయిదు': '5',
    'ఆరు': '6',
    'ఏడు': '7',
    'ఎనిమిది': '8',
    'ఎనమిది': '8',
    'తొమ్మిది': '9',
    'తొమిది': '9',
    'పది': '10',
    'ఇరవై': '20',
    'ముప్పై': '30',
    'నలభై': '40',
    'యాభై': '50',
    'అరవై': '60',
    'డెబ్బై': '70',
    'ఎనభై': '80',
    'తొంభై': '90',
    'అరకిలో': '0.5',
    'అర కిలో': '0.5 kg',
    'రెండున్నర': '2.5',
    'మూడున్నర': '3.5',
    'రెండున్న': '2.5',

    'okati': '1',
    'okkati': '1',
    'okaati': '1',
    'rendu': '2',
    'reṇḍu': '2',
    'moodu': '3',
    'mudu': '3',
    'mooru': '3',
    'nalugu': '4',
    'naalugu': '4',
    'nalaguu': '4',
    'aidu': '5',
    'ayidu': '5',
    'aidoo': '5',
    'aaru': '6',
    'aru': '6',
    'aarru': '6',
    'edu': '7',
    'yedu': '7',
    'enimidi': '8',
    'enamidi': '8',
    'enimadhi': '8',
    'tommidi': '9',
    'tomidi': '9',
    'tommidhi': '9',
    'padi': '10',
    'iravai': '20',
    'irwabai': '20',
    'muppai': '30',
    'mupai': '30',
    'nalabhai': '40',
    'nalabai': '40',
    'yabhai': '50',
    'yaabhai': '50',
    'yabhay': '50',
    'aravai': '60',
    'dabai': '70',
    'debai': '70',
    'enabhai': '80',
    'enabai': '80',
    'tombhai': '90',
    'tombai': '90',
    'ara kilo': '0.5 kg',
    'renduunnara': '2.5',
    'rendunnara': '2.5',
    'moodunnara': '3.5',
    'pavu': '0.25',

    // Telugu units / common ASR spellings
    'కిలో': 'kg',
    'కిలోలు': 'kg',
    'కిలోల': 'kg',
    'కిలోగ్రాము': 'kg',
    'కిలోగ్రాములు': 'kg',
    'గ్రాము': 'g',
    'గ్రాములు': 'g',
    'లీటర్': 'litre',
    'లీటర్లు': 'litre',
    'ప్యాకెట్': 'packet',
    'ప్యాకెట్లు': 'packet',
    'పీస్': 'piece',
    'పీసులు': 'piece',
    'ముక్క': 'piece',
    'ముక్కలు': 'piece',
    'పెట్టె': 'box',
    'పెట్టెలు': 'box',
    'సీసా': 'bottle',
    'సీసాలు': 'bottle',
    'డజను': 'dozen',

    'kilo': 'kg',
    'kilos': 'kg',
    'kiloes': 'kg',
    'kilogram': 'kg',
    'kilograms': 'kg',
    'kilu': 'kg',
    'kiloo': 'kg',
    'keelo': 'kg',
    'keelos': 'kg',
    'kilolu': 'kg',
    'kilola': 'kg',
    'kilo-lu': 'kg',
    'kilo lu': 'kg',
    'killolu': 'kg',
    'kilol': 'kg',
    'kg lu': 'kg',
    'kg-lu': 'kg',
    'gramlu': 'g',
    'gramulu': 'g',
    'graml': 'g',
    'litarlu': 'litre',
    'literlu': 'litre',
    'litrelu': 'litre',
    'packetlu': 'packet',
    'packetl': 'packet',
    'packetslu': 'packet',
    'bottlelu': 'bottle',
    'bottleslu': 'bottle',
    'piece lu': 'piece',
    'pieceslu': 'piece',

    // Telugu / Roman product vocabulary
    'బియ్యం': 'rice',
    'బియమ': 'rice',
    'పాలు': 'milk',
    'నూనె': 'oil',
    'పప్పు': 'dal',
    'చక్కెర': 'sugar',
    'పంచదార': 'sugar',
    'ఉప్పు': 'salt',
    'ఉల్లి': 'onion',
    'ఉల్లిపాయ': 'onion',
    'టమాటా': 'tomato',
    'టమాటో': 'tomato',
    'బంగాళదుంప': 'potato',
    'సబ్బు': 'soap',
    'బిస్కెట్': 'biscuit',
    'అరటి': 'banana',
    'ఆపిల్': 'apple',
    'గుడ్డు': 'egg',
    'పెరుగు': 'curd',
    'మిర్చి': 'chilli',
    'పసుపు': 'turmeric',
    'కొత్తిమీర': 'coriander',
    'కొబ్బరి': 'coconut',

    'biyyam': 'rice',
    'biyam': 'rice',
    'beeyam': 'rice',
    'biyyamu': 'rice',
    'vari': 'rice',
    'paalu': 'milk',
    'palu': 'milk',
    'paluu': 'milk',
    'noone': 'oil',
    'noonelu': 'oil',
    'pappu': 'dal',
    'pappulu': 'dal',
    'pesara pappu': 'moong dal',
    'kandi pappu': 'toor dal',
    'senaga pappu': 'chana dal',
    'pasupu': 'turmeric',
    'mirapakayalu': 'chilli',
    'mirapakaya': 'chilli',
    'kothimira': 'coriander',
    'kothimeera': 'coriander',
    'kobbari': 'coconut',
    'kobbari kaya': 'coconut',
    'ulli': 'onion',
    'ullipaya': 'onion',
    'ullipayalu': 'onion',
    'tamata': 'tomato',
    'tamato': 'tomato',
    'tomatta': 'tomato',
    'bangaladumpa': 'potato',
    'bangaladumpalu': 'potato',
    'arati': 'banana',
    'guddu': 'egg',
    'perugu': 'curd',
    'sabbulu': 'soap',
    'sabbu': 'soap',
    'bisket': 'biscuit',
    'biskit': 'biscuit',

    // -------------------------------------------------------------------------
    // Hindi / Hinglish
    // -------------------------------------------------------------------------
    'एक': '1',
    'दो': '2',
    'तीन': '3',
    'चार': '4',
    'पाँच': '5',
    'पांच': '5',
    'छह': '6',
    'छः': '6',
    'सात': '7',
    'आठ': '8',
    'नौ': '9',
    'दस': '10',
    'बीस': '20',
    'तीस': '30',
    'चालीस': '40',
    'पचास': '50',
    'साठ': '60',
    'सत्तर': '70',
    'अस्सी': '80',
    'नब्बे': '90',
    'सौ': '100',
    'हजार': '1000',
    'आधा': '0.5',
    'डेढ़': '1.5',

    'ek': '1',
    'do': '2',
    'teen': '3',
    'tin': '3',
    'char': '4',
    'chaar': '4',
    'panch': '5',
    'paanch': '5',
    'che': '6',
    'chhe': '6',
    'chhah': '6',
    'saat': '7',
    'aath': '8',
    'nau': '9',
    'das': '10',
    'gyarah': '11',
    'baarah': '12',
    'barah': '12',
    'terah': '13',
    'chaudah': '14',
    'pandrah': '15',
    'solah': '16',
    'satrah': '17',
    'atharah': '18',
    'unnees': '19',
    'bees': '20',
    'tees': '30',
    'chaalis': '40',
    'chalis': '40',
    'pachaas': '50',
    'pachas': '50',
    'saath': '60',
    'sattar': '70',
    'assi': '80',
    'nabbe': '90',
    'sau': '100',
    'hazaar': '1000',
    'aadha': '0.5',
    'dedh': '1.5',
    'pauna': '0.75',

    'किलो': 'kg',
    'किलोग्राम': 'kg',
    'ग्राम': 'g',
    'लीटर': 'litre',
    'लिटर': 'litre',
    'पैकेट': 'packet',
    'पाकीट': 'packet',
    'पीस': 'piece',
    'बोतल': 'bottle',
    'डब्बा': 'box',

    'chawal': 'rice',
    'chaval': 'rice',
    'doodh': 'milk',
    'dudh': 'milk',
    'cheeni': 'sugar',
    'chini': 'sugar',
    'shakkar': 'sugar',
    'tel': 'oil',
    'tail': 'oil',
    'namak': 'salt',
    'pyaaz': 'onion',
    'pyaz': 'onion',
    'aloo': 'potato',
    'aalu': 'potato',
    'tamatar': 'tomato',
    'tamater': 'tomato',
    'sabun': 'soap',
    'biskut': 'biscuit',
    'anda': 'egg',
    'dahi': 'curd',
    'makkhan': 'butter',

    // -------------------------------------------------------------------------
    // Tamil Roman forms
    // -------------------------------------------------------------------------
    'ஒன்று': '1',
    'இரண்டு': '2',
    'மூன்று': '3',
    'நான்கு': '4',
    'ஐந்து': '5',
    'ஆறு': '6',
    'ஏழு': '7',
    'எட்டு': '8',
    'ஒன்பது': '9',
    'பத்து': '10',
    'இருபது': '20',
    'முப்பது': '30',
    'நாற்பது': '40',
    'ஐம்பது': '50',
    'அரைக்கிலோ': '0.5',
    'ஒன்றரை': '1.5',
    'onnu': '1',
    'onnnu': '1',
    'randu': '2',
    'moonu': '3',
    'naalu': '4',
    'nalu': '4',
    'anju': '5',
    'aindhu': '5',
    'ezhu': '7',
    'yelu': '7',
    'ettu': '8',
    'onbadhu': '9',
    'ombadhu': '9',
    'pathu': '10',
    'irubathu': '20',
    'muppathu': '30',
    'narpathu': '40',
    'narpadhu': '40',
    'aimbathu': '50',
    'arai kilo': '0.5 kg',
    'arisi': 'rice',
    'paal': 'milk',
    'sakkarai': 'sugar',
    'uppu': 'salt',
    'ennai': 'oil',
    'paruppu': 'dal',
    'thakkali': 'tomato',
    'vengayam': 'onion',
    'urulaikizhangu': 'potato',
    'soppu': 'soap',
    'muttai': 'egg',
    'thayir': 'curd',
    'kothamalli': 'coriander',

    // -------------------------------------------------------------------------
    // Kannada Roman forms
    // -------------------------------------------------------------------------
    'ಒಂದು': '1',
    'ಎರಡು': '2',
    'ಮೂರು': '3',
    'ನಾಲ್ಕು': '4',
    'ಐದು': '5',
    'ಆರು': '6',
    'ಏಳು': '7',
    'ಎಂಟು': '8',
    'ಒಂಬತ್ತು': '9',
    'ಹತ್ತು': '10',
    'ಇಪ್ಪತ್ತು': '20',
    'ಮೂವತ್ತು': '30',
    'ನಲವತ್ತು': '40',
    'ಐವತ್ತು': '50',
    'ondhu': '1',
    'ondu': '1',
    'eradu': '2',
    'yeradu': '2',
    'moorU': '3',
    'naalku': '4',
    'elu': '7',
    'entu': '8',
    'ombattu': '9',
    'hattu': '10',
    'ippattu': '20',
    'muvattu': '30',
    'nalvattu': '40',
    'aivattu': '50',
    'akki': 'rice',
    'haalu': 'milk',
    'sakkare': 'sugar',
    'enne': 'oil',
    'bele': 'dal',
    'eerulli': 'onion',
    'tomato': 'tomato',
    'aalugadde': 'potato',
    'sopu': 'soap',
    'biskattu': 'biscuit',
    'motte': 'egg',
    'mosaru': 'curd',

    // -------------------------------------------------------------------------
    // Malayalam Roman forms
    // -------------------------------------------------------------------------
    'ഒന്ന്': '1',
    'രണ്ട്': '2',
    'മൂന്ന്': '3',
    'നാല്': '4',
    'അഞ്ച്': '5',
    'ആറ്': '6',
    'ഏഴ്': '7',
    'എട്ട്': '8',
    'ഒൻപത്': '9',
    'പത്ത്': '10',
    'ഇരുപത്': '20',
    'മുപ്പത്': '30',
    'നാൽപത്': '40',
    'അൻപത്': '50',
    'rantu': '2',
    'moonnu': '3',
    'naal': '4',
    'anchu': '5',
    'onpathu': '9',
    'ombathu': '9',
    'irupathu': '20',
    'nalpathu': '40',
    'anpathu': '50',
    'ari': 'rice',
    'panchasara': 'sugar',
    'enna': 'oil',
    'parippu': 'dal',
    'urulakkizhangu': 'potato',
    'soap': 'soap',
    'biscuit': 'biscuit',

    // -------------------------------------------------------------------------
    // Marathi / Gujarati / Bengali / Punjabi common Roman retail words
    // -------------------------------------------------------------------------
    'don': '2',
    'donhi': '2',
    'daha': '10',
    'vis': '20',
    'tis': '30',
    'pannas': '50',
    'sath': '60',
    'ashi': '80',
    'navvad': '90',
    'duudh': 'milk',
    'sakhar': 'sugar',
    'mith': 'salt',
    'kanda': 'onion',
    'batata': 'potato',
    'tandul': 'rice',
    'chokha': 'rice',
    'nun': 'salt',
    'peyaj': 'onion',
    'alu': 'potato',

    // Common unit/currency variants across Roman Indian speech
    'rupee': 'rupee',
    'rupees': 'rupees',
    'rupaya': 'rupee',
    'rupaye': 'rupees',
    'rupay': 'rupees',
    'rupayalu': 'rupees',
    'roopayalu': 'rupees',
    'roopayi': 'rupee',
    'rupaiya': 'rupee',
    'rupaiye': 'rupees',
    'rs': 'rs',
    'inr': 'inr',
    'bucks': 'bucks',
  };

  // Multiword/compound numeric prefixes. Values are their numeric bases.
  static final Map<String, double> _tens = <String, double>{
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
    'iravai': 20,
    'muppai': 30,
    'mupai': 30,
    'nalabhai': 40,
    'nalabai': 40,
    'yabhai': 50,
    'yaabhai': 50,
    'aravai': 60,
    'dabai': 70,
    'debai': 70,
    'enabhai': 80,
    'enabai': 80,
    'tombhai': 90,
    'tombai': 90,
    'bees': 20,
    'tees': 30,
    'chalis': 40,
    'pachas': 50,
    'pachaas': 50,
    'saath': 60,
    'sattar': 70,
    'assi': 80,
    'nabbe': 90,
    'irubathu': 20,
    'muppathu': 30,
    'narpadhu': 40,
    'aimbathu': 50,
    'ippattu': 20,
    'muvattu': 30,
    'nalvattu': 40,
    'aivattu': 50,
  };

  static final Map<String, double> _singleDigitWords = <String, double>{
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ek': 1,
    'okati': 1,
    'okkati': 1,
    'rendu': 2,
    'reṇḍu': 2,
    'do': 2,
    'teen': 3,
    'moodu': 3,
    'mudu': 3,
    'moonu': 3,
    'char': 4,
    'chaar': 4,
    'nalugu': 4,
    'aidu': 5,
    'ayidu': 5,
    'panch': 5,
    'paanch': 5,
    'che': 6,
    'chhe': 6,
    'aaru': 6,
    'aru': 6,
    'saat': 7,
    'edu': 7,
    'yedu': 7,
    'ezhu': 7,
    'aath': 8,
    'enimidi': 8,
    'ettu': 8,
    'nau': 9,
    'tommidi': 9,
    'onbadhu': 9,
    'das': 10,
    'padi': 10,
  
};

  /// Normalizes realistic Indian retail speech without deleting the original
  /// transcript. It returns parser-friendly semantic tokens.
  static String normalize(String input, {String? locale}) {
    if (input.trim().isEmpty) return input;

    String text = input
        .toLowerCase()
        .replaceAll('\u2019', "'")
        .replaceAll(RegExp(r'[“”]'), '"')
        .replaceAll(RegExp(r'[\u2013\u2014]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Keep decimal points but make punctuation a token boundary.
    text = text.replaceAll(RegExp(r'[,;|/]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    final tokens = text.split(' ').where((t) => t.isNotEmpty).toList();
    final out = <String>[];

    int i = 0;
    while (i < tokens.length) {
      final raw = _cleanToken(tokens[i]);
      if (raw.isEmpty) {
        i++;
        continue;
      }

      // Multiword special unit/quantity forms.
      if (i + 1 < tokens.length) {
        final two = '${_cleanToken(tokens[i])} ${_cleanToken(tokens[i + 1])}';
        final twoAlias = _aliases[two];
        if (twoAlias != null) {
          out.add(twoAlias);
          i += 2;
          continue;
        }

        // Common "tens + digit-word" compound numbers.
        final tens = _tens[raw];
        final units = _numberFromToken(_cleanToken(tokens[i + 1]));
        if (tens != null && units != null && units >= 1 && units <= 9) {
          out.add(_formatNumber(tens + units));
          i += 2;
          continue;
        }
      }

      final alias = _aliases[raw];
      if (alias != null) {
        out.add(alias);
      } else if (raw.endsWith('-lu') && raw.length > 3) {
        // Conservative Telugu plural handling. Never strip suffixes from all
        // words globally; only try it when the stem is a known unit alias.
        final stem = raw.substring(0, raw.length - 3);
        final unitAlias = _aliases[stem];
        if (unitAlias != null && _isUnit(unitAlias)) {
          out.add(unitAlias);
        } else {
          out.add(raw);
        }
      } else if (raw.endsWith('lu') && raw.length > 3) {
        final stem = raw.substring(0, raw.length - 2);
        final unitAlias = _aliases[stem];
        if (unitAlias != null && _isUnit(unitAlias)) {
          out.add(unitAlias);
        } else {
          out.add(raw);
        }
      } else {
        out.add(raw);
      }
      i++;
    }

    return out.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _cleanToken(String token) {
    var result = token.trim().toLowerCase();
    result = result.replaceAll(RegExp(r'^[.,;:!?]+'), '');
    result = result.replaceAll(RegExp(r'[.,;:!?]+$'), '');
    return result;
  }

  static double? _numberFromToken(String token) {
    final normalized = _cleanToken(token);
    final parsed = double.tryParse(normalized);
    if (parsed != null) return parsed;
    return _singleDigitWords[normalized] ??
        double.tryParse(_aliases[normalized] ?? '');
  }

  static bool _isUnit(String value) {
    return <String>{
      'kg', 'g', 'litre', 'liter', 'ml', 'packet', 'piece', 'box', 'bottle', 'dozen'
    }.contains(value);
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
}

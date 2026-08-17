import 'package:flutter/foundation.dart';
import 'dart:math' as math;

class VoiceNlpService {
  /// Enhanced voice cleaning rules - removes unwanted words as per requirements
  static const List<String> _voiceCleanupWords = [
    'rupees', 'rs', 'rupee', 'only', 'price', 'cost', 'please', 'thank you',
    'can i get', 'i want', 'i need', 'give me', 'get me', 'wala', 'wali',
    'ka', 'ke', 'ki', 'rupye', 'rupya', 'bakse', 'dabba', 'packet', 'piece', 'pcs',
    'kilo', 'kg', 'grams', 'gram', 'gm', 'liter', 'litre', 'ml',
    'cheyyandi', 'istundi', 'undali', 'kavali', 'marchandi',
    'daggara', 'ki', 'ku', 'lo', 'ni', 'nu', 'di', 'du'
  ];

  /// 🔧 ADVANCED: Product synonyms for better recognition
  static const Map<String, List<String>> _productSynonyms = {
    'milk': ['doodh', 'dudh', 'paal', 'pal'],
    'sugar': ['cheeni', 'shakkar', 'sakkare'],
    'rice': ['chawal', 'chaval', 'biyyam', 'vari'],
    'oil': ['tel', 'tail', 'enne', 'noone'],
    'bread': ['roti', 'pav', 'bread'],
    'soap': ['sabun', 'saabun'],
    'tea': ['chai', 'chaha', 'te'],
    'coffee': ['kapi', 'kaapi'],
    'salt': ['namak', 'uppu'],
    'water': ['paani', 'neeru'],
    'biscuit': ['biskut', 'biskit'],
    'egg': ['anda', 'guddu'],
    'butter': ['makhan', 'venna'],
    'curd': ['dahi', 'perugu'],
    'tomato': ['tamatar', 'ramapala'],
    'onion': ['pyaaz', 'ulli'],
    'potato': ['aloo', 'aalu', 'bangaladumpa'],
    'banana': ['kela', 'arati'],
    'apple': ['seb', 'sebu'],
  };

  /// 🔧 ADVANCED: Phonetic mapping for common mispronunciations
  static const Map<String, String> _phoneticMap = {
    'suger': 'sugar',
    'milck': 'milk',
    'bred': 'bread',
    'buter': 'butter',
    'choklet': 'chocolate',
    'bisquit': 'biscuit',
    'teliphon': 'telephone',
    'computar': 'computer',
    'mobail': 'mobile',
    'lapatap': 'laptop',
  };

  /// Parses a complex, multi-item voice command into a list of structured items.
  /// Example: "2 kg sugar 50 rupees aur 1 oil packet 150 phir adha kilo chawal"
  /// Output: [ {item: 'sugar', qty: 2.0, price: 50.0}, {item: 'oil packet', qty: 1.0, price: 150.0}, {item: 'chawal', qty: 0.5} ]
  static List<Map<String, dynamic>> parseMultipleItems(String voiceInput, {List<Map<String, dynamic>> knownInventory = const []}) {
    final List<Map<String, dynamic>> extractedItems = [];
    if (voiceInput.trim().isEmpty) return extractedItems;

    // 1. Normalize Speech with enhanced cleanup
    String normalized = _normalizeSpeech(voiceInput.toLowerCase());

    // 2. Split into distinct item phrases using conjunctions and punctuation
    final splitRegex = RegExp(
      r'(?:\s*(?:,|;|\||\u0964|\.)\s*)|\s+(?:and|aur|phir|then|also|plus|uske baad|iske sath)\s+',
      caseSensitive: false,
    );

    final parts = normalized.split(splitRegex).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    // 3. Process each part
    for (String part in parts) {
      final parsed = _parseSingleItem(part, knownInventory);
      if (parsed != null && parsed['item'].toString().isNotEmpty) {
        extractedItems.add(parsed);
      }
    }

    return extractedItems;
  }

  /// 🔧 ADVANCED: Enhanced speech normalization with phonetic correction and synonym expansion
  static String _normalizeSpeech(String text) {
    String res = text.toLowerCase();
    
    // 🔧 ADVANCED: Apply phonetic corrections first
    _phoneticMap.forEach((misspelled, correct) {
      res = res.replaceAll(RegExp(r'\b' + misspelled + r'\b'), correct);
    });
    
    // 🔧 ADVANCED: Extended number translations with regional variations
    final Map<String, String> wordToNum = {
      // English
      'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5',
      'six': '6', 'seven': '7', 'eight': '8', 'nine': '9', 'ten': '10',
      'eleven': '11', 'twelve': '12', 'thirteen': '13', 'fourteen': '14', 'fifteen': '15',
      'twenty': '20', 'thirty': '30', 'forty': '40', 'fifty': '50',
      'hundred': '100', 'thousand': '1000',
      // Hindi
      'ek': '1', 'do': '2', 'teen': '3', 'char': '4', 'panch': '5',
      'che': '6', 'saat': '7', 'aath': '8', 'nau': '9', 'das': '10',
      'gyarah': '11', 'barah': '12', 'terah': '13', 'chaudah': '14', 'pandrah': '15',
      'bees': '20', 'tees': '30', 'chalis': '40', 'pachas': '50',
      'sau': '100', 'hazaar': '1000',
      'aadha': '0.5', 'adha': '0.5', 'dedh': '1.5', 'dhaai': '2.5', 'dhai': '2.5',
      'sawa': '1.25', 'paune': '0.75',
      // Telugu
      'okati': '1', 'rendu': '2', 'moodu': '3', 'nalugu': '4', 'aidu': '5',
      'aaru': '6', 'edu': '7', 'enimidi': '8', 'tommidi': '9', 'padi': '10',
      'ardham': '0.5', 'paadi': '1.5',
      // Tamil
      'ondru': '1', 'irandu': '2', 'moondru': '3', 'naangu': '4', 'aindhu': '5',
      'aaru': '6', 'ezhu': '7', 'ettu': '8', 'onpathu': '9', 'pathu': '10',
      // Kannada
      'ondu': '1', 'eradu': '2', 'mooru': '3', 'naalku': '4', 'aidu': '5',
      'aaru': '6', 'elu': '7', 'entu': '8', 'ombhattu': '9', 'hattu': '10',
      // Malayalam
      'onn': '1', 'rand': '2', 'moonnu': '3', 'naalu': '4', 'anchu': '5',
      'aaru': '6', 'ezhu': '7', 'ettu': '8', 'onpathu': '9', 'pathu': '10',
      // Marathi
      'ek': '1', 'don': '2', 'teen': '3', 'chaar': '4', 'paach': '5',
      'saha': '6', 'sata': '7', 'aath': '8', 'nau': '9', 'dahaa': '10',
    };

    wordToNum.forEach((word, num) {
      res = res.replaceAll(RegExp(r'\b' + word + r'\b'), num);
    });

    // 🔧 ADVANCED: Handle compound numbers (e.g., "twenty one" -> "21")
    res = _handleCompoundNumbers(res);

    // Remove enhanced noise words
    for (String nw in _voiceCleanupWords) {
      res = res.replaceAll(RegExp(r'\b' + nw + r'\b', caseSensitive: false), ' ');
    }
    
    // Cleanup multiple spaces
    return res.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 🔧 ADVANCED: Handle compound numbers like "twenty one" -> "21"
  static String _handleCompoundNumbers(String text) {
    // Pattern for compound numbers: (tens word) + (ones word)
    final tensMap = {
      'twenty': '2', 'thirty': '3', 'forty': '4', 'fifty': '5',
      'sixty': '6', 'seventy': '7', 'eighty': '8', 'ninety': '9',
      'bees': '2', 'tees': '3', 'chalis': '4', 'pachas': '5',
    };
    
    final onesMap = {
      'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5',
      'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
      'ek': '1', 'do': '2', 'teen': '3', 'char': '4', 'panch': '5',
    };

    for (var entry in tensMap.entries) {
      for (var onesEntry in onesMap.entries) {
        final pattern = RegExp(r'\b' + entry.key + r'\s+' + onesEntry.key + r'\b', caseSensitive: false);
        final replacement = entry.value + onesEntry.value;
        text = text.replaceAll(pattern, replacement);
      }
    }
    
    return text;
  }

  /// 🔧 ADVANCED: Enhanced single item parsing with context awareness
  static Map<String, dynamic>? _parseSingleItem(String phrase, List<Map<String, dynamic>> inventory) {
    // 🔧 ADVANCED: Improved quantity/price extraction with context
    final numMatches = RegExp(r'\d+(\.\d+)?').allMatches(phrase).toList();
    
    double qty = 1.0;
    double price = 0.0;
    String itemStr = phrase;

    if (numMatches.isNotEmpty) {
      if (numMatches.length == 1) {
        double val = double.parse(numMatches.first.group(0)!);
        // 🔧 ADVANCED: Better heuristics for qty vs price detection
        if (val > 1000 || (val > 100 && val % 10 == 0)) {
          // Likely a price (large amounts or round numbers)
          price = val;
        } else if (val < 10 && val > 0) {
          // Likely a quantity (small numbers)
          qty = val;
        } else {
          // Ambiguous - check for price indicators in phrase
          if (phrase.contains('rs') || phrase.contains('rupee') || phrase.contains('₹')) {
            price = val;
          } else {
            qty = val;
          }
        }
      } else if (numMatches.length >= 2) {
        // Typically: Qty [Item] Price
        qty = double.parse(numMatches[0].group(0)!);
        price = double.parse(numMatches[1].group(0)!);
      }

      // Remove the matched numbers to extract the item name
      for (var match in numMatches) {
        itemStr = itemStr.replaceFirst(match.group(0)!, '');
      }
    }

    itemStr = itemStr.trim();
    if (itemStr.isEmpty) return null;

    // 🔧 ADVANCED: Apply synonym expansion before matching
    itemStr = _expandSynonyms(itemStr);

    // 🔧 ADVANCED: Enhanced fuzzy matching with inventory
    if (inventory.isNotEmpty) {
      final bestMatch = _findBestMatch(itemStr, inventory);
      if (bestMatch != null) {
        itemStr = bestMatch['name'];
        if (price == 0 && bestMatch['price'] != null) {
          price = (bestMatch['price'] as num).toDouble();
        }
      }
    }

    // 🔧 ADVANCED: Validation and error correction
    if (qty <= 0) qty = 1.0;
    if (price < 0) price = 0.0;

    return {
      'item': itemStr,
      'qty': qty,
      'price': price,
    };
  }

  /// 🔧 ADVANCED: Expand synonyms to canonical product names
  static String _expandSynonyms(String itemStr) {
    for (var entry in _productSynonyms.entries) {
      for (var synonym in entry.value) {
        if (itemStr.contains(synonym)) {
          itemStr = itemStr.replaceAll(synonym, entry.key);
        }
      }
    }
    return itemStr;
  }

  /// 🔧 ADVANCED: Enhanced fuzzy matching with multiple algorithms
  static Map<String, dynamic>? _findBestMatch(String query, List<Map<String, dynamic>> inventory) {
    if (inventory.isEmpty) return null;
    
    double bestScore = 0.0;
    Map<String, dynamic>? bestItem;

    for (var item in inventory) {
      String itemName = (item['name'] ?? '').toString().toLowerCase();
      
      // 🔧 ADVANCED: Multi-algorithm scoring
      double score = 0.0;
      
      // 1. Levenshtein distance (edit distance)
      int levenshteinDist = _levenshtein(query, itemName);
      double levenshteinScore = 1.0 - (levenshteinDist / math.max(query.length, itemName.length));
      score += levenshteinScore * 0.4; // 40% weight
      
      // 2. Jaccard similarity (word overlap)
      double jaccardScore = _jaccardSimilarity(query, itemName);
      score += jaccardScore * 0.3; // 30% weight
      
      // 3. Substring match bonus
      if (itemName.contains(query) || query.contains(itemName)) {
        score += 0.3; // 30% bonus
      }
      
      // 4. Soundex phonetic similarity (for similar-sounding words)
      double soundexScore = _soundexSimilarity(query, itemName);
      score += soundexScore * 0.1; // 10% weight
      
      // 5. Length similarity penalty (prefer similar length matches)
      double lengthDiff = (query.length - itemName.length).abs().toDouble();
      double lengthScore = 1.0 - (lengthDiff / math.max(query.length, itemName.length));
      score += lengthScore * 0.1; // 10% weight

      if (score > bestScore && score > 0.5) { // Threshold for acceptable match
        bestScore = score;
        bestItem = item;
      }
    }
    
    return bestItem;
  }

  /// 🔧 ADVANCED: Jaccard similarity for word overlap
  static double _jaccardSimilarity(String a, String b) {
    final setA = a.split(' ').toSet();
    final setB = b.split(' ').toSet();
    
    if (setA.isEmpty && setB.isEmpty) return 1.0;
    if (setA.isEmpty || setB.isEmpty) return 0.0;
    
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    
    return intersection / union;
  }

  /// 🔧 ADVANCED: Soundex phonetic similarity
  static double _soundexSimilarity(String a, String b) {
    final soundexA = _soundex(a);
    final soundexB = _soundex(b);
    
    if (soundexA == soundexB) return 1.0;
    if (soundexA.substring(0, 3) == soundexB.substring(0, 3)) return 0.7;
    if (soundexA[0] == soundexB[0]) return 0.4;
    
    return 0.0;
  }

  /// 🔧 ADVANCED: Soundex algorithm for phonetic comparison
  static String _soundex(String s) {
    if (s.isEmpty) return '';
    
    String result = s[0].toUpperCase();
    String previous = '';
    
    for (int i = 1; i < s.length; i++) {
      String c = s[i].toUpperCase();
      String code = _soundexCode(c);
      
      if (code.isNotEmpty && code != previous) {
        result += code;
        previous = code;
      }
    }
    
    // Pad or truncate to 4 characters
    while (result.length < 4) {
      result += '0';
    }
    return result.substring(0, 4);
  }

  static String _soundexCode(String c) {
    switch (c) {
      case 'B': case 'F': case 'P': case 'V': return '1';
      case 'C': case 'G': case 'J': case 'K': case 'Q': case 'S': case 'X': case 'Z': return '2';
      case 'D': case 'T': return '3';
      case 'L': return '4';
      case 'M': case 'N': return '5';
      case 'R': return '6';
      default: return '';
    }
  }

  static int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> v0 = List<int>.generate(b.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        int cost = (a[i] == b[j]) ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost
        ].reduce((min, e) => e < min ? e : min);
      }
      for (int j = 0; j <= b.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[b.length];
  }
}

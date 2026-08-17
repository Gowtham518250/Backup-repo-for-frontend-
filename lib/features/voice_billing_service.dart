import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../voice_billing_enhanced_vocabulary.dart' as vocab;

class VoiceBillingService {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;

  Future<bool> initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize();
      return _speechEnabled;
    } catch (e) {
      if (kDebugMode) debugPrint('Speech init failed: $e');
      return false;
    }
  }

  bool get isListening => _speechToText.isListening;

  void startListening(Function(String) onResult) async {
    if (!_speechEnabled) {
      bool initialized = await initSpeech();
      if (!initialized) return;
    }
    await _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
        }
      },
    );
  }

  void stopListening() async {
    await _speechToText.stop();
  }

  /// PHASE 4 FIX: Enhanced NLP parser for natural product-price input
  /// Supports: "Chicken Biryani 200" → {name: "Chicken Biryani", price: 200, qty: 1}
  /// Also supports: "2 water 50", "masala dosa 150 x3", etc.
  Map<String, dynamic> parseSpokenText(String text, {String language = 'hi-IN'}) {
    if (text.isEmpty) return {'items': [], 'error': 'Empty input'};
    
    // Get vocabulary based on language
    final vocab.LanguageVocabulary languageVocab = _getLanguageVocabulary(language);
    final numberWords = languageVocab.numberWords;
    final priceWords = languageVocab.priceWords;
    
    final Map<String, dynamic> result = {
      'items': <Map<String, dynamic>>[],
      'success': false,
      'debug': {},
    };

    String normalized = text.toLowerCase().trim();
    
    // Remove noise words
    final noiseWords = [
      'please add', 'add', 'item', 'product', 'ok', 'alright', 'stop', 
      'the', 'a', 'and', 'next', 'one more', 'one', 'uhm', 'uh', 'ah', 'like',
    ];
    
    for (final noise in noiseWords) {
      normalized = normalized.replaceAll(noise, '');
    }
    
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (kDebugMode) debugPrint('📝 Normalized: $normalized');

    // ── PATTERN 1: "Chicken Biryani 200" (product name + price) ──
    // Try to match: <words> <number>
    final parts = normalized.split(RegExp(r'\s+'));
    
    // Find number at the end
    int? priceValue;
    int priceIndex = -1;
    int qtyValue = 1;
    int qtyIndex = -1;
    
    // Scan from right to left for price and quantity
    for (int i = parts.length - 1; i >= 0; i--) {
      final part = parts[i];
      
      // Check for direct number
      if (int.tryParse(part) != null) {
        if (priceValue == null) {
          priceValue = int.parse(part);
          priceIndex = i;
        } else if (qtyValue == 1) {
          qtyValue = int.parse(part);
          qtyIndex = i;
          break;
        }
      }
      
      // Check for word number (e.g., "fifty", "fifty rupees")
      final num? wordNum = numberWords[part];
      if (wordNum != null) {
        if (priceValue == null) {
          priceValue = wordNum.toInt();
          priceIndex = i;
        } else if (qtyValue == 1) {
          qtyValue = wordNum.toInt();
          qtyIndex = i;
          break;
        }
      }
      
      // Check for price keywords
      if (priceWords.contains(part) && priceIndex >= 0) {
        // Move price index to just before price word
        break;
      }
    }
    
    if (priceValue != null && priceValue > 0 && priceIndex >= 0) {
      // Product name is everything before the price
      final productNameParts = parts.sublist(0, priceIndex);
      
      if (productNameParts.isNotEmpty) {
        final productName = productNameParts.join(' ').trim();
        
        if (productName.isNotEmpty && productName.length > 2) {
          result['items'].add({
            'product_name': productName,
            'price': priceValue.toDouble(),
            'qty': qtyValue,
            'unit': 'piece',
          });
          result['success'] = true;
          if (kDebugMode) {
            debugPrint('✅ Pattern 1 matched: "$productName" x$qtyValue @ ₹$priceValue');
          }
          return result;
        }
      }
    }

    // ── PATTERN 2: "2 water 50" (qty + product + price) ──
    if (parts.length >= 3) {
      final firstNum = int.tryParse(parts[0]) ?? (numberWords[parts[0]]?.toInt());
      final lastNum = int.tryParse(parts[parts.length - 1]) ?? 
                      (numberWords[parts[parts.length - 1]]?.toInt());
      
      if (firstNum != null && firstNum > 0 && lastNum != null && lastNum > 0) {
        final productParts = parts.sublist(1, parts.length - 1);
        if (productParts.isNotEmpty) {
          final productName = productParts.join(' ').trim();
          if (productName.isNotEmpty && productName.length > 2) {
            result['items'].add({
              'product_name': productName,
              'price': lastNum.toDouble(),
              'qty': firstNum,
              'unit': 'piece',
            });
            result['success'] = true;
            if (kDebugMode) {
              debugPrint('✅ Pattern 2 matched: $firstNum x "$productName" @ ₹$lastNum');
            }
            return result;
          }
        }
      }
    }

    // ── PATTERN 3: Multiple products separated by "and" ──
    final items = normalized.split(RegExp(r'\s+and\s+'));
    if (items.length > 1) {
      for (final item in items) {
        final itemParts = item.split(RegExp(r'\s+'));
        if (itemParts.length >= 2) {
          int? itemPrice;
          int itemQty = 1;
          
          for (int i = itemParts.length - 1; i >= 0; i--) {
            final part = itemParts[i];
            if (int.tryParse(part) != null && itemPrice == null) {
              itemPrice = int.parse(part);
              break;
            }
          }
          
          if (itemPrice != null && itemPrice > 0) {
            final productNameParts = itemParts.sublist(0, itemParts.length - 1);
            final productName = productNameParts.join(' ').trim();
            
            if (productName.isNotEmpty && productName.length > 2) {
              result['items'].add({
                'product_name': productName,
                'price': itemPrice.toDouble(),
                'qty': itemQty,
                'unit': 'piece',
              });
            }
          }
        }
      }
      
      if (result['items'].isNotEmpty) {
        result['success'] = true;
        if (kDebugMode) {
          debugPrint('✅ Pattern 3 matched: ${result['items'].length} products');
        }
        return result;
      }
    }

    // Fallback: naive parser for simple cases
    String lowercased = text.toLowerCase()
      .replaceAll('one', '1').replaceAll('a ', '1 ').replaceAll('an ', '1 ')
      .replaceAll('two', '2').replaceAll('three', '3').replaceAll('four', '4')
      .replaceAll('five', '5').replaceAll('six', '6').replaceAll('seven', '7')
      .replaceAll('eight', '8').replaceAll('nine', '9').replaceAll('ten', '10');

    lowercased = lowercased.replaceAll('add', '').replaceAll('and', '').replaceAll('please', '').trim();

    final simpleParts = lowercased.split(RegExp(r'\s+'));
    int currentQty = 1;

    for (int i = 0; i < simpleParts.length; i++) {
      final part = simpleParts[i];
      if (int.tryParse(part) != null) {
        currentQty = int.parse(part);
      } else {
        if (part.length > 2) {
          result['items'].add({
            'product_name': part,
            'price': 0.0,
            'qty': currentQty,
            'unit': 'piece',
          });
          currentQty = 1;
        }
      }
    }

    result['success'] = result['items'].isNotEmpty;
    if (result['success']) {
      if (kDebugMode) debugPrint('✅ Fallback parser matched: ${result['items'].length} items');
    }
    
    return result;
  }

  /// Get language vocabulary
  vocab.LanguageVocabulary _getLanguageVocab(String language) {
    if (language.startsWith('hi')) {
      return vocab.LanguageVocabulary(
        numberWords: vocab.hindiNumberWords,
        priceWords: vocab.hindiPriceWords,
        unitWords: vocab.hindiUnitWords,
      );
    } else if (language.startsWith('te')) {
      return vocab.LanguageVocabulary(
        numberWords: vocab.teluguNumberWords,
        priceWords: vocab.teluguPriceWords,
        unitWords: vocab.teluguUnitWords,
      );
    } else if (language.startsWith('ta')) {
      return vocab.LanguageVocabulary(
        numberWords: vocab.tamilNumberWords,
        priceWords: vocab.tamilPriceWords,
        unitWords: vocab.tamilUnitWords,
      );
    }
    // Default to English
    return vocab.LanguageVocabulary(
      numberWords: vocab.englishNumberWords,
      priceWords: vocab.englishPriceWords,
      unitWords: vocab.englishUnitWords,
    );
  }

  /// Get language vocabulary - wrapper function
  vocab.LanguageVocabulary _getLanguageVocabulary(String language) {
    return _getLanguageVocab(language);
  }
}


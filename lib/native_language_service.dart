import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class NativeLanguageService {
  static final ModelManager _modelManager = OnDeviceTranslatorModelManager();
  static OnDeviceTranslator? _hindiTranslator;
  static bool _isModelDownloaded = false;

  // Custom dictionary for phonetic Hinglish words that ML Kit struggles with
  static final Map<String, String> _hinglishDictionary = {
    'aalu': 'potato',
    'aloo': 'potato',
    'pyaaz': 'onion',
    'pyaz': 'onion',
    'tamatar': 'tomato',
    'chini': 'sugar',
    'cheeni': 'sugar',
    'namak': 'salt',
    'doodh': 'milk',
    'dudh': 'milk',
    'chawal': 'rice',
    'atta': 'wheat flour',
    'aata': 'wheat flour',
    'paneer': 'cottage cheese',
    'mirchi': 'chilli',
    'haldi': 'turmeric',
    'tel': 'oil',
    'pani': 'water',
    'chai': 'tea',
    'patti': 'tea leaves',
    'sabji': 'vegetable',
    'sabzi': 'vegetable',
    'dal': 'lentil',
    'daal': 'lentil',
    'ghee': 'clarified butter',
    'dahi': 'curd',
    'nimbu': 'lemon',
    'lasun': 'garlic',
    'lahsun': 'garlic',
    'adrak': 'ginger',
  };

  /// Initialize the ML Kit Model
  static Future<void> initialize() async {
    try {
      _isModelDownloaded = await _modelManager.isModelDownloaded(TranslateLanguage.hindi.bcpCode);
      if (!_isModelDownloaded) {
        if (kDebugMode) debugPrint('Downloading Hindi Translation Model (~30MB)...');
        _isModelDownloaded = await _modelManager.downloadModel(TranslateLanguage.hindi.bcpCode);
      }
      
      if (_isModelDownloaded) {
        _hindiTranslator = OnDeviceTranslator(
          sourceLanguage: TranslateLanguage.hindi,
          targetLanguage: TranslateLanguage.english,
        );
        if (kDebugMode) debugPrint('Offline Translation Engine Ready!');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error initializing NativeLanguageService: ');
    }
  }

  /// Translates text safely. Falls back to Hinglish dictionary if native translation is unnecessary.
  static Future<String> translateToEnglish(String input) async {
    String text = input.toLowerCase().trim();

    // 1. Check Hinglish Dictionary FIRST (extremely fast O(1))
    // We split into words, translate individually, and rebuild
    final words = text.split(RegExp(r'\s+'));
    for (int i = 0; i < words.length; i++) {
      if (_hinglishDictionary.containsKey(words[i])) {
        words[i] = _hinglishDictionary[words[i]]!;
      }
    }
    text = words.join(' ');

    // 2. Check for Native Script (Devanagari Unicode Block: 0900-097F)
    final hasHindiScript = RegExp(r'[ऀ-ॿ]').hasMatch(text);
    if (!hasHindiScript) {
      // If it's pure English/Hinglish characters, return dictionary result
      return text;
    }

    // 3. Use ML Kit for Native Script Offline Translation
    if (_hindiTranslator != null && _isModelDownloaded) {
      try {
        final translatedText = await _hindiTranslator!.translateText(text);
        if (kDebugMode) debugPrint('Translated $text -> $translatedText');
        return translatedText.toLowerCase();
      } catch (e) {
        if (kDebugMode) debugPrint('Translation Failed: $e');
      }
    } else {
      // Lazy init if not ready
      await initialize();
      if (_hindiTranslator != null) {
        try {
          return (await _hindiTranslator!.translateText(text)).toLowerCase();
        } catch (_) {}
      }
    }

    return text;
  }

  static void dispose() {
    _hindiTranslator?.close();
  }
}

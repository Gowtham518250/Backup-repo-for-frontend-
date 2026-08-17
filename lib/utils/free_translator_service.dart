import 'dart:convert';
import 'package:http/http.dart' as http;

class FreeTranslatorService {
  /// Translates text using the free public Google Translate API endpoint.
  /// No API key is required.
  static Future<String> translate(String text, {String from = 'auto', String to = 'en'}) async {
    if (text.trim().isEmpty) return text;
    
    // For some Indic scripts, 'auto' might struggle on single words.
    // However, it is generally very reliable.
    final url = Uri.parse(
      'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$from&tl=$to&dt=t&q=${Uri.encodeComponent(text)}'
    );

    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        // Response format is highly nested JSON:
        // [[["Translated text", "Original text", null, null, 1]], null, "ta"]
        final jsonResponse = jsonDecode(response.body);
        
        if (jsonResponse != null && jsonResponse.isNotEmpty) {
          final List translations = jsonResponse[0];
          String translatedString = '';
          
          for (var item in translations) {
            if (item != null && item.isNotEmpty) {
              translatedString += item[0];
            }
          }
          
          return translatedString.trim();
        }
      }
      print('Translation failed with status: ${response.statusCode}');
      return text; // Fallback to original text if translation fails
    } catch (e) {
      print('Translation error: $e');
      return text; // Fallback
    }
  }
}

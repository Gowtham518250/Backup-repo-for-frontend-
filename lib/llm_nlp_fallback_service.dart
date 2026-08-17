import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;

/// 🤖 ADVANCED: LLM-based NLP Fallback Service
/// Uses AI models (OpenAI GPT-4, Claude, or local LLMs) for complex voice parsing
/// Falls back to this when rule-based parser has low confidence
class LLMNLPFallbackService {
  // API configurations (should be stored securely)
  String? _openaiApiKey;
  String? _claudeApiKey;
  String? _localLLMEndpoint;
  
  bool _isEnabled = false;
  
  /// Initialize LLM service
  Future<bool> initialize({
    String? openaiApiKey,
    String? claudeApiKey,
    String? localLLMEndpoint,
  }) async {
    _openaiApiKey = openaiApiKey;
    _claudeApiKey = claudeApiKey;
    _localLLMEndpoint = localLLMEndpoint;
    
    _isEnabled = (_openaiApiKey != null && _openaiApiKey!.isNotEmpty) ||
                 (_claudeApiKey != null && _claudeApiKey!.isNotEmpty) ||
                 (_localLLMEndpoint != null && _localLLMEndpoint!.isNotEmpty);
    
    if (kDebugMode) {
      debugPrint('🤖 LLM NLP Service initialized: ${_isEnabled ? "ENABLED" : "DISABLED"}');
    }
    
    return _isEnabled;
  }
  
  /// Check if LLM fallback is available
  bool get isAvailable => _isEnabled;
  
  /// Parse voice transcript using LLM
  /// Returns: List of {name, quantity, unit, price, confidence}
  Future<List<Map<String, dynamic>>> parseWithLLM({
    required String transcript,
    required String languageCode,
    List<Map<String, dynamic>> knownInventory = const [],
  }) async {
    if (!isAvailable) {
      throw Exception('LLM service is not enabled');
    }
    
    try {
      // Try OpenAI first
      if (_openaiApiKey != null && _openaiApiKey!.isNotEmpty) {
        final result = await _parseWithOpenAI(
          transcript: transcript,
          languageCode: languageCode,
          knownInventory: knownInventory,
        );
        if (result.isNotEmpty) return result;
      }
      
      // Try Claude if OpenAI fails
      if (_claudeApiKey != null && _claudeApiKey!.isNotEmpty) {
        final result = await _parseWithClaude(
          transcript: transcript,
          languageCode: languageCode,
          knownInventory: knownInventory,
        );
        if (result.isNotEmpty) return result;
      }
      
      // Try local LLM endpoint
      if (_localLLMEndpoint != null && _localLLMEndpoint!.isNotEmpty) {
        final result = await _parseWithLocalLLM(
          transcript: transcript,
          languageCode: languageCode,
          knownInventory: knownInventory,
        );
        if (result.isNotEmpty) return result;
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('❌ LLM parsing failed: $e');
      return [];
    }
  }
  
  /// Parse using OpenAI GPT-4
  Future<List<Map<String, dynamic>>> _parseWithOpenAI({
    required String transcript,
    required String languageCode,
    required List<Map<String, dynamic>> knownInventory,
  }) async {
    try {
      final inventoryContext = knownInventory.isNotEmpty
          ? 'Known inventory items: ${knownInventory.map((i) => i['name']).join(', ')}'
          : '';
      
      final prompt = '''
You are a voice billing parser for a retail shop. Parse the following voice transcript in $languageCode language.

Transcript: "$transcript"

$inventoryContext

Extract all items mentioned. For each item, provide:
- name: product name (match with known inventory if possible)
- quantity: numeric value
- unit: kg/gm/litre/piece (default to 'piece' if not specified)
- price: price in rupees (0 if not mentioned)

Return ONLY valid JSON array like:
[
  {"name": "sugar", "quantity": 2.0, "unit": "kg", "price": 50.0},
  {"name": "milk", "quantity": 1.0, "unit": "litre", "price": 60.0}
]
''';
      
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_openaiApiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': 'gpt-4',
          'messages': [
            {'role': 'system', 'content': 'You are a JSON-only voice billing parser. Return only valid JSON, no explanations.'},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.1,
          'max_tokens': 500,
        }),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        // Extract JSON from response (handle markdown code blocks)
        String jsonStr = content;
        if (jsonStr.contains('```json')) {
          jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
        } else if (jsonStr.contains('```')) {
          jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
        }
        
        final List<dynamic> items = json.decode(jsonStr);
        
        if (kDebugMode) {
          debugPrint('🤖 OpenAI parsed ${items.length} items');
        }
        
        return items.map((item) => {
          'name': item['name']?.toString() ?? '',
          'quantity': (item['quantity'] as num?)?.toDouble() ?? 0.0,
          'unit': item['unit']?.toString() ?? 'piece',
          'price': (item['price'] as num?)?.toDouble() ?? 0.0,
          'confidence': 0.95, // LLM typically has high confidence
          'source': 'openai',
        }).toList();
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ OpenAI parsing failed: $e');
      return [];
    }
  }
  
  /// Parse using Claude
  Future<List<Map<String, dynamic>>> _parseWithClaude({
    required String transcript,
    required String languageCode,
    required List<Map<String, dynamic>> knownInventory,
  }) async {
    try {
      final inventoryContext = knownInventory.isNotEmpty
          ? 'Known inventory items: ${knownInventory.map((i) => i['name']).join(', ')}'
          : '';
      
      final prompt = '''
You are a voice billing parser for a retail shop. Parse the following voice transcript in $languageCode language.

Transcript: "$transcript"

$inventoryContext

Extract all items mentioned. Return ONLY valid JSON array:
[{"name": "...", "quantity": 1.0, "unit": "...", "price": 0.0}]
''';
      
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': _claudeApiKey!,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': 'claude-3-opus-20240229',
          'max_tokens': 500,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['content'][0]['text'];
        
        // Extract JSON
        String jsonStr = content;
        if (jsonStr.contains('```json')) {
          jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
        } else if (jsonStr.contains('```')) {
          jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
        }
        
        final List<dynamic> items = json.decode(jsonStr);
        
        if (kDebugMode) {
          debugPrint('🤖 Claude parsed ${items.length} items');
        }
        
        return items.map((item) => {
          'name': item['name']?.toString() ?? '',
          'quantity': (item['quantity'] as num?)?.toDouble() ?? 0.0,
          'unit': item['unit']?.toString() ?? 'piece',
          'price': (item['price'] as num?)?.toDouble() ?? 0.0,
          'confidence': 0.95,
          'source': 'claude',
        }).toList();
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Claude parsing failed: $e');
      return [];
    }
  }
  
  /// Parse using local LLM (Ollama, etc.)
  Future<List<Map<String, dynamic>>> _parseWithLocalLLM({
    required String transcript,
    required String languageCode,
    required List<Map<String, dynamic>> knownInventory,
  }) async {
    try {
      final prompt = '''
Parse this voice transcript into billing items:
"$transcript"
Language: $languageCode
${knownInventory.isNotEmpty ? 'Known items: ${knownInventory.map((i) => i['name']).join(', ')}' : ''}

Return JSON array: [{"name": "...", "quantity": 1.0, "unit": "...", "price": 0.0}]
''';
      
      final response = await http.post(
        Uri.parse('$_localLLMEndpoint/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': 'llama3',
          'prompt': prompt,
          'stream': false,
          'format': 'json',
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['response'];
        
        final List<dynamic> items = json.decode(content);
        
        if (kDebugMode) {
          debugPrint('🤖 Local LLM parsed ${items.length} items');
        }
        
        return items.map((item) => {
          'name': item['name']?.toString() ?? '',
          'quantity': (item['quantity'] as num?)?.toDouble() ?? 0.0,
          'unit': item['unit']?.toString() ?? 'piece',
          'price': (item['price'] as num?)?.toDouble() ?? 0.0,
          'confidence': 0.90, // Local LLM slightly lower confidence
          'source': 'local_llm',
        }).toList();
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Local LLM parsing failed: $e');
      return [];
    }
  }
  
  /// Enable/disable LLM fallback
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    if (kDebugMode) {
      debugPrint('🤖 LLM fallback ${enabled ? "ENABLED" : "DISABLED"}');
    }
  }
}

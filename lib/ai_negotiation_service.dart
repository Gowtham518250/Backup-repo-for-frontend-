import 'dart:convert';
import 'api_client.dart';

class AiNegotiationService {
  /// Generates a professional negotiation message for a supplier
  /// based on product inventory and sales history.
  static Future<String> generateNegotiationMessage({
    required String productName,
    required double currentStock,
    required double minStock,
    required double unitPrice,
    required String category,
  }) async {
    try {
      // Prompt for the AI to generate a negotiation message
      final prompt = """
      Act as a retail shop owner. One of my products, '$productName', is low on stock ($currentStock remaining, minimum threshold is $minStock). 
      I want to reorder a bulk quantity from my supplier. 
      The current unit price I sell at is ₹$unitPrice. 
      Generate a professional, persuasive WhatsApp or Email message to my supplier requesting a 10-15% bulk discount for the next shipment, 
      mentioning that I have high turnover for this '$category' item and want to maintain a long-term partnership.
      Keep it concise and ready to send.
      """;

      final response = await ApiClient.postJson(ApiClient.chatbotEndpoint, {
        'message': prompt,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // The Master List says POST /chatbot/ returns a response
        return data['response'] ?? 'Could not generate message. Please try again.';
      } else {
        return 'AI Service is currently busy. Please try again later.';
      }
    } catch (e) {
      return 'Error generating negotiation: $e';
    }
  }
}

/// Feature 3: Festival Stock Predictor
/// Show "stock up" banner 7-14 days before Indian festivals

import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_client.dart';

class FestivalStockPredictorService {
  static const List<String> indianFestivals = [
    'Diwali', 'Holi', 'Eid', 'Pongal', 'Navratri', 
    'Durga Puja', 'Rakhi', 'Janmashtami', 'Ganesh Chaturthi'
  ];
  
  /// Get upcoming festival alerts from backend
  static Future<List<Map<String, dynamic>>> getUpcomingFestivalAlerts() async {
    try {
      final response = await ApiClient.getJson(ApiClient.todayInsightEndpoint);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final festivals = List<Map<String, dynamic>>.from(data['festivals'] ?? []);
        
        return festivals.where((f) {
          final daysUntil = f['days_until'] ?? 999;
          return daysUntil > 0 && daysUntil <= 14;
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching festival data: $e');
      return [];
    }
  }
  
  /// Get top products to stock for a festival
  static Future<List<Map<String, dynamic>>> getFestivalTopProducts(String festivalName) async {
    try {
      final response = await ApiClient.getJson('/api/festivals/top-products/$festivalName');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['top_5_products'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching festival products: $e');
      return [];
    }
  }
}


/// Feature 4: Chatbot Context Service
/// Inject shop data into chatbot for personalized responses


class ChatbotContextService {
  /// Get chatbot system prompt with shop context
  static Future<String> getChatbotSystemPrompt() async {
    try {
      final response = await ApiClient.getJson('/api/chatbot/context');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['system_prompt'] ?? '';
      }
      return '';
    } catch (e) {
      return '';
    }
  }
  
  /// Get greeting with shop name
  static Future<String> getPersonalizedGreeting() async {
    try {
      final response = await ApiClient.getJson('/api/chatbot/greeting');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['greeting'] ?? 'Hello! How can I help you?';
      }
      return 'Hello! How can I help you?';
    } catch (e) {
      return 'Hello! How can I help you?';
    }
  }
  
  /// Send message with context to chatbot API
  static Future<String> sendMessageWithContext(String userMessage) async {
    try {
      final contextResponse = await ApiClient.getJson('/api/chatbot/context');
      
      if (contextResponse.statusCode != 200) {
        return 'Unable to load shop context';
      }
      
      final context = jsonDecode(contextResponse.body);
      
      // Send to LLM with context
      final response = await ApiClient.postJson(ApiClient.chatbotEndpoint, {
        'message': userMessage,
        'context': context,
      });
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] ?? 'No response';
      }
      
      return 'Error getting response';
    } catch (e) {
      return 'Error: $e';
    }
  }
}

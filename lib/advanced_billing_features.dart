/// Voice-First Billing Engine (Feature 1)
/// Hindi+English mixed voice parsing into bill rows

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher_string.dart';

class AdvancedVoiceParser {
  
  static Map<String, dynamic>? parseVoiceCommand(String voiceText) {
    try {
      String text = voiceText.toLowerCase().trim();
      final patterns = [
        RegExp(r'(\d+\.?\d*)\s*(?:kg|gm|ld|m|piece|pcs|units?)?\s*([a-zA-Zा-ह]+)\s*(\d+\.?\d*)'),
        RegExp(r'([a-zA-Zा-ह]+)\s*(\d+\.?\d*)\s*rupees?'),
      ];
      Map<String, dynamic> result = {};
      for (var pattern in patterns) {
        final match = pattern.firstMatch(text);
        if (match != null) {
          if (pattern.pattern.contains('kg|gm')) {
            result['quantity'] = double.tryParse(match.group(1) ?? '1') ?? 1;
            result['product_name'] = match.group(2)?.trim();
            result['price'] = double.tryParse(match.group(3) ?? '0') ?? 0;
          }
        }
      }
      if (result.isNotEmpty && result['product_name'] != null) return result;
      return null;
    } catch (e) { return null; }
  }

  static List<Map<String, dynamic>> parseBatchVoiceCommand(String voiceText) {
    List<Map<String, dynamic>> results = [];
    final items = voiceText.split(',');
    for (String item in items) {
      final parsed = parseVoiceCommand(item.trim());
      if (parsed != null) results.add(parsed);
    }
    return results;
  }

  static Map<String, int> hindiNumbers = {
    'एक': 1, 'दो': 2, 'तीन': 3, 'चार': 4, 'पाँच': 5,
    'छः': 6, 'सात': 7, 'आठ': 8, 'नौ': 9, 'दस': 10,
  };

  static String convertHindiToEnglish(String text) {
    String result = text;
    hindiNumbers.forEach((hindi, english) {
      result = result.replaceAll(hindi, english.toString());
    });
    return result;
  }
}


/// Feature 5: WhatsApp Bill Auto-Send
class WhatsAppBillFormatter {

  static String formatBillForWhatsApp({
    required String shopName,
    required List<Map<String, dynamic>> items,
    required double total,
    required String? customerName,
  }) {
    String message = "🛍️ $shopName\n\n";
    message += "📋 Bill Items:\n";
    message += "═" * 30 + "\n";
    for (var item in items) {
      String name = item['product_name'] ?? 'Item';
      int quantity = item['quantity'] ?? 1;
      double price = (item['price'] ?? 0).toDouble();
      double lineTotal = quantity * price;
      message += "$name\n";
      message += "  $quantity x ₹${price.toStringAsFixed(2)} = ₹${lineTotal.toStringAsFixed(2)}\n";
    }
    message += "═" * 30 + "\n";
    message += "Total: ₹${total.toStringAsFixed(2)}\n\n";
    if (customerName != null && customerName.isNotEmpty) {
      message += "👤 Thanks $customerName!\n";
    }
    message += "Thank you for shopping with us! 🙏\n";
    message += "📱 Visit again soon!\n";
    return message;
  }

  static Future<void> sendBillViaWhatsApp({
    required String phoneNumber,
    required String billMessage,
    required BuildContext context,
  }) async {
    if (phoneNumber.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer phone not provided'))
        );
      }
      return;
    }
    String formattedPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (!formattedPhone.startsWith('91') && formattedPhone.length == 10) {
      formattedPhone = '91$formattedPhone';
    }
    final whatsappUrl = 'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(billMessage)}';
    try {
      if (await canLaunchUrlString(whatsappUrl)) {
        await launchUrlString(whatsappUrl);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WhatsApp not installed'))
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening WhatsApp: $e'))
        );
      }
    }
  }
}


/// Feature 6: Split Payment Cash+UPI
class SplitPaymentHandler {

  static Future<Map<String, dynamic>> showSplitPaymentDialog({
    required BuildContext context,
    required double totalAmount,
  }) async {
    double cashAmount = 0;
    double upiAmount = totalAmount;

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState) => AlertDialog(
          title: const Text('💰 Split Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total: ₹${totalAmount.toStringAsFixed(2)}'),
              const SizedBox(height: 20),
              TextField(
                decoration: const InputDecoration(labelText: '💵 Cash Amount'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    cashAmount = double.tryParse(value) ?? 0;
                    if (cashAmount > totalAmount) cashAmount = totalAmount; // Validation
                    upiAmount = totalAmount - cashAmount;
                  });
                },
              ),
              const SizedBox(height: 10),
              Text('📱 UPI Amount: ₹${upiAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx, {
                  'cash': cashAmount,
                  'upi': upiAmount,
                  'payment_type': 'SPLIT'
                });
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    ) ?? {'cash': 0, 'upi': 0};
  }
}


/// Feature 9: Saved Bill Templates
class BillingTemplateManager {
  static const String _templatePrefix = 'billing_template_';

  static Future<bool> saveAsTemplate({
    required String templateName,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_templatePrefix$templateName';
      await prefs.setString(key, jsonEncode({
        'name': templateName,
        'items': items,
        'created_at': DateTime.now().toIso8601String(),
      }));
      return true;
    } catch (e) { return false; }
  }

  static Future<List<Map<String, dynamic>>?> loadTemplate(String templateName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_templatePrefix$templateName';
      final data = prefs.getString(key);
      if (data != null) {
        final decoded = jsonDecode(data);
        return List<Map<String, dynamic>>.from(decoded['items'] ?? []);
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<List<String>> getAllTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      return keys
          .where((k) => k.startsWith(_templatePrefix))
          .map((k) => k.replaceFirst(_templatePrefix, ''))
          .toList();
    } catch (e) { return []; }
  }

  static Future<bool> deleteTemplate(String templateName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_templatePrefix$templateName');
      return true;
    } catch (e) { return false; }
  }

  static Future<List<String>> suggestTemplates({int limit = 3}) async {
    final all = await getAllTemplates();
    return all.take(limit).toList();
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'api_client.dart';

class SharingIntentService {
  static late StreamSubscription _intentDataStreamSubscription;

  static void init() {
    // For sharing images coming from outside the app while the app is in the memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty && (value.first.type == SharedMediaType.text || value.first.type == SharedMediaType.url)) {
        final text = value.first.path;
        _saveToBackend(text);
      }
    }, onError: (err) {
      debugPrint("getMediaStream error: $err");
    });

    // For sharing images coming from outside the app while the app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty && (value.first.type == SharedMediaType.text || value.first.type == SharedMediaType.url)) {
        final text = value.first.path;
        // Small delay to let the UI mount and ApiClient initialize
        Future.delayed(const Duration(seconds: 2), () {
          _saveToBackend(text);
        });
      }
    });
  }
  
  static Future<void> _saveToBackend(String text) async {
    try {
      debugPrint("Parsing WhatsApp Order...");
      final response = await ApiClient.postJson(
        ApiClient.whatsappOrders,
        {'raw_text': text, 'total_amount': 0.0},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("Order added to Pending Queue!");
      } else {
        debugPrint("Failed to save order");
      }
    } catch (e) {
      debugPrint('Failed to save WhatsApp order: $e');
      debugPrint("Network Error: Could not save order");
    }
  }

  static void dispose() {
    _intentDataStreamSubscription.cancel();
  }
}

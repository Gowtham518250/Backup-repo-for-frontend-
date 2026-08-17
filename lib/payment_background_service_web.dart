import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'payment_announcement_service.dart';
import 'payment_detection_service.dart';

Future<void> initializeBackgroundService() async {
  debugPrint('⚠️ Background service not supported on web');
  try {
    await PaymentAnnouncementService().init();

    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('payment_sound_lang') ?? 'en-US';

    final pds = PaymentDetectionService();
    pds.setLanguage(PaymentDetectionService.mapLanguage(langCode));

    pds.onSpeak = (text) async {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('payment_sound_lang') ?? 'en-US';
      PaymentAnnouncementService().speakSimple(text, lang);
    };

    await pds.start();
    debugPrint('✅ Payment services initialized (web mode)');
  } catch (e) {
    debugPrint('⚠️ Failed to initialize payment services on web: $e');
  }
}

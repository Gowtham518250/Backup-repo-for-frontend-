import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'payment_detection_service.dart';

/// WhatsApp Message Service - Build and send localized messages via WhatsApp
class WhatsAppMessageService {
  static const String _tag = '💬 WHATSAPP_MSG';
  
  /// Build day closing report message
  static String buildDayClosingMessage({
    required double upiSales,
    required double recordedCash,
    required double actualCash,
    VoiceLanguage language = VoiceLanguage.english,
  }) {
    final discrepancy = recordedCash - actualCash;
    final discrepancyText = _buildDiscrepancyText(discrepancy, language);
    
    switch (language) {
      case VoiceLanguage.hindi:
        return '''✅ आज का हिसाब
━━━━━━━━━━━━━━━
UPI: ₹${upiSales.toStringAsFixed(0)}
Cash दर्ज: ₹${recordedCash.toStringAsFixed(0)}
Cash मिला: ₹${actualCash.toStringAsFixed(0)}
━━━━━━━━━━━━━━━
$discrepancyText''';
      
      case VoiceLanguage.tamil:
        return '''✅ இன்றைய கணக்கு
━━━━━━━━━━━━━━━
UPI: ₹${upiSales.toStringAsFixed(0)}
பதிவு செய்யப்பட்ட நகை: ₹${recordedCash.toStringAsFixed(0)}
பெற்ற நகை: ₹${actualCash.toStringAsFixed(0)}
━━━━━━━━━━━━━━━
$discrepancyText''';
      
      case VoiceLanguage.telugu:
        return '''✅ నేటి ఖాతా
━━━━━━━━━━━━━━━
UPI: ₹${upiSales.toStringAsFixed(0)}
నమోదు చేసిన నగదు: ₹${recordedCash.toStringAsFixed(0)}
అందుకున్న నగదు: ₹${actualCash.toStringAsFixed(0)}
━━━━━━━━━━━━━━━
$discrepancyText''';
      
      case VoiceLanguage.kannada:
        return '''✅ ಇಂದಿನ ಹಿಸಾಬು
━━━━━━━━━━━━━━━
UPI: ₹${upiSales.toStringAsFixed(0)}
ದಾಖಲೆ ನಗದು: ₹${recordedCash.toStringAsFixed(0)}
ಪಡೆದ ನಗದು: ₹${actualCash.toStringAsFixed(0)}
━━━━━━━━━━━━━━━
$discrepancyText''';
      
      default:
        return '''✅ Today's Summary
━━━━━━━━━━━━━━━
UPI Sales: ₹${upiSales.toStringAsFixed(2)}
Cash Recorded: ₹${recordedCash.toStringAsFixed(2)}
Cash Received: ₹${actualCash.toStringAsFixed(2)}
━━━━━━━━━━━━━━━
$discrepancyText''';
    }
  }
  
  /// Build udhar reminder message
  static String buildUdharReminderMessage({
    required String customerName,
    required double amount,
    VoiceLanguage language = VoiceLanguage.english,
  }) {
    switch (language) {
      case VoiceLanguage.hindi:
        return '$customerName भाई, ₹${amount.toStringAsFixed(0)} बाकी है। जब आएं तब दे देना। 🙏';
      
      case VoiceLanguage.tamil:
        return '$customerName அண்ணா, ₹${amount.toStringAsFixed(0)} மீதம் உள்ளது. வரும்போது கொடுங்கள். 🙏';
      
      case VoiceLanguage.telugu:
        return '$customerName, ₹${amount.toStringAsFixed(0)} బాకీ ఉంది. వచ్చినప్పుడు ఇవ్వండి. 🙏';
      
      case VoiceLanguage.kannada:
        return '$customerName, ₹${amount.toStringAsFixed(0)} ಮಿತಿ ಉಳಿದಿದೆ. ವಿನಂತಿಸುವಾಗ ಕೊಡಿ. 🙏';
      
      default:
        return '$customerName, ₹${amount.toStringAsFixed(2)} is pending. Please settle when convenient. 🙏';
    }
  }
  
  /// Build multi-shop consolidated report
  static String buildConsolidatedShopReport({
    required List<Map<String, dynamic>> shops,  // [{name, sales}, ...]
    required double totalSales,
    VoiceLanguage language = VoiceLanguage.english,
  }) {
    List<String> shopLines = [];
    for (int i = 0; i < shops.length; i++) {
      shopLines.add('${i + 1}. ${shops[i]['name']}: ₹${shops[i]['sales'].toStringAsFixed(0)}');
    }
    
    switch (language) {
      case VoiceLanguage.hindi:
        return '''📊 आज का हिसाब
${shopLines.join('\n')}
━━━━━━━━━━━━━━━
कुल: ₹${totalSales.toStringAsFixed(0)}
🙏 धन्यवाद''';
      
      case VoiceLanguage.tamil:
        return '''📊 இன்றைய கணக்கு
${shopLines.join('\n')}
━━━━━━━━━━━━━━━
மொத்தம்: ₹${totalSales.toStringAsFixed(0)}
🙏 நன்றி''';
      
      default:
        return '''📊 Today's Summary
${shopLines.join('\n')}
━━━━━━━━━━━━━━━
Total: ₹${totalSales.toStringAsFixed(2)}
🙏 Thank You''';
    }
  }
  
  /// Build delivery status message
  static String buildDeliveryStatusMessage({
    required String orderId,
    required String deliveryStatus,
    required double amount,
    VoiceLanguage language = VoiceLanguage.english,
  }) {
    switch (language) {
      case VoiceLanguage.hindi:
        return 'Order #$orderId की स्थिति: $deliveryStatus\nराशि: ₹${amount.toStringAsFixed(0)}\n🚚';
      
      case VoiceLanguage.tamil:
        return 'Order #$orderId அச்சம்: $deliveryStatus\nத्राणि: ₹${amount.toStringAsFixed(0)}\n🚚';
      
      default:
        return 'Order #$orderId Status: $deliveryStatus\nAmount: ₹${amount.toStringAsFixed(2)}\n🚚';
    }
  }
  
  /// Build festival alert message
  static String buildFestivalAlertMessage({
    required String festivalName,
    required String itemName,
    required int daysUntil,
    required int currentStock,
    required int recommendedStock,
    VoiceLanguage language = VoiceLanguage.english,
  }) {
    switch (language) {
      case VoiceLanguage.hindi:
        return '🎉 $festivalName में $daysUntil दिन बाकी\n$itemName स्टॉक करें!\n अभी: $currentStock, सुझाव: $recommendedStock';
      
      case VoiceLanguage.tamil:
        return '🎉 $festivalName ற்கு $daysUntil நாட்கள் உள்ளது\n$itemName சேகரிக்க வேண்டும்!\nதற்போது: $currentStock, பரிந்துரை: $recommendedStock';
      
      default:
        return '🎉 $festivalName in $daysUntil days\nStock up $itemName!\nNow: $currentStock, Recommended: $recommendedStock';
    }
  }
  
  static String _buildDiscrepancyText(double discrepancy, VoiceLanguage language) {
    if (discrepancy.abs() < 10) {
      switch (language) {
        case VoiceLanguage.hindi:
          return 'सब ठीक है ✅';
        case VoiceLanguage.tamil:
          return 'எல்லாம் சரியாக உள்ளது ✅';
        default:
          return 'All good ✅';
      }
    } else if (discrepancy > 0) {
      switch (language) {
        case VoiceLanguage.hindi:
          return '⚠️ कमी: ₹${discrepancy.toStringAsFixed(0)}';
        case VoiceLanguage.tamil:
          return '⚠️ குறைவு: ₹${discrepancy.toStringAsFixed(0)}';
        default:
          return '⚠️ Shortage: ₹${discrepancy.toStringAsFixed(2)}';
      }
    } else {
      switch (language) {
        case VoiceLanguage.hindi:
          return '✨ अतिरिक्त: ₹${(-discrepancy).toStringAsFixed(0)}';
        case VoiceLanguage.tamil:
          return '✨ கூடுதல்: ₹${(-discrepancy).toStringAsFixed(0)}';
        default:
          return '✨ Extra: ₹${(-discrepancy).toStringAsFixed(2)}';
      }
    }
  }

  /// Send Digital Receipt to unsaved WhatsApp number instantly
  static Future<void> sendDigitalReceipt({
    required String phone,
    required String shopName,
    required String billNo,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
  }) async {
    // 1. Build the beautiful text receipt
    StringBuffer sb = StringBuffer();
    sb.writeln('🏪 *$shopName*');
    sb.writeln('');
    sb.writeln('🧾 *Bill No:* $billNo');
    final now = DateTime.now();
    sb.writeln('📅 *Date:* ${now.day}/${now.month}/${now.year}');
    sb.writeln('');
    sb.writeln('🛒 *Items Purchased:*');
    
    for (var item in items) {
      final name  = item['product_name'] ?? item['name'] ?? 'Item';
      final qty   = item['quantity'] ?? item['qty'] ?? 1;
      final price = item['price'] ?? 0;
      final lineTotal = (qty is num ? qty : double.tryParse(qty.toString()) ?? 1)
                      * (price is num ? price : double.tryParse(price.toString()) ?? 0);
      sb.writeln('• $name (x$qty) — ₹${lineTotal.toStringAsFixed(0)}');
    }
    
    sb.writeln('');
    sb.writeln('💰 *Total: ₹${totalAmount.toStringAsFixed(0)}*');
    sb.writeln('');
    sb.writeln('Thank you for shopping with us! Visit again. 🙏');

    await _launchWhatsApp(phone: phone, message: sb.toString());
  }

  /// Send a pre-filled order message to the shop owner.
  /// Called from the customer-facing "Order on WhatsApp" share button.
  /// No WhatsApp API needed — simply opens WhatsApp with a pre-filled message.
  static Future<void> sendOrderRequest({
    required String shopOwnerPhone,
    required String shopName,
    required List<Map<String, dynamic>> cartItems,
    required double total,
    String? customerName,
  }) async {
    StringBuffer sb = StringBuffer();
    sb.writeln('🛍 *Order Request — $shopName*');
    if (customerName != null && customerName.isNotEmpty) {
      sb.writeln('👤 Customer: $customerName');
    }
    sb.writeln('');
    sb.writeln('📦 *Items:*');
    for (final item in cartItems) {
      final name  = item['product_name'] ?? item['name'] ?? 'Item';
      final qty   = item['quantity'] ?? item['qty'] ?? 1;
      final unit  = item['unit'] ?? '';
      final price = item['price'] ?? 0;
      sb.writeln('• $name — $qty $unit @ ₹$price');
    }
    sb.writeln('');
    sb.writeln('💰 *Total: ₹${total.toStringAsFixed(0)}*');
    sb.writeln('');
    sb.writeln('Please confirm my order. Thank you! 🙏');

    await _launchWhatsApp(phone: shopOwnerPhone, message: sb.toString());
  }

  /// Build and send a complete Payment Reminder with fixed amount & UPI payment link/QR intent
  static Future<bool> sendPaymentReminderWithUPI({
    required String phone,
    required String customerName,
    required double pendingAmount,
    required String shopName,
    String? upiId,
    String? dueDate,
  }) async {
    final formattedAmount = pendingAmount.toStringAsFixed(2);
    final cleanUpi = (upiId ?? '').trim();

    StringBuffer sb = StringBuffer();
    sb.writeln('🏪 *$shopName*');
    sb.writeln('📌 *PAYMENT REMINDER*');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('Dear *$customerName*,');
    sb.writeln('');
    sb.writeln('Your pending balance amount of *₹$formattedAmount* is due.');
    if (dueDate != null && dueDate.isNotEmpty) {
      sb.writeln('📅 *Due Date:* $dueDate');
    }
    sb.writeln('');
    sb.writeln('💳 *Pay Online via UPI:*');
    
    if (cleanUpi.isNotEmpty) {
      final upiUri = 'upi://pay?pa=$cleanUpi&pn=${Uri.encodeComponent(shopName)}&am=$formattedAmount&cu=INR&tn=PaymentToShop';
      sb.writeln('Tap to Pay: $upiUri');
      sb.writeln('UPI ID: `$cleanUpi`');
    } else {
      sb.writeln('Amount Due: *₹$formattedAmount*');
    }

    sb.writeln('');
    sb.writeln('Kindly clear your balance at your earliest convenience. Thank you! 🙏');

    return await sendCustomMessage(phone: phone, message: sb.toString());
  }

  /// Send custom message using native frontend launcher
  static Future<bool> sendCustomMessage({
    required String phone,
    required String message,
  }) async {
    return await _launchWhatsApp(phone: phone, message: message);
  }

  /// Core launcher — opens WhatsApp app with [phone] and pre-filled [message] strictly from frontend.
  static Future<bool> _launchWhatsApp({
    required String phone,
    required String message,
  }) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length == 10) cleanPhone = '91$cleanPhone';

    final encoded = Uri.encodeComponent(message);
    final Uri whatsappUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encoded');
    final Uri webUri      = Uri.parse('https://wa.me/$cleanPhone?text=$encoded');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        final opened = await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        if (opened) return true;
      }
      // Some Android builds report false from canLaunchUrl for HTTPS even
      // though a browser is available. Try the web fallback directly.
      final openedWeb = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      if (openedWeb) return true;
      debugPrint('$_tag Could not launch WhatsApp/browser for phone: $cleanPhone');
      return false;
    } catch (e) {
      debugPrint('$_tag WhatsApp launch error: $e');
      return false;
    }
  }
}

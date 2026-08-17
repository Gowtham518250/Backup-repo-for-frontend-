import 'dart:convert';
import 'api_client.dart';

class NotificationServiceClient {
  static String get _notificationPrefix => '${ApiClient.baseUrl}/notifications';

  /// Send SMS notification
  static Future<Map<String, dynamic>> sendSMS({
    required String phoneNumber,
    required String message,
    String? templateId,
  }) async {
    try {
      final res = await ApiClient.postJson(
        '$_notificationPrefix/sms/send',
        {
          'phone_number': phoneNumber,
          'message': message,
          'template_id': templateId,
        },
      );

      if (res.statusCode == 200) {
        return json.decode(res.body);
      } else {
        return {
          'success': false,
          'error': 'Failed to send SMS',
          'status': res.statusCode,
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Send Email notification
  static Future<Map<String, dynamic>> sendEmail({
    required String recipientEmail,
    required String subject,
    required String body,
    List<Map<String, String>>? attachments,
  }) async {
    try {
      final res = await ApiClient.postJson(
        '$_notificationPrefix/email/send',
        {
          'recipient_email': recipientEmail,
          'subject': subject,
          'body': body,
          'attachments': attachments,
        },
      );

      if (res.statusCode == 200) {
        return json.decode(res.body);
      } else {
        return {
          'success': false,
          'error': 'Failed to send email',
          'status': res.statusCode,
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Send WhatsApp message using backend template
  static Future<Map<String, dynamic>> sendWhatsApp({
    required String phoneNumber,
    required String templateName,
    Map<String, String>? templateParams,
  }) async {
    try {
      final res = await ApiClient.postJson(
        '$_notificationPrefix/whatsapp/send',
        {
          'phone_number': phoneNumber,
          'template_name': templateName,
          'template_params': templateParams,
        },
      );

      if (res.statusCode == 200) {
        return json.decode(res.body);
      } else {
        return {
          'success': false,
          'error': 'Failed to send WhatsApp message',
          'status': res.statusCode,
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Send bill reminder SMS
  static Future<Map<String, dynamic>> sendBillReminder({
    required String customerPhone,
    required String invoiceNumber,
    required double amount,
    required String dueDate,
    required String customerName,
  }) async {
    final message = 'Hi $customerName, reminder for invoice $invoiceNumber for ₹${amount.toStringAsFixed(0)} due on $dueDate. Reply YES to confirm. -Shop';
    
    return sendSMS(
      phoneNumber: customerPhone,
      message: message,
      templateId: 'bill_reminder',
    );
  }

  /// Send order confirmation SMS
  static Future<Map<String, dynamic>> sendOrderConfirmation({
    required String customerPhone,
    required String orderId,
    required double amount,
    required String customerName,
  }) async {
    final message = 'Hi $customerName, your order $orderId for ₹${amount.toStringAsFixed(0)} has been confirmed. Track status in our app.';
    
    return sendSMS(
      phoneNumber: customerPhone,
      message: message,
      templateId: 'order_confirmation',
    );
  }

  /// Send delivery notification
  static Future<Map<String, dynamic>> sendDeliveryNotification({
    required String customerPhone,
    required String orderId,
    required String status, // IN_TRANSIT, DELIVERED
    required String estimatedTime,
    required String customerName,
  }) async {
    final message = status == 'DELIVERED'
        ? 'Hi $customerName, your order $orderId has been delivered! Thank you for shopping with us.'
        : 'Hi $customerName, your order $orderId is on the way. Estimated delivery: $estimatedTime';
    
    return sendSMS(
      phoneNumber: customerPhone,
      message: message,
      templateId: 'delivery_notification',
    );
  }

  /// Send daily closing report email
  static Future<Map<String, dynamic>> sendDayClosingReport({
    required String shopperEmail,
    required String shopName,
    required double revenue,
    required double profit,
    required int transactions,
    required String date,
  }) async {
    final body = '''
Daily Closing Report - $date

Shop: $shopName
Total Revenue: ₹${revenue.toStringAsFixed(0)}
Profit: ₹${profit.toStringAsFixed(0)}
Transactions: $transactions

Login to dashboard for detailed analytics.
''';

    return sendEmail(
      recipientEmail: shopperEmail,
      subject: 'Daily Closing Report - $date',
      body: body,
    );
  }

  /// Send payment collection notification
  static Future<Map<String, dynamic>> sendPaymentCollectionAlert({
    required String phoneNumber,
    required String customerName,
    required double amountDue,
    required String invoiceNumber,
  }) async {
    final message = 'Hi, $customerName has a pending payment of ₹${amountDue.toStringAsFixed(0)} for invoice $invoiceNumber. Send reminder?';
    
    return sendSMS(
      phoneNumber: phoneNumber,
      message: message,
      templateId: 'payment_alert',
    );
  }

  /// Send birthday discount notification
  static Future<Map<String, dynamic>> sendBirthdayDiscount({
    required String customerPhone,
    required String customerName,
    required double discountPercent,
  }) async {
    final message = 'Happy Birthday $customerName! 🎉 Enjoy $discountPercent% discount on your next purchase. Valid today only!';
    
    return sendWhatsApp(
      phoneNumber: customerPhone,
      templateName: 'birthday_discount',
      templateParams: {
        'customer_name': customerName,
        'discount': '$discountPercent%',
      },
    );
  }

  /// Send loyalty points earned notification
  static Future<Map<String, dynamic>> sendLoyaltyPointsNotification({
    required String customerPhone,
    required String customerName,
    required int pointsEarned,
    required int totalPoints,
  }) async {
    final message = 'Hi $customerName, you earned $pointsEarned loyalty points! Total balance: $totalPoints points.';
    
    return sendSMS(
      phoneNumber: customerPhone,
      message: message,
      templateId: 'loyalty_points',
    );
  }

  /// Get notification history
  static Future<List<Map<String, dynamic>>> getNotificationHistory({
    int limit = 50,
    String? type, // sms, email, whatsapp
  }) async {
    try {
      final query = type != null ? '?type=$type&limit=$limit' : '?limit=$limit';
      final res = await ApiClient.getJson('$_notificationPrefix/history$query');

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

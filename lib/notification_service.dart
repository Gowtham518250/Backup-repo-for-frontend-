import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // 🔒 CRITICAL: Track initialization state to prevent re-entry
  bool _isInitialized = false;
  bool _isInitializing = false;

  /// Initialize notification service (idempotent)
  Future<void> init() async {
    // 🔒 CRITICAL: Prevent multiple simultaneous initialization
    if (_isInitialized) {
      if (kDebugMode) debugPrint('✅ NotificationService already initialized');
      return;
    }
    
    if (_isInitializing) {
      if (kDebugMode) debugPrint('⏳ NotificationService initialization in progress...');
      // Wait for initialization to complete
      while (_isInitializing) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    _isInitializing = true;

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          if (kDebugMode) debugPrint('📢 Notification clicked: ${response.payload}');
        },
      );

      // Create notification channel for Android 8.0+
      if (!kIsWeb && Platform.isAndroid) {
        try {
          final androidPlugin = _notificationsPlugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          
          const AndroidNotificationChannel channel = AndroidNotificationChannel(
            'export_channel',
            'Data Exports',
            description: 'Notifications for completed data exports',
            importance: Importance.max,
          );

          await androidPlugin?.createNotificationChannel(channel);
          
          if (kDebugMode) debugPrint('✅ Android notification channel created');
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Error creating notification channel: $e');
        }
        
        // Request permission explicitly for Android 13+ using permission_handler
        try {
          final status = await Permission.notification.request();
          if (kDebugMode) debugPrint('📱 Notification permission status: $status');
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Error requesting notification permission: $e');
        }
      }

      _isInitialized = true;
      if (kDebugMode) debugPrint('✅ NotificationService initialized successfully');
    } catch (e, st) {
      if (kDebugMode) debugPrint('❌ Error initializing NotificationService: $e\n$st');
      _isInitialized = false;
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> showDownloadNotification(String title, String body, String filePath) async {
    try {
      await show(title, body, payload: filePath);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error showing download notification: $e');
    }
  }

  /// General static method for showing notifications from anywhere
  static Future<void> show(String title, String body, {String? payload}) async {
    try {
      // Get preferences with error handling
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Error getting SharedPreferences: $e');
      }

      final whatsappOnly = prefs?.getBool('whatsapp_only_notifications') ?? true;

      // Try WhatsApp-only notification if enabled
      if (whatsappOnly && prefs != null) {
        try {
          final shopPhone =
              (prefs.getString('shop_phone') ?? prefs.getString('contact_phone') ?? '').trim();
          final digits = shopPhone.replaceAll(RegExp(r'\D'), '');
          
          if (digits.isNotEmpty) {
            try {
              final msg = Uri.encodeComponent('$title\n$body');
              final uri = Uri.parse('https://wa.me/$digits?text=$msg');
              
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                if (kDebugMode) debugPrint('✅ WhatsApp notification sent');
                return;
              }
            } catch (e) {
              if (kDebugMode) debugPrint('⚠️ Error launching WhatsApp: $e');
              // Fall through to local notification
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Error processing phone number: $e');
          // Fall through to local notification
        }
      }

      // Show local notification as fallback
      try {
        const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
          'export_channel',
          'Data Exports',
          channelDescription: 'Notifications for completed data exports',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          styleInformation: BigTextStyleInformation(''),
        );

        const NotificationDetails platformChannelSpecifics = NotificationDetails(
          android: androidPlatformChannelSpecifics,
        );

        await NotificationService()._notificationsPlugin.show(
          DateTime.now().millisecond, // unique ID
          title,
          body,
          platformChannelSpecifics,
          payload: payload,
        );
        
        if (kDebugMode) debugPrint('✅ Local notification shown');
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Error showing local notification: $e');
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('❌ Critical error in show(): $e\n$st');
    }
  }

  static Future<void> showNotification({required String title, required String body, String? payload}) async {
    try {
      await show(title, body, payload: payload);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error in showNotification(): $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      _isInitialized = false;
      if (kDebugMode) debugPrint('✅ NotificationService disposed');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error disposing NotificationService: $e');
    }
  }
}

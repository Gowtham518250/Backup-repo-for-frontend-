import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart'; // To get the auth token
import 'package:shared_preferences/shared_preferences.dart';

// Top-level background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `Firebase.initializeApp()` before using other Firebase services.
  if (kDebugMode) print("Handling a background message: ${message.messageId}");
}

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // 1. Request permissions for iOS and Android 13+
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) print('User granted permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      return;
    }

    // 2. Set up background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Set up foreground notification presentation (local notifications)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Use the new DarwinInitializationSettings instead of IOSInitializationSettings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (kDebugMode) print("Notification clicked! Payload: ${response.payload}");
        // Here you could navigate to the orders page
      },
    );

    // 4. Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) print('Got a message whilst in the foreground!');
      if (kDebugMode) print('Message data: ${message.data}');

      if (message.notification != null) {
        if (kDebugMode) print('Message also contained a notification: ${message.notification}');
        _showLocalNotification(message);
      }
    });

    // 5. Get and register FCM token
    try {
      String? token = await _firebaseMessaging.getToken();
      if (kDebugMode) print("FCM Device Token: $token");
      if (token != null) {
        await registerTokenWithBackend(token);
      }
    } catch (e) {
      if (kDebugMode) print("Error getting FCM token: $e");
    }

    // 6. Listen for token refreshes
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      registerTokenWithBackend(newToken);
    });
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    // High importance channel for Android to ensure it pops up (heads-up)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.', // description
      importance: Importance.max,
      playSound: true,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: const DarwinNotificationDetails(presentSound: true, presentAlert: true, presentBadge: true),
    );

    await _localNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  static Future<void> registerTokenWithBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwtToken = prefs.getString('auth_token');
      final baseUrl = ApiClient.baseUrl;

      if (jwtToken == null) {
        if (kDebugMode) print("Cannot register FCM token: User not logged in yet");
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'fcm_token': token}),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) print("FCM token registered with backend successfully");
      } else {
        if (kDebugMode) print("Failed to register FCM token. Status: ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e) {
      if (kDebugMode) print("Error sending FCM token to backend: $e");
    }
  }
}
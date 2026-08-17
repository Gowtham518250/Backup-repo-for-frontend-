import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Schedules a daily 9 PM income summary notification in Telugu + English.
/// Uses flutter_local_notifications (already in pubspec: ^17.1.2).
/// No extra packages needed — uses a repeating daily timer approach.
class DailySummaryNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId   = 'daily_summary_channel';
  static const _channelName = '\u0c30ోజూ స్టేట్మెంట్ | Daily Summary';
  static const _notifId     = 9900;
  static const _prefKey     = 'daily_summary_last_scheduled_date';

  static bool _channelCreated = false;

  /// Call from DashboardPage.initState() once per app session.
  /// Schedules the 9 PM notification for today (or tomorrow if already past 9 PM).
  static Future<void> scheduleTodayNotification({
    required double todayRevenue,
    required int todayBills,
    required String topProduct,
  }) async {
    try {
      await _ensureChannel();

      final prefs  = await SharedPreferences.getInstance();
      final today  = DateTime.now();
      final todayStr = '${today.year}-${today.month}-${today.day}';

      // Only schedule once per day
      final lastScheduled = prefs.getString(_prefKey) ?? '';
      if (lastScheduled == todayStr) return;
      await prefs.setString(_prefKey, todayStr);

      final ninepm = DateTime(today.year, today.month, today.day, 21, 0, 0);
      final target = ninepm.isBefore(today)
          ? ninepm.add(const Duration(days: 1))
          : ninepm;
      final delay = target.difference(today);

      final amountStr = _formatAmount(todayRevenue);

      // Telugu + English notification content
      final teluguBody =
          '\u0c28ేడు సంపాదన: \u20b9$amountStr | $todayBills బిల్లులు'
          '${topProduct.isNotEmpty ? " | Best: $topProduct" : ""}';

      if (kDebugMode) {
        debugPrint('\u2705 Daily summary notification scheduled in ${delay.inMinutes} min');
      }

      // Fire after calculated delay using a one-shot timer
      Timer(delay, () async {
        try {
          await _showNow(
            title: '\u0c2a్రతిరోజూ రిపోర్ట్ 📊 | Daily Report',
            body: teluguBody,
          );
        } catch (e) {
          if (kDebugMode) debugPrint('Daily summary notify error: $e');
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('DailySummaryNotificationService error: $e');
    }
  }

  static Future<void> _showNow({required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Daily shop income summary at 9 PM',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(_notifId, title, body, details);
  }

  static Future<void> _ensureChannel() async {
    if (_channelCreated) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Daily shop income summary at 9 PM',
        importance: Importance.high,
      );
      await androidPlugin.createNotificationChannel(channel);
    }
    _channelCreated = true;
  }

  static String _formatAmount(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

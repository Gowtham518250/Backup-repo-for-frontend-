// dart:async import removed — Timer was removed in Issue 4.1 fix.
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_background_service_ios/flutter_background_service_ios.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'payment_announcement_service.dart';
import 'payment_detection_service.dart';

Future<void> _ensurePaymentNotificationChannel() async {
  if (!Platform.isAndroid) return;
  final plugin = FlutterLocalNotificationsPlugin();
  final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (android == null) return;
  const channel = AndroidNotificationChannel(
    'payment_detection_channel',
    'Payment Detection',
    description: 'Foreground service notification for payment detection.',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );
  await android.createNotificationChannel(channel);
}

@pragma('vm:entry-point')
Future<bool> onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  var hasNotificationPermission = true;
  try {
    final status = await Permission.notification.status;
    hasNotificationPermission = status.isGranted;
  } catch (_) {
    hasNotificationPermission = false;
  }

  if (service is AndroidServiceInstance && hasNotificationPermission) {
    service.setForegroundNotificationInfo(
      title: "Retail Mind",
      content: "Listening for payments...",
    );
  }

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

    // FIX: The UI isolate (dashboard) and this background isolate each hold
    // a *separate* PaymentDetectionService singleton instance. When the user
    // taps "Enable Payment Detection" and grants SMS/notification-listener
    // permission, that only affects the UI isolate's instance — this
    // background isolate (the one that actually keeps listening once the
    // app is backgrounded) never learns permissions changed and its
    // listeners stay dead. Listen for an explicit restart signal from the
    // UI isolate so we can re-run start() (via restart()) with the
    // now-granted permissions.
    bool restartInProgress = false;
    service.on('restart_payment_detection').listen((event) async {
      if (restartInProgress) {
        debugPrint('⏳ Background isolate: restart already in progress; ignoring duplicate signal');
        return;
      }

      restartInProgress = true;
      debugPrint('🔁 Background isolate: restarting payment detection after permission grant');
      try {
        await pds.restart();
        debugPrint('✅ Background isolate: payment detection restarted');
      } catch (e) {
        debugPrint('⚠️ Background isolate: restart failed: $e');
      } finally {
        restartInProgress = false;
      }
    });

    try {
      final accessibilityEnabled =
          await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
      debugPrint(
        accessibilityEnabled
            ? '✅ Accessibility service permission is enabled'
            : '⚠️ Accessibility service permission is NOT enabled',
      );
    } catch (e) {
      debugPrint('⚠️ Accessibility status check failed: $e');
    }

    // FIX (critical, part 2): lets the UI isolate promote this service to a
    // real foreground service the moment POST_NOTIFICATIONS is granted,
    // instead of requiring a full app reinstall to stop being killed by
    // Android. Without this, a service that started in background-only
    // mode on first launch (before permission was granted) stays
    // non-foreground — and therefore killable — forever.
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        debugPrint('⬆️ Background isolate: promoting to foreground service');
        service.setAsForegroundService();
      });
      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    debugPrint('✅ Background payment services initialized');
  } catch (e) {
    debugPrint('⚠️ Background service init error: $e');
    return false;
  }

  // FIX (Issue 4.1): Removed Timer.periodic(1 second) that was calling
  // service.invoke('update') every second, causing constant CPU wake locks
  // and significant battery drain. The PaymentDetectionService is
  // event-driven (SMS/notifications), so no polling timer is required.

  return true;
}

Future<void> initializeBackgroundService() async {
  try {
    final service = FlutterBackgroundService();

    // The background-service plugin requires a custom channel to exist before
    // configure()/startForeground() when notificationChannelId is supplied.
    await _ensurePaymentNotificationChannel();

    // Check notification permission on Android 13+ to avoid CannotPostForegroundServiceNotificationException
    // We only check the status; we do not call request() from here because this code can run in the background without UI context.
    var isForeground = true;
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          isForeground = false; // Run in background-only mode if permission is not granted yet
          debugPrint('⚠️ Notification permission not granted yet. Starting service in background-only mode to avoid crash.');
        }
      }
    } catch (pe) {
      isForeground = false; // Safe fallback
      debugPrint('⚠️ Permission check failed: $pe');
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        // FIX (critical): this was hardcoded to `false` regardless of the
        // `isForeground` value computed just above (which was dead code —
        // computed then ignored). Running as a non-foreground service means
        // Android has no persistent notification to justify keeping the
        // process alive, so within minutes of the app leaving the
        // foreground (screen off, app swiped away, OEM battery manager
        // sweep on Xiaomi/Oppo/Vivo/Samsung, etc.) the OS kills this
        // isolate outright — silently, with no exception anywhere to catch.
        // This is why detection stops after backgrounding even with the
        // restart-bridge fix in place: that bridge restarts a process
        // Android is about to kill anyway.
        isForegroundMode: isForeground,
        notificationChannelId: 'payment_detection_channel',
        initialNotificationTitle: 'Retail Mind',
        initialNotificationContent: 'Listening for payments...',
        foregroundServiceNotificationId: 888,
        // Android 14+ / target SDK 34+ requires an explicit FGS type.
        // Payment-notification monitoring is not data transfer, location, media,
        // or another predefined category, so use the documented specialUse type.
        foregroundServiceTypes: [AndroidForegroundType.specialUse],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onStart,
      ),
    );

    await service.startService();
    debugPrint('✅ Background service started successfully (foreground=$isForeground)');
  } catch (e) {
    debugPrint('⚠️ Failed to start background service: $e');
    await _initializeFallback();
  }
}

Future<void> _initializeFallback() async {
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
    debugPrint('✅ Payment services initialized (fallback mode)');
  } catch (e) {
    debugPrint('⚠️ Failed fallback initialization: $e');
  }
}

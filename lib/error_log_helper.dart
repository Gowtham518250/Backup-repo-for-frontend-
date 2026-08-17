import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// 🚨 ERROR LOGGING HELPER - Unified error tracking across app
class ErrorLogHelper {
  static final _crashlytics = FirebaseCrashlytics.instance;

  /// Log an exception with context
  static Future<void> logException(
    Object exception,
    StackTrace? stackTrace, {
    String? context,
    Map<String, String>? attributes,
  }) async {
    if (kDebugMode) {
      debugPrint('❌ Error [$context]: $exception\n$stackTrace');
    }

    // Log to Crashlytics in production
    if (!kDebugMode) {
      try {
        await _crashlytics.recordError(
          exception,
          stackTrace,
          reason: context,
          printDetails: false,
        );

        // Add custom attributes for debugging
        if (attributes != null) {
          for (final entry in attributes.entries) {
            await _crashlytics.setCustomKey(entry.key, entry.value);
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Failed to log to Crashlytics: $e');
      }
    }
  }

  /// Log a simple error message (non-exception context)
  static Future<void> logMessage(
    String message, {
    String level = 'INFO', // INFO, WARNING, ERROR
    Map<String, String>? attributes,
  }) async {
    if (kDebugMode) {
      debugPrint('[$level] $message');
    }

    if (!kDebugMode) {
      try {
        await _crashlytics.log('[$level] $message');
        if (attributes != null) {
          for (final entry in attributes.entries) {
            await _crashlytics.setCustomKey(entry.key, entry.value);
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Failed to log message: $e');
      }
    }
  }

  /// Set user context for better error attribution
  static Future<void> setUserContext(int userId, String email, String shopName) async {
    try {
      await _crashlytics.setUserIdentifier(userId.toString());
      await _crashlytics.setCustomKey('email', email);
      await _crashlytics.setCustomKey('shop_name', shopName);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to set user context: $e');
    }
  }

  /// Clear user context on logout
  static Future<void> clearUserContext() async {
    try {
      await _crashlytics.setUserIdentifier('');
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to clear user context: $e');
    }
  }
}

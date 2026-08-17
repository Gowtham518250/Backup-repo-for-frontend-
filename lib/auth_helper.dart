import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'secure_token_storage.dart';
import 'session_logout_service.dart';

/// Unified auth facade — all token storage goes through [SecureTokenStorage].
class AuthHelper {
  static const int tokenExpiryMinutes = 120;

  static Future<void> saveToken(String token) async {
    try {
      await SecureTokenStorage.saveToken(token);
      if (kDebugMode) debugPrint('✅ Auth token saved securely');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error saving token: $e');
    }
  }

  static Future<String?> getToken() => SecureTokenStorage.getToken();

  static Future<bool> isTokenExpired() async {
    final valid = await SecureTokenStorage.isSessionValid();
    return !valid;
  }

  /// Full secure wipe — same path as owner logout (no server notify).
  static Future<void> clearAuthData() async {
    try {
      await SessionLogoutService.performFullLogout(notifyServer: false);
      if (kDebugMode) debugPrint('✅ Auth session cleared');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error clearing auth data: $e');
    }
  }

  static void redirectToLogin(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    });
  }

  static Future<bool> checkResponseStatus(int statusCode, BuildContext context) async {
    if (statusCode == 401 || statusCode == 403) {
      // OFFLINE-FIRST: Check if user has valid local session before forcing logout
      final hasLocalSession = await SecureTokenStorage.isSessionValid();
      
      if (statusCode == 401 && hasLocalSession) {
        // 401 with local session = likely offline or server error, don't force logout
        if (kDebugMode) debugPrint('⚠️ 401 error but local session exists - keeping user logged in (offline mode)');
        return true; // Don't force logout
      }
      
      // 403 or 401 without local session = force logout
      await SessionLogoutService.performFullLogout(notifyServer: false);
      if (context.mounted) {
        redirectToLogin(
          context,
          statusCode == 401
              ? 'Session expired. Please login again.'
              : 'Access denied. Please login again.',
        );
      }
      return false;
    }
    return true;
  }

  static String categorizeError(int statusCode) {
    if (statusCode == 400) return 'Invalid request. Please check your input.';
    if (statusCode == 401) return 'Session expired. Please login again.';
    if (statusCode == 403) return 'Access denied. Permission required.';
    if (statusCode == 404) return 'Resource not found.';
    if (statusCode == 409) return 'Duplicate entry. Item already exists.';
    if (statusCode == 422) return 'Validation error. Please check your input.';
    if (statusCode == 500) return 'Server error. Please try again later.';
    if (statusCode == 503) return 'Server unavailable. Please try again later.';
    return 'Error occurred. Please try again.';
  }
}

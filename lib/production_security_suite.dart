import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'rate_limiter.dart';
import 'secure_token_storage.dart';
import 'session_logout_service.dart';
import 'dart:async';

/// 🔒 Production Security Suite for 100cr Enterprise Apps
/// Prevents: Race conditions, session hijacking, data integrity issues

class ProductionSecuritySuite {
  // ============ TRANSACTION SAFETY ============
  
  /// Show transaction confirmation with amount verification
  static Future<bool> confirmTransaction({
    required BuildContext context,
    required String title,
    required String description,
    required double amount,
    required String action,
    Color? accentColor,
  }) async {
    final currentAmount = amount;
    bool confirmed = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (accentColor ?? Colors.indigo).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentColor ?? Colors.indigo),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Amount:', style: TextStyle(fontWeight: FontWeight.w500)),
                  Text(
                    '₹${currentAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: accentColor ?? Colors.indigo,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Verify amount before confirming',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: accentColor ?? Colors.indigo,
            ),
            onPressed: () {
              confirmed = true;
              Navigator.pop(ctx);
            },
            child: Text(action),
          ),
        ],
      ),
    );

    return confirmed;
  }

  // ============ SESSION TIMEOUT SAFETY ============

  /// Monitor session and warn before timeout
  static Future<void> initSessionMonitor(BuildContext context) async {
    final token = await SecureTokenStorage.getToken();
    if (token == null) return;

    // Check every 30 seconds if session is still valid
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        final isValid = await SecureTokenStorage.isSessionValid();
        if (!isValid && context.mounted) {
          timer.cancel();
          _showSessionExpiredDialog(context);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Session monitor error: $e');
      }
    });
  }

  static void _showSessionExpiredDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text(
          'Your session has expired for security reasons. Please login again.\n\n'
          'Your data is safe and will be synced on next login.',
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              await SessionLogoutService.performFullLogout(notifyServer: false);
              if (ctx.mounted) {
                Navigator.pushNamedAndRemoveUntil(ctx, '/login', (_) => false);
              }
            },
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  // ============ FORM VALIDATION HELPERS ============

  /// Enhanced email validation
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) return 'Email is required';
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    
    if (email.length > 254) {
      return 'Email address too long';
    }
    
    return null;
  }

  /// Enhanced password validation
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) return 'Password is required';
    
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain uppercase letter';
    }
    
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain lowercase letter';
    }
    
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain number';
    }
    
    // Special chars validation - check for common ones
    if (!password.contains(RegExp(r'[!@#\$%\^&*(),.?":{}|<>]'))) {
      return r'Password must contain special character: !@#$%^&*';
    }
    
    return null;
  }

  /// Enhanced phone validation (Indian format)
  static String? validatePhone(String? phone) {
    if (phone == null || phone.isEmpty) return 'Phone is required';
    
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleaned.length != 10) {
      return 'Phone must be exactly 10 digits';
    }
    
    if (!RegExp(r'^[6-9]').hasMatch(cleaned)) {
      return 'Phone must start with 6-9';
    }
    
    return null;
  }

  /// Name validation
  static String? validateName(String? name) {
    if (name == null || name.isEmpty) return 'Name is required';
    
    if (name.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    
    if (name.length > 100) {
      return 'Name too long (max 100 chars)';
    }
    
    if (name.contains(RegExp(r'[<>\"%;]'))) {
      return 'Name contains invalid characters';
    }
    
    return null;
  }

  // ============ OFFLINE DATA PROTECTION ============

  /// Encrypt sensitive data before storing using flutter_secure_storage
  static Future<void> saveProtectedData(
    String key,
    String value,
  ) async {
    try {
      // 🔒 SECURITY FIX: Use flutter_secure_storage instead of fake XOR encryption
      // flutter_secure_storage provides proper encryption with platform-specific secure storage
      const secureStorage = FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );
      
      await secureStorage.write(key: '_protected_$key', value: value);
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving protected data: $e');
    }
  }

  /// Retrieve encrypted data using flutter_secure_storage
  static Future<String?> getProtectedData(String key) async {
    try {
      // 🔒 SECURITY FIX: Use flutter_secure_storage instead of fake XOR decryption
      const secureStorage = FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );
      
      return await secureStorage.read(key: '_protected_$key');
    } catch (e) {
      if (kDebugMode) debugPrint('Error reading protected data: $e');
      return null;
    }
  }

  // ============ RACE CONDITION PREVENTION ============

  /// Mutex for critical operations
  static final Map<String, dynamic> _operationMutex = {};

  /// Execute operation with mutual exclusion
  static Future<T> executeAtomically<T>(
    String operationKey,
    Future<T> Function() operation,
  ) async {
    // Simple lock pattern - prevent concurrent execution of same key
    while (_operationMutex[operationKey] == true) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    
    try {
      _operationMutex[operationKey] = true;
      return await operation();
    } finally {
      _operationMutex.remove(operationKey);
    }
  }

  // ============ ERROR RECOVERY ============

  /// Show error with recovery options
  static Future<void> showErrorWithRecovery(
    BuildContext context,
    String error,
    VoidCallback? onRetry,
  ) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 32),
        title: const Text('Error Occurred'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '💡 Try: Check internet, wait, or retry',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
          if (onRetry != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                onRetry();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  // ============ DATA INTEGRITY CHECKS ============

  /// Verify critical data hasn't been tampered
  static Future<bool> verifyDataIntegrity(
    String dataKey,
    String expectedHash,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(dataKey) ?? '';
      
      // Simple hash (use crypto library for production)
      final hash = data.hashCode.toString();
      
      return hash == expectedHash;
    } catch (e) {
      return false;
    }
  }

  // ============ TIMEOUT PROTECTION ============

  /// Wrap API call with timeout
  static Future<T> withTimeout<T>(
    Future<T> future, {
    Duration? timeout,
    String? operationName,
  }) async {
    final actualTimeout = timeout ?? const Duration(seconds: 30);
    final opName = operationName ?? 'Operation';
    
    try {
      return await future.timeout(
        actualTimeout,
        onTimeout: () {
          throw TimeoutException(
            '$opName took too long. Check your internet connection.',
            actualTimeout,
          );
        },
      );
    } on TimeoutException catch (e) {
      if (kDebugMode) debugPrint('Timeout: ${e.message}');
      rethrow;
    }
  }
}

/// Global rate limiter instance
final _globalRateLimiter = RateLimiter();

/// Check if request is allowed (prevent duplicate submissions)
Future<bool> canSubmitRequest(String action) async {
  if (!_globalRateLimiter.allowRequest(action)) {
    await _globalRateLimiter.waitIfRateLimited(action);
    return _globalRateLimiter.allowRequest(action);
  }
  return true;
}

/// Reset rate limiter for testing
void resetRateLimiter() {
  _globalRateLimiter.resetAll();
}

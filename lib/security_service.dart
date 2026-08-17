import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'api_client.dart';
import 'secure_token_storage.dart';
// Removed iOS auth import

class SecurityService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static const String _masterPinKey = 'master_app_pin_hash';
  static const String _pinSetupCompleteKey = 'master_pin_setup_complete';
  static const String _biometricEnabledKey = 'biometric_login_enabled';
  /// Owner completed post-login biometric gate, or enabled from Shop Details after device auth.
  static const String _ownerBiometricStatusKey = 'owner_biometric_status_v1';
  
  /// Validate PIN strength (4-6 digits, no repeating patterns)
  static String? validatePinStrength(String pin) {
    if (pin.isEmpty) return 'PIN cannot be empty';
    if (pin.length < 4 || pin.length > 6) return 'PIN must be 4-6 digits';
    if (!RegExp(r'^[0-9]+$').hasMatch(pin)) return 'PIN must contain only digits';
    
    // Prevent weak patterns: 0000, 1111, 1234, 9876, etc.
    if (RegExp(r'^(\d)\1+$').hasMatch(pin)) {
      return 'PIN cannot have all same digits (e.g., 0000)';
    }
    if (_isSequentialPin(pin)) {
      return 'PIN cannot be sequential (e.g., 1234 or 4321)';
    }

    return null; // Valid PIN
  }

  static bool _isSequentialPin(String pin) {
    if (pin.length < 4) return false;
    var ascending = true;
    var descending = true;
    for (var i = 1; i < pin.length; i++) {
      final prev = int.parse(pin[i - 1]);
      final curr = int.parse(pin[i]);
      if (curr != prev + 1) ascending = false;
      if (curr != prev - 1) descending = false;
    }
    return ascending || descending;
  }

  // =========== BIOMETRICS (NEW) ===========

  /// Check if the device hardware supports biometrics
  static Future<bool> isBiometricHardwareAvailable() async {
    try {
      if (kIsWeb) return false;

      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();

      // Hardware capability alone is not enough for a useful biometric flow.
      // If the device has no enrolled biometric, authenticate() will fail and
      // the caller can fall back to the owner PIN flow.
      if (!canCheck || !supported) return false;

      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (e) {
      if (kDebugMode) debugPrint('Biometric capability check failed: $e');
      return false;
    }
  }

  /// Check if the user has enabled biometric login in settings
  static Future<bool> isBiometricEnabled() async {
    final val = await _secureStorage.read(key: _biometricEnabledKey);
    return val == 'true';
  }

  /// Toggle biometric login preference
  static Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      await _secureStorage.write(key: _biometricEnabledKey, value: 'true');
    } else {
      await _secureStorage.delete(key: _biometricEnabledKey);
    }
  }

  /// Delete biometric login preference from secure device storage
  static Future<void> disableBiometric() async {
    await _secureStorage.delete(key: _biometricEnabledKey);
  }

  // ----- Owner biometric registration (post shop / owner OTP) -----

  static Future<String?> _readOwnerBiometricStatus() async {
    return _secureStorage.read(key: _ownerBiometricStatusKey);
  }

  /// One-time migration: if biometric was already on before this feature, treat owner as verified.
  static Future<void> migrateLegacyOwnerBiometricStatus() async {
    final existing = await _readOwnerBiometricStatus();
    if (existing != null) return;
    if (await isBiometricEnabled()) {
      await _secureStorage.write(key: _ownerBiometricStatusKey, value: 'verified');
    }
  }

  static Future<bool> isOwnerBiometricVerificationComplete() async {
    await migrateLegacyOwnerBiometricStatus();
    return await _readOwnerBiometricStatus() == 'verified';
  }

  static Future<void> setOwnerBiometricStatusVerified() async {
    await _secureStorage.write(key: _ownerBiometricStatusKey, value: 'verified');
  }

  /// Owner skipped registration or device cannot use biometrics — biometric login forced off.
  static Future<void> setOwnerBiometricStatusDeclined() async {
    await _secureStorage.write(key: _ownerBiometricStatusKey, value: 'declined');
    await disableBiometric();
  }

  /// True when owner should see the registration screen after OTP (native + hardware + not decided yet).
  static Future<bool> shouldShowOwnerBiometricGate() async {
    if (kIsWeb) return false;
    if (!await isBiometricHardwareAvailable()) return false;
    await migrateLegacyOwnerBiometricStatus();
    final s = await _readOwnerBiometricStatus();
    if (s == 'verified' || s == 'declined') return false;
    return true;
  }

  /// Turn off biometric login if owner never completed verification (repair inconsistent state).
  static Future<void> enforceBiometricLoginRequiresVerification() async {
    await migrateLegacyOwnerBiometricStatus();
    final s = await _readOwnerBiometricStatus();
    if (s != 'verified' && await isBiometricEnabled()) {
      await disableBiometric();
    }
  }

  /// Perform physical biometric authentication
  static Future<bool> authenticateBiometrically({
    String reason = 'Authenticate to access sensitive data',
  }) async {
    try {
      if (kIsWeb) return false;

      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported || !canCheck) {
        if (kDebugMode) debugPrint('Biometric authentication is not supported.');
        return false;
      }

      final available = await _localAuth.getAvailableBiometrics();
      if (available.isEmpty) {
        if (kDebugMode) {
          debugPrint('No enrolled biometric is available on this device.');
        }
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Biometric Authentication',
          ),
        ],
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Biometric authentication error: $e');
      return false;
    }
  }

  /// Check if master PIN has been set by user
  static Future<bool> isPinSet() async {
    final val = await _secureStorage.read(key: _pinSetupCompleteKey);
    return val == 'true';
  }

  /// Public compatibility method: returns the stored PIN hash.
  /// Call-sites that compare `getMasterPin() == input` will need the sha256 hash of `input`.
  /// This method exists solely to keep the build compiling.
  static Future<String> getMasterPin() async {
    try {
      return await _getMasterPinHash();
    } catch (_) {
      // Return hash of default '0000' when no PIN is set
      return sha256.convert(utf8.encode('0000')).toString();
    }
  }

  /// Get the current master PIN hash (raises exception if not set)
  static Future<String> _getMasterPinHash() async {
    final hash = await _secureStorage.read(key: _masterPinKey);
    if (hash == null) throw Exception('Master PIN not set');
    return hash;
  }

  /// Set or change the master PIN (with validation and hashing)
  static Future<bool> setMasterPin(String newPin) async {
    final validation = validatePinStrength(newPin);
    if (validation != null) throw Exception(validation);
    try {
      final hash = sha256.convert(utf8.encode(newPin)).toString();
      await _secureStorage.write(key: _masterPinKey, value: hash);
      await _secureStorage.write(key: _pinSetupCompleteKey, value: 'true');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Show a PIN entry dialog to verify identity
  static Future<bool> verifyMasterPin(BuildContext context) async {
    try {
      final isPinConfigured = await isPinSet();
      if (!isPinConfigured) {
        // 🛡️ ENHANCEMENT: Allow user to set up PIN directly if not set
        final setupNow = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('PIN Required'),
            content: const Text('To access Worker Management, you need to set up a Master PIN first. Would you like to set it up now?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                child: const Text('SETUP NOW', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ?? false;

        if (setupNow && context.mounted) {
          final newPin = await _showSetupPinDialog(context);
          if (newPin != null && newPin.isNotEmpty) {
            await setMasterPin(newPin);
            return true; // Proceed after setup
          }
        }
        return false;
      }

      int attempts = 0;
      const maxAttempts = 3;
      
      // 🛡️ ENHANCEMENT: Try Biometrics first if enabled
      if (await isBiometricEnabled() && await isBiometricHardwareAvailable()) {
        final success = await authenticateBiometrically(reason: 'Verification required for Owner access');
        if (success) return true;
        // If biometrics fail or cancelled, proceed to PIN as fallback
      }
      
      while (attempts < maxAttempts) {
        final controller = TextEditingController();
        
        final result = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Column(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 48, color: Color(0xFF6366F1)),
                const SizedBox(height: 12),
                Text('Master PIN Required', 
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Attempt ${attempts + 1}/$maxAttempts',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                const Text('Please enter your master PIN.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: const Color(0xFF6366F1).withValues(alpha: 0.05),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx), 
                child: Text('CANCEL', style: TextStyle(color: Colors.grey[600]))
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                child: const Text('VERIFY'),
              ),
            ],
          ),
        );
        
        if (result != null && result.isNotEmpty) {
          final enteredHash = sha256.convert(utf8.encode(result)).toString();
          final storedHash = await _getMasterPinHash();
          if (enteredHash == storedHash) return true;
        } else if (result == null) {
          return false; // User cancelled
        }
        
        attempts++;
        if (attempts < maxAttempts && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Invalid PIN. Attempts remaining: ${maxAttempts - attempts}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      
      // Max attempts reached
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Max PIN attempts exceeded. Please try again later.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return false;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Reset master PIN (uses secure storage)
  static Future<bool> resetMasterPin() async {
    try {
      await _secureStorage.delete(key: _masterPinKey);
      await _secureStorage.delete(key: _pinSetupCompleteKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> _showSetupPinDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Setup Master PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a 4-6 digit numeric PIN to secure your worker and financial data.'),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: '----',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.length < 4) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('PIN must be at least 4 digits')));
                return;
              }
              Navigator.pop(ctx, controller.text);
            },
            child: const Text('SAVE PIN'),
          ),
        ],
      ),
    );
  }

  /// Generate strong PIN suggestion (crypto-random 4 digits, non-sequential).
  static String generateStrongPin() {
    final rng = Random.secure();
    for (var attempt = 0; attempt < 20; attempt++) {
      final pin = List.generate(4, (_) => rng.nextInt(10)).join();
      if (validatePinStrength(pin) == null) return pin;
    }
    return '5927';
  }

  /// Clear master PIN on logout so the next owner sets their own.
  static Future<void> clearMasterPinOnLogout() => resetMasterPin();
  
  // ==================== BACKEND SECURITY HARDENING INTEGRATION ====================
  
  /// Check input security via backend (Phase 1-10 Production Fixes)
  static Future<Map<String, dynamic>> checkInputSecurity(Map<String, dynamic> input) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        return {'success': false, 'error': 'NOT_AUTHENTICATED'};
      }
      
      final response = await ApiClient.postJson(
        ApiClient.securityCheckInput,
        {'input': input},
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'is_safe': data['is_safe'],
          'threats_detected': data['threats_detected'],
          'sanitized_input': data['sanitized_input'],
        };
      } else {
        return {'success': false, 'error': 'BACKEND_ERROR'};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Input security check failed: $e');
      return {'success': false, 'error': 'NETWORK_ERROR'};
    }
  }
  
  /// Get rate limit status from backend
  static Future<Map<String, dynamic>> getRateLimitStatus() async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        return {'success': false, 'error': 'NOT_AUTHENTICATED'};
      }
      
      final response = await ApiClient.getJson(
        ApiClient.securityRateLimitStatus,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'rate_limited': data['rate_limited'],
          'remaining_requests': data['remaining_requests'],
          'reset_time': data['reset_time'],
        };
      } else {
        return {'success': false, 'error': 'BACKEND_ERROR'};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Rate limit check failed: $e');
      return {'success': false, 'error': 'NETWORK_ERROR'};
    }
  }
  
  /// Validate password strength via backend
  static Future<Map<String, dynamic>> validatePasswordBackend(String password) async {
    try {
      final response = await ApiClient.postJson(
        ApiClient.securityValidatePassword,
        {'password': password},
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'is_strong': data['is_strong'],
          'strength_score': data['strength_score'],
          'suggestions': data['suggestions'],
        };
      } else {
        return {'success': false, 'error': 'BACKEND_ERROR'};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Password validation failed: $e');
      return {'success': false, 'error': 'NETWORK_ERROR'};
    }
  }
  
  /// Get security headers from backend
  static Future<Map<String, dynamic>> getSecurityHeaders() async {
    try {
      final response = await ApiClient.getJson(
        ApiClient.securitySecurityHeaders,
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'headers': data['headers'],
        };
      } else {
        return {'success': false, 'error': 'BACKEND_ERROR'};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Security headers check failed: $e');
      return {'success': false, 'error': 'NETWORK_ERROR'};
    }
  }
  
  /// Sanitize batch inputs via backend
  static Future<Map<String, dynamic>> sanitizeBatchInputs(List<Map<String, dynamic>> inputs) async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) {
        return {'success': false, 'error': 'NOT_AUTHENTICATED'};
      }
      
      final response = await ApiClient.postJson(
        ApiClient.securitySanitizeBatch,
        {'inputs': inputs},
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'sanitized_inputs': data['sanitized_inputs'],
          'threats_removed': data['threats_removed'],
        };
      } else {
        return {'success': false, 'error': 'BACKEND_ERROR'};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Batch sanitization failed: $e');
      return {'success': false, 'error': 'NETWORK_ERROR'};
    }
  }
  
  /// Get CSRF token from backend
  static Future<Map<String, dynamic>> getCsrfToken() async {
    try {
      final response = await ApiClient.getJson(
        ApiClient.securityCsrfToken,
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'csrf_token': data['csrf_token'],
          'expires_at': data['expires_at'],
        };
      } else {
        return {'success': false, 'error': 'BACKEND_ERROR'};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ CSRF token fetch failed: $e');
      return {'success': false, 'error': 'NETWORK_ERROR'};
    }
  }
  
  /// Check for SQL injection patterns via backend
  static Future<Map<String, dynamic>> checkSqlInjection(String input) async {
    try {
      final response = await ApiClient.getJson(
        '${ApiClient.securityCheckSqlInjection}?query=$input',
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'is_suspicious': data['is_suspicious'],
          'patterns_found': data['patterns_found'],
        };
      } else {
        return {'success': false, 'error': 'BACKEND_ERROR'};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ SQL injection check failed: $e');
      return {'success': false, 'error': 'NETWORK_ERROR'};
    }
  }
}

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'dart:typed_data';
import 'dart:math';

/// 🔒 SECURITY SERVICE: Secure storage for sensitive shop data
/// Replaces unencrypted SharedPreferences usage for payment credentials, PINs, etc.
/// 
/// Usage:
/// ```dart
/// await SecurePreferencesService.setUpiId('upi@bank');
/// final upi = await SecurePreferencesService.getUpiId();
/// ```
class SecurePreferencesService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  
  // Keys for sensitive data
  static const String _upiIdKey = 'shop_upi_id_enc';
  static const String _masterPinKey = 'master_pin_hash_enc';
  static const String _paymentQrKey = 'payment_qr_b64_enc';
  static const String _encKeyForLocal = 'secure_prefs_key';

  // ========= ENCRYPTION KEY MANAGEMENT =========
  static Future<enc.Key> _getOrCreateEncryptionKey() async {
    final stored = await _storage.read(key: _encKeyForLocal);
    if (stored != null) {
      return enc.Key.fromBase64(stored);
    }
    // Generate new 256-bit key
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final key = enc.Key(Uint8List.fromList(bytes));
    await _storage.write(key: _encKeyForLocal, value: key.base64);
    return key;
  }

  static Future<String> _encrypt(String plaintext) async {
    final key = await _getOrCreateEncryptionKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  static Future<String?> _decrypt(String combined) async {
    try {
      final parts = combined.split(':');
      if (parts.length != 2) return null;
      final key = await _getOrCreateEncryptionKey();
      final iv = enc.IV.fromBase64(parts[0]);
      final encrypter = enc.Encrypter(enc.AES(key));
      return encrypter.decrypt(enc.Encrypted.fromBase64(parts[1]), iv: iv);
    } catch (e) {
      return null;
    }
  }

  // ========= UPI ID MANAGEMENT =========
  
  /// Save UPI ID securely (encrypted)
  static Future<void> setUpiId(String upiId) async {
    if (upiId.isEmpty) {
      await _storage.delete(key: _upiIdKey);
      return;
    }
    final encrypted = await _encrypt(upiId);
    await _storage.write(key: _upiIdKey, value: encrypted);
  }

  /// Retrieve UPI ID (decrypted)
  static Future<String?> getUpiId() async {
    final encrypted = await _storage.read(key: _upiIdKey);
    if (encrypted == null) return null;
    return await _decrypt(encrypted);
  }

  /// Clear UPI ID
  static Future<void> clearUpiId() async {
    await _storage.delete(key: _upiIdKey);
  }

  // ========= MASTER PIN MANAGEMENT =========
  
  /// Save Master PIN hash (NEVER store plaintext)
  /// Hash the PIN before calling this: bcrypt.hashpw(pin.encode(), bcrypt.gensalt())
  static Future<void> setMasterPinHash(String pinHash) async {
    if (pinHash.isEmpty) {
      await _storage.delete(key: _masterPinKey);
      return;
    }
    final encrypted = await _encrypt(pinHash);
    await _storage.write(key: _masterPinKey, value: encrypted);
  }

  /// Check if Master PIN is set (returns true/false, doesn't expose PIN)
  static Future<bool> isMasterPinSet() async {
    final encrypted = await _storage.read(key: _masterPinKey);
    return encrypted != null && encrypted.isNotEmpty;
  }

  /// Retrieve Master PIN hash for comparison (use bcrypt.checkpw for verification)
  static Future<String?> getMasterPinHash() async {
    final encrypted = await _storage.read(key: _masterPinKey);
    if (encrypted == null) return null;
    return await _decrypt(encrypted);
  }

  /// Clear Master PIN
  static Future<void> clearMasterPin() async {
    await _storage.delete(key: _masterPinKey);
  }

  // ========= PAYMENT QR CODE MANAGEMENT =========
  
  /// Save Payment QR (base64 encoded) securely
  static Future<void> setPaymentQrB64(String qrBase64) async {
    if (qrBase64.isEmpty) {
      await _storage.delete(key: _paymentQrKey);
      return;
    }
    final encrypted = await _encrypt(qrBase64);
    await _storage.write(key: _paymentQrKey, value: encrypted);
  }

  /// Retrieve Payment QR (decrypted base64)
  static Future<String?> getPaymentQrB64() async {
    final encrypted = await _storage.read(key: _paymentQrKey);
    if (encrypted == null) return null;
    return await _decrypt(encrypted);
  }

  /// Clear Payment QR
  static Future<void> clearPaymentQr() async {
    await _storage.delete(key: _paymentQrKey);
  }

  // ========= BULK OPERATIONS =========
  
  /// Clear ALL sensitive payment data (call on logout)
  static Future<void> clearAllPaymentData() async {
    try {
      await Future.wait([
        clearUpiId(),
        clearMasterPin(),
        clearPaymentQr(),
      ]);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ SecurePreferencesService.clearAllPaymentData failed: $e');
    }
  }

  /// Export all keys (for debugging only - should be disabled in production)
  static Future<Map<String, String?>> debugExportAll() async {
    return {
      'upi_id': await getUpiId(),
      'payment_qr': await getPaymentQrB64(),
      'master_pin_hash': await getMasterPinHash(),
    };
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

class SecureTokenStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _kToken = 'auth_token_enc';
  static const String _kCustomerToken = 'customer_token_enc';
  static const String _kRefreshToken = 'auth_refresh_enc';
  static const String _kUser  = 'auth_user_enc';
  static const String _kKey   = 'aes_device_key';

  /// 🔧 PHASE 2 FIX: Get user_id for token isolation - prevents cross-user token leakage
  static Future<int?> _getUserId() async {
    final secureUserId = await _storage.read(key: 'user_id');
    if (secureUserId != null) {
      final parsed = int.tryParse(secureUserId);
      if (parsed != null && parsed > 0) return parsed;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final scopedUserId = prefs.getInt('current_scoped_user_id');
      if (scopedUserId != null && scopedUserId > 0) return scopedUserId;
    } catch (_) {
      // ignore
    }

    return null;
  }
  
  /// 🔧 PHASE 2 FIX: Get scoped key with user_id to prevent cross-user token leakage
  static Future<String?> _getScopedKeyOrBase(String baseKey) async {
    final userId = await _getUserId();
    if (userId == null || userId == 0) {
      return baseKey;
    }
    return '${baseKey}_$userId';
  }

  static Future<String> _getScopedKey(String baseKey) async {
    final scopedKey = await _getScopedKeyOrBase(baseKey);
    if (scopedKey == null) {
      if (kDebugMode) {
        debugPrint('⚠️ SECURITY: No user_id available for scoped secure token storage; using base key.');
      }
      return baseKey;
    }
    return scopedKey;
  }

  static Future<enc.Key> _getOrCreateKey() async {
    final stored = await _storage.read(key: _kKey);
    if (stored != null) {
      try {
        return enc.Key.fromBase64(stored);
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to parse stored key, generating new one: $e');
        }
        // Continue to generate new key if parsing fails
      }
    }
    
    // Use cryptographically secure key generation with salt
    final secureRandom = math.Random.secure();
    final salt = List<int>.generate(32, (_) => secureRandom.nextInt(256));
    final keyBytes = List<int>.generate(32, (_) => secureRandom.nextInt(256));
    
    // Store salt for future key derivation
    await _storage.write(key: '${_kKey}_salt', value: base64UrlEncode(salt));
    
    final key = enc.Key(Uint8List.fromList(keyBytes));
    await _storage.write(key: _kKey, value: key.base64);
    
    if (kDebugMode) {
      print('✅ Generated new encryption key with salt');
    }
    return key;
  }
  
  /// Rotate encryption key for enhanced security
  static Future<void> rotateKey() async {
    try {
      if (kDebugMode) {
        print('🔄 Rotating encryption key...');
      }
      
      // Get old key
      final oldKey = await _getOrCreateKey();
      
      // Generate new key
      final secureRandom = math.Random.secure();
      final newSalt = List<int>.generate(32, (_) => secureRandom.nextInt(256));
      final newKeyBytes = List<int>.generate(32, (_) => secureRandom.nextInt(256));
      final newKey = enc.Key(Uint8List.fromList(newKeyBytes));
      
      // Re-encrypt all data with new key
      await _reencryptData(oldKey, newKey);
      
      // Store new key and salt
      await _storage.write(key: '${_kKey}_salt', value: base64UrlEncode(newSalt));
      await _storage.write(key: _kKey, value: newKey.base64);
      
      if (kDebugMode) {
        print('✅ Encryption key rotated successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Key rotation failed: $e');
      }
      rethrow;
    }
  }
  
  /// Re-encrypt all known encrypted secure-storage records for the current
  /// user before the key itself is replaced. If any record cannot be
  /// decrypted, rotation aborts so an old key is never discarded while
  /// encrypted data still depends on it.
  static Future<void> _reencryptData(enc.Key oldKey, enc.Key newKey) async {
    final userId = await _getUserId();
    final userSuffix = userId != null && userId > 0 ? '_$userId' : '';

    const logicalKeys = <String>[
      _kToken,
      _kCustomerToken,
      _kRefreshToken,
      _kTime,
      _kUser,
    ];

    for (final logicalKey in logicalKeys) {
      final scopedKey = '$logicalKey$userSuffix';
      final combined = await _storage.read(key: scopedKey);
      if (combined == null || combined.isEmpty) continue;

      final parts = combined.split(':');
      if (parts.length != 2) {
        throw StateError('Cannot rotate key: invalid encrypted payload for $scopedKey');
      }

      final oldIv = enc.IV.fromBase64(parts[0]);
      final oldCipher = parts[1];
      final oldEncrypter = enc.Encrypter(enc.AES(oldKey));
      final plaintext = oldEncrypter.decrypt64(oldCipher, iv: oldIv);

      final newIv = enc.IV.fromSecureRandom(16);
      final newEncrypter = enc.Encrypter(enc.AES(newKey));
      final encrypted = newEncrypter.encrypt(plaintext, iv: newIv);
      await _storage.write(
        key: scopedKey,
        value: '${newIv.base64}:${encrypted.base64}',
      );
    }

    if (kDebugMode) {
      print('✅ Re-encrypted encrypted session records for current user');
    }
  }

  static Future<void> saveUserId(int userId) async {
    await _storage.write(key: 'user_id', value: userId.toString());
  }

  static Future<void> clearUserId() async {
    await _storage.delete(key: 'user_id');
  }

  static const String _kTime   = 'auth_time_enc';

  static Future<void> saveToken(String token) async {
    final key = await _getOrCreateKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key));
    final encrypted = encrypter.encrypt(token, iv: iv);
    // Store iv:ciphertext together with user-scoped key
    final scopedTokenKey = await _getScopedKey(_kToken);
    final combined = '${iv.base64}:${encrypted.base64}';
    await _storage.write(key: scopedTokenKey, value: combined);
    
    // Save current timestamp for 7-day auto-login check (unique IV per field)
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    final timeIv = enc.IV.fromSecureRandom(16);
    final timeEnc = encrypter.encrypt(now, iv: timeIv);
    final scopedTimeKey = await _getScopedKey(_kTime);
    await _storage.write(key: scopedTimeKey, value: '${timeIv.base64}:${timeEnc.base64}');
  }

  static Future<void> saveCustomerToken(String token) async {
    final key = await _getOrCreateKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key));
    final encrypted = encrypter.encrypt(token, iv: iv);
    final combined = '${iv.base64}:${encrypted.base64}';
    final scopedCustomerKey = await _getScopedKey(_kCustomerToken);
    await _storage.write(key: scopedCustomerKey, value: combined);
  }

  static Future<String?> getCustomerToken() async {
    final scopedCustomerKey = await _getScopedKey(_kCustomerToken);
    final combined = await _storage.read(key: scopedCustomerKey);
    if (combined == null) return null;

    try {
      final parts = combined.split(':');
      if (parts.length < 2) return null;
      final key = await _getOrCreateKey();
      final iv = enc.IV.fromBase64(parts[0]);
      final encrypter = enc.Encrypter(enc.AES(key));
      return encrypter.decrypt(enc.Encrypted.fromBase64(parts[1]), iv: iv);
    } catch (e) {
      if (kDebugMode) debugPrint('SecureTokenStorage.getCustomerToken: decrypt failed ($e)');
      return null;
    }
  }

  static Future<String?> getToken() async {
    final scopedTokenKey = await _getScopedKey(_kToken);
    final combined = await _storage.read(key: scopedTokenKey);
    if (combined == null) return null;

    try {
      final parts = combined.split(':');
      if (parts.length < 2) return null;
      final key = await _getOrCreateKey();
      final iv = enc.IV.fromBase64(parts[0]);
      final encrypter = enc.Encrypter(enc.AES(key));
      return encrypter.decrypt(enc.Encrypted.fromBase64(parts[1]), iv: iv);
    } catch (e) {
      if (kDebugMode) debugPrint('SecureTokenStorage.getToken: decrypt failed ($e)');
      return null;
    }
  }

  static Future<void> saveRefreshToken(String token) async {
    final key = await _getOrCreateKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key));
    final encrypted = encrypter.encrypt(token, iv: iv);
    final combined = '${iv.base64}:${encrypted.base64}';
    final scopedRefreshKey = await _getScopedKey(_kRefreshToken);
    await _storage.write(key: scopedRefreshKey, value: combined);
  }

  static Future<String?> getRefreshToken() async {
    final scopedRefreshKey = await _getScopedKey(_kRefreshToken);
    final combined = await _storage.read(key: scopedRefreshKey);
    if (combined == null) return null;
    try {
      final parts = combined.split(':');
      // 🔒 SECURITY FIX: Safe array access - check array bounds before access
      if (parts.length < 2) return null;
      final key = await _getOrCreateKey();
      final iv = enc.IV.fromBase64(parts[0]);
      final encrypter = enc.Encrypter(enc.AES(key));
      return encrypter.decrypt(enc.Encrypted.fromBase64(parts[1]), iv: iv);
    } catch (e) {
      if (kDebugMode) debugPrint('SecureTokenStorage.getRefreshToken: decrypt failed ($e)');
      return null;
    }
  }

  static Future<bool> isSessionValid() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;

    final scopedTimeKey = await _getScopedKey(_kTime);
    final combined = await _storage.read(key: scopedTimeKey);
    if (combined == null) return false;

    try {
      final parts = combined.split(':');
      if (parts.length < 2) return false;
      final key = await _getOrCreateKey();
      final iv = enc.IV.fromBase64(parts[0]);
      final encrypter = enc.Encrypter(enc.AES(key));
      final timestamp = int.tryParse(
        encrypter.decrypt(enc.Encrypted.fromBase64(parts[1]), iv: iv),
      );
      if (timestamp == null) return false;

      const maxSessionAge = Duration(days: 7);
      return DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(timestamp),
          ) <=
          maxSessionAge;
    } catch (e) {
      if (kDebugMode) debugPrint('SecureTokenStorage.isSessionValid: timestamp check failed ($e)');
      return false;
    }
  }

  static Future<void> saveUser(Map<String, dynamic> userData) async {
    final key = await _getOrCreateKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key));
    final jsonStr = json.encode(userData);
    final encrypted = encrypter.encrypt(jsonStr, iv: iv);
    final scopedKey = await _getScopedKey(_kUser);
    await _storage.write(key: scopedKey, value: '${iv.base64}:${encrypted.base64}');
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final scopedKey = await _getScopedKey(_kUser);
    final combined = await _storage.read(key: scopedKey);
    if (combined == null) return null;
    try {
      final parts = combined.split(':');
      if (parts.length != 2) return null;
      final key = await _getOrCreateKey();
      final iv = enc.IV.fromBase64(parts[0]);
      final encrypter = enc.Encrypter(enc.AES(key));
      final decrypted = encrypter.decrypt(enc.Encrypted.fromBase64(parts[1]), iv: iv);
      return json.decode(decrypted) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) debugPrint('SecureTokenStorage.getUser: decrypt failed ($e)');
      return null;
    }
  }

  static Future<void> clearAll() async {
    // ✅ FIX: Only delete SESSION keys — do NOT wipe biometric preferences.
    // Previously `_storage.deleteAll()` was wiping biometric_login_enabled and
    // owner_biometric_status_v1, forcing the user to re-setup fingerprint/face
    // unlock after every logout. Biometric settings belong to the DEVICE, not
    // the session, so they must persist across logins.

    final userId = await _getUserId();
    if (userId != null && userId > 0) {
      await _storage.delete(key: '${_kToken}_$userId');
      await _storage.delete(key: '${_kCustomerToken}_$userId');
      await _storage.delete(key: '${_kRefreshToken}_$userId');
      await _storage.delete(key: '${_kTime}_$userId');
      await _storage.delete(key: '${_kUser}_$userId');
    }

    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kCustomerToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kTime);
    await _storage.delete(key: _kUser);
    await _storage.delete(key: _kKey);
    await _storage.delete(key: '${_kKey}_salt');
    await clearUserId();
    // NOT deleted here. Call SecurityService.disableBiometric() explicitly
    // only if the user actively turns it off in settings.
  }

  static Future<void> deleteToken() async {
    final userId = await _getUserId();
    if (userId != null && userId > 0) {
      await _storage.delete(key: '${_kToken}_$userId');
    }
    await _storage.delete(key: _kToken);
  }

  /// Alias used by session management logout flow.
  static Future<void> clearToken() async => deleteToken();

  static Future<void> clearRefreshToken() async {
    final userId = await _getUserId();
    if (userId != null && userId > 0) {
      await _storage.delete(key: '${_kRefreshToken}_$userId');
    }
    await _storage.delete(key: _kRefreshToken);
  }
}
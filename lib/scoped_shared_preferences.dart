import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

/// 🔒 SECURITY: User-scoped SharedPreferences service to prevent data leakage across accounts
/// This ensures that when users switch accounts on the same device, their data is completely isolated
class ScopedSharedPreferences {
  static String _currentUserId = '0';
  
  /// Set the current user ID for scoping
  static Future<void> setCurrentUserId(int userId) async {
    _currentUserId = userId.toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_scoped_user_id', userId);
    if (kDebugMode) debugPrint('🔒 Scoped user ID set to: $userId');
  }
  
  /// Get the current user ID for scoping
  static Future<int> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('current_scoped_user_id') ?? 0;
  }
  
  /// 🔒 Scoped key prefix to prevent data leakage
  static Future<String> _scopedKey(String key) async {
    if (_currentUserId == '0') {
      final prefs = await SharedPreferences.getInstance();
      final persistedId = prefs.getInt('current_scoped_user_id') ?? 0;
      if (persistedId != 0) {
        _currentUserId = persistedId.toString();
      }
    }

    if (_currentUserId == '0') {
      if (kDebugMode) debugPrint('⚠️ SECURITY: No user ID set for scoped key: $key; using default scope.');
      return 'user_0_$key';
    }
    return 'user_${_currentUserId}_$key';
  }
  
  /// 🔒 Scoped String operations
  static Future<bool> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(await _scopedKey(key), value);
  }
  
  static Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(await _scopedKey(key));
  }
  
  /// 🔒 Scoped Int operations
  static Future<bool> setInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setInt(await _scopedKey(key), value);
  }
  
  static Future<int?> getInt(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(await _scopedKey(key));
  }
  
  /// 🔒 Scoped Bool operations
  static Future<bool> setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setBool(await _scopedKey(key), value);
  }
  
  static Future<bool?> getBool(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(await _scopedKey(key));
  }
  
  /// 🔒 Scoped Double operations
  static Future<bool> setDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setDouble(await _scopedKey(key), value);
  }
  
  static Future<double?> getDouble(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(await _scopedKey(key));
  }
  
  /// 🔒 Scoped Remove operation
  static Future<bool> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.remove(await _scopedKey(key));
  }
  
  /// 🔒 Clear all scoped data for current user
  static Future<void> clearCurrentUserScopedData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await getCurrentUserId();
    if (userId == 0) {
      await prefs.remove('current_scoped_user_id');
      _currentUserId = '0';
      return;
    }
    
    final keys = prefs.getKeys();
    
    for (final key in keys) {
      if (key.startsWith('user_${userId}_')) {
        await prefs.remove(key);
        if (kDebugMode) debugPrint('🔒 Cleared scoped key: $key');
      }
    }

    await prefs.remove('current_scoped_user_id');
    _currentUserId = '0';
  }
  
  /// 🔒 Clear all legacy unscoped keys that might leak data
  static Future<void> clearLegacyUnscopedKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyKeys = [
      'shop_name', 'location', 'shop_phone', 'shop_email', 'shop_logo_url',
      'shop_profile_json', 'workers_json', 'online_store_active', 'shop_published_online',
      'dashboard_daily_insight_v1', 'user_name', 'logo_base64',
      'welcome_card_dismissed', 'last_backup_time', 'payment_qr_b64',
      'payment_sound_lang', 'payment_sound_enabled', 'is_dark_mode',
      'is_staff_mode', 'last_loaded_user_id',
      // Add more keys as needed
    ];
    
    for (final key in legacyKeys) {
      await prefs.remove(key);
      if (kDebugMode) debugPrint('🧹 Cleared legacy unscoped key: $key');
    }
  }
  
  /// 🔒 Clear all user-scoped data when switching accounts
  static Future<void> clearAllUserDataForUser(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    for (final key in keys) {
      if (key.startsWith('user_${userId}_')) {
        await prefs.remove(key);
        if (kDebugMode) debugPrint('🔒 Cleared user data for ID $userId: $key');
      }
    }
  }
  
  /// 🔒 Debug: List all keys to check for data leakage
  static Future<void> debugListAllKeys() async {
    if (!kDebugMode) return;
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    debugPrint('🔍 All SharedPreferences keys:');
    for (final key in keys) {
      debugPrint('  - $key');
    }
  }
}

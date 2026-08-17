import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'secure_token_storage.dart';
import 'notification_service.dart';

/// 
/// SHOP PROFILE PERSISTENCE SERVICE
/// ================================
/// 
/// Ensures shop profile survives:
/// - Logout
/// - App reinstall
/// - Device switch
/// 
/// Features:
/// - Local cache
/// - Remote sync
/// - Conflict resolution
/// - Automatic restoration on login
/// 
class ShopProfilePersistenceService {
  static const String _profileCacheKey = 'shop_profile_cache';
  static const String _lastSyncKey = 'shop_profile_last_sync';
  static const String _profileVersionKey = 'shop_profile_version';
  static const String _pendingSyncKey = 'shop_profile_pending_sync';
  
  static Timer? _syncTimer;
  static bool _isSyncing = false;
  
  /// 🔧 PHASE 2 FIX: Get user_id for isolation - prevents data leakage between users
  static Future<int?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final primary = prefs.getInt('user_id');
    final alternate = prefs.getInt('userId');
    return primary ?? alternate;
  }
  
  /// 🔧 PHASE 2 FIX: Get scoped key with user_id to prevent cross-user data leakage
  static Future<String> _getScopedKey(String baseKey) async {
    final userId = await _getUserId();
    if (userId == null || userId == 0) {
      throw Exception('SECURITY: Cannot access profile without authenticated user_id');
    }
    return '${baseKey}_$userId';
  }
  
  /// 🔧 FIX: Extract error message from non-JSON backend responses
  static String _extractErrorMessage(String responseBody) {
    try {
      final data = json.decode(responseBody);
      if (data is Map) {
        return data['detail']?.toString() ?? 
               data['message']?.toString() ?? 
               data['error']?.toString() ?? 
               'Unknown error';
      }
      return responseBody;
    } catch (_) {
      // Not JSON, return as-is
      return responseBody;
    }
  }
  
  /// Save shop profile to local cache
  static Future<void> saveProfileLocally(Map<String, dynamic> profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scopedCacheKey = await _getScopedKey(_profileCacheKey);
      final scopedLastSyncKey = await _getScopedKey(_lastSyncKey);
      final scopedVersionKey = await _getScopedKey(_profileVersionKey);
      
      await prefs.setString(scopedCacheKey, json.encode(profile));
      await prefs.setString(scopedLastSyncKey, DateTime.now().toIso8601String());
      await prefs.setInt(scopedVersionKey, DateTime.now().millisecondsSinceEpoch);
      
      if (kDebugMode) debugPrint('💾 Shop profile saved locally (user-isolated)');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to save profile locally: $e');
    }
  }
  
  /// Load shop profile from local cache
  static Future<Map<String, dynamic>?> loadProfileLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scopedCacheKey = await _getScopedKey(_profileCacheKey);
      
      final profileStr = prefs.getString(scopedCacheKey);
      
      if (profileStr != null) {
        final profile = json.decode(profileStr) as Map<String, dynamic>;
        if (kDebugMode) debugPrint('📖 Shop profile loaded from local cache (user-isolated)');
        return profile;
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to load profile locally: $e');
      return null;
    }
  }
  
  /// Fetch shop profile from backend
  static Future<Map<String, dynamic>?> fetchProfileFromBackend() async {
    try {
      final token = await SecureTokenStorage.getToken();
      if (token == null || token.isEmpty) {
        if (kDebugMode) debugPrint('⚠️ No auth token for profile fetch');
        return null;
      }
      
      final response = await ApiClient.getJson(
        '/api/shop/profile',
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Save to local cache
        await saveProfileLocally(data);
        
        if (kDebugMode) debugPrint('✅ Shop profile fetched from backend');
        return data;
      } else {
        if (kDebugMode) debugPrint('⚠️ Backend profile fetch failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Backend profile fetch error: $e');
      return null;
    }
  }
  
  /// Sync shop profile to backend with retry logic
  static Future<Map<String, dynamic>> syncProfileToBackend(Map<String, dynamic> profile) async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final token = await SecureTokenStorage.getToken();
        if (token == null || token.isEmpty) {
          return {'success': false, 'error': 'NOT_AUTHENTICATED'};
        }
        
        if (kDebugMode) debugPrint('🔄 Backend sync attempt $attempt/$maxRetries');
        
        final userId = profile['user_id'] ?? profile['id'] ?? '';
        final response = await ApiClient.putJson(
          '/api/shop/profile${userId.toString().isNotEmpty ? "?user_id=$userId" : ""}',
          profile,
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 15));
        
          if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          // Update local cache
          await saveProfileLocally(data);
          
          if (kDebugMode) debugPrint('✅ Shop profile synced to backend (attempt $attempt)');
          return {'success': true, 'profile': data};
        } else {
          final error = _extractErrorMessage(response.body);
          if (kDebugMode) debugPrint('⚠️ Backend sync failed (attempt $attempt): $error');
          
          // If shop does not exist, try to create it
          if (response.statusCode == 400 || response.statusCode == 404) {
            final createRes = await ApiClient.postJson('/api/shop/create', profile, headers: {'Authorization': 'Bearer $token'});
            if (createRes.statusCode == 200 || createRes.statusCode == 201) {
                final data = json.decode(createRes.body);
                await saveProfileLocally(data);
                return {'success': true, 'profile': data};
            }
          }
          
          // Don't retry on authentication errors
          if (response.statusCode == 401 || response.statusCode == 403) {
            return {'success': false, 'error': error};
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Profile sync error (attempt $attempt): $e');
      }
      
      // Wait before retry
      if (attempt < maxRetries) {
        await Future.delayed(retryDelay);
      }
    }
    
    return {'success': false, 'error': 'MAX_RETRIES_EXCEEDED'};
  }
  
  /// Get shop profile with automatic fallback
  /// Tries local cache first, then backend
  static Future<Map<String, dynamic>?> getProfile() async {
    // Try local cache first
    final localProfile = await loadProfileLocally();
    if (localProfile != null) {
      // Check if cache is stale (older than 5 minutes)
      final isStale = await _isCacheStale();
      if (!isStale) {
        return localProfile;
      }
    }
    
    // Fetch from backend
    final backendProfile = await fetchProfileFromBackend();
    if (backendProfile != null) {
      return backendProfile;
    }
    
    // Fallback to local cache even if stale
    return localProfile;
  }
  
  /// Restore shop profile after app reinstall
  /// Called on login to ensure profile is available
  static Future<Map<String, dynamic>> restoreProfile() async {
    try {
      if (kDebugMode) debugPrint('🔄 Restoring shop profile...');

      // Fetch from backend (source of truth)
      final backendProfile = await fetchProfileFromBackend();

      if (backendProfile != null) {
        // Apply profile data to individual preference fields
        await applyProfileToPrefs(backendProfile);

        if (kDebugMode) debugPrint('✅ Shop profile restored from backend and applied to prefs');
        return {
          'success': true,
          'source': 'backend',
          'profile': backendProfile
        };
      }

      // Try local cache as fallback
      final localProfile = await loadProfileLocally();
      if (localProfile != null) {
        // Apply profile data to individual preference fields
        await applyProfileToPrefs(localProfile);

        if (kDebugMode) debugPrint('✅ Shop profile restored from local cache and applied to prefs');
        return {
          'success': true,
          'source': 'local',
          'profile': localProfile
        };
      }

      if (kDebugMode) debugPrint('⚠️ No shop profile available for restoration');
      return {
        'success': false,
        'error': 'NO_PROFILE_AVAILABLE'
      };
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Profile restoration failed: $e');
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }
  
  /// Reconcile profile differences between local and backend
  static Future<Map<String, dynamic>> reconcileProfile() async {
    try {
      if (kDebugMode) debugPrint('🔍 Reconciling shop profile...');
      
      final localProfile = await loadProfileLocally();
      final backendProfile = await fetchProfileFromBackend();
      
      if (localProfile == null && backendProfile == null) {
        return {'success': true, 'message': 'No profile to reconcile'};
      }
      
      if (localProfile == null) {
        // Only backend exists - use it
        return {'success': true, 'action': 'USE_BACKEND', 'profile': backendProfile};
      }
      
      if (backendProfile == null) {
        // Only local exists - sync to backend
        final syncResult = await syncProfileToBackend(localProfile);
        return syncResult;
      }
      
      // Both exist - check for conflicts
      final localVersion = localProfile['version'] ?? 0;
      final backendVersion = backendProfile['version'] ?? 0;
      
      if (backendVersion > localVersion) {
        // Backend is newer - use it
        await saveProfileLocally(backendProfile);
        return {'success': true, 'action': 'USE_BACKEND', 'profile': backendProfile};
      } else if (localVersion > backendVersion) {
        // Local is newer - sync to backend
        final syncResult = await syncProfileToBackend(localProfile);
        return syncResult;
      } else {
        // Same version - use backend as source of truth
        await saveProfileLocally(backendProfile);
        return {'success': true, 'action': 'USE_BACKEND', 'profile': backendProfile};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Profile reconciliation failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// Clear local profile cache (called on logout)
  static Future<void> clearProfileCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scopedCacheKey = await _getScopedKey(_profileCacheKey);
      final scopedLastSyncKey = await _getScopedKey(_lastSyncKey);
      final scopedVersionKey = await _getScopedKey(_profileVersionKey);
      final scopedPendingSyncKey = await _getScopedKey(_pendingSyncKey);
      final scopedPendingSyncTimeKey = await _getScopedKey('pending_sync_time');
      
      await prefs.remove(scopedCacheKey);
      await prefs.remove(scopedLastSyncKey);
      await prefs.remove(scopedVersionKey);
      await prefs.remove(scopedPendingSyncKey);
      await prefs.remove(scopedPendingSyncTimeKey);
      
      // Also clear individual shop profile fields from prefs
      await prefs.remove('shop_name');
      await prefs.remove('location');
      await prefs.remove('shop_type');
      await prefs.remove('shop_phone');
      await prefs.remove('website');
      await prefs.remove('shop_tagline');
      await prefs.remove('primary_upi_id');
      await prefs.remove('upi_id');
      await prefs.remove('shop_gst');
      await prefs.remove('gst_number');
      await prefs.remove('logo_base64');
      await prefs.remove('state');
      await prefs.remove('shop_state');
      
      if (kDebugMode) debugPrint('🗑️ Shop profile cache cleared (user-isolated)');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to clear profile cache: $e');
    }
  }
  
  /// Check if local cache is stale
  static Future<bool> _isCacheStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scopedLastSyncKey = await _getScopedKey(_lastSyncKey);
      final lastSyncStr = prefs.getString(scopedLastSyncKey);

      if (lastSyncStr == null) return true;

      final lastSync = DateTime.tryParse(lastSyncStr);
      if (lastSync == null) return true;

      final staleThreshold = DateTime.now().subtract(const Duration(minutes: 5));
      return lastSync.isBefore(staleThreshold);
    } catch (e) {
      return true; // Assume stale if check fails
    }
  }

  /// Apply backend profile data to local preferences
  static Future<void> applyProfileToPrefs(Map<String, dynamic> profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 🔧 FIX: previously this only handled the WRAPPED shape
      // ({'profile': {...}, 'settings': {...}} — what a successful
      // backend sync stores). But saveProfileLocally() is called with the
      // FLAT shape ({'shop_name': ..., 'phone': ...}) *before* the backend
      // call even happens, as an offline-safe local save. If that sync
      // then fails (offline, timeout, backend error — the normal case
      // this local save exists to protect against), the cache is left
      // flat, and shopData below ended up null every time — silently
      // applying nothing, so a just-edited shop name/phone/etc. would
      // vanish back to its old value on the next load even though it was
      // genuinely saved to local storage. Now this accepts either shape.
      final dynamic nestedRaw = profile['profile'] ?? profile['shop_profile'];
      final Map<String, dynamic>? shopData = nestedRaw is Map
          ? Map<String, dynamic>.from(nestedRaw)
          : profile; // already flat — use as-is

      if (shopData != null) {
        // Apply individual fields to prefs for backward compatibility
        if (shopData['shop_name'] != null) {
          await prefs.setString('shop_name', shopData['shop_name'].toString());
        }
        if (shopData['location'] != null) {
          await prefs.setString('location', shopData['location'].toString());
        }
        if (shopData['shop_type'] != null) {
          await prefs.setString('shop_type', shopData['shop_type'].toString());
        }
        if (shopData['phone'] != null || shopData['shop_phone'] != null) {
          await prefs.setString('shop_phone', (shopData['phone'] ?? shopData['shop_phone']).toString());
        }
        if (shopData['website'] != null) {
          await prefs.setString('website', shopData['website'].toString());
        }
        if (shopData['shop_tagline'] != null || shopData['tagline'] != null) {
          await prefs.setString('shop_tagline', (shopData['shop_tagline'] ?? shopData['tagline']).toString());
        }
        if (shopData['primary_upi_id'] != null || shopData['upi_id'] != null) {
          await prefs.setString('primary_upi_id', (shopData['primary_upi_id'] ?? shopData['upi_id']).toString());
          await prefs.setString('upi_id', (shopData['primary_upi_id'] ?? shopData['upi_id']).toString());
        }
        if (shopData['gst_number'] != null || shopData['shop_gst'] != null || shopData['gstin'] != null) {
          await prefs.setString('gst_number', (shopData['gst_number'] ?? shopData['shop_gst'] ?? shopData['gstin']).toString());
          await prefs.setString('shop_gst', (shopData['gst_number'] ?? shopData['shop_gst'] ?? shopData['gstin']).toString());
        }
        if (shopData['logo_url'] != null) {
          await prefs.setString('logo_url', shopData['logo_url'].toString());
        }
        if (shopData['state'] != null || shopData['shop_state'] != null) {
          await prefs.setString('state', (shopData['state'] ?? shopData['shop_state']).toString());
        }
        if (shopData['online_shopping_enabled'] != null) {
          await prefs.setBool('online_shopping_enabled', shopData['online_shopping_enabled'] == true || shopData['online_shopping_enabled'] == 'true');
        }
        if (shopData['is_night_shop'] != null) {
          await prefs.setBool('is_night_shop', shopData['is_night_shop'] == true || shopData['is_night_shop'] == 'true');
        }

        if (kDebugMode) debugPrint('✅ Shop profile applied to local preferences');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to apply profile to prefs: $e');
    }
  }
  
  /// Get profile sync status
  static Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scopedCacheKey = await _getScopedKey(_profileCacheKey);
      final scopedLastSyncKey = await _getScopedKey(_lastSyncKey);
      final scopedVersionKey = await _getScopedKey(_profileVersionKey);
      final scopedPendingSyncKey = await _getScopedKey(_pendingSyncKey);
      
      final lastSyncStr = prefs.getString(scopedLastSyncKey);
      final hasLocalProfile = prefs.containsKey(scopedCacheKey);
      final hasPendingSync = prefs.containsKey(scopedPendingSyncKey);
      
      return {
        'has_local_profile': hasLocalProfile,
        'last_sync': lastSyncStr,
        'is_stale': await _isCacheStale(),
        'version': prefs.getInt(scopedVersionKey),
        'has_pending_sync': hasPendingSync,
      };
    } catch (e) {
      return {
        'has_local_profile': false,
        'last_sync': null,
        'is_stale': true,
        'version': null,
        'has_pending_sync': false,
      };
    }
  }
  
  /// Update specific profile field and sync
  static Future<Map<String, dynamic>> updateProfileField(
    String field,
    dynamic value
  ) async {
    try {
      // Get current profile
      final profile = await getProfile();
      if (profile == null) {
        return {'success': false, 'error': 'NO_PROFILE'};
      }
      
      // Update field
      profile[field] = value;
      profile['version'] = DateTime.now().millisecondsSinceEpoch;
      
      // Sync to backend
      return await syncProfileToBackend(profile);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Profile field update failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// Initialize profile persistence service
  /// Should be called on app startup
  static Future<void> initialize() async {
    try {
      if (kDebugMode) debugPrint('🚀 Initializing Shop Profile Persistence Service');
      
      // Check if restoration is needed
      final localProfile = await loadProfileLocally();
      if (localProfile == null) {
        if (kDebugMode) debugPrint('ℹ️ No local profile - will restore on login');
      } else {
        if (kDebugMode) debugPrint('✅ Local profile found');
      }
      
      // Start background sync for pending profiles
      _startBackgroundSync();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Profile service initialization failed: $e');
    }
  }
  
  /// Start background sync for failed operations
  static void _startBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (_isSyncing) return;
      
      await _syncPendingProfile();
    });
    
    if (kDebugMode) debugPrint('🔄 Background sync started (every 5 minutes)');
  }
  
  /// Stop background sync
  static void stopBackgroundSync() {
    _syncTimer?.cancel();
    if (kDebugMode) debugPrint('⏹️ Background sync stopped');
  }
  
  /// Mark profile for pending sync
  static Future<void> markForSync(Map<String, dynamic> profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scopedPendingSyncKey = await _getScopedKey(_pendingSyncKey);
      final scopedPendingSyncTimeKey = await _getScopedKey('pending_sync_time');
      
      await prefs.setString(scopedPendingSyncKey, json.encode(profile));
      await prefs.setInt(scopedPendingSyncTimeKey, DateTime.now().millisecondsSinceEpoch);
      
      if (kDebugMode) debugPrint('📝 Profile marked for pending sync (user-isolated)');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to mark profile for sync: $e');
    }
  }
  
  /// Sync pending profile
  static Future<void> _syncPendingProfile() async {
    try {
      _isSyncing = true;
      
      final prefs = await SharedPreferences.getInstance();
      final scopedPendingSyncKey = await _getScopedKey(_pendingSyncKey);
      final scopedPendingSyncTimeKey = await _getScopedKey('pending_sync_time');
      
      final pendingProfileStr = prefs.getString(scopedPendingSyncKey);
      
      if (pendingProfileStr == null) {
        return; // No pending sync
      }
      
      final pendingProfile = json.decode(pendingProfileStr) as Map<String, dynamic>;
      
      if (kDebugMode) debugPrint('🔄 Attempting to sync pending profile...');
      
      final result = await syncProfileToBackend(pendingProfile);
      
      if (result['success'] == true) {
        // Remove from pending
        await prefs.remove(scopedPendingSyncKey);
        await prefs.remove(scopedPendingSyncTimeKey);
        if (kDebugMode) debugPrint('✅ Pending profile synced successfully (user-isolated)');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Pending sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }
  
  /// Force immediate sync of pending profile
  static Future<bool> forceSyncPending() async {
    try {
      await _syncPendingProfile();
      
      final prefs = await SharedPreferences.getInstance();
      final scopedPendingSyncKey = await _getScopedKey(_pendingSyncKey);
      
      final pendingProfileStr = prefs.getString(scopedPendingSyncKey);
      
      return pendingProfileStr == null; // Returns true if no pending sync
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Force sync failed: $e');
      return false;
    }
  }
  /// Cleanup resources
  static Future<void> dispose() async {
    stopBackgroundSync();
    if (kDebugMode) debugPrint('🧹 Profile persistence service disposed');
  }
}
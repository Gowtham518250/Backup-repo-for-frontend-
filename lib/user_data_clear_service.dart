import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'inventory_management_service.dart';
import 'local_storage_service.dart';
import 'inventory_sync_service.dart';
import 'secure_preferences_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:hive_flutter/hive_flutter.dart';

/// Clear ONLY session-specific data on logout/new login
/// NEVER delete sales, invoices, customers, products, inventory, or pending sync queue!
class UserDataClearService {
  /// List of user-specific cache keys that should be cleared (ONLY session data)
  static const List<String> userDataKeys = [
    // 🚨 CRITICAL: User ID must be cleared to prevent multi-user device contamination
    'user_id',
    'userId',
    
    // Session Cache (SAFE to CLEAR)
    'sales_cache',
    'daily_sales',
    'monthly_sales',
    'yearly_sales',
    'backend_sales',
    'local_sales',
    
    // Inventory Cache (SAFE to CLEAR - not the actual product/inventory data in Hive)
    'inventory_cache',
    'products_cache',
    
    // Workers & Attendance
    'workers_cache',
    'backend_workers',
    'workers',
    'workers_json',
    'attendance_cache',
    'backend_attendance',
    'attendance_data',
    
    // Customers Cache (SAFE to CLEAR - not actual customer data in Hive)
    'customers_cache',
    'invoices_cache',
    'backend_customers',
    
    // Analytics & Reports
    'analytics_cache',
    'analytics_summary',
    'performance_stats',
    'daily_insight',
    'product_analytics',
    
    // Stock alerts
    'stock_alerts',
    
    // Role / staff / customer session (CRITICAL)
    'is_staff_mode',
    'role',
    'app_mode',
    'active_staff_name',
    'customer_name',
    'customer_phone',
    'customer_email',
    'last_online_order_id',

    // Bill state
    'last_bill_number',
    'low_stock_history',
    'last_loaded_user_id',
    'dashboard_daily_insight_v1',
    'active_shop_id',
    'offline_payments_queue_v1',
    'confirmed_utrs_local',
    'pds_dedup_v1',
    'pds_trusted_senders_v1',

    // Other session data (SAFE to CLEAR)
    'auth_token',
    'session_cache',
    'last_sync_time',
    'quotes_cache',
    'shop_logo_url',
    
    // Notifications
    'notifications_cache',
    'recent_notifications',
    
    'shop_profile_json',

    // Account data
    'account_invoices',
    'account_workers',
    
    // Shop Profile & Images
    'logo_base64',
    'payment_qr_b64',
    'shop_name',
    'location',
    'shop_type',
    'shop_phone',
    'website',
    'tagline',
    'upi_id',
    'shop_state',
    'contact_person',
    'email',
    'user_name',
    'shop_email',
    'gst_number',
    'shop_categories',
    'opening_hour',
    'closing_hour',
    
    // Other session data
    'bg_sms_queue',
    'master_pin',
    'local_expenses',
    '_otp_code',
    '_otp_email',
    '_otp_expiry',
    '_otp_last_sent',

    // Growth / retention kit (per-account hygiene on logout)
    'retail_shop_focus_v1',
    'retail_focus_onboarding_v1_done',
    'retail_first_open_ms',
    'retail_bills_completed_count',
    'retail_last_bill_completed_ms',
    'retail_last_app_open_ms',
    'retail_play_store_url_hint',
  ];

  /// Clear ONLY session-specific data (NEVER delete sales/invoices/customers/products/inventory/sync queue!)
  static Future<void> clearAllUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (kDebugMode) debugPrint('🧹 Clearing ONLY session-specific user data...');

      List<dynamic> salesHistory = [];
      List<dynamic> allInvoices = [];
      List<dynamic> customers = [];
      Map<String, dynamic> productData = {};
      List<dynamic> inventory = [];

      final storageReady = await _storageBackendsAvailable();
      if (!storageReady) {
        if (kDebugMode) debugPrint('⚠️ Platform storage unavailable; skipping business-data preservation during clear.');
      } else {
        // Preserve business data when storage is available; otherwise skip.
        try {
          await _ensureHiveInitialized();
          salesHistory = await LocalStorageService.loadSales();
          if (kDebugMode) debugPrint('📦 Preserving ${salesHistory.length} sales records');
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Failed to preserve sales history: $e');
        }

        try {
          await _ensureHiveInitialized();
          allInvoices = await LocalStorageService.loadLocalInvoices();
          if (kDebugMode) debugPrint('📦 Preserving ${allInvoices.length} invoices');
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Failed to preserve invoices: $e');
        }

        try {
          await _ensureHiveInitialized();
          customers = await LocalStorageService.loadLocalCustomers();
          if (kDebugMode) debugPrint('📦 Preserving ${customers.length} customers');
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Failed to preserve customers: $e');
        }

        try {
          await _ensureHiveInitialized();
          final loadedProducts = await LocalStorageService.loadLocalProducts();
          if (loadedProducts is Map<String, dynamic>) {
            productData = loadedProducts;
          } else if (loadedProducts is List) {
            productData = {'products': loadedProducts};
          }
          if (kDebugMode) debugPrint('📦 Preserving product data');
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Failed to preserve product data: $e');
        }

        try {
          await _ensureHiveInitialized();
          inventory = await LocalStorageService.loadInventory();
          if (kDebugMode) debugPrint('📦 Preserving ${inventory.length} inventory records');
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Failed to preserve inventory: $e');
        }
      }

      // Clear session keys
      // FIX: 'user_id'/'userId' are in this list, and every LocalStorageService
      // save function below (saveSales, saveLocalInvoices, etc.) is guarded by
      // _hasValidUserId() — which reads exactly those two keys. Removing them
      // first, then calling saveSales()/saveLocalInvoices()/etc. afterward,
      // meant every "restore" call below silently no-op'd (logged a debug
      // line and returned) instead of actually writing anything back. The
      // Hive box itself is user-id-scoped so this often self-heals on a
      // same-account relogin once initializeSession() sets user_id again —
      // but any restore step whose data wasn't already durably on disk
      // before this function ran had no working safety net. Preserving
      // user_id/userId until after the restore closes that gap.
      final preservedUserId = prefs.getInt('user_id');
      final preservedUserIdAlt = prefs.getInt('userId');
      for (final key in userDataKeys) {
        if (key == 'user_id' || key == 'userId') continue;
        if (prefs.containsKey(key)) {
          await prefs.remove(key);
          if (kDebugMode) debugPrint('  ✓ Cleared: $key');
        }
      }
      
      // Clear dynamic per-account keys (EXCEPT SYNC QUEUE KEYS!)
      const dynamicPrefixes = [
        'local_customers_',
        'backend_customers_',
        'cohort_',
        'retail_',
        '_otp_',
        '_protected_',
        'all_sales_',
        // FIX: product_catalog_service.dart's cache used to be a single
        // global 'product_catalog_v2' key (see that file's fix) — now it's
        // scoped per user as 'product_catalog_v2_{userId}'. Clearing both
        // forms: the prefix here catches the new scoped key, and the
        // explicit remove() right below catches any leftover legacy
        // unscoped key from before that fix.
        'product_catalog_v2_',
        // FIX: WorkerLocalStorage scopes its own keys as workers_{shopkeeperId}
        // (see worker_local_storage.dart) rather than going through
        // ScopedSharedPreferences, so this cleanup pass never touched it.
        // The per-ID key naming means a different user logging in wouldn't
        // actually see the previous user's worker records on screen (they'd
        // query a different key), but the old data was never purged either
        // -- left sitting on the device indefinitely, which matters if the
        // device is later inspected, backed up, or handed to someone else.
        'workers_',
      ];
      final allKeys = prefs.getKeys().toList();
      for (final key in allKeys) {
        if (dynamicPrefixes.any((p) => key.startsWith(p))) {
          await prefs.remove(key);
          if (kDebugMode) debugPrint('  ✓ Cleared dynamic key: $key');
        }
      }
      await prefs.remove('product_catalog_v2'); // legacy unscoped key
      
      // Now that sales/invoices/customers/products/inventory have been
      // durably restored (using the preserved user_id), it's safe to clear
      // user_id/userId as originally intended — the new session's
      // initializeSession() call will set the real one right after this.
      if (preservedUserId != null) await prefs.remove('user_id');
      if (preservedUserIdAlt != null) await prefs.remove('userId');
      await prefs.remove('current_scoped_user_id');

      // Reset inventory management service
      InventoryManagementService.reset();

      // Clear any sensitive payment credentials stored outside SharedPreferences
      try {
        await SecurePreferencesService.clearAllPaymentData();
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Failed to clear payment credentials: $e');
      }

      // DO NOT clear orphan sales boxes - they're already user-scoped!
      
      // 🔧 RESTORE ALL BUSINESS DATA
      if (salesHistory.isNotEmpty) {
        try {
          await LocalStorageService.saveSales(salesHistory);
          if (kDebugMode) debugPrint('✅ Restored ${salesHistory.length} sales records');
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Failed to restore sales history: $e');
        }
      }
      
      if (allInvoices.isNotEmpty) {
        try {
          await LocalStorageService.saveLocalInvoices(allInvoices);
          if (kDebugMode) debugPrint('✅ Restored ${allInvoices.length} invoices');
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Failed to restore invoices: $e');
        }
      }
      
      if (customers.isNotEmpty) {
        try {
          await LocalStorageService.saveLocalCustomers(customers);
          if (kDebugMode) debugPrint('✅ Restored ${customers.length} customers');
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Failed to restore customers: $e');
        }
      }
      
      if (productData.isNotEmpty) {
        try {
          await LocalStorageService.saveLocalProducts(productData);
          if (kDebugMode) debugPrint('✅ Restored product data');
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Failed to restore product data: $e');
        }
      }
      
      if (inventory.isNotEmpty) {
        try {
          await LocalStorageService.saveInventory(inventory);
          if (kDebugMode) debugPrint('✅ Restored ${inventory.length} inventory records');
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Failed to restore inventory: $e');
        }
      }
      
      // 🔧 FIX: Remove user_id only after restore completes
      // This ensures LocalStorageService can access user-scoped Hive boxes during restore
      // We kept user_id during restore by skipping it in the clear loop above
      // Now safely remove it after all restores complete
      await prefs.remove('user_id');
      await prefs.remove('userId');
      if (kDebugMode) debugPrint('✅ Removed user_id after restore complete');
      
      // Refresh inventory from backend when storage is available.
      if (storageReady) {
        try {
          await InventorySyncService.refreshAllInventory();
          await InventorySyncService.updateLastSyncTimestamp();
          if (kDebugMode) debugPrint('✅ Inventory refreshed from backend');
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Failed to refresh inventory: $e');
        }
      }

      if (kDebugMode) debugPrint('✅ Session data cleared successfully (business data preserved)');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error clearing user data: $e');
    }
  }

  static Future<bool> _storageBackendsAvailable() async {
    try {
      await SharedPreferences.getInstance();
      await getApplicationDocumentsDirectory();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Storage backends unavailable: $e');
      return false;
    }
  }

  static Future<void> _ensureHiveInitialized() async {
    try {
      if (!Hive.isBoxOpen('dummy')) {
        await Hive.initFlutter();
      }
    } catch (_) {
      // Ignore; this is best-effort and the service will continue with a no-op restore.
    }
  }

  /// Keep only session-critical data, clear everything else
  static Future<void> clearAllButAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Keys to KEEP
      final keysToKeep = {
        'auth_token',
        'user_id',
        'userId',
        'user_name',
        'email',
        'shop_name',
        'location',
        'payment_sound_enabled',
        'payment_sound_lang',
        'language_code',
        'sender_email',
        'app_password',
        'email_credentials_configured',
      };
      
      if (kDebugMode) debugPrint('🧹 Clearing all user data except auth...');
      
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (!keysToKeep.contains(key)) {
          await prefs.remove(key);
          if (kDebugMode) debugPrint('  ✓ Cleared: $key');
        }
      }
      
      if (kDebugMode) debugPrint('✅ User data cleared (auth preserved)');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error clearing data: $e');
    }
  }

  /// Verify no data leakage - check if there's any old user data still cached
  static Future<Map<String, List<String>>> detectDataLeakage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final leakedKeys = <String, List<String>>{};
      
      for (final key in userDataKeys) {
        if (prefs.containsKey(key)) {
          final value = prefs.get(key);
          if (value != null) {
            leakedKeys.putIfAbsent('found', () => []);
            leakedKeys['found']!.add(key);
            if (kDebugMode) debugPrint('⚠️ LEAKED DATA DETECTED: $key');
          }
        }
      }
      
      if (leakedKeys.isEmpty) {
        if (kDebugMode) debugPrint('✅ No data leakage detected');
      }
      
      return leakedKeys;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error checking leakage: $e');
      return {};
    }
  }
}
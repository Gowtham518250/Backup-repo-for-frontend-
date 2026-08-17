import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state_reset.dart';
import 'api_client.dart';
import 'account_data_sync_service.dart';
import 'customer_api_client.dart';
import 'google_auth_service.dart';
import 'local_storage_service.dart';
import 'online_orders_listener.dart';
import 'payment_detection_service.dart';
import 'payment_detection_system.dart';
import 'security_service.dart';
import 'sale_service.dart';
import 'secure_preferences_service.dart';
import 'secure_token_storage.dart';
import 'session_management.dart';
import 'sync_queue_manager.dart';
import 'sync_service.dart';
import 'user_data_clear_service.dart';
import 'scoped_shared_preferences.dart';

/// Single logout / session-isolation path for owner and customer flows.
/// NEVER delete sales, invoices, customers, products, inventory, or pending sync queue!
class SessionLogoutService {
  static bool _inProgress = false;

  /// Runs a single logout cleanup step without letting a failure there
  /// abort the rest of the chain. Before this fix, _clearCore() ran ~15
  /// sequential awaited steps with no error handling on all but the first
  /// (server logout) — if ANY step threw (e.g. a plugin channel error,
  /// Google Sign-In not configured, a locked Hive box), the exception
  /// propagated straight out of performOwnerLogout() to the button's
  /// onPressed handler, which never reached the Navigator call after it.
  /// Net effect: tap "Logout", confirmation dialog closes, nothing happens —
  /// the user is stuck on the same screen (or behind a loading dialog that
  /// never dismisses). Each step is now isolated so logout always completes
  /// and the caller can always navigate to the login screen.
  static Future<void> _step(String label, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Logout step failed ($label): $e');
    }
  }

  static Future<void> _clearCore({bool notifyServer = true}) async {
    if (notifyServer) {
      await _step(
        'server logout',
        () => SessionManagementService.logout().timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            if (kDebugMode) {
              debugPrint('⏱️ Logout server request timed out; continuing local logout');
            }
          },
        ),
      );
    }

    await _step(
      'stop online orders listener',
      () => OnlineOrdersListener.instance.stop().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('⏱️ Online orders listener stop timed out; continuing logout');
          }
        },
      ),
    );

    // 🔒 FIRST: Close all current user's Hive boxes to ensure data isolation.
    // Box names are already scoped per user (e.g. "sales_v2_$userId"), so
    // closing the current user's boxes is sufficient — the next user who
    // logs in resolves their own scoped box names and can never read this
    // user's data. DO NOT call clearOtherUserBoxes() here: it permanently
    // deletes other users' local Hive boxes from disk, including sales,
    // invoices, customers, and inventory that haven't synced to the server
    // yet. On a shared device (e.g. owner + cashier on one tablet), every
    // logout or "enter customer mode" was silently wiping the other
    // account's unsynced business data. Isolation does not require deletion.
    await _step('close user boxes', () => LocalStorageService.closeUserBoxes());
    // Reset sync queue box reference to ensure new user gets their own queue
    await _step('reset sync queue box', () => SyncQueueManager.resetBoxReference());

    // 🔒 SECURITY: Clear all scoped SharedPreferences data for current user
    await _step('clear scoped prefs', () => ScopedSharedPreferences.clearCurrentUserScopedData());
    await _step('clear legacy unscoped keys', () => ScopedSharedPreferences.clearLegacyUnscopedKeys());

    // Use UserDataClearService which now preserves all business data in scoped boxes
    await _step('clear user data', () => UserDataClearService.clearAllUserData());
    await _step('clear secure token storage', () => SecureTokenStorage.clearAll());
    await _step('clear payment data', () => SecurePreferencesService.clearAllPaymentData());
    await _step('clear session tokens', () => SessionManagementService.clearTokens());
    await _step(
      'reset api auth runtime state',
      () => ApiClient.resetAuthRuntimeState(),
    );
    // DO NOT clear sync queue! (it's user-scoped and will be reloaded for new user)
    // await SyncQueueManager.clearQueue();
    await _step('clear account data cache', () => AccountDataSyncService.clearAllCache());
    await _step('google sign-out', () => GoogleAuthService.signOut());
    await _step('clear master pin', () => SecurityService.clearMasterPinOnLogout());
    await _step('clear pds state', () => PdsStateStore.clearAll());
    await _step('clear sale in-flight', () async => SaleService.clearInFlight());
    await _step('clear payment detection', () async => PaymentDetectionSystem.clearOnLogout());
    await _step('reset customer api client', () async => CustomerAPIClient.reset());
    await _step('reset app state', () async => AppStateReset.resetAll());
    // DO NOT clear sales boxes! (they're scoped per user)
    // await LocalStorageService.clearOrphanSalesBoxes();
    // await LocalStorageService.purgeLegacyUnscopedHiveBoxes();
  }

  /// Owner logout — use from every dashboard/settings logout button.
  static Future<void> performOwnerLogout({bool processQueueFirst = false}) async {
    if (_inProgress) {
      if (kDebugMode) debugPrint('⚠️ Logout already in progress');
      return;
    }
    _inProgress = true;
    try {
      if (processQueueFirst) {
        await SyncService.processQueueSafe();
      }
      await _clearCore(notifyServer: true).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('⏱️ Owner logout cleanup exceeded 20s; continuing to reset logout state');
          }
        },
      );
    } finally {
      _inProgress = false;
    }
  }

  /// Account deletion / forced wipe (optional server notify).
  static Future<void> performFullLogout({bool notifyServer = true}) async {
    if (_inProgress) return;
    _inProgress = true;
    try {
      await _clearCore(notifyServer: notifyServer);
    } finally {
      _inProgress = false;
    }
  }

  /// Customer login: wipe owner tokens, Hive session prefs, and UPI/email leakage.
  static Future<void> enterCustomerMode({
    required String customerName,
    required String customerPhone,
  }) async {
    await _clearCore(notifyServer: false);

    final phoneDigits = customerPhone.replaceAll(RegExp(r'\D'), '');
    final email = phoneDigits.isNotEmpty
        ? '$phoneDigits@customer.local'
        : 'guest@customer.local';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'customer');
    await prefs.setString('app_mode', 'customer');
    await prefs.setString('customer_name', customerName);
    await prefs.setString('customer_phone', customerPhone);
    await prefs.setString('customer_email', email);

    if (kDebugMode) debugPrint('✅ Customer mode — owner session cleared (business data preserved)');
  }

  /// Leaving customer flow back to owner login.
  static Future<void> exitCustomerMode() async {
    final prefs = await SharedPreferences.getInstance();
    const keys = [
      'role',
      'app_mode',
      'customer_name',
      'customer_phone',
      'customer_email',
      'last_online_order_id',
    ];
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  static Future<bool> isCustomerMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role') == 'customer' ||
        prefs.getString('app_mode') == 'customer';
  }
}
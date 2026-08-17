import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'package:flutter/foundation.dart';

/// Service for syncing invoices and workers to backend per account
class AccountDataSyncService {
  // Get all invoices for current user account from backend
  static Future<List<Map<String, dynamic>>> fetchAccountInvoices() async {
    try {
      if (kDebugMode) debugPrint('📥 Fetching invoices from backend...');
      final response = await ApiClient.getJson('${ApiClient.invoicesPrefix}/user');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final invoices = List<Map<String, dynamic>>.from(data['invoices'] ?? []);
        if (kDebugMode) debugPrint('✅ Fetched ${invoices.length} invoices');
        await _cacheInvoices(invoices);
        return invoices;
      } else if (response.statusCode == 401) {
        if (kDebugMode) debugPrint('⚠️ Unauthorized - need to login');
        return [];
      } else {
        if (kDebugMode) debugPrint('❌ Failed to fetch invoices: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error fetching invoices: $e');
      return [];
    }
  }

  // Get all workers for current user account from backend
  static Future<List<Map<String, dynamic>>> fetchAccountWorkers() async {
    try {
      if (kDebugMode) debugPrint('📥 Fetching workers from backend...');
      final response = await ApiClient.getJson('/api/workers/user');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final workers = List<Map<String, dynamic>>.from(data['workers'] ?? []);
        if (kDebugMode) debugPrint('✅ Fetched ${workers.length} workers');
        await _cacheWorkers(workers);
        return workers;
      } else if (response.statusCode == 401) {
        if (kDebugMode) debugPrint('⚠️ Unauthorized - need to login');
        return [];
      } else {
        if (kDebugMode) debugPrint('❌ Failed to fetch workers: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error fetching workers: $e');
      return [];
    }
  }

  // Save invoice to backend
  static Future<bool> saveInvoiceToBackend(Map<String, dynamic> invoice) async {
    try {
      debugPrint('📤 Saving invoice to backend...');
      
      final response = await ApiClient.postJson(
        '${ApiClient.invoicesPrefix}/create',
        invoice,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('✅ Invoice saved to backend');
        return true;
      } else {
        debugPrint('❌ Failed to save invoice: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error saving invoice: $e');
      return false;
    }
  }

  // Save worker to backend
  static Future<bool> saveWorkerToBackend(Map<String, dynamic> worker) async {
    try {
      debugPrint('📤 Saving worker to backend...');
      
      final response = await ApiClient.postJson(
        '/api/workers/create',
        worker,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('✅ Worker saved to backend');
        return true;
      } else {
        debugPrint('❌ Failed to save worker: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error saving worker: $e');
      return false;
    }
  }

  // Update invoice in backend
  static Future<bool> updateInvoiceInBackend(
    String invoiceId,
    Map<String, dynamic> updatedData,
  ) async {
    try {
      debugPrint('📤 Updating invoice in backend...');
      
      final response = await ApiClient.putJson(
        '${ApiClient.invoicesPrefix}/$invoiceId',
        updatedData,
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Invoice updated in backend');
        return true;
      } else {
        debugPrint('❌ Failed to update invoice: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error updating invoice: $e');
      return false;
    }
  }

  // Update worker in backend
  static Future<bool> updateWorkerInBackend(
    String workerId,
    Map<String, dynamic> updatedData,
  ) async {
    try {
      debugPrint('📤 Updating worker in backend...');
      
      final response = await ApiClient.putJson(
        '/api/workers/$workerId',
        updatedData,
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Worker updated in backend');
        return true;
      } else {
        debugPrint('❌ Failed to update worker: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error updating worker: $e');
      return false;
    }
  }

  // Delete invoice from backend
  static Future<bool> deleteInvoiceFromBackend(String invoiceId) async {
    try {
      debugPrint('📤 Deleting invoice from backend...');
      
      final response = await ApiClient.deleteJson(
        '${ApiClient.invoicesPrefix}/$invoiceId',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('✅ Invoice deleted from backend');
        return true;
      } else {
        debugPrint('❌ Failed to delete invoice: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error deleting invoice: $e');
      return false;
    }
  }

  // Delete worker from backend
  static Future<bool> deleteWorkerFromBackend(String workerId) async {
    try {
      debugPrint('📤 Deleting worker from backend...');
      
      final response = await ApiClient.deleteJson(
        '/api/workers/$workerId',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('✅ Worker deleted from backend');
        return true;
      } else {
        debugPrint('❌ Failed to delete worker: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error deleting worker: $e');
      return false;
    }
  }

  // Sync all account data on login
  static Future<Map<String, dynamic>> syncAllAccountDataOnLogin() async {
    try {
      debugPrint('🔄 Syncing all account data...');
      
      final invoices = await fetchAccountInvoices();
      final workers = await fetchAccountWorkers();
      
      debugPrint('✅ Account data sync complete');
      
      return {
        'invoices': invoices,
        'workers': workers,
        'syncedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ Error syncing account data: $e');
      return {};
    }
  }

  // =========== LOCAL CACHING ===========

  // SECURITY FIX C2: Cache keys are user-scoped to prevent cross-account data leakage.
  static Future<String> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0;
    return id.toString();
  }

  static Future<String> get _invoicesCacheKey async => 'invoices_cache_${await _getUserId()}';
  static Future<String> get _workersCacheKey async => 'workers_cache_${await _getUserId()}';
  static Future<String> get _invoicesSyncKey async => 'invoices_last_sync_${await _getUserId()}';
  static Future<String> get _workersSyncKey async => 'workers_last_sync_${await _getUserId()}';

  static Future<void> _cacheInvoices(List<Map<String, dynamic>> invoices) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _invoicesCacheKey;
      final syncKey = await _invoicesSyncKey;
      await prefs.setString(key, jsonEncode(invoices));
      await prefs.setString(syncKey, DateTime.now().toIso8601String());
      if (kDebugMode) debugPrint('✅ Invoices cached ($key)');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error caching invoices: $e');
    }
  }

  static Future<void> _cacheWorkers(List<Map<String, dynamic>> workers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _workersCacheKey;
      final syncKey = await _workersSyncKey;
      await prefs.setString(key, jsonEncode(workers));
      await prefs.setString(syncKey, DateTime.now().toIso8601String());
      if (kDebugMode) debugPrint('✅ Workers cached ($key)');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error caching workers: $e');
    }
  }

  // Get cached invoices (offline fallback)
  static Future<List<Map<String, dynamic>>> getCachedInvoices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(await _invoicesCacheKey);
      if (jsonStr == null) return [];
      return List<Map<String, dynamic>>.from(jsonDecode(jsonStr));
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error reading cached invoices: $e');
      return [];
    }
  }

  // Get cached workers (offline fallback)
  static Future<List<Map<String, dynamic>>> getCachedWorkers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(await _workersCacheKey);
      if (jsonStr == null) return [];
      return List<Map<String, dynamic>>.from(jsonDecode(jsonStr));
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error reading cached workers: $e');
      return [];
    }
  }

  // Get last sync time
  static Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeStr = prefs.getString(await _invoicesSyncKey);
      if (timeStr == null) return null;
      return DateTime.parse(timeStr);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error getting last sync time: $e');
      return null;
    }
  }

  // Clear all cached data for current user (call on logout)
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(await _invoicesCacheKey);
      await prefs.remove(await _workersCacheKey);
      await prefs.remove(await _invoicesSyncKey);
      await prefs.remove(await _workersSyncKey);
      // Also clear legacy flat keys from older app versions
      await prefs.remove('invoices_cache');
      await prefs.remove('workers_cache');
      await prefs.remove('last_sync_time');
      if (kDebugMode) debugPrint('✅ All account cache cleared');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error clearing cache: $e');
    }
  }
}

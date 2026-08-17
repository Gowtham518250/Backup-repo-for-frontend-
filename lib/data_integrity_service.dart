import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_storage_service.dart';
import 'api_client.dart';
import 'secure_token_storage.dart';

/// Data Integrity Service
/// Verifies data integrity between local storage and backend
/// Detects and resolves data conflicts and corruption
class DataIntegrityService {
  static DataIntegrityService? _instance;
  static const String _lastIntegrityCheckKey = 'last_integrity_check';
  static const String _integrityIssuesKey = 'integrity_issues';
  
  DataIntegrityService._();
  
  static DataIntegrityService get instance {
    _instance ??= DataIntegrityService._();
    return _instance!;
  }
  
  /// Perform comprehensive integrity check
  Future<IntegrityReport> performIntegrityCheck({bool forceFullCheck = false}) async {
    final report = IntegrityReport();
    
    try {
      if (kDebugMode) debugPrint('🔍 Starting data integrity check');
      
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getString(_lastIntegrityCheckKey);
      
      // Skip full check if done recently (unless forced)
      if (!forceFullCheck && lastCheck != null) {
        final lastCheckTime = DateTime.parse(lastCheck);
        final hoursSinceCheck = DateTime.now().difference(lastCheckTime).inHours;
        
        if (hoursSinceCheck < 6) {
          if (kDebugMode) debugPrint('⏭️ Skipping full check (last check $hoursSinceCheck hours ago)');
          report.checkSkipped = true;
          return report;
        }
      }
      
      // Check sales integrity
      await _checkSalesIntegrity(report);
      
      // Check products integrity
      await _checkProductsIntegrity(report);
      
      // Check customers integrity
      await _checkCustomersIntegrity(report);
      
      // Check sync queue integrity
      await _checkSyncQueueIntegrity(report);
      
      // Update last check time
      await prefs.setString(_lastIntegrityCheckKey, DateTime.now().toIso8601String());
      
      // Store any issues found
      if (report.hasIssues) {
        await _storeIntegrityIssues(report);
      }
      
      if (kDebugMode) {
        debugPrint('📊 Integrity check completed:');
        debugPrint('   Issues found: ${report.totalIssues}');
        debugPrint('   Sales issues: ${report.salesIssues}');
        debugPrint('   Product issues: ${report.productIssues}');
        debugPrint('   Customer issues: ${report.customerIssues}');
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Integrity check error: $e');
      report.checkError = e.toString();
    }
    
    return report;
  }
  
  /// Check sales integrity
  Future<void> _checkSalesIntegrity(IntegrityReport report) async {
    try {
      final localSales = await LocalStorageService.loadSales();
      final token = await SecureTokenStorage.getToken();
      
      if (token == null || token.isEmpty) {
        if (kDebugMode) debugPrint('🔒 No token for sales integrity check');
        return;
      }
      
      // Fetch backend sales
      try {
        final response = await ApiClient.getJson('/api/invoices');
        if (response.statusCode == 200) {
          final backendSales = json.decode(response.body);
          
          if (backendSales is List) {
            // Compare counts
            if (localSales.length != backendSales.length) {
              report.salesIssues += (localSales.length - backendSales.length).abs();
              report.addIssue('Sales count mismatch: local=${localSales.length}, backend=${backendSales.length}');
            }
            
            // Check for missing sales in backend
            final backendIds = (backendSales as List).map((s) => s['sale_id'] as String?).toSet();
            for (final sale in localSales) {
              final saleId = sale['sale_id'] as String?;
              if (saleId != null && !backendIds.contains(saleId)) {
                report.addIssue('Sale missing in backend: $saleId');
                report.missingInBackend.add(saleId);
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Backend sales check failed: $e');
        report.backendCheckFailed = true;
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Sales integrity check error: $e');
    }
  }
  
  /// Check products integrity
  Future<void> _checkProductsIntegrity(IntegrityReport report) async {
    try {
      final localProducts = await LocalStorageService.loadBackendProducts();
      final token = await SecureTokenStorage.getToken();
      
      if (token == null || token.isEmpty) {
        if (kDebugMode) debugPrint('🔒 No token for products integrity check');
        return;
      }
      
      // Fetch backend products
      try {
        final response = await ApiClient.getJson('/api/products');
        if (response.statusCode == 200) {
          final backendProducts = json.decode(response.body);
          
          if (backendProducts is List) {
            // Compare counts
            if (localProducts.length != backendProducts.length) {
              report.productIssues += (localProducts.length - backendProducts.length).abs();
              report.addIssue('Products count mismatch: local=${localProducts.length}, backend=${backendProducts.length}');
            }
            
            // Check for missing products in backend
            final backendIds = (backendProducts as List).map((p) => p['id'].toString()).toSet();
            for (final product in localProducts) {
              final productId = product['id'].toString();
              if (!backendIds.contains(productId)) {
                report.addIssue('Product missing in backend: $productId');
                report.missingInBackend.add(productId);
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Backend products check failed: $e');
        report.backendCheckFailed = true;
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Products integrity check error: $e');
    }
  }
  
  /// Check customers integrity
  Future<void> _checkCustomersIntegrity(IntegrityReport report) async {
    try {
      final localCustomers = await LocalStorageService.loadLocalCustomers();
      final token = await SecureTokenStorage.getToken();
      
      if (token == null || token.isEmpty) {
        if (kDebugMode) debugPrint('🔒 No token for customers integrity check');
        return;
      }
      
      // Fetch backend customers
      try {
        final response = await ApiClient.getJson(ApiClient.customersPrefix);
        if (response.statusCode == 200) {
          final backendCustomers = json.decode(response.body);
          
          if (backendCustomers is List) {
            // Compare counts
            if (localCustomers.length != backendCustomers.length) {
              report.customerIssues += (localCustomers.length - backendCustomers.length).abs();
              report.addIssue('Customers count mismatch: local=${localCustomers.length}, backend=${backendCustomers.length}');
            }
            
            // Check for missing customers in backend
            final backendIds = (backendCustomers as List).map((c) => c['id'].toString()).toSet();
            for (final customer in localCustomers) {
              final customerId = customer['id'].toString();
              if (!backendIds.contains(customerId)) {
                report.addIssue('Customer missing in backend: $customerId');
                report.missingInBackend.add(customerId);
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Backend customers check failed: $e');
        report.backendCheckFailed = true;
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Customers integrity check error: $e');
    }
  }
  
  /// Check sync queue integrity
  Future<void> _checkSyncQueueIntegrity(IntegrityReport report) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString('offline_sync_queue') ?? '[]';
      final List<dynamic> queue = json.decode(queueJson);
      
      // Check for corrupted entries
      int corruptedCount = 0;
      for (int i = queue.length - 1; i >= 0; i--) {
        final item = queue[i];
        if (!_isValidQueueItem(item)) {
          queue.removeAt(i);
          corruptedCount++;
        }
      }
      
      if (corruptedCount > 0) {
        await prefs.setString('offline_sync_queue', json.encode(queue));
        report.addIssue('Removed $corruptedCount corrupted sync queue items');
        report.syncQueueIssues = corruptedCount;
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Sync queue integrity check error: $e');
    }
  }
  
  /// Resolve integrity issues
  Future<bool> resolveIntegrityIssues(IntegrityReport report) async {
    try {
      if (kDebugMode) debugPrint('🔧 Resolving integrity issues');
      
      // Sync missing items to backend
      if (report.missingInBackend.isNotEmpty) {
        await _syncMissingItems(report.missingInBackend);
      }
      
      // Clear stored issues
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_integrityIssuesKey);
      
      if (kDebugMode) debugPrint('✅ Integrity issues resolved');
      return true;
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error resolving integrity issues: $e');
      return false;
    }
  }
  
  /// Sync missing items to backend
  Future<void> _syncMissingItems(List<String> missingIds) async {
    try {
      final token = await SecureTokenStorage.getToken();
      if (token == null || token.isEmpty) return;
      
      if (kDebugMode) debugPrint('🔄 Syncing ${missingIds.length} missing items to backend');
      
      // This would be implemented based on the specific types of missing items
      // For now, we'll add them to the sync queue
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString('offline_sync_queue') ?? '[]';
      final List<dynamic> queue = json.decode(queueJson);
      
      for (final id in missingIds) {
        queue.add({
          'action': 'sync_missing',
          'data': {'id': id},
          'synced': false,
        });
      }
      
      await prefs.setString('offline_sync_queue', json.encode(queue));
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error syncing missing items: $e');
    }
  }
  
  /// Store integrity issues
  Future<void> _storeIntegrityIssues(IntegrityReport report) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_integrityIssuesKey, json.encode(report.toJson()));
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error storing integrity issues: $e');
    }
  }
  
  /// Get stored integrity issues
  Future<IntegrityReport?> getStoredIntegrityIssues() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final issuesJson = prefs.getString(_integrityIssuesKey);
      
      if (issuesJson != null) {
        final data = json.decode(issuesJson);
        return IntegrityReport.fromJson(data);
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting stored integrity issues: $e');
      return null;
    }
  }
  
  /// Validation helper
  bool _isValidQueueItem(dynamic item) {
    return item is Map && 
           item.containsKey('action') && 
           item.containsKey('data');
  }
}

/// Integrity report
class IntegrityReport {
  int salesIssues = 0;
  int productIssues = 0;
  int customerIssues = 0;
  int syncQueueIssues = 0;
  bool backendCheckFailed = false;
  bool checkSkipped = false;
  String? checkError;
  final List<String> issues = [];
  final List<String> missingInBackend = [];
  
  bool get hasIssues => totalIssues > 0;
  int get totalIssues => salesIssues + productIssues + customerIssues + syncQueueIssues;
  
  void addIssue(String issue) {
    issues.add(issue);
  }
  
  Map<String, dynamic> toJson() {
    return {
      'sales_issues': salesIssues,
      'product_issues': productIssues,
      'customer_issues': customerIssues,
      'sync_queue_issues': syncQueueIssues,
      'backend_check_failed': backendCheckFailed,
      'check_skipped': checkSkipped,
      'check_error': checkError,
      'issues': issues,
      'missing_in_backend': missingInBackend,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  static IntegrityReport fromJson(Map<String, dynamic> json) {
    final report = IntegrityReport();
    report.salesIssues = json['sales_issues'] ?? 0;
    report.productIssues = json['product_issues'] ?? 0;
    report.customerIssues = json['customer_issues'] ?? 0;
    report.syncQueueIssues = json['sync_queue_issues'] ?? 0;
    report.backendCheckFailed = json['backend_check_failed'] ?? false;
    report.checkSkipped = json['check_skipped'] ?? false;
    report.checkError = json['check_error'];
    report.issues.addAll(List<String>.from(json['issues'] ?? []));
    report.missingInBackend.addAll(List<String>.from(json['missing_in_backend'] ?? []));
    return report;
  }
}
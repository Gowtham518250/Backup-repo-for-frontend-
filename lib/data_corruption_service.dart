import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_storage_service.dart';

/// Data Corruption Detection and Repair Service
/// Detects data corruption and attempts automatic repair
/// Provides data validation and recovery mechanisms
class DataCorruptionService {
  static DataCorruptionService? _instance;
  static const String _corruptionLogKey = 'corruption_log';
  static const String _lastCheckKey = 'last_corruption_check';
  
  DataCorruptionService._();
  
  static DataCorruptionService get instance {
    _instance ??= DataCorruptionService._();
    return _instance!;
  }
  
  /// Perform comprehensive corruption check
  Future<CorruptionReport> checkForCorruption({bool forceFullCheck = false}) async {
    final report = CorruptionReport();
    
    try {
      if (kDebugMode) debugPrint('🔍 Starting data corruption check');
      
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getString(_lastCheckKey);
      
      // Skip full check if done recently (unless forced)
      if (!forceFullCheck && lastCheck != null) {
        final lastCheckTime = DateTime.parse(lastCheck);
        final hoursSinceCheck = DateTime.now().difference(lastCheckTime).inHours;
        
        if (hoursSinceCheck < 12) {
          if (kDebugMode) debugPrint('⏭️ Skipping full corruption check (last check $hoursSinceCheck hours ago)');
          report.checkSkipped = true;
          return report;
        }
      }
      
      // Check each data type for corruption
      await _checkSalesCorruption(report);
      await _checkProductsCorruption(report);
      await _checkCustomersCorruption(report);
      await _checkInvoicesCorruption(report);
      await _checkStorageConsistency(report);
      
      // Update last check time
      await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());
      
      // Log any corruption found
      if (report.hasCorruption) {
        await _logCorruption(report);
      }
      
      if (kDebugMode) {
        debugPrint('📊 Corruption check completed:');
        debugPrint('   Corruption found: ${report.hasCorruption}');
        debugPrint('   Corrupted records: ${report.totalCorruptedRecords}');
        debugPrint('   Repaired records: ${report.repairedRecords}');
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Corruption check error: $e');
      report.checkError = e.toString();
    }
    
    return report;
  }
  
  /// Check sales data for corruption
  Future<void> _checkSalesCorruption(CorruptionReport report) async {
    try {
      final sales = await LocalStorageService.loadSales();
      int corruptedCount = 0;
      int repairedCount = 0;
      
      for (int i = sales.length - 1; i >= 0; i--) {
        final sale = sales[i];
        
        if (!_isValidSaleRecord(sale)) {
          corruptedCount++;
          
          // Attempt repair
          if (_attemptSaleRepair(sale)) {
            repairedCount++;
            if (kDebugMode) debugPrint('🔧 Repaired corrupted sale record');
          } else {
            // Remove if unrepairable
            sales.removeAt(i);
            report.addCorruptedRecord('sale', sale['sale_id']?.toString() ?? 'unknown');
          }
        }
      }
      
      if (corruptedCount > 0) {
        await LocalStorageService.saveSales(sales);
        report.salesCorrupted = corruptedCount;
        report.salesRepaired = repairedCount;
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Sales corruption check error: $e');
    }
  }
  
  /// Check products data for corruption
  Future<void> _checkProductsCorruption(CorruptionReport report) async {
    try {
      final products = await LocalStorageService.loadBackendProducts();
      int corruptedCount = 0;
      int repairedCount = 0;
      
      for (int i = products.length - 1; i >= 0; i--) {
        final product = products[i];
        
        if (!_isValidProductRecord(product)) {
          corruptedCount++;
          
          // Attempt repair
          if (_attemptProductRepair(product)) {
            repairedCount++;
            if (kDebugMode) debugPrint('🔧 Repaired corrupted product record');
          } else {
            // Remove if unrepairable
            products.removeAt(i);
            report.addCorruptedRecord('product', product['id']?.toString() ?? 'unknown');
          }
        }
      }
      
      if (corruptedCount > 0) {
        await LocalStorageService.saveBackendProducts(products);
        report.productsCorrupted = corruptedCount;
        report.productsRepaired = repairedCount;
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Products corruption check error: $e');
    }
  }
  
  /// Check customers data for corruption
  Future<void> _checkCustomersCorruption(CorruptionReport report) async {
    try {
      final customers = await LocalStorageService.loadLocalCustomers();
      int corruptedCount = 0;
      int repairedCount = 0;
      
      for (int i = customers.length - 1; i >= 0; i--) {
        final customer = customers[i];
        
        if (!_isValidCustomerRecord(customer)) {
          corruptedCount++;
          
          // Attempt repair
          if (_attemptCustomerRepair(customer)) {
            repairedCount++;
            if (kDebugMode) debugPrint('🔧 Repaired corrupted customer record');
          } else {
            // Remove if unrepairable
            customers.removeAt(i);
            report.addCorruptedRecord('customer', customer['phone']?.toString() ?? 'unknown');
          }
        }
      }
      
      if (corruptedCount > 0) {
        await LocalStorageService.saveLocalCustomers(customers);
        report.customersCorrupted = corruptedCount;
        report.customersRepaired = repairedCount;
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Customers corruption check error: $e');
    }
  }
  
  /// Check invoices data for corruption
  Future<void> _checkInvoicesCorruption(CorruptionReport report) async {
    try {
      final invoices = await LocalStorageService.loadLocalInvoices();
      int corruptedCount = 0;
      int repairedCount = 0;
      
      for (int i = invoices.length - 1; i >= 0; i--) {
        final invoice = invoices[i];
        
        if (!_isValidInvoiceRecord(invoice)) {
          corruptedCount++;
          
          // Attempt repair
          if (_attemptInvoiceRepair(invoice)) {
            repairedCount++;
            if (kDebugMode) debugPrint('🔧 Repaired corrupted invoice record');
          } else {
            // Remove if unrepairable
            invoices.removeAt(i);
            report.addCorruptedRecord('invoice', invoice['invoice_number']?.toString() ?? 'unknown');
          }
        }
      }
      
      if (corruptedCount > 0) {
        await LocalStorageService.saveLocalInvoices(invoices);
        report.invoicesCorrupted = corruptedCount;
        report.invoicesRepaired = repairedCount;
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Invoices corruption check error: $e');
    }
  }
  
  /// Check storage consistency
  Future<void> _checkStorageConsistency(CorruptionReport report) async {
    try {
      // Check for orphaned records
      await _checkOrphanedSales(report);
      await _checkOrphanedInvoices(report);
      
      // Check for data type inconsistencies
      await _checkDataTypeConsistency(report);
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Storage consistency check error: $e');
    }
  }
  
  /// Check for orphaned sales (sales without corresponding invoices if needed)
  Future<void> _checkOrphanedSales(CorruptionReport report) async {
    try {
      final sales = await LocalStorageService.loadSales();
      final invoices = await LocalStorageService.loadLocalInvoices();
      
      // Check if sales have corresponding invoices for credit sales
      final invoiceSaleIds = invoices
          .where((inv) => inv['sale_id'] != null)
          .map((inv) => inv['sale_id'] as String)
          .toSet();
      
      int orphanedCount = 0;
      for (final sale in sales) {
        final isCreditSale = sale['payment_method'] == 'credit' || 
                            sale['payment_status'] == 'pending';
        
        if (isCreditSale && !invoiceSaleIds.contains(sale['sale_id'])) {
          // This is a credit sale without invoice - could be intentional or corruption
          // Log it for review
          report.addInconsistency('Credit sale without invoice: ${sale['sale_id']}');
          orphanedCount++;
        }
      }
      
      if (orphanedCount > 0) {
        report.inconsistenciesFound += orphanedCount;
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Orphaned sales check error: $e');
    }
  }
  
  /// Check for orphaned invoices
  Future<void> _checkOrphanedInvoices(CorruptionReport report) async {
    try {
      final invoices = await LocalStorageService.loadLocalInvoices();
      final sales = await LocalStorageService.loadSales();
      
      final saleIds = sales.map((s) => s['sale_id'] as String).toSet();
      
      int orphanedCount = 0;
      for (final invoice in invoices) {
        if (invoice['sale_id'] != null && !saleIds.contains(invoice['sale_id'])) {
          // Invoice references non-existent sale
          report.addCorruptedRecord('orphaned_invoice', invoice['invoice_number']?.toString() ?? 'unknown');
          orphanedCount++;
        }
      }
      
      if (orphanedCount > 0) {
        report.invoicesCorrupted += orphanedCount;
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Orphaned invoices check error: $e');
    }
  }
  
  /// Check data type consistency
  Future<void> _checkDataTypeConsistency(CorruptionReport report) async {
    try {
      final sales = await LocalStorageService.loadSales();
      
      int typeErrors = 0;
      for (final sale in sales) {
        // Check critical fields have correct data types
        if (sale['total_amount'] is! num) {
          typeErrors++;
          report.addInconsistency('Sale ${sale['sale_id']}: total_amount is not a number');
        }
        
        if (sale['items'] is! List) {
          typeErrors++;
          report.addInconsistency('Sale ${sale['sale_id']}: items is not a list');
        }
      }
      
      if (typeErrors > 0) {
        report.dataTypeErrors = typeErrors;
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Data type consistency check error: $e');
    }
  }
  
  /// Repair corrupted data
  Future<bool> repairCorruption(CorruptionReport report) async {
    try {
      if (kDebugMode) debugPrint('🔧 Starting corruption repair');
      
      int totalRepaired = 0;
      
      // Re-run checks with repair enabled
      await _checkSalesCorruption(report);
      await _checkProductsCorruption(report);
      await _checkCustomersCorruption(report);
      await _checkInvoicesCorruption(report);
      
      totalRepaired = report.salesRepaired + report.productsRepaired + 
                      report.customersRepaired + report.invoicesRepaired;
      
      if (kDebugMode) debugPrint('✅ Corruption repair completed: $totalRepaired records repaired');
      return true;
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Corruption repair error: $e');
      return false;
    }
  }
  
  /// Log corruption for analysis
  Future<void> _logCorruption(CorruptionReport report) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logJson = prefs.getString(_corruptionLogKey) ?? '[]';
      final List<dynamic> log = json.decode(logJson);
      
      log.add({
        'timestamp': DateTime.now().toIso8601String(),
        'total_corrupted': report.totalCorruptedRecords,
        'total_repaired': report.repairedRecords,
        'corrupted_records': report.corruptedRecords,
        'inconsistencies': report.inconsistencies,
      });
      
      // Keep only last 50 log entries
      if (log.length > 50) {
        log.removeAt(0);
      }
      
      await prefs.setString(_corruptionLogKey, json.encode(log));
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error logging corruption: $e');
    }
  }
  
  /// Get corruption log
  Future<List<Map<String, dynamic>>> getCorruptionLog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logJson = prefs.getString(_corruptionLogKey) ?? '[]';
      return List<Map<String, dynamic>>.from(json.decode(logJson));
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting corruption log: $e');
      return [];
    }
  }
  
  /// Validation and repair helpers
  bool _isValidSaleRecord(dynamic sale) {
    return sale is Map && 
           sale.containsKey('sale_id') && 
           sale.containsKey('total_amount') &&
           sale.containsKey('items') &&
           sale['total_amount'] is num &&
           sale['items'] is List;
  }
  
  bool _attemptSaleRepair(Map<String, dynamic> sale) {
    try {
      // Attempt to fix common issues
      if (sale['total_amount'] is String) {
        sale['total_amount'] = double.tryParse(sale['total_amount']) ?? 0.0;
      }
      
      if (sale['items'] is! List && sale['items'] != null) {
        // Try to convert items to list
        if (sale['items'] is String) {
          sale['items'] = json.decode(sale['items']);
        } else {
          sale['items'] = [];
        }
      }
      
      // Re-validate after repair attempts
      return _isValidSaleRecord(sale);
    } catch (e) {
      return false;
    }
  }
  
  bool _isValidProductRecord(dynamic product) {
    return product is Map && 
           product.containsKey('id') && 
           product.containsKey('name') &&
           product.containsKey('price') &&
           product['price'] is num;
  }
  
  bool _attemptProductRepair(Map<String, dynamic> product) {
    try {
      if (product['price'] is String) {
        product['price'] = double.tryParse(product['price']) ?? 0.0;
      }
      
      return _isValidProductRecord(product);
    } catch (e) {
      return false;
    }
  }
  
  bool _isValidCustomerRecord(dynamic customer) {
    return customer is Map && 
           customer.containsKey('phone') && 
           customer.containsKey('name');
  }
  
  bool _attemptCustomerRepair(Map<String, dynamic> customer) {
    try {
      if (customer['phone'] == null || customer['phone'].toString().isEmpty) {
        return false; // Can't repair missing phone
      }
      
      if (customer['name'] == null || customer['name'].toString().isEmpty) {
        customer['name'] = 'Customer'; // Default name
      }
      
      return _isValidCustomerRecord(customer);
    } catch (e) {
      return false;
    }
  }
  
  bool _isValidInvoiceRecord(dynamic invoice) {
    return invoice is Map && 
           invoice.containsKey('invoice_number') && 
           invoice.containsKey('total_amount') &&
           invoice['total_amount'] is num;
  }
  
  bool _attemptInvoiceRepair(Map<String, dynamic> invoice) {
    try {
      if (invoice['total_amount'] is String) {
        invoice['total_amount'] = double.tryParse(invoice['total_amount']) ?? 0.0;
      }
      
      return _isValidInvoiceRecord(invoice);
    } catch (e) {
      return false;
    }
  }
}

/// Corruption report
class CorruptionReport {
  int salesCorrupted = 0;
  int productsCorrupted = 0;
  int customersCorrupted = 0;
  int invoicesCorrupted = 0;
  int salesRepaired = 0;
  int productsRepaired = 0;
  int customersRepaired = 0;
  int invoicesRepaired = 0;
  int inconsistenciesFound = 0;
  int dataTypeErrors = 0;
  bool checkSkipped = false;
  String? checkError;
  
  final List<Map<String, String>> corruptedRecords = [];
  final List<String> inconsistencies = [];
  
  bool get hasCorruption => totalCorruptedRecords > 0;
  int get totalCorruptedRecords => salesCorrupted + productsCorrupted + customersCorrupted + invoicesCorrupted;
  int get repairedRecords => salesRepaired + productsRepaired + customersRepaired + invoicesRepaired;
  
  void addCorruptedRecord(String type, String id) {
    corruptedRecords.add({'type': type, 'id': id});
  }
  
  void addInconsistency(String description) {
    inconsistencies.add(description);
  }
}
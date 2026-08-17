import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'local_storage_service.dart';

/// Data Validation Service
/// Validates data integrity before display and sync
/// Ensures users see correct data and prevents corruption
class DataValidationService {
  static DataValidationService? _instance;
  
  DataValidationService._();
  
  static DataValidationService get instance {
    _instance ??= DataValidationService._();
    return _instance!;
  }
  
  /// Validate sales data before display
  Future<ValidationResult> validateSalesData(List<dynamic> sales) async {
    if (sales.isEmpty) {
      return ValidationResult(isValid: true, message: 'No sales data to validate');
    }
    
    int invalidCount = 0;
    List<String> issues = [];
    
    for (var sale in sales) {
      if (sale is! Map) {
        invalidCount++;
        issues.add('Invalid sale format: not a Map');
        continue;
      }
      
      // Check required fields
      if (sale['id'] == null || sale['id'].toString().isEmpty) {
        invalidCount++;
        issues.add('Sale missing ID');
      }
      
      if (sale['total'] == null) {
        invalidCount++;
        issues.add('Sale missing total amount');
      } else {
        // Validate total is a valid number
        final total = double.tryParse(sale['total'].toString());
        if (total == null || total < 0) {
          invalidCount++;
          issues.add('Sale has invalid total amount: ${sale['total']}');
        }
      }
      
      // Validate date format
      if (sale['created_at'] != null) {
        try {
          DateTime.parse(sale['created_at'].toString());
        } catch (e) {
          invalidCount++;
          issues.add('Sale has invalid date format: ${sale['created_at']}');
        }
      }
    }
    
    final isValid = invalidCount == 0;
    final message = isValid 
      ? 'All ${sales.length} sales records are valid'
      : '$invalidCount of ${sales.length} sales records have issues: ${issues.take(3).join(", ")}${issues.length > 3 ? "..." : ""}';
    
    return ValidationResult(
      isValid: isValid,
      message: message,
      issueCount: invalidCount,
      issues: issues,
    );
  }
  
  /// Validate customer data before display
  Future<ValidationResult> validateCustomerData(List<dynamic> customers) async {
    if (customers.isEmpty) {
      return ValidationResult(isValid: true, message: 'No customer data to validate');
    }
    
    int invalidCount = 0;
    List<String> issues = [];
    
    for (var customer in customers) {
      if (customer is! Map) {
        invalidCount++;
        issues.add('Invalid customer format: not a Map');
        continue;
      }
      
      // Check required fields
      if (customer['id'] == null || customer['id'].toString().isEmpty) {
        invalidCount++;
        issues.add('Customer missing ID');
      }
      
      // Validate phone number format
      if (customer['phone'] != null) {
        final phone = customer['phone'].toString();
        if (phone.isNotEmpty && !RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
          invalidCount++;
          issues.add('Customer has invalid phone: $phone');
        }
      }
      
      // Validate balance
      if (customer['balance'] != null) {
        final balance = double.tryParse(customer['balance'].toString());
        if (balance == null) {
          invalidCount++;
          issues.add('Customer has invalid balance: ${customer['balance']}');
        }
      }
    }
    
    final isValid = invalidCount == 0;
    final message = isValid 
      ? 'All ${customers.length} customer records are valid'
      : '$invalidCount of ${customers.length} customer records have issues: ${issues.take(3).join(", ")}${issues.length > 3 ? "..." : ""}';
    
    return ValidationResult(
      isValid: isValid,
      message: message,
      issueCount: invalidCount,
      issues: issues,
    );
  }
  
  /// Validate inventory data before display
  Future<ValidationResult> validateInventoryData(List<dynamic> products) async {
    if (products.isEmpty) {
      return ValidationResult(isValid: true, message: 'No inventory data to validate');
    }
    
    int invalidCount = 0;
    List<String> issues = [];
    
    for (var product in products) {
      if (product is! Map) {
        invalidCount++;
        issues.add('Invalid product format: not a Map');
        continue;
      }
      
      // Check required fields
      if (product['id'] == null || product['id'].toString().isEmpty) {
        invalidCount++;
        issues.add('Product missing ID');
      }
      
      if (product['product_name'] == null || product['product_name'].toString().isEmpty) {
        invalidCount++;
        issues.add('Product missing name');
      }
      
      // Validate stock (should not be negative)
      if (product['current_stock'] != null) {
        final stock = int.tryParse(product['current_stock'].toString());
        if (stock == null) {
          invalidCount++;
          issues.add('Product has invalid stock: ${product['current_stock']}');
        } else if (stock < 0) {
          invalidCount++;
          issues.add('Product has negative stock: $stock');
        }
      }
      
      // Validate price
      if (product['unit_price'] != null) {
        final price = double.tryParse(product['unit_price'].toString());
        if (price == null || price < 0) {
          invalidCount++;
          issues.add('Product has invalid price: ${product['unit_price']}');
        }
      }
    }
    
    final isValid = invalidCount == 0;
    final message = isValid 
      ? 'All ${products.length} product records are valid'
      : '$invalidCount of ${products.length} product records have issues: ${issues.take(3).join(", ")}${issues.length > 3 ? "..." : ""}';
    
    return ValidationResult(
      isValid: isValid,
      message: message,
      issueCount: invalidCount,
      issues: issues,
    );
  }
  
  /// Validate single sale record before saving
  ValidationResult validateSingleSale(Map<String, dynamic> sale) {
    List<String> issues = [];
    
    // Check required fields
    if (sale['id'] == null || sale['id'].toString().isEmpty) {
      issues.add('Missing sale ID');
    }
    
    if (sale['total'] == null) {
      issues.add('Missing total amount');
    } else {
      final total = double.tryParse(sale['total'].toString());
      if (total == null || total < 0) {
        issues.add('Invalid total amount: ${sale['total']}');
      }
    }
    
    // Validate items array
    if (sale['items'] == null) {
      issues.add('Missing items array');
    } else if (sale['items'] is! List) {
      issues.add('Items is not an array');
    } else if ((sale['items'] as List).isEmpty) {
      issues.add('Items array is empty');
    }
    
    return ValidationResult(
      isValid: issues.isEmpty,
      message: issues.isEmpty ? 'Sale record is valid' : 'Sale has issues: ${issues.join(", ")}',
      issues: issues,
      issueCount: issues.length,
    );
  }
  
  /// Clean and sanitize data before display
  Map<String, dynamic> cleanSaleData(Map<String, dynamic> sale) {
    final cleaned = Map<String, dynamic>.from(sale);
    
    // Ensure numeric fields are proper types
    if (cleaned['total'] != null) {
      cleaned['total'] = double.tryParse(cleaned['total'].toString()) ?? 0.0;
    }
    
    if (cleaned['subtotal'] != null) {
      cleaned['subtotal'] = double.tryParse(cleaned['subtotal'].toString()) ?? 0.0;
    }
    
    if (cleaned['tax'] != null) {
      cleaned['tax'] = double.tryParse(cleaned['tax'].toString()) ?? 0.0;
    }
    
    // Ensure date fields are proper format
    if (cleaned['created_at'] != null) {
      try {
        DateTime.parse(cleaned['created_at'].toString());
      } catch (e) {
        cleaned['created_at'] = DateTime.now().toIso8601String();
      }
    }
    
    // Remove null values that shouldn't be null
    cleaned['items'] = cleaned['items'] ?? [];
    cleaned['customer_name'] = cleaned['customer_name'] ?? 'Unknown Customer';
    cleaned['customer_phone'] = cleaned['customer_phone'] ?? '';
    
    return cleaned;
  }
  
  /// Perform quick data integrity check
  Future<DataIntegritySummary> performQuickIntegrityCheck() async {
    try {
      if (kDebugMode) debugPrint('🔍 Performing quick data integrity check');
      
      // Load data from local storage
      final sales = await LocalStorageService.loadSales();
      final customers = await LocalStorageService.loadLocalCustomers();
      final products = await LocalStorageService.loadBackendProducts();
      
      // Validate each dataset
      final salesValidation = await validateSalesData(sales);
      final customersValidation = await validateCustomerData(customers);
      final productsValidation = await validateInventoryData(products);
      
      final summary = DataIntegritySummary(
        salesValid: salesValidation.isValid,
        salesIssues: salesValidation.issueCount,
        customersValid: customersValidation.isValid,
        customersIssues: customersValidation.issueCount,
        productsValid: productsValidation.isValid,
        productsIssues: productsValidation.issueCount,
        overallValid: salesValidation.isValid && customersValidation.isValid && productsValidation.isValid,
        timestamp: DateTime.now(),
      );
      
      if (kDebugMode) {
        debugPrint('📊 Data Integrity Summary:');
        debugPrint('  Sales: ${salesValidation.isValid ? "✅ Valid" : "❌ ${salesValidation.issueCount} issues"}');
        debugPrint('  Customers: ${customersValidation.isValid ? "✅ Valid" : "❌ ${customersValidation.issueCount} issues"}');
        debugPrint('  Products: ${productsValidation.isValid ? "✅ Valid" : "❌ ${productsValidation.issueCount} issues"}');
        debugPrint('  Overall: ${summary.overallValid ? "✅ Valid" : "❌ Issues detected"}');
      }
      
      return summary;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Quick integrity check failed: $e');
      return DataIntegritySummary(
        salesValid: false,
        salesIssues: -1,
        customersValid: false,
        customersIssues: -1,
        productsValid: false,
        productsIssues: -1,
        overallValid: false,
        timestamp: DateTime.now(),
        errorMessage: e.toString(),
      );
    }
  }
}

/// Validation result
class ValidationResult {
  final bool isValid;
  final String message;
  final int issueCount;
  final List<String> issues;
  
  ValidationResult({
    required this.isValid,
    required this.message,
    this.issueCount = 0,
    this.issues = const [],
  });
  
  @override
  String toString() {
    return 'ValidationResult(isValid: $isValid, message: $message, issues: $issueCount)';
  }
}

/// Data integrity summary
class DataIntegritySummary {
  final bool salesValid;
  final int salesIssues;
  final bool customersValid;
  final int customersIssues;
  final bool productsValid;
  final int productsIssues;
  final bool overallValid;
  final DateTime timestamp;
  final String? errorMessage;
  
  DataIntegritySummary({
    required this.salesValid,
    required this.salesIssues,
    required this.customersValid,
    required this.customersIssues,
    required this.productsValid,
    required this.productsIssues,
    required this.overallValid,
    required this.timestamp,
    this.errorMessage,
  });
  
  bool hasCriticalIssues() {
    return !overallValid || (salesIssues > 10 || customersIssues > 5 || productsIssues > 10);
  }
  
  @override
  String toString() {
    return 'DataIntegritySummary(overallValid: $overallValid, salesIssues: $salesIssues, customersIssues: $customersIssues, productsIssues: $productsIssues)';
  }
}
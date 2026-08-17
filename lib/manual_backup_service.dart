import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'local_storage_service.dart';
import 'automatic_backup_service.dart';

/// Manual Backup Service
/// Provides manual backup and restore functionality for users
/// Allows users to create backups before major changes and restore when needed
class ManualBackupService {
  static ManualBackupService? _instance;
  
  ManualBackupService._();
  
  static ManualBackupService get instance {
    _instance ??= ManualBackupService._();
    return _instance!;
  }
  
  /// Create manual backup
  Future<BackupResult> createManualBackup({String? customName}) async {
    final result = BackupResult();
    
    try {
      if (kDebugMode) debugPrint('🔄 Creating manual backup');
      
      // Create backup data
      final backupData = await _createComprehensiveBackup();
      
      // Add manual backup metadata
      backupData['backup_type'] = 'manual';
      backupData['backup_name'] = customName ?? 'Manual Backup';
      backupData['created_by'] = 'user';
      
      // Save to file
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = customName != null 
          ? '${customName.replaceAll(' ', '_')}_$timestamp.json'
          : 'manual_backup_$timestamp.json';
      
      final file = await _saveBackupFile(fileName, backupData);
      
      result.success = true;
      result.filePath = file.path;
      result.fileSize = await file.length();
      result.backupName = customName ?? 'Manual Backup';
      
      if (kDebugMode) debugPrint('✅ Manual backup created: ${file.path}');
      
    } catch (e) {
      result.success = false;
      result.error = e.toString();
      if (kDebugMode) debugPrint('❌ Manual backup creation failed: $e');
    }
    
    return result;
  }
  
  /// Create comprehensive backup data
  Future<Map<String, dynamic>> _createComprehensiveBackup() async {
    final backupData = <String, dynamic>{};
    
    try {
      // Backup all critical data
      final sales = await LocalStorageService.loadSales();
      backupData['sales'] = sales;
      
      final products = await LocalStorageService.loadBackendProducts();
      backupData['products'] = products;
      
      final localProducts = await LocalStorageService.loadLocalProducts();
      backupData['local_products'] = localProducts;
      
      final customers = await LocalStorageService.loadLocalCustomers();
      backupData['customers'] = customers;
      
      final invoices = await LocalStorageService.loadLocalInvoices();
      backupData['invoices'] = invoices;
      
      // Backup settings and preferences
      final prefs = await SharedPreferences.getInstance();
      backupData['shop_profile'] = json.decode(prefs.getString('shop_profile_json') ?? '{}');
      backupData['sync_queue'] = json.decode(prefs.getString('offline_sync_queue') ?? '[]');
      
      // Add metadata
      backupData['backup_timestamp'] = DateTime.now().toIso8601String();
      backupData['backup_version'] = '2.0';
      backupData['app_version'] = '2.0';
      
      if (kDebugMode) {
        debugPrint('📦 Comprehensive backup created:');
        debugPrint('   Sales: ${sales.length} records');
        debugPrint('   Products: ${products.length} records');
        debugPrint('   Customers: ${customers.length} records');
        debugPrint('   Invoices: ${invoices.length} records');
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error creating comprehensive backup: $e');
      rethrow;
    }
    
    return backupData;
  }
  
  /// Save backup to file
  Future<File> _saveBackupFile(String fileName, Map<String, dynamic> backupData) async {
    try {
      final directory = await _getManualBackupDirectory();
      final file = File('${directory.path}/$fileName');
      
      final jsonString = json.encode(backupData);
      await file.writeAsString(jsonString);
      
      return file;
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error saving backup file: $e');
      rethrow;
    }
  }
  
  /// Get manual backup directory
  Future<Directory> _getManualBackupDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${directory.path}/manual_backups');
    
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    
    return backupDir;
  }
  
  /// Restore from manual backup
  Future<RestoreResult> restoreFromBackup(String backupPath) async {
    final result = RestoreResult();
    
    try {
      if (kDebugMode) debugPrint('🔄 Restoring from manual backup: $backupPath');
      
      final file = File(backupPath);
      if (!await file.exists()) {
        throw Exception('Backup file not found');
      }
      
      final jsonString = await file.readAsString();
      final backupData = json.decode(jsonString);
      
      if (backupData is! Map) {
        throw Exception('Invalid backup format');
      }
      
      // Create automatic backup before restore
      if (kDebugMode) debugPrint('💾 Creating pre-restore backup');
      await AutomaticBackupService.instance.forceBackup();
      
      // Restore all data
      int restoredCount = 0;
      
      if (backupData.containsKey('sales')) {
        await LocalStorageService.saveSales(backupData['sales']);
        restoredCount += (backupData['sales'] as List).length;
        if (kDebugMode) debugPrint('✅ Restored ${backupData['sales'].length} sales');
      }
      
      if (backupData.containsKey('products')) {
        await LocalStorageService.saveBackendProducts(backupData['products']);
        restoredCount += (backupData['products'] as List).length;
        if (kDebugMode) debugPrint('✅ Restored ${backupData['products'].length} products');
      }
      
      if (backupData.containsKey('local_products')) {
        await LocalStorageService.saveLocalProducts(backupData['local_products']);
        if (kDebugMode) debugPrint('✅ Restored local products');
      }
      
      if (backupData.containsKey('customers')) {
        await LocalStorageService.saveLocalCustomers(backupData['customers']);
        restoredCount += (backupData['customers'] as List).length;
        if (kDebugMode) debugPrint('✅ Restored ${backupData['customers'].length} customers');
      }
      
      if (backupData.containsKey('invoices')) {
        await LocalStorageService.saveLocalInvoices(backupData['invoices']);
        restoredCount += (backupData['invoices'] as List).length;
        if (kDebugMode) debugPrint('✅ Restored ${backupData['invoices'].length} invoices');
      }
      
      if (backupData.containsKey('shop_profile')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('shop_profile_json', json.encode(backupData['shop_profile']));
        if (kDebugMode) debugPrint('✅ Restored shop profile');
      }
      
      if (backupData.containsKey('sync_queue')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('offline_sync_queue', json.encode(backupData['sync_queue']));
        if (kDebugMode) debugPrint('✅ Restored sync queue');
      }
      
      result.success = true;
      result.restoredRecords = restoredCount;
      result.backupTimestamp = backupData['backup_timestamp'];
      
      if (kDebugMode) debugPrint('✅ Manual backup restore completed');
      
    } catch (e) {
      result.success = false;
      result.error = e.toString();
      if (kDebugMode) debugPrint('❌ Manual backup restore failed: $e');
    }
    
    return result;
  }
  
  /// Share backup file
  Future<bool> shareBackup(String backupPath) async {
    try {
      final file = File(backupPath);
      if (!await file.exists()) {
        throw Exception('Backup file not found');
      }
      
      await Share.shareXFiles([XFile(backupPath)], text: 'Retail Mind Backup');
      
      if (kDebugMode) debugPrint('✅ Backup file shared');
      return true;
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error sharing backup: $e');
      return false;
    }
  }
  
  /// List all manual backups
  Future<List<ManualBackupInfo>> listManualBackups() async {
    final backups = <ManualBackupInfo>[];
    
    try {
      final directory = await _getManualBackupDirectory();
      final files = directory.listSync()
          .where((entity) => entity is File && entity.path.endsWith('.json'))
          .cast<File>()
          .toList();
      
      for (final file in files) {
        try {
          final jsonString = await file.readAsString();
          final data = json.decode(jsonString);
          
          if (data is Map && data.containsKey('backup_timestamp')) {
            final timestamp = DateTime.parse(data['backup_timestamp'] as String);
            final size = await file.length();
            final backupName = data['backup_name'] ?? 'Manual Backup';
            
            backups.add(ManualBackupInfo(
              fileName: file.path.split('/').last,
              backupName: backupName,
              timestamp: timestamp,
              size: size,
              path: file.path,
              salesCount: (data['sales'] as List?)?.length ?? 0,
              productsCount: (data['products'] as List?)?.length ?? 0,
              customersCount: (data['customers'] as List?)?.length ?? 0,
            ));
          }
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Error reading backup file ${file.path}: $e');
        }
      }
      
      // Sort by timestamp (newest first)
      backups.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error listing manual backups: $e');
    }
    
    return backups;
  }
  
  /// Delete manual backup
  Future<bool> deleteManualBackup(String backupPath) async {
    try {
      final file = File(backupPath);
      if (await file.exists()) {
        await file.delete();
        if (kDebugMode) debugPrint('🗑️ Deleted manual backup: $backupPath');
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error deleting manual backup: $e');
      return false;
    }
  }
  
  /// Export data for external backup
  Future<String> exportData() async {
    try {
      if (kDebugMode) debugPrint('📤 Exporting data for external backup');
      
      final backupData = await _createComprehensiveBackup();
      final jsonString = json.encode(backupData);
      
      if (kDebugMode) debugPrint('✅ Data exported successfully');
      return jsonString;
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error exporting data: $e');
      rethrow;
    }
  }
  
  /// Import data from external backup
  Future<bool> importData(String jsonString) async {
    try {
      if (kDebugMode) debugPrint('📥 Importing data from external backup');
      
      final backupData = json.decode(jsonString);
      if (backupData is! Map) {
        throw Exception('Invalid backup format');
      }
      
      // Create automatic backup before import
      await AutomaticBackupService.instance.forceBackup();
      
      // Restore data
      if (backupData.containsKey('sales')) {
        await LocalStorageService.saveSales(backupData['sales']);
      }
      
      if (backupData.containsKey('products')) {
        await LocalStorageService.saveBackendProducts(backupData['products']);
      }
      
      if (backupData.containsKey('customers')) {
        await LocalStorageService.saveLocalCustomers(backupData['customers']);
      }
      
      if (kDebugMode) debugPrint('✅ Data imported successfully');
      return true;
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error importing data: $e');
      return false;
    }
  }
}

/// Backup result
class BackupResult {
  bool success = false;
  String? filePath;
  int? fileSize;
  String? backupName;
  String? error;
}

/// Restore result
class RestoreResult {
  bool success = false;
  int restoredRecords = 0;
  String? backupTimestamp;
  String? error;
}

/// Manual backup information
class ManualBackupInfo {
  final String fileName;
  final String backupName;
  final DateTime timestamp;
  final int size;
  final String path;
  final int salesCount;
  final int productsCount;
  final int customersCount;
  
  ManualBackupInfo({
    required this.fileName,
    required this.backupName,
    required this.timestamp,
    required this.size,
    required this.path,
    required this.salesCount,
    required this.productsCount,
    required this.customersCount,
  });
  
  String get formattedTimestamp => DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);
  String get formattedSize => '${(size / 1024).toStringAsFixed(2)} KB';
}
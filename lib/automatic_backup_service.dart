import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'local_storage_service.dart';
import 'secure_token_storage.dart';

/// Automatic Backup Service
/// Performs daily automatic backups of critical data to local storage
/// Provides data recovery capability and additional protection against data loss
class AutomaticBackupService {
  static AutomaticBackupService? _instance;
  Timer? _backupTimer;
  bool _isRunning = false;
  bool _isBackingUp = false;
  
  static const Duration _backupInterval = Duration(hours: 24); // Daily backup
  static const int _maxBackupFiles = 7; // Keep last 7 days of backups
  
  AutomaticBackupService._();
  
  static AutomaticBackupService get instance {
    _instance ??= AutomaticBackupService._();
    return _instance!;
  }
  
  /// Start the automatic backup service
  Future<void> start() async {
    if (_isRunning) {
      if (kDebugMode) debugPrint('🔄 Automatic backup service already running');
      return;
    }
    
    _isRunning = true;
    
    if (kDebugMode) debugPrint('🚀 Starting automatic backup service');
    
    // Perform initial backup
    await _performBackup();
    
    // Start periodic backup
    _backupTimer = Timer.periodic(_backupInterval, (_) async {
      await _performBackup();
    });
  }
  
  /// Stop the automatic backup service
  void stop() {
    if (!_isRunning) return;
    
    _isRunning = false;
    _backupTimer?.cancel();
    _backupTimer = null;
    
    if (kDebugMode) debugPrint('🛑 Automatic backup service stopped');
  }
  
  /// Perform backup operation
  Future<void> _performBackup() async {
    if (_isBackingUp) {
      if (kDebugMode) debugPrint('⏳ Backup already in progress, skipping');
      return;
    }
    
    _isBackingUp = true;
    
    try {
      if (kDebugMode) debugPrint('🔄 Starting automatic backup');
      
      // Check if user is authenticated
      final isAuthenticated = await SecureTokenStorage.isSessionValid();
      if (!isAuthenticated) {
        if (kDebugMode) debugPrint('🔒 User not authenticated, skipping backup');
        return;
      }
      
      // Create backup data
      final backupData = await _createBackupData();
      
      // Save backup to file
      await _saveBackupToFile(backupData);
      
      // Clean up old backups
      await _cleanupOldBackups();
      
      if (kDebugMode) debugPrint('✅ Automatic backup completed');
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Backup error: $e');
    } finally {
      _isBackingUp = false;
    }
  }
  
  /// Create backup data from all critical sources
  Future<Map<String, dynamic>> _createBackupData() async {
    final backupData = <String, dynamic>{};
    
    try {
      // Backup sales data
      final sales = await LocalStorageService.loadSales();
      backupData['sales'] = sales;
      
      // Backup products data
      final products = await LocalStorageService.loadBackendProducts();
      backupData['products'] = products;
      
      // Backup local products
      final localProducts = await LocalStorageService.loadLocalProducts();
      backupData['local_products'] = localProducts;
      
      // Backup customers data
      final customers = await LocalStorageService.loadLocalCustomers();
      backupData['customers'] = customers;
      
      // Backup invoices data
      final invoices = await LocalStorageService.loadLocalInvoices();
      backupData['invoices'] = invoices;
      
      // Backup shop profile
      final prefs = await SharedPreferences.getInstance();
      final shopProfileJson = prefs.getString('shop_profile_json');
      if (shopProfileJson != null) {
        backupData['shop_profile'] = json.decode(shopProfileJson);
      }
      
      // Backup sync queue
      final syncQueueJson = prefs.getString('offline_sync_queue');
      if (syncQueueJson != null) {
        backupData['sync_queue'] = json.decode(syncQueueJson);
      }
      
      // Add metadata
      backupData['backup_timestamp'] = DateTime.now().toIso8601String();
      backupData['backup_version'] = '1.0';
      backupData['app_version'] = '2.0'; // Update with actual app version
      
      if (kDebugMode) {
        debugPrint('📦 Backup data created:');
        debugPrint('   Sales: ${sales.length} records');
        debugPrint('   Products: ${products.length} records');
        debugPrint('   Customers: ${customers.length} records');
        debugPrint('   Invoices: ${invoices.length} records');
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error creating backup data: $e');
      rethrow;
    }
    
    return backupData;
  }
  
  /// Save backup to file
  Future<void> _saveBackupToFile(Map<String, dynamic> backupData) async {
    try {
      final directory = await _getBackupDirectory();
      if (directory == null) {
        throw Exception('Could not access backup directory');
      }
      
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'backup_$timestamp.json';
      final file = File('${directory.path}/$fileName');
      
      final jsonString = json.encode(backupData);
      await file.writeAsString(jsonString);
      
      if (kDebugMode) debugPrint('💾 Backup saved to: ${file.path}');
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error saving backup file: $e');
      rethrow;
    }
  }
  
  /// Get backup directory
  Future<Directory?> _getBackupDirectory() async {
    try {
      if (kIsWeb) {
        // Web: Use a different approach or skip file-based backups
        if (kDebugMode) debugPrint('🌐 Web platform - file backups not supported');
        return null;
      }
      
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/backups');
      
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      
      return backupDir;
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting backup directory: $e');
      return null;
    }
  }
  
  /// Clean up old backup files
  Future<void> _cleanupOldBackups() async {
    try {
      final directory = await _getBackupDirectory();
      if (directory == null) return;
      
      final files = directory.listSync()
          .where((entity) => entity is File && entity.path.endsWith('.json'))
          .cast<File>()
          .toList();
      
      // Sort by modification time (oldest first)
      files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
      
      // Remove old files if we have more than max
      if (files.length > _maxBackupFiles) {
        final filesToDelete = files.sublist(0, files.length - _maxBackupFiles);
        for (final file in filesToDelete) {
          await file.delete();
          if (kDebugMode) debugPrint('🗑️ Deleted old backup: ${file.path}');
        }
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error cleaning up old backups: $e');
    }
  }
  
  /// Force immediate backup (manual trigger)
  Future<void> forceBackup() async {
    if (kDebugMode) debugPrint('🔄 Forcing immediate backup');
    await _performBackup();
  }
  
  /// Get list of available backups
  Future<List<BackupInfo>> getAvailableBackups() async {
    final backups = <BackupInfo>[];
    
    try {
      final directory = await _getBackupDirectory();
      if (directory == null) return backups;
      
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
            
            backups.add(BackupInfo(
              fileName: file.path.split('/').last,
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
      if (kDebugMode) debugPrint('❌ Error getting available backups: $e');
    }
    
    return backups;
  }
  
  /// Restore from backup
  Future<bool> restoreFromBackup(String backupPath) async {
    try {
      if (kDebugMode) debugPrint('🔄 Restoring from backup: $backupPath');
      
      final file = File(backupPath);
      if (!await file.exists()) {
        throw Exception('Backup file not found');
      }
      
      final jsonString = await file.readAsString();
      final backupData = json.decode(jsonString);
      
      if (backupData is! Map) {
        throw Exception('Invalid backup format');
      }
      
      // Restore sales data
      if (backupData.containsKey('sales')) {
        await LocalStorageService.saveSales(backupData['sales']);
        if (kDebugMode) debugPrint('✅ Restored ${backupData['sales'].length} sales');
      }
      
      // Restore products data
      if (backupData.containsKey('products')) {
        await LocalStorageService.saveBackendProducts(backupData['products']);
        if (kDebugMode) debugPrint('✅ Restored ${backupData['products'].length} products');
      }
      
      // Restore local products
      if (backupData.containsKey('local_products')) {
        await LocalStorageService.saveLocalProducts(backupData['local_products']);
        if (kDebugMode) debugPrint('✅ Restored local products');
      }
      
      // Restore customers data
      if (backupData.containsKey('customers')) {
        await LocalStorageService.saveLocalCustomers(backupData['customers']);
        if (kDebugMode) debugPrint('✅ Restored ${backupData['customers'].length} customers');
      }
      
      // Restore invoices data
      if (backupData.containsKey('invoices')) {
        await LocalStorageService.saveLocalInvoices(backupData['invoices']);
        if (kDebugMode) debugPrint('✅ Restored ${backupData['invoices'].length} invoices');
      }
      
      // Restore shop profile
      if (backupData.containsKey('shop_profile')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('shop_profile_json', json.encode(backupData['shop_profile']));
        if (kDebugMode) debugPrint('✅ Restored shop profile');
      }
      
      // Restore sync queue
      if (backupData.containsKey('sync_queue')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('offline_sync_queue', json.encode(backupData['sync_queue']));
        if (kDebugMode) debugPrint('✅ Restored sync queue');
      }
      
      if (kDebugMode) debugPrint('✅ Backup restore completed');
      return true;
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Backup restore failed: $e');
      return false;
    }
  }
  
  /// Delete a specific backup
  Future<bool> deleteBackup(String backupPath) async {
    try {
      final file = File(backupPath);
      if (await file.exists()) {
        await file.delete();
        if (kDebugMode) debugPrint('🗑️ Deleted backup: $backupPath');
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error deleting backup: $e');
      return false;
    }
  }
}

/// Backup information class
class BackupInfo {
  final String fileName;
  final DateTime timestamp;
  final int size;
  final String path;
  final int salesCount;
  final int productsCount;
  final int customersCount;
  
  BackupInfo({
    required this.fileName,
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
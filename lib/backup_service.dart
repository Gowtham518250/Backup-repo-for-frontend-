import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'local_storage_service.dart';

class BackupService {
  static const String backupDir = 'retail_mind_backups';
  static const int maxBackups = 10;

  /// Create a full backup of all app data
  static Future<Map<String, dynamic>> createBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Validate we have data to backup
      if (prefs.getKeys().isEmpty) {
        throw Exception('No app data to backup');
      }
      
      // Include both SharedPreferences and the encrypted Hive-backed business snapshot.
      String? localStorageSnapshot;
      try {
        final snapshotPath = await LocalStorageService.exportSecureBackup();
        if (snapshotPath != null) {
          localStorageSnapshot = await File(snapshotPath).readAsString();
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Secure local snapshot unavailable: $e');
      }

      final prefsData = _getAllPreferences(prefs);
      final backupData = {
        'timestamp': DateTime.now().toIso8601String(),
        'version': '2.1',
        'appVersion': '1.0.0+1',
        'data': {
          'preferences': prefsData,
          'backupDate': DateTime.now().toString(),
          'local_storage_backup': localStorageSnapshot,
        },
        'checksum': _generateChecksum({
          'preferences': prefsData,
          'local_storage_backup': localStorageSnapshot,
        }),
      };

      // Save backup file
      final backupPath = await _saveBackupFile(backupData);
    if (kDebugMode) debugPrint('✅ Backup created successfully at: $backupPath');
      
      return {
        'success': true,
        'path': backupPath,
        'timestamp': backupData['timestamp'],
        'size': (await File(backupPath).length()) ~/ 1024, // KB
        'recordCount': prefs.getKeys().length,
      };
    } catch (e) {
    if (kDebugMode) debugPrint('❌ Backup creation failed: $e');
      throw Exception('Backup creation failed: $e');
    }
  }

  /// Restore from backup with validation
  static Future<bool> restoreBackup(String backupFilePath) async {
    try {
      final file = File(backupFilePath);
      if (!await file.exists()) {
        throw Exception('Backup file not found at: $backupFilePath');
      }

      // Size Validation (max 50MB) to prevent memory allocation attacks
      final fileSize = await file.length();
      if (fileSize > 50 * 1024 * 1024) {
        throw Exception('Backup file too large (exceeds 50MB limit)');
      }

      final jsonStr = await file.readAsString();
      final backupData = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      // Validate backup structure
      if (!backupData.containsKey('timestamp') || !backupData.containsKey('data')) {
        throw Exception('Invalid backup file format');
      }

      // App Version Compatibility Check
      final version = backupData['version']?.toString();
      if (version != '2.0' && version != '2.1') {
        throw Exception('Incompatible backup version ($version). Expected 2.0 or 2.1');
      }

      // Staleness Check (Max 30 days)
      final timestampStr = backupData['timestamp']?.toString();
      if (timestampStr != null) {
        final backupDate = DateTime.tryParse(timestampStr);
        if (backupDate != null) {
          final ageDays = DateTime.now().difference(backupDate).inDays;
          if (ageDays > 30) {
            throw Exception('Backup is too old to restore ($ageDays days). Max allowed is 30 days.');
          }
        }
      }

      // Validate checksum if present
      if (backupData.containsKey('checksum')) {
        final prefsData = backupData['data']['preferences'] as Map<String, dynamic>?;
        final localSnapshot = backupData['data']['local_storage_backup'];
        final calculatedChecksum = version == '2.1'
            ? _generateChecksum({'preferences': prefsData ?? <String, dynamic>{}, 'local_storage_backup': localSnapshot})
            : _generateChecksum(prefsData ?? <String, dynamic>{});
        if (calculatedChecksum != backupData['checksum']) {
          throw Exception('Backup file corrupted: checksum mismatch');
        }
      }
      
      final prefs = await SharedPreferences.getInstance();
      
      // Restore all preferences
      final prefsData = backupData['data']['preferences'] as Map<String, dynamic>;
      int restoredCount = 0;
      
      for (var entry in prefsData.entries) {
        try {
          await _restorePreference(prefs, entry.key, entry.value);
          restoredCount++;
        } catch (e) {
    if (kDebugMode) debugPrint('⚠️ Failed to restore key ${entry.key}: $e');
          // Continue with next entry
        }
      }

      final localSnapshot = backupData['data']['local_storage_backup'];
      if (localSnapshot is String && localSnapshot.isNotEmpty) {
        final restored = await LocalStorageService.importSecureBackup(localSnapshot);
        if (!restored) throw Exception('Local business-data restore failed');
      }
    if (kDebugMode) debugPrint('✅ Backup restored successfully: $restoredCount items restored');
      return true;
    } catch (e) {
    if (kDebugMode) debugPrint('❌ Backup restore failed: $e');
      throw Exception('Backup restore failed: $e');
    }
  }

  /// List all available backups
  static Future<List<Map<String, dynamic>>> listBackups() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDirPath = '${directory.path}/$backupDir';
      final backupFolder = Directory(backupDirPath);

      if (!await backupFolder.exists()) {
        return [];
      }

      final files = await backupFolder.list().toList();
      final backups = <Map<String, dynamic>>[];

      for (var file in files) {
        if (file.path.endsWith('.json')) {
          final stat = await file.stat();
          try {
            final content = await File(file.path).readAsString();
            final data = jsonDecode(content) as Map<String, dynamic>;
            
            backups.add({
              'path': file.path,
              'timestamp': data['timestamp'] ?? '',
              'fileSize': stat.size ~/ 1024,
              'date': DateTime.tryParse(data['timestamp'] ?? '')?.toString().split('.')[0] ?? 'Unknown',
              'name': file.path.split('/').last,
            });
          } catch (_) {
            // Skip invalid backup files
          }
        }
      }

      // Sort by timestamp descending
      backups.sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));
      return backups;
    } catch (e) {
      throw Exception('Failed to list backups: $e');
    }
  }

  /// Delete a backup
  static Future<bool> deleteBackup(String backupFilePath) async {
    try {
      final file = File(backupFilePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Failed to delete backup: $e');
    }
  }

  /// Auto backup (can be called periodically)
  static Future<void> autoBackup() async {
    try {
      await createBackup();
      
      // Clean old backups
      final backups = await listBackups();
      if (backups.length > maxBackups) {
        // Delete oldest backups
        for (int i = maxBackups; i < backups.length; i++) {
          await deleteBackup(backups[i]['path']);
        }
      }
    } catch (e) {
      // Silently fail for auto-backup
    if (kDebugMode) debugPrint('Auto-backup error: $e');
    }
  }

  /// Export backup to external location
  static Future<String> exportBackup(String backupFilePath) async {
    try {
      final sourceFile = File(backupFilePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source backup not found');
      }

      final directory = await getDownloadsDirectory();
      if (directory == null) throw Exception('Downloads directory not found');

      final fileName = 'retail_mind_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final exportFile = File('${directory.path}/$fileName');
      
      await sourceFile.copy(exportFile.path);
      return exportFile.path;
    } catch (e) {
      throw Exception('Backup export failed: $e');
    }
  }

  // Private helpers

  static Future<String> _saveBackupFile(Map<String, dynamic> data) async {
    final directory = await getApplicationDocumentsDirectory();
    final backupDirPath = '${directory.path}/$backupDir';
    final backupFolder = Directory(backupDirPath);

    if (!await backupFolder.exists()) {
      await backupFolder.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '$backupDirPath/backup_$timestamp.json';
    final file = File(filePath);

    await file.writeAsString(jsonEncode(data));
    return filePath;
  }

  static Map<String, dynamic> _getAllPreferences(SharedPreferences prefs) {
    // SECURITY FIX C4: Exclude sensitive keys from backup.
    // These should never be serialized to a file that may be exported.
    const sensitiveKeyPrefixes = [
      '_otp_',
      '_protected_',
    ];
    const sensitiveKeys = {
      'master_pin',
      'app_password',
      'sender_email',
      'auth_token',
      'access_token',
      'refresh_token',
      'upi_id',
      'payment_qr_b64',
      'logo_base64',
    };

    final result = <String, dynamic>{};
    final keys = prefs.getKeys();

    for (var key in keys) {
      // Skip sensitive keys
      if (sensitiveKeys.contains(key)) continue;
      if (sensitiveKeyPrefixes.any((p) => key.startsWith(p))) continue;
      try {
        result[key] = prefs.get(key);
      } catch (_) {
        // Skip keys that can't be serialized
      }
    }

    return result;
  }

  static Future<void> _restorePreference(
    SharedPreferences prefs,
    String key,
    dynamic value,
  ) async {
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is List) {
      await prefs.setStringList(key, List<String>.from(value));
    }
  }

  /// Get backup statistics
  static Future<Map<String, dynamic>> getBackupStats() async {
    try {
      final backups = await listBackups();
      int totalSize = 0;

      for (var backup in backups) {
        totalSize += (backup['fileSize'] as int? ?? 0);
      }

      return {
        'totalBackups': backups.length,
        'totalSize': totalSize,
        'lastBackup': backups.isNotEmpty ? backups[0]['date'] : 'Never',
        'availableSpace': await _getAvailableSpace(),
      };
    } catch (e) {
      throw Exception('Failed to get backup stats: $e');
    }
  }

  static Future<int> _getAvailableSpace() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final stat = await directory.stat();
      return stat.size ~/ (1024 * 1024); // MB
    } catch (_) {
      return 0;
    }
  }

  /// Generate SHA-256 checksum for backup data integrity (FIX 20)
  static String _generateChecksum(Map<String, dynamic> data) {
    try {
      final jsonString = jsonEncode(data);
      final bytes = utf8.encode(jsonString);
      return sha256.convert(bytes).toString();
    } catch (e) {
      return '';
    }
  }

  /// Validate backup integrity
  static Future<bool> validateBackup(String backupFilePath) async {
    try {
      final file = File(backupFilePath);
      if (!await file.exists()) return false;

      final jsonStr = await file.readAsString();
      final backupData = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      // Check required fields
      if (!backupData.containsKey('timestamp') || 
          !backupData.containsKey('data') ||
          !backupData.containsKey('version')) {
        return false;
      }

      // Validate checksum if present
      if (backupData.containsKey('checksum')) {
        final prefsData = backupData['data']['preferences'] as Map<String, dynamic>?;
        if (prefsData != null) {
          final calculatedChecksum = _generateChecksum(prefsData);
          return calculatedChecksum == backupData['checksum'];
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}


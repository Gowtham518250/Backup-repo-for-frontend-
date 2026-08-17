/// BACKUP SERVICE INTEGRATION WIDGET
/// 
/// Drop this into dashboard_page.dart to add backup/restore UI
/// Integrates BackupService with dashboard maintenance section

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backup_service.dart';

/// Add this widget to your dashboard maintenance card
class BackupManagementSection extends StatefulWidget {
  const BackupManagementSection({Key? key}) : super(key: key);

  @override
  State<BackupManagementSection> createState() => _BackupManagementSectionState();
}

class _BackupManagementSectionState extends State<BackupManagementSection> {
  bool _isCreatingBackup = false;
  bool _autoBackupEnabled = false;
  DateTime? _lastBackupTime;
  String _backupStatus = 'No backup yet';

  @override
  void initState() {
    super.initState();
    _loadBackupStatus();
  }

  Future<void> _loadBackupStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackup = prefs.getString('last_backup_time');
    final autoBackupPref = prefs.getBool('auto_backup_enabled') ?? false;
    
    setState(() {
      _lastBackupTime = lastBackup != null ? DateTime.tryParse(lastBackup) : null;
      _autoBackupEnabled = autoBackupPref;
      _backupStatus = _lastBackupTime != null 
        ? 'Last backup: ${_lastBackupTime.toString().split(".").first}'
        : 'No backup yet';
    });
  }

  Future<void> _createBackupNow() async {
    if (_isCreatingBackup) return;
    
    setState(() => _isCreatingBackup = true);
    
    try {
      final result = await BackupService.createBackup();
      if (result['success'] == true) {
        final now = DateTime.now();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_backup_time', now.toIso8601String());
        
        setState(() {
          _lastBackupTime = now;
          _backupStatus = '✅ Backup created (${result['size']} KB)';
        });
        
        // Show success snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Backup created successfully'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _backupStatus = '❌ Backup failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Backup failed: $e')),
        );
      }
    } finally {
      setState(() => _isCreatingBackup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.backup, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Data Backup',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Status display
            Text(
              _backupStatus,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (_lastBackupTime != null)
              Text(
                'Last backup: ${_lastBackupTime.toString().split('.').first}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 12),
            
            // Backup button
            ElevatedButton.icon(
              onPressed: _isCreatingBackup ? null : _createBackupNow,
              icon: _isCreatingBackup
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
              label: Text(
                _isCreatingBackup ? 'Creating backup...' : 'Create Backup Now',
              ),
            ),
            const SizedBox(height: 12),
            
            // Auto-backup toggle
            SwitchListTile(
              title: const Text('Auto-backup daily (2 AM)'),
              subtitle: const Text('Automatic backup every 24 hours'),
              value: _autoBackupEnabled,
              onChanged: (value) async {
                setState(() => _autoBackupEnabled = value);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('auto_backup_enabled', value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Add this to your dashboard build method:
///
/// @override
/// Widget build(BuildContext context) {
///   return ListView(
///     children: [
///       // ... other dashboard sections ...
///       
///       // Add backup section to maintenance area
///       const BackupManagementSection(),
///       
///       // ... rest of dashboard ...
///     ],
///   );
/// }

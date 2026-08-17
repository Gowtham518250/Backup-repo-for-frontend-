import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'data_protection_service.dart';

/// Data Protection Dashboard - Monitor & Manage Data Safety
class DataProtectionPage extends StatefulWidget {
  const DataProtectionPage({Key? key}) : super(key: key);

  @override
  State<DataProtectionPage> createState() => _DataProtectionPageState();
}

class _DataProtectionPageState extends State<DataProtectionPage> {
  static const Color _primary = Color(0xFF6366F1);
  
  bool _checking = false;
  Map<String, dynamic> _integrityStatus = {};
  Map<String, dynamic> _backupStatus = {};
  bool _syncing = false;
  bool _backing = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _checking = true);
    
    final integrity = await DataProtectionService.verifyDataIntegrity();
    final backup = await DataProtectionService.exportBackup();
    
    setState(() {
      _integrityStatus = integrity;
      _backupStatus = backup;
      _checking = false;
    });
  }

  Future<void> _performSync() async {
    setState(() => _syncing = true);
    
    final result = await DataProtectionService.syncAllData(maxRetries: 3);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result 
              ? '✅ All data synced to backend!' 
              : '⚠️ Sync partially failed (retrying)',
          ),
          backgroundColor: result ? Colors.green : Colors.orange,
        ),
      );
      
      setState(() => _syncing = false);
      await _loadStatus();
    }
  }

  Future<void> _createBackup() async {
    setState(() => _backing = true);
    
    final result = await DataProtectionService.createLocalBackup();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result 
              ? '✅ Local backup created!' 
              : '❌ Backup failed',
          ),
          backgroundColor: result ? Colors.green : Colors.red,
        ),
      );
      
      setState(() => _backing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Protection'),
        backgroundColor: _primary,
        elevation: 0,
      ),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _primary, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Data Safety Status',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _integrityStatus['status'] == 'success'
                              ? '✅ All data is safe and verified'
                              : '⚠️ Issues detected - run integrity check',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: _integrityStatus['status'] == 'success'
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Backup Status
                  _buildStatusCard(
                    title: 'Backend Backup',
                    items: [
                      'Invoices: ${_backupStatus['backup_summary']?['invoices'] ?? 0}',
                      'Customers (Khata): ${_backupStatus['backup_summary']?['khata_customers'] ?? 0}',
                      'Expenses: ${_backupStatus['backup_summary']?['expenses'] ?? 0}',
                      'Products: ${_backupStatus['backup_summary']?['products'] ?? 0}',
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Integrity Issues
                  if (_integrityStatus['integrity_issues'] != null &&
                      (_integrityStatus['integrity_issues'] as List).isNotEmpty)
                    _buildWarningCard(
                      title: 'Issues Found (${_integrityStatus['issue_count']})',
                      issues: _integrityStatus['integrity_issues'],
                    ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  _buildActionButton(
                    label: 'Sync All Data to Backend',
                    icon: Icons.cloud_upload,
                    loading: _syncing,
                    onPressed: _performSync,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),

                  _buildActionButton(
                    label: 'Create Local Backup',
                    icon: Icons.save,
                    loading: _backing,
                    onPressed: _createBackup,
                    color: Colors.purple,
                  ),
                  const SizedBox(height: 12),

                  _buildActionButton(
                    label: 'Refresh Status',
                    icon: Icons.refresh,
                    loading: _checking,
                    onPressed: _loadStatus,
                    color: Colors.teal,
                  ),
                  const SizedBox(height: 24),

                  // Info Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How Data Protection Works:',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Every transaction stored locally AND on backend\n'
                          '• Auto-sync with 3x retry on network issues\n'
                          '• Integrity checks prevent data corruption\n'
                          '• Create backups before major operations',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required List<String> items,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '• $item',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard({
    required String title,
    required List<dynamic> issues,
  }) {
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.orange[900],
              ),
            ),
            const SizedBox(height: 8),
            ...issues.map((issue) => Text(
              '⚠️ $issue',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.orange[800],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool loading,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              )
            : Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

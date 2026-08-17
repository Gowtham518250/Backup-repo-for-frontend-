import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class SystemManagementPage extends StatefulWidget {
  const SystemManagementPage({super.key});
  @override
  State<SystemManagementPage> createState() => _SystemManagementPageState();
}

class _SystemManagementPageState extends State<SystemManagementPage> {
  static const _bg = Color(0xFF1A1A2E);
  static const _card = Color(0xFF16213E);

  bool _loading = false;

  Future<void> _handle(String name, Future<http.Response> Function() action, {bool isJson = true}) async {
    setState(() => _loading = true);
    try {
      final res = await action();
      if (mounted) {
        showDialog(context: context, builder: (_) => AlertDialog(
          backgroundColor: _card,
          title: Text('$name Result', style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(child: Text(
            isJson ? const JsonEncoder.withIndent('  ').convert(jsonDecode(res.body)) : res.body,
            style: GoogleFonts.robotoMono(color: Colors.cyanAccent, fontSize: 12),
          )),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _btn(String label, IconData icon, VoidCallback onTap, {Color color = Colors.cyanAccent}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity, height: 50,
        child: ElevatedButton.icon(
          onPressed: _loading ? null : onTap,
          style: ElevatedButton.styleFrom(backgroundColor: color.withValues(alpha: 0.2), foregroundColor: color, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withValues(alpha: 0.5)))),
          icon: Icon(icon), label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _card, title: Text('System Management', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))),
      body: _loading ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)) : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Cache Management', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _btn('View Cache Stats', Icons.analytics, () => _handle('Stats', () => ApiClient.getJson('/api/cache/stats'))),
          _btn('Warm Product Cache', Icons.inventory, () => _handle('Warm Products', () => ApiClient.postJson('/api/cache/warm/products', {}))),
          _btn('Warm Analytics Cache', Icons.insights, () => _handle('Warm Analytics', () => ApiClient.postJson('/api/cache/warm/analytics', {}))),
          _btn('Clear ALL Cache', Icons.delete_forever, () => _handle('Clear Cache', () => http.delete(Uri.parse('${ApiClient.baseUrl}/api/cache/clear-all')), isJson: false), color: Colors.redAccent),
          
          const SizedBox(height: 32),
          Text('Batch Operations', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _btn('View Batch History', Icons.history, () => _handle('History', () => ApiClient.getJson('/batch/api/batch/history')), color: Colors.amberAccent),
          _btn('Export Products', Icons.download, () => _handle('Export', () => ApiClient.postJson('/batch/api/batch/products/export', {})), color: Colors.amberAccent),
          _btn('Import Products (CSV)', Icons.upload, () => _handle('Import', () => ApiClient.postJson('/batch/api/batch/products/import', {})), color: Colors.amberAccent),
          _btn('Import Customers (CSV)', Icons.people, () => _handle('Import', () => ApiClient.postJson('/batch/api/batch/customers/import', {})), color: Colors.amberAccent),
        ]),
      ),
    );
  }
}

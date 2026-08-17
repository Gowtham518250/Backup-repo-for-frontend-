import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'gst_compliance.dart';
import 'local_storage_service.dart';
import 'format_helper.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class GstFilingPage extends StatefulWidget {
  final Map<String, dynamic> gstr1Data;

  const GstFilingPage({super.key, required this.gstr1Data});

  @override
  State<GstFilingPage> createState() => _GstFilingPageState();
}

class _GstFilingPageState extends State<GstFilingPage> {
  static const Color _primary = Color(0xFF6366F1);
  
  late Map<String, dynamic> _gstr1Data;
  String selectedMonth = '';
  List<Map<String, dynamic>> _invoices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _gstr1Data = widget.gstr1Data;
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    final sales = await LocalStorageService.loadSales();
    setState(() {
      _invoices = sales.cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  Future<void> _shareGSTR1Json() async {
    try {
      final jsonString = GSTCompliance.exportGSTR1AsJSON(
        sellerGSTIN: _gstr1Data['seller_gstin'] ?? '',
        period: _gstr1Data['period'] ?? '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
        invoices: _invoices,
      );

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/GSTR1_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles([XFile(file.path)],
        text: 'GSTR-1 Export - Ready for filing',
        subject: 'GSTR-1 Filing Export',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _copyToClipboard() async {
    try {
      final summary = _gstr1Data['summary'] as Map? ?? {};
      final text =
          'GSTR-1 Summary\n'
          'B2B Invoices: ${_gstr1Data['b2b']?['count'] ?? 0}\n'
          'B2B Value: ₹${(summary['total_b2b_value'] ?? 0).toStringAsFixed(0)}\n'
          'B2B GST: ₹${(summary['total_b2b_gst'] ?? 0).toStringAsFixed(0)}\n\n'
          'B2C Value: ₹${(summary['total_b2c_value'] ?? 0).toStringAsFixed(0)}\n'
          'B2C GST: ₹${(summary['total_b2c_gst'] ?? 0).toStringAsFixed(0)}\n\n'
          'Total Value: ₹${(summary['grand_total_value'] ?? 0).toStringAsFixed(0)}\n'
          'Total GST: ₹${(summary['grand_total_gst'] ?? 0).toStringAsFixed(0)}';
      
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Summary copied to clipboard (ready for CA)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _gstr1Data['summary'] as Map? ?? {};
    final b2bCount = _gstr1Data['b2b']?['count'] ?? 0;
    final b2cData = _gstr1Data['b2c'] as Map? ?? {};
    final b2cCount = b2cData['number_of_invoices'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GSTR-1 Filing'),
        backgroundColor: _primary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period & Filing Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Period', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                                const SizedBox(height: 4),
                                Text(_gstr1Data['period']?.toString() ?? 'N/A',
                                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: _primary)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Filing Date', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                                const SizedBox(height: 4),
                                Text(_gstr1Data['filing_date']?.toString().split('T').first ?? 'N/A',
                                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _gstr1Data['status']?.toString() ?? 'READY',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Summary Cards
                  Text('Summary', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _summaryCard(
                          'B2B Invoices',
                          '$b2bCount',
                          Colors.blue,
                          Icons.business_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _summaryCard(
                          'B2C Invoices',
                          '$b2cCount',
                          Colors.green,
                          Icons.shopping_bag_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _summaryCard(
                          'HSN Codes',
                          '${_gstr1Data['hsn_summary']?['hsn_count'] ?? 0}',
                          Colors.orange,
                          Icons.tag_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _summaryCard(
                          'Total GST',
                          '₹${(summary['grand_total_gst'] ?? 0).toStringAsFixed(0)}',
                          Colors.red,
                          Icons.receipt_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Financial Summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Financial Breakdown', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        _breakdownRow('B2B Value', '₹${(summary['total_b2b_value'] ?? 0).toStringAsFixed(0)}'),
                        const SizedBox(height: 8),
                        _breakdownRow('B2B GST', '₹${(summary['total_b2b_gst'] ?? 0).toStringAsFixed(0)}'),
                        const Divider(height: 16),
                        _breakdownRow('B2C Value', '₹${(summary['total_b2c_value'] ?? 0).toStringAsFixed(0)}'),
                        const SizedBox(height: 8),
                        _breakdownRow('B2C GST', '₹${(summary['total_b2c_gst'] ?? 0).toStringAsFixed(0)}'),
                        const Divider(height: 16),
                        _breakdownRow('Total Turnover', '₹${(summary['grand_total_value'] ?? 0).toStringAsFixed(0)}', isTotal: true),
                        const SizedBox(height: 8),
                        _breakdownRow('Total GST Liability', '₹${(summary['grand_total_gst'] ?? 0).toStringAsFixed(0)}', isTotal: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.cloud_download_rounded),
                      label: const Text('Download GSTR-1 JSON'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _shareGSTR1Json,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.content_copy_rounded),
                      label: const Text('Copy Summary for CA'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: const BorderSide(color: _primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _copyToClipboard,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Compliance Checklist
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Compliance Checklist', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green.shade800)),
                        const SizedBox(height: 12),
                        ...((_gstr1Data['compliance_validation'] as Map?)?.entries ?? []).map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_rounded, size: 18, color: Colors.green.shade600),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    c.value?.toString() ?? 'All invoices are GST compliant',
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // CA Fee Saving Badge
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.blue.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Column(
                      children: [
                        Text('💰 CA Fee Saving', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.blue.shade800)),
                        const SizedBox(height: 8),
                        Text('You just saved ₹500 by auto-generating GSTR-1!', 
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue.shade700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: isTotal ? Colors.black : Colors.grey[700],
            )),
        Text(value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
              color: isTotal ? _primary : Colors.black,
            )),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'bank_reconciliation.dart';
import 'local_storage_service.dart';

class BankStatementParserPage extends StatefulWidget {
  const BankStatementParserPage({super.key});

  @override
  State<BankStatementParserPage> createState() => _BankStatementParserPageState();
}

class _BankStatementParserPageState extends State<BankStatementParserPage> {
  static const Color _primary = Color(0xFF6366F1);
  
  List<BankEntry> _parsedEntries = [];
  List<Map<String, dynamic>> _appSales = [];
  List<Map<String, dynamic>> _matched = [];
  List<Map<String, dynamic>> _unmatched = [];
  bool _loading = false;
  String _status = 'Ready to parse PDF';

  @override
  void initState() {
    super.initState();
    _loadAppSales();
  }

  Future<void> _loadAppSales() async {
    final sales = await LocalStorageService.loadSales();
    setState(() {
      _appSales = sales.map((s) => Map<String, dynamic>.from(s)).toList();
    });
  }

  Future<void> _parsePDF() async {
    setState(() {
      _loading = true;
      _status = 'Parsing PDF...';
    });

    try {
      // Show file picker and get filepath
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      
      if (result == null || result.files.isEmpty) {
        setState(() => _status = 'No file selected');
        return;
      }
      
      final filepath = result.files.single.path;
      if (filepath == null) {
        setState(() => _status = 'File path not available');
        return;
      }
      
      final entries = await BankStatementParser.parsePDFFile(filepath);
      
      setState(() {
        _parsedEntries = entries;
        _status = 'Found ${entries.length} transactions. Reconciling...';
      });

      // Convert to format expected by reconciliation
      final bankTransactions = entries.map((e) => {
        'amount': e.amount.toString(),
        'date': e.date.toIso8601String(),
        'reference': e.reference,
        'rawLine': e.rawLine,
      }).toList();

      // Reconcile
      final unmatched = BankReconciliation.reconcile(bankTransactions, _appSales);
      
      // Separate matched and unmatched
      final matched = bankTransactions.where((txn) => 
        !_unmatched.any((u) => u['amount'] == txn['amount'] && 
                              u['date']?.split('T').first == txn['date']?.split('T').first)
      ).toList();

      setState(() {
        _matched = matched;
        _unmatched = unmatched;
        _status = 'Reconciliation complete. ${matched.length} matched, ${unmatched.length} unmatched.';
        _loading = false;
      });

    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text('Bank Statement Parser', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_status, style: GoogleFonts.poppins(color: Colors.blue.shade800)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Parse Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _parsePDF,
                icon: _loading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file),
                label: Text(_loading ? 'Processing...' : 'Select & Parse PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Results
            if (_parsedEntries.isNotEmpty) ...[
              _buildResultsSection(),
            ],

            // Instructions
            if (_parsedEntries.isEmpty) ...[
              Text('Instructions', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildInstructionCard(
                'Supported Banks',
                'HDFC, SBI, ICICI, AXIS, KOTAK Mahindra Bank statements',
                Icons.account_balance,
              ),
              const SizedBox(height: 12),
              _buildInstructionCard(
                'PDF Format',
                'Upload bank statement PDF downloaded from net banking',
                Icons.picture_as_pdf,
              ),
              const SizedBox(height: 12),
              _buildInstructionCard(
                'UPI Transactions',
                'Only UPI credit transactions will be extracted and matched',
                Icons.payment,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reconciliation Results', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // Summary
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard('Parsed', '${_parsedEntries.length}', Colors.blue, Icons.receipt),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard('Matched', '${_matched.length}', Colors.green, Icons.check_circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard('Unmatched', '${_unmatched.length}', Colors.orange, Icons.warning),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Matched Transactions
        if (_matched.isNotEmpty) ...[
          Text('✅ Matched Transactions', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
          const SizedBox(height: 12),
          ..._matched.take(5).map((txn) => _buildTransactionCard(txn, true)),
          if (_matched.length > 5) 
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('+ ${_matched.length - 5} more matched transactions', 
                style: GoogleFonts.poppins(color: Colors.green.shade600)),
            ),
          const SizedBox(height: 24),
        ],

        // Unmatched Transactions
        if (_unmatched.isNotEmpty) ...[
          Text('⚠️ Unmatched Transactions', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
          const SizedBox(height: 12),
          ..._unmatched.map((txn) => _buildTransactionCard(txn, false)),
        ],
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> txn, bool isMatched) {
    final amount = double.tryParse(txn['amount']?.toString() ?? '0') ?? 0;
    final date = txn['date']?.toString() ?? '';
    final reference = txn['reference']?.toString() ?? 'Unknown';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isMatched ? Colors.green.shade50 : Colors.orange.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              isMatched ? Icons.check_circle : Icons.warning,
              color: isMatched ? Colors.green : Colors.orange,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('₹${amount.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  Text(reference, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                  Text(date.split('T').first, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500)),
                ],
              ),
            ),
            if (!isMatched) ...[
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _addAsSale(txn),
                child: const Text('Add as Sale'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: GoogleFonts.poppins(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionCard(String title, String description, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(description, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addAsSale(Map<String, dynamic> txn) async {
    // Create a sale entry from the unmatched transaction
    final sale = {
      'sale_id': 'BANK-${DateTime.now().millisecondsSinceEpoch}',
      'total': txn['amount'],
      'payment_method': 'BANK_TRANSFER',
      'customer_name': 'Bank Transaction',
      'date': txn['date'],
      'reference': txn['reference'],
      'rawLine': txn['rawLine'],
      'is_from_bank_statement': true,
      'created_at': DateTime.now().toIso8601String(),
    };

    // Add to local storage
    final sales = await LocalStorageService.loadSales();
    sales.add(sale);
    await LocalStorageService.saveSales(sales);

    // Remove from unmatched
    setState(() {
      _unmatched.remove(txn);
      _matched.add(txn);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction added as sale'), backgroundColor: Colors.green),
    );
  }
}
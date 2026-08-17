import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'api_client.dart';

class BankReconPage extends StatefulWidget {
  const BankReconPage({super.key});
  @override
  State<BankReconPage> createState() => _BankReconPageState();
}

class _BankReconPageState extends State<BankReconPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<dynamic> _records = [];

  final _bankNameC = TextEditingController();
  final _refC = TextEditingController();
  final _amountC = TextEditingController();
  final _notesC = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _submitting = false;

  static const _bg = Color(0xFF1A1A2E);
  static const _card = Color(0xFF16213E);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    try {
      final res = await ApiClient.getJson('/bank-recon');
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        setState(() => _records = d is List ? d : (d['records'] ?? []));
      }
    } catch (e) {
      debugPrint('Bank recon fetch error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_bankNameC.text.isEmpty || _amountC.text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ApiClient.postJson('/bank-recon', {
        'bank_name': _bankNameC.text,
        'transaction_reference': _refC.text,
        'amount': double.tryParse(_amountC.text) ?? 0,
        'date': _selectedDate.toIso8601String().split('T').first,
        'notes': _notesC.text,
      });
      _bankNameC.clear(); _refC.clear(); _amountC.clear(); _notesC.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reconciliation added!')));
      _tabController.animateTo(0);
      _fetchRecords();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _submitting = false);
    }
  }

  Widget _field(TextEditingController c, String hint, {bool numeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: Colors.white38),
          filled: true, fillColor: Colors.white10,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        title: Text('Bank Reconciliation', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.amberAccent, unselectedLabelColor: Colors.white54, indicatorColor: Colors.amberAccent,
          tabs: const [Tab(text: 'Records'), Tab(text: 'Add New')],
        ),
      ),
      body: TabBarView(controller: _tabController, children: [
        // Records tab
        _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
            : RefreshIndicator(
                onRefresh: _fetchRecords,
                child: _records.isEmpty
                    ? Center(child: Text('No reconciliation records', style: GoogleFonts.poppins(color: Colors.white38)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _records.length,
                        itemBuilder: (ctx, i) {
                          final r = _records[i];
                          final reconciled = r['reconciled'] == true;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: (reconciled ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.3)),
                            ),
                            child: Row(children: [
                              CircleAvatar(
                                backgroundColor: (reconciled ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.15),
                                child: Icon(reconciled ? Icons.check_circle : Icons.pending, color: reconciled ? Colors.greenAccent : Colors.redAccent, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(r['bank_name']?.toString() ?? 'Bank', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                                Text(r['date']?.toString() ?? '', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
                              ])),
                              Text('Rs ${r['amount']?.toString() ?? '0'}', style: GoogleFonts.poppins(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                            ]),
                          );
                        },
                      ),
              ),
        // Add new tab
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('New Reconciliation Entry', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _field(_bankNameC, 'Bank Name'),
            _field(_refC, 'Transaction Reference'),
            _field(_amountC, 'Amount (Rs)', numeric: true),
            _field(_notesC, 'Notes'),
            ListTile(
              tileColor: Colors.white10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.calendar_today, color: Colors.amberAccent),
              title: Text('Date: ${_selectedDate.toIso8601String().split('T').first}', style: const TextStyle(color: Colors.white)),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                if (d != null) setState(() => _selectedDate = d);
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _submitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

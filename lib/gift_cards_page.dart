import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'api_client.dart';

class GiftCardsPage extends StatefulWidget {
  const GiftCardsPage({super.key});
  @override
  State<GiftCardsPage> createState() => _GiftCardsPageState();
}

class _GiftCardsPageState extends State<GiftCardsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Issue tab
  final _issueNameC = TextEditingController();
  final _issuePhoneC = TextEditingController();
  final _issueAmountC = TextEditingController();
  final _issueValidityC = TextEditingController();
  bool _issuing = false;

  // Redeem tab
  final _redeemCodeC = TextEditingController();
  final _redeemPhoneC = TextEditingController();
  bool _redeeming = false;

  // GST tab
  bool _exporting = false;
  String _gstData = '';

  static const _bg = Color(0xFF1A1A2E);
  static const _card = Color(0xFF16213E);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<void> _issueCard() async {
    setState(() => _issuing = true);
    try {
      final res = await ApiClient.postJson('/gift-cards', {
        'customer_name': _issueNameC.text,
        'customer_phone': _issuePhoneC.text,
        'amount': double.tryParse(_issueAmountC.text) ?? 0,
        'validity_days': int.tryParse(_issueValidityC.text) ?? 365,
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        final code = jsonDecode(res.body)['gift_card_code'] ?? 'UNKNOWN';
        if (mounted) {
          showDialog(context: context, builder: (_) => AlertDialog(
            backgroundColor: _card,
            title: const Text('Gift Card Issued!', style: TextStyle(color: Colors.white)),
            content: SelectableText(code, style: GoogleFonts.robotoMono(color: Colors.purpleAccent, fontSize: 24, fontWeight: FontWeight.bold)),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
          ));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${res.body}')));
      }
    } finally {
      if (mounted) setState(() => _issuing = false);
    }
  }

  Future<void> _redeemCard() async {
    setState(() => _redeeming = true);
    try {
      final res = await ApiClient.postJson('/gift-cards/redeem', {
        'code': _redeemCodeC.text,
        'customer_phone': _redeemPhoneC.text,
      });
      if (res.statusCode == 200) {
        final bal = jsonDecode(res.body)['remaining_balance'] ?? 0;
        if (mounted) {
          showDialog(context: context, builder: (_) => AlertDialog(
            backgroundColor: _card,
            title: const Text('Redeemed Successfully', style: TextStyle(color: Colors.white)),
            content: Text('Remaining Balance: Rs $bal', style: GoogleFonts.poppins(color: Colors.greenAccent, fontSize: 18)),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
          ));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${res.body}')));
      }
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  Future<void> _exportGst() async {
    setState(() => _exporting = true);
    try {
      final res = await ApiClient.getJson('/gst/export-gstr1');
      if (res.statusCode == 200) {
        setState(() => _gstData = const JsonEncoder.withIndent('  ').convert(jsonDecode(res.body)));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _field(TextEditingController c, String hint, {bool numeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: c, keyboardType: numeric ? TextInputType.number : TextInputType.text,
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
        title: Text('Gift Cards & GST', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController, indicatorColor: Colors.purpleAccent, labelColor: Colors.purpleAccent, unselectedLabelColor: Colors.white54,
          tabs: const [Tab(text: 'Issue'), Tab(text: 'Redeem'), Tab(text: 'GST')],
        ),
      ),
      body: TabBarView(controller: _tabController, children: [
        // Issue
        SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
          const Icon(Icons.card_giftcard, size: 64, color: Colors.purpleAccent),
          const SizedBox(height: 24),
          _field(_issueNameC, 'Customer Name'), _field(_issuePhoneC, 'Customer Phone'),
          _field(_issueAmountC, 'Amount (Rs)', numeric: true), _field(_issueValidityC, 'Validity (Days)', numeric: true),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            onPressed: _issuing ? null : _issueCard, style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            child: _issuing ? const CircularProgressIndicator(color: Colors.white) : const Text('Issue Gift Card', style: TextStyle(fontWeight: FontWeight.bold)),
          )),
        ])),
        // Redeem
        SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
          const Icon(Icons.redeem, size: 64, color: Colors.purpleAccent),
          const SizedBox(height: 24),
          _field(_redeemCodeC, 'Gift Card Code'), _field(_redeemPhoneC, 'Customer Phone'),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            onPressed: _redeeming ? null : _redeemCard, style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: _redeeming ? const CircularProgressIndicator(color: Colors.white) : const Text('Redeem Card', style: TextStyle(fontWeight: FontWeight.bold)),
          )),
        ])),
        // GST
        Padding(padding: const EdgeInsets.all(24), child: Column(children: [
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
            onPressed: _exporting ? null : _exportGst, style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
            icon: _exporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Icon(Icons.download),
            label: const Text('Export GSTR-1 Data'),
          )),
          const SizedBox(height: 16),
          if (_gstData.isNotEmpty) ...[
            Align(alignment: Alignment.centerRight, child: TextButton.icon(
              onPressed: () { Clipboard.setData(ClipboardData(text: _gstData)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard'))); },
              icon: const Icon(Icons.copy, color: Colors.purpleAccent), label: const Text('Copy', style: TextStyle(color: Colors.purpleAccent)),
            )),
            Expanded(child: Container(
              width: double.infinity, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
              child: SingleChildScrollView(child: Text(_gstData, style: GoogleFonts.robotoMono(color: Colors.greenAccent, fontSize: 12))),
            )),
          ]
        ])),
      ]),
    );
  }
}

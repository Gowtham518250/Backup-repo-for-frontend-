import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'local_storage_service.dart';
import 'format_helper.dart';
import 'app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;
import 'whatsapp_message_service.dart';
import 'payment_detection_service.dart';
import 'financial_math.dart';

class DayClosingPage extends StatefulWidget {
  const DayClosingPage({super.key});

  @override
  State<DayClosingPage> createState() => _DayClosingPageState();
}

class _DayClosingPageState extends State<DayClosingPage> {
  List<Map<String, dynamic>> _todaySales = [];
  double _totalCash = 0;
  double _totalOnline = 0;
  double _totalBorrow = 0;
  double _openingBalance = 0;
  double _actualCashHandedOver = 0;
  bool _loading = true;
  bool _showWhatsAppReport = false;
  final _openingCtrl = TextEditingController();
  final _cashHandoverCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTodayData();
  }

  @override
  void dispose() {
    _openingCtrl.dispose();
    _cashHandoverCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTodayData() async {
    final allSales = await LocalStorageService.loadSales();
    
    // 🔒 FIX: Check if widget is still mounted before setState
    if (!mounted) return;
    
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    setState(() {
      _todaySales = allSales.where((s) {
        final date = s['business_date'] ?? s['sale_date'] ?? s['invoice_date'] ?? s['created_at'] ?? '';
        return date.toString().split('T').first.startsWith(todayStr);
      }).map((e) => Map<String, dynamic>.from(e as Map)).toList().cast<Map<String, dynamic>>();

      _totalCash = 0;
      _totalOnline = 0;
      _totalBorrow = 0;

      for (var s in _todaySales) {
        // Try multiple field names for total amount (STRICT: must not be 0)
        double total = 0;
        
        // Priority order: use first available non-zero value
        if (s['total'] != null) total = double.tryParse(s['total'].toString()) ?? 0;
        if (total == 0 && s['total_amount'] != null) total = double.tryParse(s['total_amount'].toString()) ?? 0;
        if (total == 0 && s['amount'] != null) total = double.tryParse(s['amount'].toString()) ?? 0;
        if (total == 0 && s['grandTotal'] != null) total = double.tryParse(s['grandTotal'].toString()) ?? 0;
        if (total == 0 && s['price'] != null && s['quantity'] != null) {
          final price = double.tryParse(s['price'].toString()) ?? 0;
          final qty = double.tryParse(s['quantity'].toString()) ?? 1;
          total = CurrencyManager.multiply(price, qty);
        }
        
        // Skip invalid/zero amounts
        if (total <= 0) continue;
        
        final method = s['payment_method']?.toString().toUpperCase().trim() ?? 'CASH';
        final status = s['payment_status']?.toString().toUpperCase().trim() ?? 'PAID';

        if (status == 'BORROW' || method == 'BORROW' || method == 'CREDIT' || method == 'KHATA') {
          _totalBorrow += total;
        } else if (method == 'CASH' || method == 'CASH PAYMENT' || method.isEmpty || method == 'CASH_PAYMENT') {
          _totalCash += total;
        } else if (method.contains('UPI') || method.contains('CARD') || method.contains('ONLINE') || method.contains('BANK')) {
          _totalOnline += total;
        } else {
          _totalCash += total; // Default to cash if unclear
        }
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalRevenue = _totalCash + _totalOnline + _totalBorrow;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text('Daily Closing', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Opening Cash Balance', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _openingCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              prefixText: '₹ ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onChanged: (v) => setState(() => _openingBalance = double.tryParse(v) ?? 0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('Actual Cash Being Handed Over', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _cashHandoverCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              prefixText: '₹ ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onChanged: (v) => setState(() => _actualCashHandedOver = double.tryParse(v) ?? 0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSummaryCard(totalRevenue),
                const SizedBox(height: 24),
                _buildPaymentBreakdown(),
                const SizedBox(height: 24),
                _buildBillList(),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Closing Cash Balance', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.green.shade800)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Opening + Cash Collected - Returned\n= ₹${(_openingBalance + _totalCash - _totalBorrow).toStringAsFixed(0)}', 
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade700)),
                          Text('₹${(_openingBalance + _totalCash - _totalBorrow).toStringAsFixed(0)}', 
                              style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                _buildCloseButton(),
                if (_showWhatsAppReport) ...[
                  const SizedBox(height: 24),
                  _buildWhatsAppReport(),
                ],
              ],
            ),
          ),
    );
  }

  Widget _buildSummaryCard(double total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearAnimation(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Text('Today\'s Total Revenue', style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
          const SizedBox(height: 8),
          Text('₹${total.toStringAsFixed(0)}', style: GoogleFonts.poppins(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: Text('${_todaySales.length} Total Bills Generated', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Breakdown', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937))),
        const SizedBox(height: 16),
        _buildMethodRow(Icons.money_rounded, 'Cash in Hand', _totalCash, Colors.green),
        const SizedBox(height: 12),
        _buildMethodRow(Icons.account_balance_wallet_rounded, 'Online / UPI', _totalOnline, Colors.blue),
        const SizedBox(height: 12),
        _buildMethodRow(Icons.hourglass_bottom_rounded, 'Borrows / Udhaar', _totalBorrow, Colors.orange),
      ],
    );
  }

  Widget _buildMethodRow(IconData icon, String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: const Color(0xFF4B5563)))),
          Text('₹${amount.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildBillList() {
    if (_todaySales.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Sales', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937))),
        const SizedBox(height: 16),
        ..._todaySales.take(5).map((s) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s['customer_name'] ?? 'Guest Customer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          subtitle: Text(s['created_at']?.toString().substring(11, 16) ?? '', style: GoogleFonts.poppins(fontSize: 12)),
          trailing: Text('₹${s['total_amount']}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5))),
        )),
      ],
    );
  }

  Widget _buildCloseButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: () => _confirmClosing(),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text('CLOSE DAY & PREPARE REPORT', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildWhatsAppReport() {
    final discrepancy = _totalCash - _actualCashHandedOver;
    final language = _getCurrentLanguage();
    final message = WhatsAppMessageService.buildDayClosingMessage(
      upiSales: _totalOnline,
      recordedCash: _totalCash,
      actualCash: _actualCashHandedOver,
      language: language,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.message, color: Colors.green.shade700, size: 24),
              const SizedBox(width: 8),
              Text('WhatsApp Report Ready', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(message, style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _showWhatsAppReport = false),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Amounts'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _sendWhatsAppReport(),
                  icon: const Icon(Icons.send),
                  label: const Text('Send to Owner'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  VoiceLanguage _getCurrentLanguage() {
    // Get language from SharedPreferences (same as payment detection service)
    // Default to hindi for Indian kirana shops
    return VoiceLanguage.hindi;
  }

  Future<void> _sendWhatsAppReport() async {
    final prefs = await SharedPreferences.getInstance();
    final ownerPhone = prefs.getString('shop_phone') ?? '';
    final shopName = prefs.getString('shop_name') ?? 'My Shop';

    if (ownerPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add your phone number in Shop Settings first')),
      );
      return;
    }

    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    final total = _totalCash + _totalOnline + _totalBorrow;

    // Build message — no API key needed, wa.me does this for free
    final summary =
      '*$shopName — Daily Summary ($dateStr)*\n\n'
      'Cash collected: Rs.${_totalCash.toStringAsFixed(0)}\n'
      'UPI / Online:   Rs.${_totalOnline.toStringAsFixed(0)}\n'
      'Udhar given:    Rs.${_totalBorrow.toStringAsFixed(0)}\n'
      '─────────────────\n'
      '*Total revenue: Rs.${total.toStringAsFixed(0)}*\n\n'
      'Sent from Retail Mind';

    // Clean phone — remove +91, spaces, dashes
    final digits = ownerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final phone = digits.startsWith('91') ? digits : '91$digits';

    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(summary)}';

    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      // Auto-close day after sending
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp automatically. You can use the Share/WhatsApp button from your phone.')),
        );
      }
    }
  }

  void _confirmClosing() {
    if (_actualCashHandedOver <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the actual cash being handed over')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Verify Closing Amount?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recorded Cash: ₹${_totalCash.toStringAsFixed(0)}', style: GoogleFonts.poppins()),
            Text('Cash Handed Over: ₹${_actualCashHandedOver.toStringAsFixed(0)}', style: GoogleFonts.poppins()),
            Text('Discrepancy: ₹${(_totalCash - _actualCashHandedOver).toStringAsFixed(0)}', 
              style: GoogleFonts.poppins(
                color: (_totalCash - _actualCashHandedOver).abs() > 10 ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              )),
            const SizedBox(height: 16),
            Text('WhatsApp summary will be sent automatically to the owner.', style: GoogleFonts.poppins(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _autoSendDailySummary(); // FIX-7: Auto-send instead of showing UI
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('CONFIRM CLOSING', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// FIX-7: Auto-send WhatsApp summary (no manual confirmation needed)
  Future<void> _autoSendDailySummary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ownerPhone = prefs.getString('shop_phone') ?? '';
      final shopName = prefs.getString('shop_name') ?? 'Your Shop';
      
      if (ownerPhone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Owner phone not configured — day closed locally')),
        );
        Navigator.pop(context, true);
        return;
      }

      final totalRevenue = _totalCash + _totalOnline + _totalBorrow;
      final now = DateTime.now();
      final dateStr = '${now.day}/${now.month}/${now.year}';

      final message =
        '📊 *$shopName — Day Summary ($dateStr)*\n\n'
        '💵 Cash: ₹${_totalCash.toStringAsFixed(0)}\n'
        '📱 UPI/Online: ₹${_totalOnline.toStringAsFixed(0)}\n'
        '📒 Udhar: ₹${_totalBorrow.toStringAsFixed(0)}\n'
        '━━━━━━━━━━━\n'
        '💰 *Total: ₹${totalRevenue.toStringAsFixed(0)}*\n\n'
        '_Sent by Retail Mind_';

      final url = 'https://wa.me/91$ownerPhone?text=${Uri.encodeComponent(message)}';
      
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Day closed! WhatsApp summary sent.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error auto-sending WhatsApp: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Day closed. WhatsApp error: $e')),
          );
        }
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error in day closing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Day closed with error: $e')),
        );
      }
      Navigator.pop(context, true);
    }
  }
}

class LinearAnimation extends LinearGradient {
  const LinearAnimation({required super.colors, super.begin, super.end});
}

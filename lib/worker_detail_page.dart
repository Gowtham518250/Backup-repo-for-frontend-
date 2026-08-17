import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'secure_token_storage.dart';
import 'models.dart';
import 'payment_history_storage.dart';
import 'worker_attendance_detail_page.dart';

/// Full profile page for a single worker: editable details, salary &
/// payment history, and a shortcut into their attendance record.
/// Pop with `true` when the worker was edited/deleted so the caller
/// (WorkerManagementPage) knows to refresh its list.
class WorkerDetailPage extends StatefulWidget {
  final Map<String, dynamic> worker; // raw worker JSON from the list page

  const WorkerDetailPage({super.key, required this.worker});

  @override
  State<WorkerDetailPage> createState() => _WorkerDetailPageState();
}

class _WorkerDetailPageState extends State<WorkerDetailPage> {
  static const Color _primary = Colors.indigo;

  late Map<String, dynamic> _worker;
  bool _dirty = false;
  bool _loadingPayments = true;
  List<WorkerPayment> _payments = [];
  int? _shopkeeperId;

  @override
  void initState() {
    super.initState();
    _worker = Map<String, dynamic>.from(widget.worker);
    _loadPayments();
  }

  int get _workerId => _worker['id'] is int ? _worker['id'] as int : int.parse('${_worker['id']}');

  Future<void> _loadPayments() async {
    setState(() => _loadingPayments = true);
    final prefs = await SharedPreferences.getInstance();
    _shopkeeperId = prefs.getInt('user_id') ?? prefs.getInt('userId');
    if (_shopkeeperId != null) {
      _payments = await PaymentHistoryStorage.fetchForWorker(_shopkeeperId!, _workerId);
    }
    if (mounted) setState(() => _loadingPayments = false);
  }

  Future<void> _openEditDialog() async {
    final nameCtrl = TextEditingController(text: _worker['name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: _worker['phone']?.toString() ?? '');
    final positionCtrl = TextEditingController(text: _worker['position']?.toString() ?? 'Staff');
    final salaryCtrl = TextEditingController(text: _worker['salary']?.toString() ?? '');
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (context, setModalState) {
        return AlertDialog(
          title: Text('Edit Worker', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person))),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone))),
              const SizedBox(height: 12),
              TextField(controller: positionCtrl, decoration: const InputDecoration(labelText: 'Position / Role', prefixIcon: Icon(Icons.work))),
              const SizedBox(height: 12),
              TextField(controller: salaryCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Salary', prefixIcon: Icon(Icons.attach_money))),
            ]),
          ),
          actions: [
            TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      setModalState(() => isSubmitting = true);
                      try {
                        final token = await SecureTokenStorage.getToken() ?? '';
                        // NOTE: assumes ApiClient exposes putJson alongside its
                        // existing getJson/postJson/deleteJson helpers. Add one
                        // (PUT /api/attendance/workers/{id}) if it isn't there yet.
                        final response = await ApiClient.putJson(
                          '/api/attendance/workers/$_workerId',
                          {
                            'name': nameCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'position': positionCtrl.text.trim(),
                            'salary': double.tryParse(salaryCtrl.text.trim()) ?? 0.0,
                          },
                          headers: {'Authorization': 'Bearer $token'},
                        );
                        if (response.statusCode == 200) {
                          setState(() {
                            _worker['name'] = nameCtrl.text.trim();
                            _worker['phone'] = phoneCtrl.text.trim();
                            _worker['position'] = positionCtrl.text.trim();
                            _worker['salary'] = double.tryParse(salaryCtrl.text.trim()) ?? 0.0;
                            _dirty = true;
                          });
                          if (context.mounted) Navigator.pop(ctx);
                        } else {
                          throw Exception('Failed to update worker (${response.statusCode})');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                        }
                        setModalState(() => isSubmitting = false);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes'),
            ),
          ],
        );
      }),
    );
  }

  void _showAddPaymentDialog() {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String type = 'Salary';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setModalState) {
        return AlertDialog(
          title: Text('Log Payment', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)', prefixIcon: Icon(Icons.currency_rupee))),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: type,
              items: ['Salary', 'Advance', 'Bonus', 'Other'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setModalState(() => type = v ?? 'Salary'),
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            const SizedBox(height: 12),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)', prefixIcon: Icon(Icons.note_alt_outlined))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text.trim());
                if (amt == null || amt <= 0 || _shopkeeperId == null) return;
                await PaymentHistoryStorage.addPayment(
                  _shopkeeperId!,
                  WorkerPayment(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    workerId: _workerId,
                    amount: amt,
                    note: noteCtrl.text.trim(),
                    type: type,
                    date: DateTime.now(),
                  ),
                );
                if (context.mounted) Navigator.pop(ctx);
                await _loadPayments();
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _deletePayment(WorkerPayment p) async {
    if (_shopkeeperId == null) return;
    await PaymentHistoryStorage.deletePayment(_shopkeeperId!, p.id);
    await _loadPayments();
  }

  Worker _asWorkerModel() {
    // Build a Worker instance for the attendance-detail page from the raw map.
    return Worker.fromJson(_worker);
  }

  @override
  Widget build(BuildContext context) {
    final name = _worker['name']?.toString() ?? '';
    final phone = _worker['phone']?.toString() ?? '';
    final position = _worker['position']?.toString() ?? 'Staff';
    final salary = double.tryParse(_worker['salary']?.toString() ?? '') ?? 0.0;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _dirty);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text('Worker Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context, _dirty)),
          actions: [IconButton(icon: const Icon(Icons.edit), onPressed: _openEditDialog)],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
              ),
              child: Column(children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: _primary.withValues(alpha: 0.1),
                  foregroundColor: _primary.withValues(alpha: 0.8),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                Text(name, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(position, style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _infoTile(Icons.phone_outlined, 'Phone', phone.isEmpty ? '—' : phone)),
                  Expanded(child: _infoTile(Icons.attach_money, 'Salary', '₹${salary.toStringAsFixed(0)}')),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => WorkerAttendanceDetailPage(worker: _asWorkerModel())),
              ),
              icon: const Icon(Icons.calendar_month),
              label: const Text('View Attendance & Payroll'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary, foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Payment History', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
              TextButton.icon(onPressed: _showAddPaymentDialog, icon: const Icon(Icons.add, size: 18), label: const Text('Log Payment')),
            ]),
            const SizedBox(height: 8),
            if (_loadingPayments)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (_payments.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Text('No payments logged yet', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
              )
            else
              ..._payments.map((p) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        backgroundColor: _primary.withValues(alpha: 0.05),
                        foregroundColor: _primary,
                        child: Icon(p.type == 'Advance' ? Icons.trending_up : Icons.payments_outlined, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${p.type} • ₹${p.amount.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(DateFormat('dd MMM yyyy').format(p.date) + (p.note.isNotEmpty ? ' • ${p.note}' : ''),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ]),
                      ),
                      IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.redAccent), onPressed: () => _deletePayment(p)),
                    ]),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Column(children: [
      Icon(icon, color: Colors.grey.shade500, size: 20),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
    ]);
  }
}

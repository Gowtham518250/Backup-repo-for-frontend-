import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'visual_widgets.dart';
import 'local_storage_service.dart';

/// Expense Tracking Page — Record shop expenses and view totals
class ExpensePage extends StatefulWidget {
  const ExpensePage({super.key});
  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage>
    with SingleTickerProviderStateMixin {
  // Modern SaaS Colors - synced with visual_widgets.dart
  static const _primary = AppColors.primary;        // #635BFF
  static const _danger = AppColors.danger;          // #EF4444

  List<Map<String, dynamic>> _expenses = [];
  bool _loading = true;
  late TabController _tab;

  final _categories = [
    'Rent', 'Electricity', 'Water', 'Internet', 'Salaries',
    'Stock Purchase', 'Transport', 'Packaging', 'Repairs', 'Miscellaneous'
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadExpenses();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    try {
      final storedExpenses = await LocalStorageService.loadExpenses();
      final loadedExpenses = storedExpenses
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList()
        ..sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
      setState(() {
        _expenses = loadedExpenses;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveExpenses() async {
    await LocalStorageService.saveExpenses(_expenses);
  }

  double get _totalThisMonth {
    final now = DateTime.now();
    return _expenses
        .where((e) {
          try {
            final d = DateTime.parse(e['date'] ?? '');
            return d.month == now.month && d.year == now.year;
          } catch (_) { return false; }
        })
        .fold(0.0, (sum, e) => sum + (double.tryParse(e['amount']?.toString() ?? '0') ?? 0));
  }

  double get _totalAll =>
      _expenses.fold(0.0, (sum, e) => sum + (double.tryParse(e['amount']?.toString() ?? '0') ?? 0));

  void _showAddDialog() {
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    String selectedCategory = _categories.first;
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 4, height: 28, color: _danger, margin: const EdgeInsets.only(right: 12)),
                Text('Add Expense', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 16),

              // Amount
              TextField(
                controller: amountC,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (₹) *',
                  prefixIcon: const Icon(Icons.currency_rupee_rounded, color: _danger),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _danger, width: 2)),
                ),
              ),
              const SizedBox(height: 12),

              // Category dropdown
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category_rounded, color: _primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => ss(() => selectedCategory = v ?? selectedCategory),
              ),
              const SizedBox(height: 12),

              // Note
              TextField(
                controller: noteC,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  prefixIcon: const Icon(Icons.note_rounded, color: _primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              // Date picker
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) ss(() => selectedDate = d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_rounded, color: _primary, size: 20),
                    const SizedBox(width: 12),
                    Text(DateFormat('dd MMM yyyy').format(selectedDate),
                        style: GoogleFonts.poppins(fontSize: 14)),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ]),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _danger, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final amt = double.tryParse(amountC.text.trim());
                    if (amt == null || amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid amount')));
                      return;
                    }
                    _expenses.insert(0, {
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'amount': amt,
                      'category': selectedCategory,
                      'note': noteC.text.trim(),
                      'date': selectedDate.toIso8601String(),
                    });
                    await _saveExpenses();
                    if (mounted) {
                      Navigator.pop(context);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('✅ Expense recorded!'),
                          backgroundColor: _primary));
                    }
                  },
                  child: Text('Save Expense', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final byCategory = <String, double>{};
    for (final e in _expenses) {
      final cat = e['category']?.toString() ?? 'Misc';
      byCategory[cat] = (byCategory[cat] ?? 0) + (double.tryParse(e['amount']?.toString() ?? '0') ?? 0);
    }
    final topCategories = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Expense Tracker', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _danger,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'History'), Tab(text: 'Summary')],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadExpenses),
        ],
      ),
      body: Column(children: [
        // Summary header
        Container(
          color: _danger,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(children: [
            _chip('₹${_totalThisMonth.toStringAsFixed(0)}', 'This Month', Icons.calendar_today),
            const SizedBox(width: 12),
            _chip('₹${_totalAll.toStringAsFixed(0)}', 'All Time', Icons.savings_rounded),
          ]),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(controller: _tab, children: [
                // History tab
                _expenses.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No expenses yet', style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey.shade500)),
                        const SizedBox(height: 8),
                        Text('Tap + to add your first expense', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400)),
                      ]))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _expenses.length,
                        itemBuilder: (_, i) => _expenseCard(_expenses[i], i),
                      ),

                // Summary tab
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('BY CATEGORY', style: GoogleFonts.spaceMono(fontSize: 11, color: Colors.grey, letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    ...topCategories.map((entry) {
                      final pct = _totalAll > 0 ? entry.value / _totalAll : 0.0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                        child: Column(children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(entry.key, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                            Text('₹${entry.value.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: _danger)),
                          ]),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: Colors.grey.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(_danger.withValues(alpha: 0.7)),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Align(alignment: Alignment.centerRight,
                              child: Text('${(pct * 100).toStringAsFixed(1)}%',
                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey))),
                        ]),
                      );
                    }),
                  ],
                ),
              ]),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: _danger,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Add Expense', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _chip(String val, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(val, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70)),
        ]),
      ]),
    );
  }

  Widget _expenseCard(Map<String, dynamic> e, int index) {
    final amt = double.tryParse(e['amount']?.toString() ?? '0') ?? 0;
    final date = DateTime.tryParse(e['date'] ?? '') ?? DateTime.now();
    final categoryColors = {
      'Rent': Colors.purple, 'Electricity': Colors.orange, 'Salaries': Colors.blue,
      'Stock Purchase': Colors.green, 'Transport': Colors.teal, 'Internet': Colors.cyan,
    };
    final color = categoryColors[e['category']] ?? _danger;

    return Dismissible(
      key: Key(e['id']?.toString() ?? index.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) async {
        setState(() => _expenses.removeAt(index));
        await _saveExpenses();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense deleted')));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.receipt_long_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e['category'] ?? 'Misc',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
            if ((e['note'] ?? '').toString().isNotEmpty)
              Text(e['note'].toString(),
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(DateFormat('dd MMM yyyy').format(date),
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade400)),
          ])),
          Text('−₹${amt.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: _danger)),
        ]),
      ),
    );
  }
}

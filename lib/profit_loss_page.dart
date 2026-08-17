import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_storage_service.dart';
import 'secure_token_storage.dart';
import 'api_client.dart';

class ProfitLossPage extends StatefulWidget {
  const ProfitLossPage({super.key});

  @override
  State<ProfitLossPage> createState() => _ProfitLossPageState();
}

class _ProfitLossPageState extends State<ProfitLossPage> {
  bool _loading = true;
  double _todayRevenue = 0.0;
  double _monthRevenue = 0.0;
  double _expenses = 0.0;
  double _todayExpenses = 0.0;
  double _netProfit = 0.0;
  List<dynamic> _sales = [];
  List<dynamic> _expensesList = [];

  @override
  void initState() {
    super.initState();
    _loadProfitLoss();
  }

  Future<void> _loadProfitLoss() async {
    setState(() => _loading = true);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0;
        final salesResp = await ApiClient.getJson(
          '/api/sales?user_id=$userId',
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 10));
        if (salesResp.statusCode == 200) {
          final parsed = List<dynamic>.from(jsonDecode(salesResp.body) as List);
          _sales = parsed;
        }
      }
    } catch (_) {
      _sales = [];
    }

    if (_sales.isEmpty) {
      _sales = await LocalStorageService.loadSales();
    }

    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isNotEmpty) {
        final expResp = await ApiClient.getJson('/api/expenses', headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 10));
        if (expResp.statusCode == 200) {
          final parsed = List<dynamic>.from(jsonDecode(expResp.body) as List);
          _expensesList = parsed;
        }
      }
    } catch (_) {
      _expensesList = [];
    }

    if (_expensesList.isEmpty) {
      _expensesList = await LocalStorageService.loadExpenses();
    }

    double todayRevenue = 0.0;
    double monthRevenue = 0.0;
    double totalExpenses = 0.0;
    double todayExpenses = 0.0;

    for (var sale in _sales) {
      final saleMap = Map<String, dynamic>.from(sale as Map);
      final created = _parseDate(saleMap['sale_date'] ?? saleMap['created_at']);
      final amount = _toDouble(saleMap['total'] ?? saleMap['total_amount'] ?? saleMap['amount']);
      if (!created.isAfter(DateTime(1970))) continue;
      if (!created.isAfter(todayStart.subtract(const Duration(days: 1)))) continue;
      if (!created.toLocal().isBefore(todayStart)) {
        todayRevenue += amount;
      }
      if (!created.isBefore(monthStart)) {
        monthRevenue += amount;
      }
    }

    for (var expense in _expensesList) {
      final expMap = Map<String, dynamic>.from(expense as Map);
      final created = _parseDate(expMap['date'] ?? expMap['expense_date'] ?? expMap['created_at']);
      final cost = _toDouble(expMap['amount'] ?? expMap['cost']);
      if (!created.isAfter(DateTime(1970))) continue;
      if (!created.isBefore(monthStart)) {
        totalExpenses += cost;
      }
      if (!created.toLocal().isBefore(todayStart)) {
        todayExpenses += cost;
      }
    }

    setState(() {
      _todayRevenue = todayRevenue;
      _monthRevenue = monthRevenue;
      _expenses = totalExpenses;
      _todayExpenses = todayExpenses;
      _netProfit = monthRevenue - totalExpenses;
      _loading = false;
    });
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime(1970);
    final raw = value.toString();
    final parsed = DateTime.tryParse(raw);
    return parsed?.toLocal() ?? DateTime(1970);
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
  }

  Widget _statCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(value, style: GoogleFonts.poppins(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit & Loss'),
        backgroundColor: const Color(0xFF10B981),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfitLoss,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Revenue vs Expenses', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    Row(children: [
                      _statCard('Today Revenue', '₹${_todayRevenue.toStringAsFixed(0)}', const Color(0xFF0F766E)),
                      const SizedBox(width: 12),
                      _statCard('Today Expense', '₹${_todayExpenses.toStringAsFixed(0)}', const Color(0xFFEF4444)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      _statCard('Month Revenue', '₹${_monthRevenue.toStringAsFixed(0)}', const Color(0xFF0F766E)),
                      const SizedBox(width: 12),
                      _statCard('Net Profit', '₹${_netProfit.toStringAsFixed(0)}', _netProfit >= 0 ? const Color(0xFF15803D) : const Color(0xFFB91C1C)),
                    ]),
                    const SizedBox(height: 24),
                    Text('Top Details', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _detailTile('Total sales records', '${_sales.length}'),
                    _detailTile('Expense entries', '${_expensesList.length}'),
                    _detailTile('Month profit percentage', _monthRevenue == 0.0 ? '0%' : '${((_netProfit / _monthRevenue) * 100).toStringAsFixed(1)}%'),
                    const SizedBox(height: 24),
                    Text('This page combines sales and expense data to give a real store-level profit view.', style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _detailTile(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700])),
          Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

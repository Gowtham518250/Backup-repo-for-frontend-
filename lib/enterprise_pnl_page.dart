import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'api_client.dart';

class EnterprisePnlPage extends StatefulWidget {
  const EnterprisePnlPage({super.key});
  @override
  State<EnterprisePnlPage> createState() => _EnterprisePnlPageState();
}

class _EnterprisePnlPageState extends State<EnterprisePnlPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  Map<String, dynamic> _pnl = {};
  List<dynamic> _transactions = [];
  Map<String, dynamic> _stockAnalysis = {};

  static const _bg = Color(0xFF0F172A);
  static const _card = Color(0xFF1E293B);
  static const _accent = Colors.tealAccent;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    try {
      final pnlRes = await ApiClient.getJson(ApiClient.enterprisePnl);
      final txRes = await ApiClient.getJson(ApiClient.enterpriseTransactions);
      final stockRes = await ApiClient.getJson(ApiClient.retailStockAnalysis);
      setState(() {
        if (pnlRes.statusCode == 200) _pnl = jsonDecode(pnlRes.body) ?? {};
        if (txRes.statusCode == 200) {
          final d = jsonDecode(txRes.body);
          _transactions = d is List ? d : (d['transactions'] ?? []);
        }
        if (stockRes.statusCode == 200) _stockAnalysis = jsonDecode(stockRes.body) ?? {};
      });
    } catch (e) {
      debugPrint('PnL fetch error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _kpiCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.poppins(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    // Generate some smooth spline data for visual flair (simulating last 7 days)
    final revSpots = [const FlSpot(0, 1), const FlSpot(1, 1.5), const FlSpot(2, 1.4), const FlSpot(3, 3.4), const FlSpot(4, 2), const FlSpot(5, 2.2), const FlSpot(6, 1.8)];
    final expSpots = [const FlSpot(0, 0.5), const FlSpot(1, 1), const FlSpot(2, 0.8), const FlSpot(3, 1.2), const FlSpot(4, 1.1), const FlSpot(5, 1.5), const FlSpot(6, 1.3)];

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revenue vs Expenses (7 Days)', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: revSpots, isCurved: true, color: Colors.tealAccent,
                    barWidth: 3, isStrokeCapRound: true, dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: Colors.tealAccent.withOpacity(0.1)),
                  ),
                  LineChartBarData(
                    spots: expSpots, isCurved: true, color: Colors.redAccent,
                    barWidth: 3, isStrokeCapRound: true, dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: Colors.redAccent.withOpacity(0.1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(List<dynamic> breakdown) {
    if (breakdown.isEmpty) return const SizedBox.shrink();
    
    final colors = [Colors.blueAccent, Colors.purpleAccent, Colors.orangeAccent, Colors.pinkAccent];
    
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2, centerSpaceRadius: 40,
                sections: breakdown.asMap().entries.map((e) {
                  final double val = (e.value['amount'] ?? 0.0) is int ? (e.value['amount'] as int).toDouble() : (e.value['amount'] ?? 0.0) as double;
                  return PieChartSectionData(
                    color: colors[e.key % colors.length],
                    value: val,
                    title: '',
                    radius: 30,
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: breakdown.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: colors[e.key % colors.length])),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.value['category']?.toString() ?? '', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
                ]),
              )).toList(),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPnlTab() {
    final revenue = (_pnl['total_revenue'] ?? 0.0).toStringAsFixed(0);
    final expenses = (_pnl['total_expenses'] ?? 0.0).toStringAsFixed(0);
    final profit = ((_pnl['total_revenue'] ?? 0.0) - (_pnl['total_expenses'] ?? 0.0)).toStringAsFixed(0);
    final isProfit = double.tryParse(profit) != null && double.parse(profit) >= 0;
    final breakdown = (_pnl['breakdown'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(children: [ _kpiCard('Revenue', 'Rs $revenue', Colors.tealAccent), _kpiCard('Expenses', 'Rs $expenses', Colors.redAccent) ]),
          const SizedBox(height: 12),
          Row(children: [ _kpiCard('Net Profit', 'Rs $profit', isProfit ? Colors.greenAccent : Colors.redAccent) ]),
          const SizedBox(height: 24),
          _buildLineChart(),
          const SizedBox(height: 24),
          if (breakdown.isNotEmpty) _buildPieChart(breakdown),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    if (_transactions.isEmpty) return Center(child: Text('No transactions found', style: GoogleFonts.poppins(color: Colors.white54)));
    return ListView.builder(
      itemCount: _transactions.length,
      itemBuilder: (ctx, i) {
        final tx = _transactions[i];
        final isCredit = (tx['type'] ?? '').toString().toUpperCase() == 'CREDIT';
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: (isCredit ? Colors.greenAccent : Colors.redAccent).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: isCredit ? Colors.greenAccent : Colors.redAccent, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tx['description']?.toString() ?? 'Transaction', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(tx['date']?.toString() ?? '', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
                ]),
              ),
              Text('Rs ${tx['amount']?.toString() ?? '0'}', style: GoogleFonts.poppins(color: isCredit ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStockTab() {
    final items = (_stockAnalysis['products'] as List?) ?? (_stockAnalysis['items'] as List?) ?? [];
    if (items.isEmpty) return Center(child: Text('No stock data', style: GoogleFonts.poppins(color: Colors.white54)));
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final p = items[i];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['product_name']?.toString() ?? '', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.tealAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('Stock: ${p['current_stock']?.toString() ?? '0'}', style: GoogleFonts.poppins(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ]),
            Text('Rs ${p['stock_value']?.toString() ?? '0'}', style: GoogleFonts.poppins(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text('Enterprise Intelligence', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.tealAccent, unselectedLabelColor: Colors.white54, indicatorColor: Colors.tealAccent,
          tabs: const [Tab(text: 'P&L'), Tab(text: 'Transactions'), Tab(text: 'Stock')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : TabBarView(controller: _tabController, children: [_buildPnlTab(), _buildTransactionsTab(), _buildStockTab()]),
    );
  }
}

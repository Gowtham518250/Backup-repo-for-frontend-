import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'local_storage_service.dart';
import 'analytics_engine.dart';
import 'tally_export_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsDashboard extends StatefulWidget {
  const AnalyticsDashboard({super.key});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  static const Color _primary = Color(0xFF6366F1);

  // ── Single source of truth for revenue / transactions / growth ──
  // Re-using AnalyticsEngine here (instead of recomputing independently)
  // is what keeps this screen's numbers in sync with the rest of the app.
  final AnalyticsEngine _engine = AnalyticsEngine();

  // Cost/profit still needs the nested item structure (the engine
  // flattens sales and drops cost_price), so we track it separately —
  // but using the SAME date + payment-ratio logic as the engine so the
  // figures stay consistent with each other.
  double _totalCost = 0;
  double _totalProfit = 0;
  double _profitMargin = 0;
  Map<String, int> _itemsSold = {};
  Map<String, double> _hourlyDistribution = {};

  bool _loading = true;
  // 0 = Today, 1 = 7 Days, 2 = 30 Days, 3 = Yearly — matches AnalyticsEngine.selectedTimeFilter
  int _selectedFilter = 0;
  static const List<String> _periodLabels = ['Today', '7 Days', '30 Days', 'Yearly'];

  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
    // "Instant" updates: silently refresh while this screen stays open,
    // so a sale made elsewhere shows up here without a manual reload.
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadAnalytics(silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    final cleaned = v.toString().replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '-') return 0.0;
    return double.tryParse(cleaned) ?? 0.0;
  }

  Future<void> _loadAnalytics({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final rawSales = await LocalStorageService.loadSales();

      // The engine canonicalizes local/cloud duplicates first. All secondary
      // analytics must consume the same canonical transaction set, otherwise
      // cost/profit/hourly charts can disagree with the KPI totals.
      _engine.recalculateAnalytics(rawSales, _selectedFilter);

      double totalCost = 0;
      final Map<String, int> itemsSold = {};
      final Map<String, double> hourlyDistribution = {};
      final now = DateTime.now();

      for (final rawSale in _engine.sales) {
        final s = Map<String, dynamic>.from(rawSale as Map);
        final dt = _engine.getLocalDate(s); // same IST-forced parsing as the engine
        final day = DateTime(dt.year, dt.month, dt.day);
        final daysAgo = DateTime(now.year, now.month, now.day).difference(day).inDays;

        final bool inRange = switch (_selectedFilter) {
          0 => daysAgo == 0,
          1 => daysAgo >= 0 && daysAgo < 7,
          2 => daysAgo >= 0 && daysAgo < 30,
          3 => dt.year == now.year,
          _ => true,
        };
        if (!inRange) continue;

        // Sales/profit are gross-business metrics. A customer owing money
        // does not make the sale itself equal to ₹0. Collected cash is shown
        // separately by the engine.
        final amount = _toDouble(s['gross_revenue'] ?? s['total_amount'] ?? s['total']);

        if (s['items'] is List) {
          for (final rawItem in s['items'] as List) {
            final item = Map<String, dynamic>.from(rawItem as Map);
            final qty = _toDouble(item['quantity'] ?? item['qty'] ?? 1);
            final itemCost = _toDouble(item['cost_price']);
            totalCost += itemCost * qty;

            final itemName = (item['product_name'] ?? item['product'] ?? item['item'] ?? 'Unknown').toString();
            itemsSold[itemName] = (itemsSold[itemName] ?? 0) + qty.round();
          }
        }

        final hkey = dt.hour.toString().padLeft(2, '0');
        hourlyDistribution[hkey] = (hourlyDistribution[hkey] ?? 0) + amount;
      }

      if (!mounted) return;
      final revenue = _engine.displayRevenue;
      setState(() {
        _totalCost = totalCost;
        _totalProfit = revenue - totalCost;
        _profitMargin = revenue > 0 ? (_totalProfit / revenue * 100) : 0;
        _itemsSold = itemsSold;
        _hourlyDistribution = hourlyDistribution;
        _loading = false;
      });
    } catch (e) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Enterprise Analytics')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final revenue = _engine.displayRevenue;
    final collected = _engine.displayCollected;
    final outstanding = _engine.displayOutstanding;
    final transactions = _engine.displayTransactions;
    final avgOrder = transactions > 0 ? revenue / transactions : 0.0;
    final growth = _engine.filteredGrowthPercentage;

    final nf = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final revenueLabel = nf.format(revenue);
    final collectedLabel = nf.format(collected);
    final outstandingLabel = nf.format(outstanding);
    final profitLabel = nf.format(_totalProfit);
    final costLabel = nf.format(_totalCost);
    final avgOrderLabel = nf.format(avgOrder);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Enterprise Analytics', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadAnalytics(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Period Selector
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<int>(
                      segments: List.generate(_periodLabels.length, (i) {
                        return ButtonSegment(
                          value: i,
                          label: Text(_periodLabels[i], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                        );
                      }),
                      selected: {_selectedFilter},
                      onSelectionChanged: (Set<int> newSelection) {
                        setState(() => _selectedFilter = newSelection.first);
                        _loadAnalytics();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (growth != 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(growth >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 16, color: growth >= 0 ? Colors.green : Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        '${growth.abs().toStringAsFixed(1)}% vs previous period',
                        style: GoogleFonts.poppins(fontSize: 12, color: growth >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),

              // KPI Cards
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildKPICard('Invoiced', revenueLabel, Colors.green, Icons.receipt_long),
                  _buildKPICard('Collected', collectedLabel, Colors.teal, Icons.payments),
                  _buildKPICard('Pending', outstandingLabel, Colors.orange, Icons.account_balance_wallet),
                  _buildKPICard('Profit', profitLabel, Colors.blue, Icons.wallet),
                  _buildKPICard('Margin', '${_profitMargin.toStringAsFixed(1)}%', Colors.orange, Icons.percent),
                  _buildKPICard('Transactions', '$transactions', Colors.purple, Icons.receipt),
                  _buildKPICard('Avg Order', avgOrderLabel, Colors.teal, Icons.shopping_cart),
                  _buildKPICard('Cost', costLabel, Colors.red, Icons.factory),
                ],
              ),
              const SizedBox(height: 24),

              // Hourly Distribution Chart
              if (_hourlyDistribution.isNotEmpty) ...[
                Text('Hourly Sales Distribution', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 12),
                Container(
                  height: 250,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                  ),
                  child: _buildHourlyChart(),
                ),
                const SizedBox(height: 24),
              ],

              // Top Products
              Text('Top Selling Products', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 12),
              ..._buildTopProductsList(),
              const SizedBox(height: 80), // room for the FAB
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigoAccent,
        icon: const Icon(Icons.description, color: Colors.white),
        label: Text('Export GST JSON (Tally)',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          final shopName = prefs.getString('shop_name') ?? 'My Shop';
          final shopGst = prefs.getString('shop_gst') ?? '';

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('📄 Generating CA-ready GST Report...')));
          }

          final result = await TallyExportService.exportGstReturns(shopName, shopGst);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(result['message'] ?? 'Export complete'),
              backgroundColor: result['success'] == true ? Colors.green : Colors.red,
            ));
          }
        },
      ),
    );
  }

  Widget _buildKPICard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildHourlyChart() {
    final spots = <FlSpot>[];
    for (int i = 0; i < 24; i++) {
      final hour = i.toString().padLeft(2, '0');
      final value = _hourlyDistribution[hour] ?? 0.0;
      spots.add(FlSpot(i.toDouble(), value));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(show: true),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _primary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTopProductsList() {
    if (_itemsSold.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text('No sales in this period', style: GoogleFonts.poppins(color: Colors.black54)),
        ),
      ];
    }

    final items = _itemsSold.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return items.take(5).map((entry) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(entry.key, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black)),
            Text('${entry.value} sold', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }).toList();
  }
}
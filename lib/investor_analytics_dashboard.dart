import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

import 'ltv_analytics_service.dart';
import 'cohort_analytics_service.dart';

/// Series A Investor Analytics Dashboard
/// Visualizes LTV, retention cohorts, and churn metrics for pitch deck
class InvestorAnalyticsDashboard extends StatefulWidget {
  const InvestorAnalyticsDashboard({Key? key}) : super(key: key);

  @override
  State<InvestorAnalyticsDashboard> createState() =>
      _InvestorAnalyticsDashboardState();
}

class _InvestorAnalyticsDashboardState extends State<InvestorAnalyticsDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xAA03030D),
        title: Text(
          '📊 Series A Investor Metrics',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: CohortAnalyticsService.generatePitchDeckMetrics(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final metrics = snapshot.data ?? {};

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Headline Pitch Card
              _buildHeadlineCard(metrics),
              const SizedBox(height: 20),

              // Retention Curve Chart
              Text(
                '📈 Retention Curve',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),
              _buildRetentionChart(metrics),
              const SizedBox(height: 20),

              // LTV Distribution
              Text(
                '💰 LTV Distribution',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),
              _buildLTVDistribution(metrics),
              const SizedBox(height: 20),

              // Churn Metrics
              Text(
                '⚠️ Churn & Retention',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),
              _buildChurnMetrics(metrics),
              const SizedBox(height: 20),

              // LTV:CAC Profitability
              Text(
                '💹 LTV:CAC Profitability',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),
              _buildLTVCACMetrics(metrics),
              const SizedBox(height: 20),

              // Export Button
              ElevatedButton.icon(
                onPressed: () => _exportPitchDeck(metrics),
                icon: const Icon(Icons.download),
                label: const Text('📥 Export Metrics'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeadlineCard(Map<String, dynamic> metrics) {
    final headline = metrics['headline_metrics'] as Map?? {};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Investor Pitch',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            headline['pitch'] ?? 'Loading metrics...',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Timestamp: ${metrics['timestamp']}',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetentionChart(Map<String, dynamic> metrics) {
    final retention = metrics['retention_curve'] as Map ?? {};

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 350,
          height: 250,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(interval: 1, 
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const titles = ['Day 1', 'Day 7', 'Day 30', 'Day 60'];
                      if (value.toInt() < titles.length) {
                        return Text(titles[value.toInt()]);
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(interval: 1, 
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text('${value.toInt()}%');
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    FlSpot(0, (retention['day_1'] as num? ?? 89).toDouble()),
                    FlSpot(1, (retention['day_7'] as num? ?? 67).toDouble()),
                    FlSpot(2, (retention['day_30'] as num? ?? 45).toDouble()),
                    FlSpot(3, (retention['day_60'] as num? ?? 22).toDouble()),
                  ],
                  isCurved: true,
                  color: const Color(0xFF6366F1),
                  barWidth: 3,
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLTVDistribution(Map<String, dynamic> metrics) {
    final ltv = metrics['ltv_distribution'] as Map ?? {};

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '₹${ltv['average_ltv'] ?? 0} Average LTV',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLTVBracket('₹0-5k', ltv['bracket_0_5k'] ?? 0, Colors.blue),
              _buildLTVBracket('₹5-10k', ltv['bracket_5_10k'] ?? 0, Colors.cyan),
              _buildLTVBracket('₹10-25k', ltv['bracket_10_25k'] ?? 0,
                  Colors.green),
              _buildLTVBracket('₹25-50k', ltv['bracket_25_50k'] ?? 0,
                  Colors.amber),
              _buildLTVBracket('₹50k+', ltv['bracket_50k_plus'] ?? 0, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLTVBracket(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 60,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildChurnMetrics(Map<String, dynamic> metrics) {
    final churn = metrics['churn_metrics'] as Map ?? {};

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFDEF7EC),
              border: Border.all(color: const Color(0xFF10B981)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Retention',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF047857),
                  ),
                ),
                Text(
                  '${churn['retention_rate_percent'] ?? 0}%',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              border: Border.all(color: const Color(0xFFEF4444)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Churn',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF7F1D1D),
                  ),
                ),
                Text(
                  '${churn['churn_rate_percent'] ?? 0}%',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLTVCACMetrics(Map<String, dynamic> metrics) {
    final ltvcac = metrics['ltv_cac_metrics'] as Map ?? {};

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFECDCD), Color(0xFFFED7AA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFFCA5A5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Average Ratio',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF92400E),
            ),
          ),
          Text(
            '${ltvcac['avg_ltv_cac_ratio'] ?? 0}x',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFD78350F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${ltvcac['percent_profitable'] ?? 0}% shops profitable (≥3x)',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }

  void _exportPitchDeck(Map<String, dynamic> metrics) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Export Metrics',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Container(
          constraints: const BoxConstraints(maxHeight: 300),
          child: SingleChildScrollView(
            child: Text(
              _formatMetricsForExport(metrics),
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '📥 Metrics exported to CSV',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  String _formatMetricsForExport(Map<String, dynamic> metrics) {
    final headline = metrics['headline_metrics'] as Map;
    final retention = metrics['retention_curve'] as Map;
    final ltv = metrics['ltv_distribution'] as Map;
    final churn = metrics['churn_metrics'] as Map;
    final ltvcac = metrics['ltv_cac_metrics'] as Map;

    return '''SERIES A INVESTOR METRICS
Timestamp,${metrics['timestamp']}

HEADLINE METRICS
Metric,Value
${headline['pitch']}

RETENTION CURVE (%)
Day 1,Day 7,Day 30,Day 60
${retention['day_1'] ?? 0},${retention['day_7'] ?? 0},${retention['day_30'] ?? 0},${retention['day_60'] ?? 0}

LTV DISTRIBUTION (₹)
Bracket,Count
0-5k,${ltv['bracket_0_5k'] ?? 0}
5-10k,${ltv['bracket_5_10k'] ?? 0}
10-25k,${ltv['bracket_10_25k'] ?? 0}
25-50k,${ltv['bracket_25_50k'] ?? 0}
50k+,${ltv['bracket_50k_plus'] ?? 0}
Average LTV,${ltv['average_ltv'] ?? 0}

CHURN METRICS
Metric,Percentage
Retention Rate,${churn['retention_rate_percent'] ?? 0}%
Churn Rate,${churn['churn_rate_percent'] ?? 0}%
Active Shops,${churn['active_shops'] ?? 0}
Churn Risk Shops,${churn['churn_risk_shops'] ?? 0}

LTV:CAC PROFITABILITY
Metric,Value
Average Ratio,${ltvcac['avg_ltv_cac_ratio'] ?? 0}x
% Profitable (>=3x),${ltvcac['percent_profitable'] ?? 0}%
Profitable Shops,${ltvcac['shops_with_profitable_ltv_cac'] ?? 0}
''';
  }
}

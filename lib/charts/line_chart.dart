import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../analytics_engine.dart';
import '../app_localizations.dart';

class RevenueLineChart extends StatelessWidget {
  final AnalyticsEngine engine;
  final Animation<double> fadeAnimation;
  final Animation<double> slideAnimation;
  final Color filterColor;
  final String currentFilterLabel;

  const RevenueLineChart({
    Key? key,
    required this.engine,
    required this.fadeAnimation,
    required this.slideAnimation,
    required this.filterColor,
    required this.currentFilterLabel,
  }) : super(key: key);

  Widget _buildEmptyChart(String message) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateTrend(List<MapEntry<dynamic, double>> entries) {
    if (entries.length < 2) return 0.0;
    final first = entries.first.value;
    final last = entries.last.value;
    if (first == 0) return 0.0;
    return ((last - first) / first) * 100;
  }

  @override
  Widget build(BuildContext context) {
    if (engine.filteredSalesCache.isEmpty) {
      return _buildEmptyChart(AppLocalizations.of(context).noProductData);
    }

    final Map<dynamic, double> dataMap;
    final List<String> labels;
    
    // Dynamically choose data source based on filter
    if (currentFilterLabel.toLowerCase().contains('week')) {
      dataMap = engine.salesByWeekCache;
      labels = dataMap.keys.toList().cast<String>();
    } else if (currentFilterLabel.toLowerCase().contains('year')) {
      dataMap = engine.salesByMonthCache;
      labels = dataMap.keys.toList().cast<String>();
    } else {
      final map = <DateTime, double>{};
      for (final s in engine.filteredSalesCache) {
        final dt = engine.getLocalDate(s);
        final day = DateTime(dt.year, dt.month, dt.day);
        final val = s['total'] is num ? (s['total'] as num).toDouble() : 0.0;
        map[day] = (map[day] ?? 0.0) + val;
      }
      final sortedEntries = map.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final recentEntries = sortedEntries.length > 7
          ? sortedEntries.sublist(sortedEntries.length - 7)
          : sortedEntries;
      dataMap = Map.fromEntries(recentEntries);
      labels = recentEntries.map((e) => "${e.key.day}/${e.key.month}").toList();
    }

    final entries = dataMap.entries.toList();
    final spots = List.generate(
      entries.length,
      (i) => FlSpot(i.toDouble(), entries[i].value),
    );

    final List<Color> gradientColors = [
      filterColor,
      filterColor.withValues(alpha: 0.5),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, slideAnimation.value),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${AppLocalizations.of(context).salesTrend}${currentFilterLabel.isNotEmpty ? ' ($currentFilterLabel)' : ''}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Color(0xFF00E5FF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timeline,
                                size: 14, color: Color(0xFF00E5FF)),
                            const SizedBox(width: 6),
                            Text(
                              AppLocalizations.of(context).last7Days,
                              style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            tooltipBgColor: isDark ? const Color(0xFF151515) : Colors.white,
                            tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            tooltipMargin: 8,
                            tooltipRoundedRadius: 8,
                            getTooltipItems: (spots) {
                              return spots.map((spot) {
                                final label = labels[spot.x.toInt()];
                                return LineTooltipItem(
                                  '$label: ',
                                  TextStyle(
                                    color: isDark ? Colors.white70 : Colors.grey[800],
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '₹${spot.y.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Color(0xFF00E5FF),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList();
                            },
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            curveSmoothness: 0.3,
                            gradient: LinearGradient(
                              colors: gradientColors,
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            barWidth: 4,
                            isStrokeCapRound: true,
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: gradientColors
                                    .map((color) => color.withValues(alpha: 0.1))
                                    .toList(),
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.white,
                                  strokeWidth: 2,
                                  strokeColor: const Color(0xFF00E5FF),
                                );
                              },
                            ),
                          ),
                        ],
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles( 
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < labels.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      labels[index],
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                              reservedSize: 32,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles( 
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    '\u20b9${(value >= 1000 ? (value/1000).toStringAsFixed(1)+'k' : value.toInt().toString())}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isDark ? Colors.white60 : Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                );
                              },
                              reservedSize: 52,
                            ),
                          ),
                          rightTitles: AxisTitles(
                              sideTitles: SideTitles( showTitles: false)),
                          topTitles: AxisTitles(
                              sideTitles: SideTitles( showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]!.withValues(alpha: 0.8),
                            strokeWidth: 1,
                            dashArray: [3, 3],
                          ),
                        ),
                        minY: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Trend indicator
                  Row(
                    children: [
                      Icon(
                        _calculateTrend(entries) >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: _calculateTrend(entries) >= 0
                            ? const Color(0xFF00E5FF)
                            : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _calculateTrend(entries) >= 0
                            ? AppLocalizations.of(context).upwardTrend
                            : AppLocalizations.of(context).downwardTrend,
                        style: TextStyle(
                          fontSize: 12,
                          color: _calculateTrend(entries) >= 0
                              ? const Color(0xFF00E5FF)
                              : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_calculateTrend(entries).abs().toStringAsFixed(1)}% ${AppLocalizations.of(context).avgChange}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import '../analytics_engine.dart';
import '../app_localizations.dart';

class RevenueBarChart extends StatelessWidget {
  final AnalyticsEngine engine;
  final Animation<double> fadeAnimation;
  final Animation<double> slideAnimation;
  final Color filterColor;

  const RevenueBarChart({
    Key? key,
    required this.engine,
    required this.fadeAnimation,
    required this.slideAnimation,
    required this.filterColor,
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
            Icon(Icons.insert_chart_outlined, size: 48, color: Colors.grey[600]),
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

  @override
  Widget build(BuildContext context) {
    try {
      if (engine.filteredSalesCache.isEmpty) {
        return _buildEmptyChart(AppLocalizations.of(context).noSalesData);
      }

      // Prefer AnalyticsEngine's canonical product aggregation. This avoids
      // losing restored invoice lines when they use product_name instead of
      // the legacy product alias.
      final map = <String, double>{};
      for (final entry in engine.productAnalyticsCache.entries) {
        final data = entry.value;
        final name = (data['display_name'] ?? data['name'] ?? entry.key)
            .toString()
            .trim();
        final rawTotal = data['total'];
        final total = rawTotal is num
            ? rawTotal.toDouble()
            : double.tryParse(rawTotal?.toString() ?? '') ?? 0.0;
        if (name.isNotEmpty && total > 0) {
          map[name] = (map[name] ?? 0.0) + total;
        }
      }

      // Fallback for legacy/nested records not represented in the cache.
      if (map.isEmpty) {
        for (final s in engine.filteredSalesCache) {
          final rawProduct =
              s['product_name'] ?? s['product'] ?? s['item'] ?? s['name'];
          final name = rawProduct?.toString().trim();
          if (name == null || name.isEmpty) continue;

          final rawTotal = s['total'] ?? s['line_total'];
          final total = rawTotal is num
              ? rawTotal.toDouble()
              : double.tryParse(rawTotal?.toString() ?? '') ?? 0.0;

          if (total > 0) {
            map[name] = (map[name] ?? 0.0) + total;
          }
        }
      }

      if (map.isEmpty) {
        return _buildEmptyChart(AppLocalizations.of(context).noProductData);
      }

    final items = map.entries.toList();
    items.sort((a, b) => b.value.compareTo(a.value));
    final topItems = items.take(6).toList();

    final List<Color> gradientColors = [
      filterColor,
      filterColor.withValues(alpha: 0.7),
    ];

    final maxValue = topItems.isNotEmpty
        ? topItems.map((e) => e.value).reduce((a, b) => a > b ? a : b)
        : 1.0;

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
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.03) // Glass effect
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 
                        Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.05),
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
                        AppLocalizations.of(context).revenueLeaders,
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
                          borderRadius: BorderRadius.circular(12),
                          color: Color(0xFF6366F1).withValues(alpha: 0.1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.leaderboard,
                                size: 14, color: Color(0xFF6366F1)),
                            const SizedBox(width: 6),
                            Text(
                              'Top ${topItems.length} ${AppLocalizations.of(context).products}',
                              style: const TextStyle(
                                color: Color(0xFF6366F1),
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
                    height: 220,
                    child: BarChart(
                      swapAnimationDuration: const Duration(milliseconds: 1000), // Slower, smoother animation
                      swapAnimationCurve: Curves.easeInOutCubic,
                      BarChartData(
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            tooltipBgColor: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? const Color(0xFF151515)
                                : Colors.white,
                            tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            tooltipMargin: 8,
                            tooltipRoundedRadius: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '${topItems[groupIndex].key}\n',
                                TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey[800],
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                                children: [
                                  TextSpan(
                                    text: '₹${rod.toY.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Color(0xFF6366F1),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const TextSpan(text: '\n'),
                                  TextSpan(
                                    text: engine.totalSales > 0 
                                      ? '${((topItems[groupIndex].value / engine.totalSales) * 100).toStringAsFixed(1)}%'
                                      : '0%',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        barGroups: topItems.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: item.value,
                                gradient: LinearGradient(
                                  colors: [
                                    gradientColors[0],
                                    gradientColors[1],
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                width: 28,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                ),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: maxValue * 1.1,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.grey[100]!,
                                ),
                              ),
                            ],
                            showingTooltipIndicators: [0],
                          );
                        }).toList(),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles( 
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < topItems.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(
                                      topItems[index].key.length > 10
                                          ? '${topItems[index].key.substring(0, 10)}..'
                                          : topItems[index].key,
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
                              reservedSize: 40,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles( 
                              showTitles: true,
                              reservedSize: 45,
                              getTitlesWidget: (value, meta) {
                                if (value == 0) return const Text('');
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    '\u20b9${(value >= 1000 ? (value/1000).toStringAsFixed(1)+'k' : value.toInt().toString())}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey[500],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: AxisTitles(
                              sideTitles: SideTitles( showTitles: false)),
                          rightTitles: AxisTitles(
                              sideTitles: SideTitles( showTitles: false)),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.grey[200]!,
                            width: 1.5,
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxValue * 1.1 / 5,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey[100]!,
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          ),
                        ),
                        alignment: BarChartAlignment.spaceBetween,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${AppLocalizations.of(context).revenueLeaders} per product',
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
    } catch (e) {
    if (kDebugMode) debugPrint('Error building bar chart: $e');
      return _buildEmptyChart(AppLocalizations.of(context).noSalesData);
    }
  }
}


/// 🥧 RevenuePieChart
/// Products sold by PRICE — shows revenue split across top products
/// Beautiful donut chart with side legend + mini progress bars

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../analytics_engine.dart';


class RevenuePieChart extends StatefulWidget {
  final AnalyticsEngine engine;
  final Animation<double> fadeAnimation;
  final Animation<double> slideAnimation;

  const RevenuePieChart({
    Key? key,
    required this.engine,
    required this.fadeAnimation,
    required this.slideAnimation,
  }) : super(key: key);

  @override
  State<RevenuePieChart> createState() => _RevenuePieChartState();
}

class _RevenuePieChartState extends State<RevenuePieChart> {
  int _touchedIndex = -1;

  static const List<Color> _palette = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF0EA5E9), // Sky
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF8B5CF6), // Violet
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
  ];

  Color _color(int i) => _palette[i % _palette.length];

  String _compact(double n) {
    if (n >= 10000000) return '${(n / 10000000).toStringAsFixed(1)}Cr';
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  Widget _empty() => Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pie_chart_outline_rounded, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('No product revenue data', style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13)),
          ],
        ),
      );

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _productNameFromSale(Map<String, dynamic> sale) {
    final raw = sale['display_name'] ??
        sale['product_name'] ??
        sale['product'] ??
        sale['name'] ??
        sale['item'] ??
        'Unknown Product';
    final name = raw.toString().trim();
    return name.isEmpty ? 'Unknown Product' : name;
  }

  double _saleRevenue(Map<String, dynamic> sale) {
    return _asDouble(
      sale['total'] ??
          sale['line_total'] ??
          sale['grand_total'] ??
          sale['total_amount'] ??
          sale['amount'] ??
          sale['revenue'],
    );
  }

  Map<String, Map<String, dynamic>> _buildRevenueProductData() {
    final direct = widget.engine.productAnalyticsCache;

    // Prefer the existing engine cache when it contains real revenue values.
    final directHasRevenue = direct.values.any(
      (v) => _asDouble(v['total']) > 0,
    );
    if (direct.isNotEmpty && directHasRevenue) {
      return {
        for (final entry in direct.entries)
          entry.key: {
            ...entry.value,
            'display_name': entry.value['display_name'] ?? entry.key,
            'total': _asDouble(entry.value['total']),
          },
      };
    }

    // Fallback: derive directly from the engine's already-filtered sales.
    // This does not alter sales/analytics calculations; it only makes the
    // visualization tolerant of different sale field names/cache versions.
    final derived = <String, Map<String, dynamic>>{};
    for (final raw in widget.engine.filteredSalesCache) {
      final sale = Map<String, dynamic>.from(raw);
      final name = _productNameFromSale(sale);
      final revenue = _saleRevenue(sale);

      final current = derived.putIfAbsent(name, () => {
        'total': 0.0,
        'count': 0,
        'quantity': 0.0,
        'display_name': name,
      });

      current['total'] = _asDouble(current['total']) + revenue;
      current['count'] = (current['count'] as int) + 1;
    }

    return derived;
  }

  @override
  Widget build(BuildContext context) {
    final productData = _buildRevenueProductData();
    if (productData.isEmpty) return _empty();

    // Sort by revenue (total sale value)
    final products = productData.entries.toList()
      ..sort((a, b) {
        final bv = _asDouble(b.value['total']);
        final av = _asDouble(a.value['total']);
        return bv.compareTo(av);
      });
    final top = products.take(6).toList();
    final grandTotal = top.fold<double>(0, (s, e) => s + _asDouble(e.value['total']));
    if (grandTotal <= 0) return _empty();

    return AnimatedBuilder(
      animation: widget.fadeAnimation,
      builder: (context, _) => Opacity(
        opacity: widget.fadeAnimation.value,
        child: Transform.translate(
          offset: Offset(0, widget.slideAnimation.value),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.09),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.pie_chart_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Revenue Split',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          Text(
                            'Top products by sale value',
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '₹${_compact(grandTotal)}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Donut + Legend ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: SizedBox(
                    height: 240,
                    child: Row(
                      children: [
                        // Donut
                        Expanded(
                          flex: 5,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  sectionsSpace: 3,
                                  centerSpaceRadius: 60,
                                  startDegreeOffset: -90,
                                  pieTouchData: PieTouchData(
                                    touchCallback: (event, resp) {
                                      setState(() {
                                        _touchedIndex = (event.isInterestedForInteractions &&
                                                resp != null &&
                                                resp.touchedSection != null)
                                            ? resp.touchedSection!.touchedSectionIndex
                                            : -1;
                                      });
                                    },
                                  ),
                                  sections: top.asMap().entries.map((entry) {
                                    final i = entry.key;
                                    final p = entry.value;
                                    final val = _asDouble(p.value['total']);
                                    final perc = grandTotal > 0 ? val / grandTotal * 100 : 0.0;
                                    final color = _color(i);
                                    final isTouched = i == _touchedIndex;
                                    return PieChartSectionData(
                                      color: color,
                                      value: val,
                                      title: perc >= 12 ? '${perc.toStringAsFixed(0)}%' : '',
                                      radius: isTouched ? 58.0 : 50.0,
                                      titleStyle: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    );
                                  }).toList(),
                                ),
                                swapAnimationDuration: const Duration(milliseconds: 500),
                                swapAnimationCurve: Curves.easeOutCubic,
                              ),
                              // Centre label
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₹${_compact(grandTotal)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF111827),
                                    ),
                                  ),
                                  Text(
                                    'Total',
                                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Legend
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: top.asMap().entries.map((entry) {
                                final i = entry.key;
                                final p = entry.value;
                                final val = _asDouble(p.value['total']);
                                final perc = grandTotal > 0 ? val / grandTotal * 100 : 0.0;
                                final color = _color(i);
                                final name = (p.value['display_name'] ?? p.value['name'] ?? p.key).toString();
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 11),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF374151),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '₹${_compact(val)}',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: color,
                                                  ),
                                                ),
                                                Text(
                                                  '${perc.toStringAsFixed(1)}%',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    color: Colors.grey[400],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: (val / grandTotal).clamp(0.0, 1.0),
                                                backgroundColor: color.withValues(alpha: 0.12),
                                                valueColor: AlwaysStoppedAnimation<Color>(color),
                                                minHeight: 4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

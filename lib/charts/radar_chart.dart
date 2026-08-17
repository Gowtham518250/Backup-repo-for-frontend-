/// 📡 RevenueRadarChart
/// Most sold products by QUANTITY — spider web polygon radar
/// Dark premium card with glowing fills + horizontal bar legend

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../analytics_engine.dart';


class RevenueRadarChart extends StatelessWidget {
  final AnalyticsEngine engine;
  final Animation<double> fadeAnimation;
  final Animation<double> slideAnimation;

  const RevenueRadarChart({
    Key? key,
    required this.engine,
    required this.fadeAnimation,
    required this.slideAnimation,
  }) : super(key: key);

  static const List<Color> _palette = [
    Color(0xFF6366F1),
    Color(0xFF06B6D4),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
  ];

  Widget _empty() => Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radar, size: 48, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text('No quantity data', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13)),
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

  double _saleQuantity(Map<String, dynamic> sale) {
    return _asDouble(sale['qty'] ?? sale['quantity'] ?? sale['units'] ?? sale['count']);
  }

  Map<String, Map<String, dynamic>> _buildQuantityProductData() {
    final direct = engine.productAnalyticsCache;

    final directHasQuantity = direct.values.any(
      (v) => _asDouble(v['quantity']) > 0,
    );
    if (direct.isNotEmpty && directHasQuantity) {
      return {
        for (final entry in direct.entries)
          entry.key: {
            ...entry.value,
            'display_name': entry.value['display_name'] ?? entry.value['name'] ?? entry.key,
            'quantity': _asDouble(entry.value['quantity']),
          },
      };
    }

    // Fallback to filtered sales so the chart remains populated even when
    // productAnalyticsCache comes from an older/newer schema.
    final derived = <String, Map<String, dynamic>>{};
    for (final raw in engine.filteredSalesCache) {
      final sale = Map<String, dynamic>.from(raw);
      final name = _productNameFromSale(sale);
      final quantity = _saleQuantity(sale);

      final current = derived.putIfAbsent(name, () => {
        'quantity': 0.0,
        'display_name': name,
      });
      current['quantity'] = _asDouble(current['quantity']) + quantity;
    }

    return derived;
  }

  @override
  Widget build(BuildContext context) {
    try {
      final productData = _buildQuantityProductData();
      if (productData.isEmpty) return _empty();

      // Build quantity list, sort descending
      var items = productData.entries.map((e) {
        final qtyD = _asDouble(e.value['quantity']);
        final name = (e.value['display_name'] ?? e.value['name'] ?? e.key).toString();
        return MapEntry(name, qtyD);
      }).toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      items = items.take(6).toList();
      final totalQty = items.fold<double>(0, (s, e) => s + e.value);
      final maxQty = items.isNotEmpty ? items.first.value : 1.0;
      if (totalQty <= 0) return _empty();

      // Radar requires ≥ 3 points
      final radarItems = List<MapEntry<String, double>>.from(items);
      while (radarItems.length < 3) {
        radarItems.add(const MapEntry('—', 0.0));
      }

      // Normalise relative to the max (so the top product fills the polygon)
      final radarVals = radarItems.map((e) => maxQty > 0 ? (e.value / maxQty * 100).clamp(0.0, 100.0) : 0.0).toList();

      return AnimatedBuilder(
        animation: fadeAnimation,
        builder: (context, _) => Opacity(
          opacity: fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, slideAnimation.value),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.20),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
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
                              colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.radar, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Volume Radar',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Most sold products by quantity',
                              style: GoogleFonts.poppins(fontSize: 11, color: Colors.white38),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${totalQty.toStringAsFixed(0)} units',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Radar Chart ──────────────────────────────────────────
                  SizedBox(
                    height: 260,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: RadarChart(
                        RadarChartData(
                          radarBackgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.5),
                          borderData: FlBorderData(show: false),
                          radarBorderData: BorderSide(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          tickCount: 4,
                          ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 0),
                          tickBorderData: BorderSide(
                            color: Colors.white.withValues(alpha: 0.07),
                            width: 1,
                          ),
                          gridBorderData: BorderSide(
                            color: Colors.white.withValues(alpha: 0.09),
                            width: 1,
                          ),
                          radarShape: RadarShape.polygon,
                          getTitle: (index, angle) {
                            try {
                              if (index < radarItems.length) {
                                final name = radarItems[index].key;
                                if (name == '—') return RadarChartTitle(text: '', angle: angle);
                                final short = name.length > 7 ? '${name.substring(0, 6)}..' : name;
                                return RadarChartTitle(
                                  text: short,
                                  angle: angle,
                                  positionPercentageOffset: 0.12,
                                );
                              }
                            } catch (_) {}
                            return RadarChartTitle(text: '', angle: angle);
                          },
                          titleTextStyle: GoogleFonts.poppins(
                            color: Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          dataSets: [
                            // Primary glow layer
                            RadarDataSet(
                              fillColor: const Color(0xFF6366F1).withValues(alpha: 0.30),
                              borderColor: const Color(0xFF6366F1),
                              entryRadius: 5,
                              borderWidth: 2.5,
                              dataEntries: radarVals.map((v) => RadarEntry(value: v)).toList(),
                            ),
                            // Inner accent layer
                            RadarDataSet(
                              fillColor: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                              borderColor: const Color(0xFF06B6D4).withValues(alpha: 0.65),
                              entryRadius: 3,
                              borderWidth: 1.5,
                              dataEntries: radarVals.map((v) => RadarEntry(value: (v * 0.55).clamp(0.0, 100.0))).toList(),
                            ),
                          ],
                        ),
                        swapAnimationDuration: const Duration(milliseconds: 800),
                        swapAnimationCurve: Curves.easeOutQuint,
                      ),
                    ),
                  ),
                  // ── Quantity bar legend ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: items.take(5).toList().asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        final pct = maxQty > 0 ? (item.value / maxQty).clamp(0.0, 1.0) : 0.0;
                        final color = _palette[i % _palette.length];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 80,
                                child: Text(
                                  item.key,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: Colors.white60,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.07),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: pct,
                                      child: Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [color, color.withValues(alpha: 0.55)],
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                item.value % 1 == 0
                                    ? item.value.toInt().toString()
                                    : item.value.toStringAsFixed(1),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('RadarChart build error: $e');
      return _empty();
    }
  }
}

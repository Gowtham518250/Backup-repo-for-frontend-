import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NavyKpiCards extends StatelessWidget {
  final double growthPercentage;
  final double totalSales;
  final int totalTransactions;
  final double averageSale;
  final int uniqueProducts;

  const NavyKpiCards({
    super.key,
    required this.growthPercentage,
    required this.totalSales,
    required this.totalTransactions,
    required this.averageSale,
    required this.uniqueProducts,
  });

  String _formatCompactNumber(double value) {
    if (value >= 10000000) {
      return '${(value / 10000000).toStringAsFixed(2)}Cr';
    } else if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(2)}L';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final isUp = growthPercentage >= 0;
    final gText = '${isUp ? '↑' : '↓'}${growthPercentage.abs().toStringAsFixed(1)}%';

    final items = [
      {
        'lbl': 'Revenue',
        'val': '₹${_formatCompactNumber(totalSales)}',
        'chg': gText,
        'up': isUp,
        'ic': Icons.trending_up_rounded,
        'kc': const Color(0xFF1B3A6B),
      },
      {
        'lbl': 'Bills',
        'val': '$totalTransactions',
        'chg': gText,
        'up': isUp,
        'ic': Icons.receipt_long_rounded,
        'kc': const Color(0xFF10B981),
      },
      {
        'lbl': 'Avg Bill',
        'val': '₹${_formatCompactNumber(averageSale)}',
        'chg': gText,
        'up': isUp,
        'ic': Icons.insights_rounded,
        'kc': const Color(0xFF2563EB),
      },
      {
        'lbl': 'Products',
        'val': '$uniqueProducts',
        'chg': gText,
        'up': isUp,
        'ic': Icons.inventory_2_rounded,
        'kc': const Color(0xFFF59E0B),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.55,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (_, idx) {
        final it = items[idx];
        final kc = it['kc'] as Color;
        final up = it['up'] as bool;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)), // Using explicit border color instead of dynamic 'border'
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: kc.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(it['ic'] as IconData, color: kc, size: 16),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: up
                          ? const Color(0xFF10B981).withValues(alpha: 0.1)
                          : const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      it['chg'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: up ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                it['val'] as String,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                it['lbl'] as String,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

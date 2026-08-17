import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NavyProfileHeader extends StatelessWidget {
  final Uint8List? logoBytes;
  final String shopName;
  final double todayRevenue;
  final double dailyGrowth;
  final int totalTransactions;
  final double averageSale;
  final String todayTopProduct;
  final VoidCallback onSettingsTap;

  const NavyProfileHeader({
    super.key,
    this.logoBytes,
    required this.shopName,
    required this.todayRevenue,
    required this.dailyGrowth,
    required this.totalTransactions,
    required this.averageSale,
    required this.todayTopProduct,
    required this.onSettingsTap,
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

  Widget _navyStatPill(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final greeting = () {
      final h = DateTime.now().hour;
      if (h < 12) return 'Good Morning';
      if (h < 17) return 'Good Afternoon';
      return 'Good Evening';
    }();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B3A6B), Color(0xFF0F2447)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Shop logo/avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                ),
                child: logoBytes != null
                    ? ClipOval(child: Image.memory(logoBytes!, fit: BoxFit.cover))
                    : Center(
                        child: Text(
                          shopName.isNotEmpty ? shopName[0].toUpperCase() : 'S',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greeting, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.75), fontSize: 12, fontWeight: FontWeight.w500)),
                    Text(shopName, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // Notification + Settings icons
              GestureDetector(
                onTap: onSettingsTap,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.settings_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Revenue display
          Text('Today\'s Revenue', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            '₹${_formatCompactNumber(todayRevenue)}',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(dailyGrowth >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: dailyGrowth >= 0 ? const Color(0xFF34D399) : const Color(0xFFFCA5A5), size: 16),
              const SizedBox(width: 4),
              Text(
                '${dailyGrowth >= 0 ? '+' : ''}${dailyGrowth.toStringAsFixed(1)}% from yesterday',
                style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Stat pills row
          Row(
            children: [
              _navyStatPill('$totalTransactions Bills', Icons.receipt_outlined),
              const SizedBox(width: 8),
              _navyStatPill('₹${_formatCompactNumber(averageSale)} Avg', Icons.insights_rounded),
              const SizedBox(width: 8),
              if (todayTopProduct.isNotEmpty)
                _navyStatPill('🔥 $todayTopProduct', Icons.star_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

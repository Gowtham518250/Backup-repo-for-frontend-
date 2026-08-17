import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NavyShopModulesSection extends StatelessWidget {
  final VoidCallback onPurchaseOrdersTap;
  final VoidCallback onOnlineStoreTap;
  final VoidCallback onWorkersTap;
  final VoidCallback onDailyReportTap;
  final VoidCallback onInventoryTap;
  final VoidCallback onKhataTap;
  final VoidCallback onExpenseTrackerTap;
  final VoidCallback onDayClosingTap;
  final VoidCallback onAllTransactionsTap;
  final VoidCallback onGstFilingTap;

  const NavyShopModulesSection({
    super.key,
    required this.onPurchaseOrdersTap,
    required this.onOnlineStoreTap,
    required this.onWorkersTap,
    required this.onDailyReportTap,
    required this.onInventoryTap,
    required this.onKhataTap,
    required this.onExpenseTrackerTap,
    required this.onDayClosingTap,
    required this.onAllTransactionsTap,
    required this.onGstFilingTap,
  });

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1B3A6B), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _navyModuleTile(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
                height: 1.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Shop Modules', Icons.widgets_rounded),
        const SizedBox(height: 16),

        // — Operations subsection —
        Row(
          children: [
            const Icon(Icons.layers_rounded, color: Color(0xFF1B3A6B), size: 14),
            const SizedBox(width: 6),
            Text(
              'Operations',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _navyModuleTile('Purchase\nOrders', Icons.local_shipping_rounded, const Color(0xFF1B3A6B), onPurchaseOrdersTap),
              const SizedBox(width: 10),
              _navyModuleTile('Online\nStore', Icons.storefront_rounded, const Color(0xFF2563EB), onOnlineStoreTap),
              const SizedBox(width: 10),
              _navyModuleTile('Workers', Icons.groups_rounded, const Color(0xFF7C3AED), onWorkersTap),
              const SizedBox(width: 10),
              _navyModuleTile('Daily\nReport', Icons.share_rounded, const Color(0xFF10B981), onDailyReportTap),
              const SizedBox(width: 10),
              _navyModuleTile('Inventory', Icons.inventory_2_rounded, const Color(0xFF0EA5E9), onInventoryTap),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // — Money & Closing subsection —
        Row(
          children: [
            const Icon(Icons.payments_rounded, color: Color(0xFF1B3A6B), size: 14),
            const SizedBox(width: 6),
            Text(
              'Money & Closing',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _navyModuleTile('Khata /\nLedger', Icons.people_alt_rounded, const Color(0xFFF59E0B), onKhataTap),
              const SizedBox(width: 10),
              _navyModuleTile('Expense\nTracker', Icons.money_off_rounded, const Color(0xFFEF4444), onExpenseTrackerTap),
              const SizedBox(width: 10),
              _navyModuleTile('Day\nClosing', Icons.lock_clock_rounded, const Color(0xFF0D9488), onDayClosingTap),
              const SizedBox(width: 10),
              _navyModuleTile('All\nTransactions', Icons.receipt_long_rounded, const Color(0xFF475569), onAllTransactionsTap),
              const SizedBox(width: 10),
              _navyModuleTile('GST\nFiling', Icons.article_rounded, const Color(0xFF1D4ED8), onGstFilingTap),
            ],
          ),
        ),
      ],
    );
  }
}

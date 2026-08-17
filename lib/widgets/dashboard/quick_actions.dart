import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NavyQuickActionsGrid extends StatelessWidget {
  final VoidCallback onNewSaleTap;
  final VoidCallback onProductsTap;
  final VoidCallback onReportsTap;
  final VoidCallback onGiftCardTap;
  final VoidCallback onHistoryTap;
  final VoidCallback onOnlineStoreTap;

  const NavyQuickActionsGrid({
    super.key,
    required this.onNewSaleTap,
    required this.onProductsTap,
    required this.onReportsTap,
    required this.onGiftCardTap,
    required this.onHistoryTap,
    required this.onOnlineStoreTap,
  });

  Widget _buildGridActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? color.withValues(alpha: 0.4) : color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isDark ? color.withValues(alpha: 0.9) : color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white.withValues(alpha: 0.9) : color.withValues(alpha: 0.9),
                height: 1.2,
              ),
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
        Text(
          'Quick Actions',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.05,
          children: [
            _buildGridActionItem(
              icon: Icons.add_shopping_cart_rounded,
              label: 'New Sale',
              color: const Color(0xFF1B3A6B), // Deep Navy
              onTap: onNewSaleTap,
              context: context,
            ),
            _buildGridActionItem(
              icon: Icons.inventory_2_rounded,
              label: 'Products',
              color: const Color(0xFF2563EB), // Royal Blue
              onTap: onProductsTap,
              context: context,
            ),
            _buildGridActionItem(
              icon: Icons.bar_chart_rounded,
              label: 'Reports',
              color: const Color(0xFF10B981), // Emerald Green
              onTap: onReportsTap,
              context: context,
            ),
            _buildGridActionItem(
              icon: Icons.card_giftcard_rounded,
              label: 'Gift Card',
              color: const Color(0xFF0EA5E9), // Sky Blue
              onTap: onGiftCardTap,
              context: context,
            ),
            _buildGridActionItem(
              icon: Icons.receipt_long_rounded,
              label: 'History',
              color: const Color(0xFF475569), // Slate
              onTap: onHistoryTap,
              context: context,
            ),
            _buildGridActionItem(
              icon: Icons.storefront_rounded,
              label: 'Online Store',
              color: const Color(0xFF1D4ED8), // Blue
              onTap: onOnlineStoreTap,
              context: context,
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

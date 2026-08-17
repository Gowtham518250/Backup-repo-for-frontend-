import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../visual_widgets.dart';

/// Owner hub for online shopping
class OnlineStoreHubPage extends StatelessWidget {
  const OnlineStoreHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Online Store',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFF1F2937)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE5E7EB)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Manage your shop online',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enable your storefront, manage inventory for customers, and handle incoming orders.',
            style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF6B7280), height: 1.4),
          ),
          const SizedBox(height: 24),
          _HubTile(
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFF6366F1),
            title: 'Manage Inventory',
            subtitle: 'Add, edit, and organize products for your online store',
            route: '/inventory',
          ),
          _HubTile(
            icon: Icons.storefront_outlined,
            color: const Color(0xFF8B5CF6),
            title: 'Store Setup',
            subtitle: 'Go live on the map, toggle online status, add voice inventory',
            route: '/online-store-manager',
          ),
          _HubTile(
            icon: Icons.receipt_long_outlined,
            color: const Color(0xFFF59E0B),
            title: 'Online Orders',
            subtitle: 'Accept or reject customer orders and deduct stock',
            route: '/owner-orders',
          ),
          const SizedBox(height: 8),
          Text(
            'Customer app (preview)',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 12),
          _HubTile(
            icon: Icons.near_me_outlined,
            color: const Color(0xFF10B981),
            title: 'Nearby Shops',
            subtitle: 'See how customers find live shops on the map',
            route: '/nearby-shops',
          ),
          _HubTile(
            icon: Icons.shopping_bag_outlined,
            color: const Color(0xFF3B82F6),
            title: 'Customer Storefront',
            subtitle: 'Preview browse & cart experience',
            route: '/customer-home',
          ),
          _HubTile(
            icon: Icons.local_shipping_outlined,
            color: const Color(0xFF6366F1),
            title: 'Order Tracking',
            subtitle: 'Preview delivery status screen for customers',
            route: '/order-tracking',
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? route;
  final VoidCallback? onTap;

  const _HubTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.route,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap ?? (route != null ? () => Navigator.pushNamed(context, route!) : null),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B7280), height: 1.35),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
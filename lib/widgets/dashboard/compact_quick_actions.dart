import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../../commission_dashboard_page.dart';
import '../../delivery_tracking_page.dart';
import '../../retail_intelligence_page.dart';

/// 🚀 Compact Quick Actions Widget
/// Premium glassmorphism horizontal quick actions section
class CompactQuickActions extends StatefulWidget {
  const CompactQuickActions({super.key});

  @override
  State<CompactQuickActions> createState() => _CompactQuickActionsState();
}

class _CompactQuickActionsState extends State<CompactQuickActions>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Quick Actions',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _buildQuickActionChip(
                  icon: Icons.fingerprint,
                  label: 'Biometric',
                  color: const Color(0xFF4F46E5),
                  onTap: () {
                    _triggerHapticFeedback();
                    Navigator.pushNamed(
                      context,
                      '/owner-biometric-register',
                      arguments: const {'fromDashboard': true},
                    );
                  },
                ),
                _buildQuickActionChip(
                  icon: Icons.psychology,
                  label: 'AI Hub',
                  color: const Color(0xFF7C3AED),
                  onTap: () {
                    _triggerHapticFeedback();
                    // ✅ PHASE 7 FIX: Navigate to actual Retail Intelligence page
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RetailIntelligencePage(),
                      ),
                    );
                  },
                ),
                _buildQuickActionChip(
                  icon: Icons.attach_money,
                  label: 'Commission',
                  color: const Color(0xFF10B981),
                  onTap: () {
                    _triggerHapticFeedback();
                    // ✅ PHASE 7 FIX: Navigate to actual Commission Dashboard
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CommissionDashboardPage(),
                      ),
                    );
                  },
                ),
                _buildQuickActionChip(
                  icon: Icons.local_shipping,
                  label: 'Delivery',
                  color: const Color(0xFF3B82F6),
                  onTap: () {
                    _triggerHapticFeedback();
                    // ✅ PHASE 7 FIX: Navigate to actual Delivery Tracking page
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeliveryTrackingPage(orderId: 101),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          _controller.forward();
        },
        onTapUp: (_) {
          _controller.reverse();
          onTap();
        },
        onTapCancel: () {
          _controller.reverse();
        },
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _triggerHapticFeedback() {
    HapticFeedback.lightImpact();
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'visual_widgets.dart';
import 'session_logout_service.dart';
import 'sync_queue_manager.dart';
import 'simple_loader.dart';

/// Modern SaaS bottom navigation bar
/// 5 tabs: Home, Analytics, Add Sale (center), Store, AI
class AppBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppBottomNav({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  bool _isOwner = true;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final prefs = await SharedPreferences.getInstance();
    final isStaff = prefs.getBool('is_staff_mode') ?? false;
    if (mounted) {
      setState(() {
        _isOwner = !isStaff;
      });
    }
  }

  void _handleRestrictedTap(int index) {
    if (!_isOwner && (index == 1 || index == 3 || index == 4)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: Owner Privileges Required'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 1. HOME / DASHBOARD
              _ModernNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isActive: widget.currentIndex == 0,
                onTap: () => _handleRestrictedTap(0),
              ),

              // 2. ADD SALE (Center - Prominent)
              _CenterActionButton(
                onTap: () => _handleRestrictedTap(1),
              ),

              // 3. STORE / MODULES
              _ModernNavItem(
                icon: Icons.storefront_rounded,
                label: 'Store',
                isActive: widget.currentIndex == 2,
                onTap: () => _handleRestrictedTap(2),
              ),

              // 4. AI CHATBOT
              _ModernNavItem(
                icon: Icons.smart_toy_rounded,
                label: 'AI',
                isActive: widget.currentIndex == 3,
                onTap: () => _handleRestrictedTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirm(BuildContext context) async {
    final pendingCount = await SyncQueueManager.getQueueSize();
    
    if (!context.mounted) return;
    
    if (pendingCount > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 8),
              const Text('Action Blocked', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('You have $pendingCount offline sales pending. Please connect to the internet to sync them before logging out, otherwise they will be permanently lost.'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B3A6B), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK, I WILL CONNECT'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              // 🔧 FIX: previously awaited performOwnerLogout() with no
              // loader and no error handling — if any internal cleanup step
              // threw, the exception stopped execution right there and the
              // Navigator call below never ran, so the button appeared to
              // do nothing. Now shows a simple loader and guarantees
              // navigation to /login regardless of what fails inside.
              try {
                await SimpleLoader.run(context, 'Logging out...', () {
                  return SessionLogoutService.performOwnerLogout();
                });
              } catch (e) {
                // Best-effort: still navigate away even if logout errored.
              }
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            child: const Text('LOGOUT'),
          ),
        ],
      ),
    );
  }
}

/// Modern navigation item widget
class _ModernNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ModernNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF1B3A6B).withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isActive ? const Color(0xFF1B3A6B) : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? const Color(0xFF1B3A6B) : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Center action button for Add Sale
class _CenterActionButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CenterActionButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B3A6B), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.all(Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x661B3A6B),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1B3A6B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
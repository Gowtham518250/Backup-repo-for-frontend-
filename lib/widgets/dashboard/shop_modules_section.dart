import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../security_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../local_storage_service.dart';
import '../../premium_ui.dart';
import '../../share_shop_page.dart';

class ShopModulesSection extends StatefulWidget {
  final VoidCallback onModuleClosed;

  const ShopModulesSection({
    Key? key,
    required this.onModuleClosed,
  }) : super(key: key);

  @override
  State<ShopModulesSection> createState() => _ShopModulesSectionState();
}

class _ShopModulesSectionState extends State<ShopModulesSection> {
  int _inventoryCount = 0;
  int _invoicesCount = 0;
  int _attendanceCount = 0;

  @override
  void initState() {
    super.initState();
    _loadOriginalData();
  }

  Future<void> _loadOriginalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Inventory Count
      try {
         final prods = await LocalStorageService.loadBackendProducts();
         _inventoryCount = prods.length;
      } catch (e) {}

      // 2. Invoices Count
      try {
          final email = prefs.getString('email') ?? 'default';
          final rawSales = prefs.getString('all_sales_$email') ?? prefs.getString('all_sales') ?? '[]';
          final List<dynamic> sales = json.decode(rawSales);
          _invoicesCount = sales.where((s) {
            final status = s['payment_status']?.toString().toUpperCase() ?? 'PAID';
            return status == 'UNPAID' || status == 'PARTIAL';
          }).length;
      } catch (e) {}

      // 3. Attendance Count
      try {
          // Attempt to find any worker key for this shopkeeper or fallback to scanning keys
          final keys = prefs.getKeys();
          final workerKey = keys.firstWhere((k) => k.startsWith('workers_'), orElse: () => 'workers_default');
          final workersJson = prefs.getString(workerKey) ?? '[]';
          final List<dynamic> workers = json.decode(workersJson);
          _attendanceCount = workers.length;
      } catch (e) {}

      if (mounted) setState(() {});
    } catch (e) {}
  }

  void _showShopModulesSheet(BuildContext context) {
    final navContext = context;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Shop modules',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1F2937)),
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 16,
                children: [
                  _buildSheetItem(
                    ctx,
                    color: const Color(0xFF4F46E5),
                    icon: Icons.inventory_2_rounded,
                    label: 'Inventory',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(navContext, '/inventory').then((_) => widget.onModuleClosed());
                    },
                  ),
                  _buildSheetItem(
                    ctx,
                    color: const Color(0xFF10B981),
                    icon: Icons.fact_check_rounded,
                    label: 'Attendance',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(navContext, '/attendance').then((_) => widget.onModuleClosed());
                    },
                  ),
                  _buildSheetItem(
                    ctx,
                    color: const Color(0xFFF59E0B),
                    icon: Icons.groups_rounded,
                    label: 'Customers',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(navContext, '/customers').then((_) => widget.onModuleClosed());
                    },
                  ),
                  _buildSheetItem(
                    ctx,
                    color: const Color(0xFF2563EB),
                    icon: Icons.receipt_long_rounded,
                    label: 'Invoices',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(navContext, '/invoices').then((_) => widget.onModuleClosed());
                    },
                  ),
                  _buildSheetItem(
                    ctx,
                    color: const Color(0xFF7C3AED),
                    icon: Icons.badge_rounded,
                    label: 'Workers',
                    onTap: () async {
                      Navigator.pop(ctx);
                      if (await SecurityService.verifyMasterPin(navContext)) {
                        if (!navContext.mounted) return;
                        Navigator.pushNamed(navContext, '/worker-management').then((_) => widget.onModuleClosed());
                      }
                    },
                  ),
                  _buildSheetItem(
                    ctx,
                    color: const Color(0xFF0D9488),
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Khata\nLedger',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(navContext, '/khata').then((_) => widget.onModuleClosed());
                    },
                  ),
                  _buildSheetItem(
                    ctx,
                    color: const Color(0xFFE11D48),
                    icon: Icons.money_off_rounded,
                    label: 'Expense\nTracker',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(navContext, '/expense').then((_) => widget.onModuleClosed());
                    },
                  ),
                  _buildSheetItem(
                    ctx,
                    color: const Color(0xFF059669),
                    icon: Icons.account_balance_rounded,
                    label: 'Bank\nRecon',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(navContext, '/bank-statement-parser');
                    },
                  ),
                  _buildSheetItem(
                    ctx,
                    color: const Color(0xFFF43F5E),
                    icon: Icons.qr_code_2_rounded,
                    label: 'Share\nShop',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(navContext, MaterialPageRoute(builder: (_) => const ShareShopPage())).then((_) => widget.onModuleClosed());
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetItem(BuildContext context, {
    required Color color,
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return BouncingWidget(
      onTap: onTap,
      child: SizedBox(
        width: (MediaQuery.of(context).size.width - 48 - 24) / 3, // 3 columns
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4B5563),
                height: 1.2,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.widgets_rounded, color: Color(0xFF8B5CF6), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Shop Modules',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _showShopModulesSheet(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Text('View All', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildOwnerQuickTile(
                  color: const Color(0xFF4F46E5),
                  icon: Icons.inventory_2,
                  label: 'Inventory',
                  subtitle: '$_inventoryCount Items',
                  onTap: () => Navigator.pushNamed(context, '/inventory').then((_) => widget.onModuleClosed()),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildOwnerQuickTile(
                  color: const Color(0xFF10B981),
                  icon: Icons.receipt,
                  label: 'Invoices',
                  subtitle: '$_invoicesCount Pending',
                  onTap: () => Navigator.pushNamed(context, '/invoices').then((_) => widget.onModuleClosed()),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildOwnerQuickTile(
                  color: const Color(0xFFF59E0B),
                  icon: Icons.how_to_reg,
                  label: 'Attendance',
                  subtitle: '$_attendanceCount Staff',
                  onTap: () => Navigator.pushNamed(context, '/attendance').then((_) => widget.onModuleClosed()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerQuickTile({
    required Color color,
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return BouncingWidget(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2), // Dynamic glow
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937),
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

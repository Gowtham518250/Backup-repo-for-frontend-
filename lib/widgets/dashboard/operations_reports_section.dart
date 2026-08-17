import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../security_service.dart';

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../local_storage_service.dart';
import '../../premium_ui.dart';

class OperationsReportsSection extends StatefulWidget {
  final VoidCallback onShareDailyReport;
  final VoidCallback onWorkerManagementClosed;

  const OperationsReportsSection({
    Key? key,
    required this.onShareDailyReport,
    required this.onWorkerManagementClosed,
  }) : super(key: key);

  @override
  State<OperationsReportsSection> createState() => _OperationsReportsSectionState();
}

class _OperationsReportsSectionState extends State<OperationsReportsSection> {
  int _pendingPurchases = 0;
  int _allTransactions = 0;
  double _monthlyExpenses = 0.0;

  @override
  void initState() {
    super.initState();
    _loadOriginalData();
  }

  Future<void> _loadOriginalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Purchase Orders
      try {
        final orders = await LocalStorageService.loadPurchaseOrders();
        _pendingPurchases = orders.where((o) {
            final status = o['status']?.toString().toUpperCase() ?? 'PENDING';
            return status == 'PENDING' || status == 'UNPAID';
        }).length;
      } catch (e) {}

      // 2. All Transactions
      try {
        final email = prefs.getString('email') ?? 'default';
        final rawSales = prefs.getString('all_sales_$email') ?? prefs.getString('all_sales') ?? '[]';
        final List<dynamic> sales = json.decode(rawSales);
        _allTransactions = sales.length;
      } catch (e) {}

      // 3. Expenses
      try {
        final expenses = await LocalStorageService.loadExpenses();
        final now = DateTime.now();
        _monthlyExpenses = expenses.where((e) {
          try {
            final dateStr = e['date'] ?? e['createdAt'] ?? '';
            if (dateStr.isEmpty) return true; // Include if no date
            final d = DateTime.parse(dateStr);
            return d.month == now.month && d.year == now.year;
          } catch (_) { return true; } // Include on parse error just in case
        }).fold(0.0, (sum, e) => sum + (double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0));
      } catch (e) {}

      if (mounted) setState(() {});
    } catch (e) {}
  }

  void _showOperationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _OperationsSheet(
        onShareDailyReport: widget.onShareDailyReport,
        onWorkerManagementClosed: widget.onWorkerManagementClosed,
        pendingPurchases: _pendingPurchases,
        monthlyExpenses: _monthlyExpenses,
        allTransactions: _allTransactions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4, left: 16, right: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
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
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.layers_rounded, color: Color(0xFF4F46E5), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Operations & Reports',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _showOperationsSheet(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildOwnerQuickTile(
                  color: const Color(0xFF4F46E5),
                  icon: Icons.local_shipping,
                  label: 'Purchases',
                  subtitle: '$_pendingPurchases Pending',
                  onTap: () => Navigator.pushNamed(context, '/purchase-orders'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildOwnerQuickTile(
                  color: const Color(0xFFE11D48),
                  icon: Icons.money_off_rounded,
                  label: 'Expenses',
                  subtitle: '₹${_monthlyExpenses.toStringAsFixed(0)}',
                  onTap: () => Navigator.pushNamed(context, '/expense'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildOwnerQuickTile(
                  color: const Color(0xFF8B5CF6),
                  icon: Icons.account_balance_wallet,
                  label: 'History',
                  subtitle: '$_allTransactions Records',
                  onTap: () => Navigator.pushNamed(context, '/all-transactions'),
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

class _OperationsSheet extends StatelessWidget {
  final VoidCallback onShareDailyReport;
  final VoidCallback onWorkerManagementClosed;
  final int pendingPurchases;
  final double monthlyExpenses;
  final int allTransactions;

  const _OperationsSheet({
    required this.onShareDailyReport,
    required this.onWorkerManagementClosed,
    required this.pendingPurchases,
    required this.monthlyExpenses,
    required this.allTransactions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Operations & Reports',
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 16,
              children: [
                _buildSheetItem(
                  context,
                  color: const Color(0xFF4F46E5),
                  icon: Icons.local_shipping_rounded,
                  label: 'Purchase\nOrders',
                  subtitle: '${pendingPurchases} Pending',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/purchase-orders');
                  },
                ),
                _buildSheetItem(
                  context,
                  color: const Color(0xFF25D366),
                  icon: Icons.share_rounded,
                  label: 'Daily\nReport',
                  onTap: () {
                    Navigator.pop(context);
                    onShareDailyReport();
                  },
                ),
                _buildSheetItem(
                  context,
                  color: const Color(0xFF7C3AED),
                  icon: Icons.groups_rounded,
                  label: 'Worker\nManagement',
                  onTap: () async {
                    Navigator.pop(context);
                    if (await SecurityService.verifyMasterPin(context)) {
                      if (!context.mounted) return;
                      Navigator.pushNamed(context, '/worker-management').then((_) => onWorkerManagementClosed());
                    }
                  },
                ),
                _buildSheetItem(
                  context,
                  color: const Color(0xFFEF4444),
                  icon: Icons.money_off_rounded,
                  label: 'Expense\nTracker',
                  subtitle: '₹${monthlyExpenses.toStringAsFixed(0)}',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/expense');
                  },
                ),
                _buildSheetItem(
                  context,
                  color: const Color(0xFF8B5CF6),
                  icon: Icons.receipt_long_rounded,
                  label: 'All\nTransactions',
                  subtitle: '${allTransactions} Records',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/all-transactions');
                  },
                ),
                _buildSheetItem(
                  context,
                  color: const Color(0xFF0D9488),
                  icon: Icons.trending_up_rounded,
                  label: 'Enterprise\nTracker',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/enterprise');
                  },
                ),
              ],
            ),
          ],
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
}

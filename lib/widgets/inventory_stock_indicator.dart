import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/spacing_utils.dart';
import '../widgets/accessibility_helper.dart';

/// 📦 Enhanced Inventory UX with Stock Warnings, Alerts, and Alternatives
class InventoryStockIndicator extends StatelessWidget {
  final int currentStock;
  final int totalStock;
  final int lowStockThreshold;
  final String productName;

  const InventoryStockIndicator({
    super.key,
    required this.currentStock,
    required this.totalStock,
    this.lowStockThreshold = 10,
    required this.productName,
  });

  @override
  Widget build(BuildContext context) {
    final stockPercentage = totalStock > 0 ? currentStock / totalStock : 0.0;
    final isLowStock = currentStock <= lowStockThreshold;
    final isOutOfStock = currentStock == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stock info row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildStockIcon(isOutOfStock, isLowStock),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _getStockStatusText(isOutOfStock, isLowStock),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStockColor(isOutOfStock, isLowStock),
                  ),
                ),
              ],
            ),
            Text(
              '$currentStock / $totalStock',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        
        // Progress bar
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            widthFactor: stockPercentage,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: _getStockColor(isOutOfStock, isLowStock),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStockIcon(bool isOutOfStock, bool isLowStock) {
    return Icon(
      isOutOfStock
          ? Icons.remove_circle_rounded
          : isLowStock
              ? Icons.warning_amber_rounded
              : Icons.inventory_2_rounded,
      size: 16,
      color: _getStockColor(isOutOfStock, isLowStock),
    );
  }

  String _getStockStatusText(bool isOutOfStock, bool isLowStock) {
    if (isOutOfStock) return 'Out of Stock';
    if (isLowStock) return 'Low Stock';
    return 'In Stock';
  }

  Color _getStockColor(bool isOutOfStock, bool isLowStock) {
    if (isOutOfStock) return const Color(0xFFEF4444);
    if (isLowStock) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }
}

/// Stock warning dialog before checkout
class StockWarningDialog extends StatelessWidget {
  final Map<String, dynamic> outOfStockItems;
  final Map<String, dynamic> lowStockItems;
  final VoidCallback onProceed;
  final VoidCallback onCancel;

  const StockWarningDialog({
    super.key,
    required this.outOfStockItems,
    required this.lowStockItems,
    required this.onProceed,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final hasOutOfStock = outOfStockItems.isNotEmpty;
    final hasLowStock = lowStockItems.isNotEmpty;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            hasOutOfStock ? Icons.error_rounded : Icons.warning_amber_rounded,
            color: hasOutOfStock ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            hasOutOfStock ? 'Out of Stock Items' : 'Low Stock Warning',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasOutOfStock) ...[
              _buildSection(
                'The following items are out of stock:',
                outOfStockItems,
                const Color(0xFFEF4444),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (hasLowStock) ...[
              _buildSection(
                'The following items have low stock:',
                lowStockItems,
                const Color(0xFFF59E0B),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (hasOutOfStock)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_rounded, size: 16, color: const Color(0xFFEF4444)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'You cannot proceed with the sale as some items are out of stock.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Go Back'),
        ),
        if (!hasOutOfStock)
          ElevatedButton(
            onPressed: onProceed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Proceed'),
          ),
      ],
    );
  }

  Widget _buildSection(String title, Map<String, dynamic> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...items.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                const SizedBox(width: 20),
                Text(
                  '• ${entry.key}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                Text(
                  'Stock: ${entry.value}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}

/// Low stock threshold settings
class LowStockThresholdSettings extends StatefulWidget {
  final int currentThreshold;
  final ValueChanged<int> onThresholdChanged;

  const LowStockThresholdSettings({
    super.key,
    required this.currentThreshold,
    required this.onThresholdChanged,
  });

  @override
  State<LowStockThresholdSettings> createState() => _LowStockThresholdSettingsState();
}

class _LowStockThresholdSettingsState extends State<LowStockThresholdSettings> {
  late int _threshold;

  @override
  void initState() {
    super.initState();
    _threshold = widget.currentThreshold;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Low Stock Alert Threshold',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Alert me when stock falls below this value',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Threshold selector
          Row(
            children: [
              IconButton(
                onPressed: _threshold > 1
                    ? () {
                        setState(() => _threshold--);
                        HapticFeedback.lightImpact();
                        widget.onThresholdChanged(_threshold);
                      }
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Container(
                width: 60,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
                child: Center(
                  child: Text(
                    '$_threshold',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() => _threshold++);
                  HapticFeedback.lightImpact();
                  widget.onThresholdChanged(_threshold);
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Product alternatives suggestion
class ProductAlternativesSuggestion extends StatelessWidget {
  final String outOfStockProduct;
  final List<Map<String, dynamic>> alternatives;
  final ValueChanged<Map<String, dynamic>> onSelectAlternative;

  const ProductAlternativesSuggestion({
    super.key,
    required this.outOfStockProduct,
    required this.alternatives,
    required this.onSelectAlternative,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: const Color(0xFF6366F1)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Alternatives for $outOfStockProduct',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Alternatives list
          ...alternatives.take(3).map((alternative) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onSelectAlternative(alternative);
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: const Color(0xFF10B981)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alternative['name'] ?? 'Unknown',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '₹${alternative['price'] ?? '0.00'}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'In Stock',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: const Color(0xFF10B981),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.add_circle, color: const Color(0xFF6366F1)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
          
          const SizedBox(height: AppSpacing.sm),
          
          // View more alternatives button
          if (alternatives.length > 3)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                // Show all alternatives
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View all ${alternatives.length} alternatives',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF6366F1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 16, color: const Color(0xFF6366F1)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Cart stock level indicator
class CartStockLevelIndicator extends StatelessWidget {
  final Map<String, int> cartItems;
  final Map<String, int> availableStock;

  const CartStockLevelIndicator({
    super.key,
    required this.cartItems,
    required this.availableStock,
  });

  @override
  Widget build(BuildContext context) {
    final itemsWithLowStock = cartItems.entries.where((entry) {
      final available = availableStock[entry.key] ?? 0;
      return available < entry.value;
    }).toList();

    if (itemsWithLowStock.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: const Color(0xFFF59E0B), size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Stock Alert',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Some items in your cart have insufficient stock:',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...itemsWithLowStock.take(3).map((entry) {
            final available = availableStock[entry.key] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const SizedBox(width: 28),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Need ${entry.value}, Have $available',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: const Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

/// Quick stock check widget
class QuickStockCheck extends StatelessWidget {
  final String productName;
  final int currentStock;
  final VoidCallback onViewDetails;

  const QuickStockCheck({
    super.key,
    required this.productName,
    required this.currentStock,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final isLowStock = currentStock < 10;
    final isOutOfStock = currentStock == 0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onViewDetails();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isOutOfStock
              ? const Color(0xFFEF4444).withValues(alpha: 0.1)
              : isLowStock
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                  : const Color(0xFF10B981).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isOutOfStock
                ? const Color(0xFFEF4444)
                : isLowStock
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF10B981),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOutOfStock ? Icons.block : isLowStock ? Icons.trending_down : Icons.inventory_2,
              size: 14,
              color: isOutOfStock
                  ? const Color(0xFFEF4444)
                  : isLowStock
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF10B981),
            ),
            const SizedBox(width: 4),
            Text(
              '$currentStock left',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isOutOfStock
                    ? const Color(0xFFEF4444)
                    : isLowStock
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
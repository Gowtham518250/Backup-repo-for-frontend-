import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/accessibility_helper.dart';
import '../theme/spacing_utils.dart';

/// 📄 Enhanced Invoice Card with Advanced Features
/// Provides items breakdown, preview thumbnails, filters, and swipe actions
class EnhancedInvoiceCard extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback? onTap;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final VoidCallback? onViewDetails;
  final VoidCallback? onPrint;

  const EnhancedInvoiceCard({
    super.key,
    required this.invoice,
    this.onTap,
    this.onShare,
    this.onDelete,
    this.onViewDetails,
    this.onPrint,
  });

  @override
  State<EnhancedInvoiceCard> createState() => _EnhancedInvoiceCardState();
}

class _EnhancedInvoiceCardState extends State<EnhancedInvoiceCard>
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
    final customerName = widget.invoice['customer_name'] ?? 'Cash Customer';
    final totalAmount = widget.invoice['total_amount'] ?? 0.0;
    final items = widget.invoice['line_items'] as List<dynamic>? ?? [];
    final paymentMethod = widget.invoice['payment_method'] ?? 'Cash';
    final invoiceDate = widget.invoice['invoice_date'] ?? DateTime.now().toString().split('T')[0];
    final status = widget.invoice['status'] ?? 'PAID';
    
    return Dismissible(
      key: Key(widget.invoice['id'].toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        HapticFeedback.mediumImpact();
        if (direction == DismissDirection.endToStart) {
          widget.onDelete?.call();
        }
      },
      background: _buildSwipeBackground(Colors.red, Icons.delete),
      secondaryBackground: _buildSwipeBackground(Colors.blue, Icons.share),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Share action
          widget.onShare?.call();
          return false;
        }
        return true;
      },
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
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
              border: Border.all(
                color: _getStatusColor(status).withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with thumbnail and status
                Row(
                  children: [
                    // Invoice preview thumbnail
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.receipt_long,
                        size: 24,
                        color: _getStatusColor(status),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Invoice info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.invoice['invoice_number'] ?? 'INV-0001',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 12,
                                color: const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  customerName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _getStatusColor(status),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(status),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                
                // Date and payment method
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      invoiceDate,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Icon(
                      Icons.payment,
                      size: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      paymentMethod,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                
                // Amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    // Quick action buttons
                    Row(
                      children: [
                        AccessibilityHelper.accessibleIconButton(
                          icon: Icons.print,
                          semanticLabel: 'Print invoice',
                          onPressed: widget.onPrint ?? () {},
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AccessibilityHelper.accessibleIconButton(
                          icon: Icons.share,
                          semanticLabel: 'Share invoice',
                          onPressed: widget.onShare ?? () {},
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AccessibilityHelper.accessibleIconButton(
                          icon: Icons.view_list,
                          semanticLabel: 'View items',
                          onPressed: widget.onViewDetails ?? () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeBackground(Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return const Color(0xFF10B981);
      case 'PARTIAL':
        return const Color(0xFFF59E0B);
      case 'UNPAID':
        return const Color(0xFFEF4444);
      case 'OVERDUE':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }
}

/// Invoice items breakdown modal
class InvoiceItemsBreakdown extends StatelessWidget {
  final List<dynamic> items;
  final double totalAmount;

  const InvoiceItemsBreakdown({
    super.key,
    required this.items,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items Breakdown',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Items list
          Expanded(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final item = items[index] as Map<String, dynamic>;
                final productName = item['product_name'] ?? 'Unknown';
                final quantity = item['quantity'] ?? 1;
                final unitPrice = item['unit_price'] ?? 0.0;
                final lineTotal = quantity * unitPrice;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productName,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '$quantity x ₹${unitPrice.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₹${lineTotal.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Total
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '₹${totalAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Invoice filter chips
class InvoiceFilterChips extends StatefulWidget {
  final List<String> availableFilters;
  final ValueChanged<String> onFilterChanged;

  const InvoiceFilterChips({
    super.key,
    required this.availableFilters,
    required this.onFilterChanged,
  });

  @override
  State<InvoiceFilterChips> createState() => _InvoiceFilterChipsState();
}

class _InvoiceFilterChipsState extends State<InvoiceFilterChips> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
        itemCount: widget.availableFilters.length,
        itemBuilder: (context, index) {
          final filter = widget.availableFilters[index];
          final isSelected = _selectedFilter == filter;
          
          return GestureDetector(
            onTap: () {
              setState(() => _selectedFilter = filter);
              HapticFeedback.lightImpact();
              widget.onFilterChanged(filter);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF6366F1)
                      : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Invoice thumbnail preview
class InvoiceThumbnail extends StatelessWidget {
  final String? thumbnailUrl;

  const InvoiceThumbnail({
    super.key,
    this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: thumbnailUrl != null && thumbnailUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.receipt_long, size: 24, color: Color(0xFF94A3B8)),
                  );
                },
              ),
            )
          : const Center(
              child: Icon(Icons.receipt_long, size: 24, color: Color(0xFF94A3B8)),
            ),
    );
  }
}

/// Quick action swipe buttons for invoices
class InvoiceSwipeActions extends StatelessWidget {
  final VoidCallback onViewItems;
  final VoidCallback? onEdit;
  final VoidCallback onPrint;
  final VoidCallback onShare;
  final VoidCallback? onDelete;

  const InvoiceSwipeActions({
    super.key,
    required this.onViewItems,
    this.onEdit,
    required this.onPrint,
    required this.onShare,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          AccessibilityHelper.accessibleIconButton(
            icon: Icons.list_alt,
            semanticLabel: 'View items',
            onPressed: onViewItems,
          ),
          if (onEdit != null)
            AccessibilityHelper.accessibleIconButton(
              icon: Icons.edit,
              semanticLabel: 'Edit invoice',
              onPressed: onEdit!,
            ),
          AccessibilityHelper.accessibleIconButton(
            icon: Icons.print,
            semanticLabel: 'Print',
            onPressed: onPrint,
          ),
          AccessibilityHelper.accessibleIconButton(
            icon: Icons.share,
            semanticLabel: 'Share',
            onPressed: onShare,
          ),
          if (onDelete != null)
            AccessibilityHelper.accessibleIconButton(
              icon: Icons.delete,
              semanticLabel: 'Delete',
              onPressed: onDelete!,
            ),
        ],
      ),
    );
  }
}
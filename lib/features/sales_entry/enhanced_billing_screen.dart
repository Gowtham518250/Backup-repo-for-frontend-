import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/spacing_utils.dart';
import '../../widgets/accessibility_helper.dart';
import '../../widgets/premium_animations.dart';
import 'controllers/sales_entry_provider.dart';

/// ⌨️ Enhanced Billing Page with Keyboard Shortcuts and Partial Payments
class EnhancedBillingScreen extends StatefulWidget {
  const EnhancedBillingScreen({super.key});

  @override
  State<EnhancedBillingScreen> createState() => _EnhancedBillingScreenState();
}

class _EnhancedBillingScreenState extends State<EnhancedBillingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _paymentMethodController;
  late Animation<double> _expandAnimation;
  
  @override
  void initState() {
    super.initState();
    _paymentMethodController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _paymentMethodController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _paymentMethodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SalesEntryProvider>();
    
    return Focus(
      onKey: _handleKeyPress,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              // Header with keyboard shortcuts hint
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Icon(Icons.keyboard, color: const Color(0xFF64748B)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Billing',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    // Keyboard shortcuts hint
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ctrl+G Generate Bill  Ctrl+S Save',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppSpacing.md),
              
              // Payment method selection (prominent)
              _buildPaymentMethodSelector(provider),
              
              const SizedBox(height: AppSpacing.lg),
              
              // Partial payment input
              _buildPartialPaymentInput(provider),
              
              const SizedBox(height: AppSpacing.xl),
              
              // Main action buttons
              _buildActionButtons(provider),
            ],
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKeyPress(FocusNode node, RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
    
    // Ctrl+G - Generate Bill
    if (event.logicalKey == LogicalKeyboardKey.keyG && 
        (event.logicalKey == LogicalKeyboardKey.controlLeft || 
         event.logicalKey == LogicalKeyboardKey.controlRight)) {
      HapticFeedback.mediumImpact();
      // Trigger generate bill
      return KeyEventResult.handled;
    }
    
    // Ctrl+S - Save Sale
    if (event.logicalKey == LogicalKeyboardKey.keyS && 
        (event.logicalKey == LogicalKeyboardKey.controlLeft || 
         event.logicalKey == LogicalKeyboardKey.controlRight)) {
      HapticFeedback.mediumImpact();
      // Trigger save sale
      _saveSale();
      return KeyEventResult.handled;
    }
    
    // Ctrl+P - Print
    if (event.logicalKey == LogicalKeyboardKey.keyP && 
        (event.logicalKey == LogicalKeyboardKey.controlLeft || 
         event.logicalKey == LogicalKeyboardKey.controlRight)) {
      HapticFeedback.mediumImpact();
      // Trigger print
      return KeyEventResult.handled;
    }
    
    // Escape - Cancel
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      HapticFeedback.lightImpact();
      Navigator.pop(context);
      return KeyEventResult.handled;
    }
    
    return KeyEventResult.ignored;
  }

  Future<void> _saveSale() async {
    final provider = context.read<SalesEntryProvider>();
    final success = await provider.submitSale();
    
    if (success && mounted) {
      HapticFeedback.heavyImpact();
      Navigator.pop(context);
    }
  }

  Widget _buildPaymentMethodSelector(SalesEntryProvider provider) {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        return SizeTransition(
          axis: Axis.vertical,
          sizeFactor: const AlwaysStoppedAnimation(1.0),
          child: Container(
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
                    Icon(Icons.payment_rounded, size: 28, color: const Color(0xFF6366F1)),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Payment Method',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                
                // Payment options with icons prominently displayed
                Column(
                  children: [
                    _buildPaymentOption(
                      icon: Icons.payments_rounded,
                      iconColor: const Color(0xFF10B981),
                      label: 'Cash',
                      isSelected: provider.selectedPaymentMethod == 'Cash',
                      onTap: () {
                        provider.setPaymentMethod('Cash');
                        HapticFeedback.lightImpact();
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildPaymentOption(
                      icon: Icons.qr_code_scanner_rounded,
                      iconColor: const Color(0xFF6366F1),
                      label: 'UPI / QR Code',
                      isSelected: provider.selectedPaymentMethod == 'UPI',
                      onTap: () {
                        provider.setPaymentMethod('UPI');
                        HapticFeedback.lightImpact();
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildPaymentOption(
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      label: 'Credit / Borrow',
                      isSelected: provider.selectedPaymentMethod == 'Credit',
                      onTap: () {
                        provider.setPaymentMethod('Credit');
                        HapticFeedback.lightImpact();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isSelected ? iconColor.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? iconColor : const Color(0xFFE2E8F0),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: iconColor,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? iconColor : const Color(0xFF1E293B),
                    ),
                  ),
                  if (isSelected)
                    const SizedBox(height: 4),
                  if (isSelected)
                    Text(
                      'Selected',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: iconColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: iconColor, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPartialPaymentInput(SalesEntryProvider provider) {
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
              Icon(Icons.wallet_rounded, size: 28, color: const Color(0xFF6366F1)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Partial Payment',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              Switch(
                value: false,
                onChanged: (value) {
                  // Toggle partial payment mode
                },
                activeColor: const Color(0xFF6366F1),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Enter Payment Amount',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      height: AccessibilityHelper.minTouchTargetSize,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF6366F1),
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        child: Row(
                          children: [
                            const Icon(Icons.currency_rupee, color: Color(0xFF6366F1)),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: TextFormField(
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Enter amount',
                                  hintStyle: TextStyle(fontSize: 16),
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Balance Due',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '₹${provider.totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(SalesEntryProvider provider) {
    return Column(
      children: [
        // TOP ROW: Primary Actions
        Row(
          children: [
            Expanded(
              child: _buildPremiumButton(
                icon: Icons.receipt_long_rounded,
                iconSize: 24,
                label: 'Generate Bill',
                backgroundColor: const Color(0xFF6366F1),
                isLoading: provider.isGeneratingBill,
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await provider.generateBillPreview();
                  // Show bill preview dialog
                },
                shortcut: 'Ctrl+G',
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _buildPremiumButton(
                icon: Icons.check_circle_rounded,
                iconSize: 24,
                label: 'Save Sale',
                backgroundColor: const Color(0xFF10B981),
                isLoading: provider.isSaving,
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  await _saveSale();
                },
                shortcut: 'Ctrl+S',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        
        // BOTTOM ROW: Payment Methods (with icons prominently displayed)
        Row(
          children: [
            Expanded(
              child: _buildPaymentButton(
                icon: Icons.payments_rounded,
                iconSize: 20,
                label: 'Cash',
                color: const Color(0xFF10B981),
                onPressed: () {
                  provider.setPaymentMethod('Cash');
                  HapticFeedback.lightImpact();
                },
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _buildPaymentButton(
                icon: Icons.qr_code_scanner_rounded,
                iconSize: 20,
                label: 'UPI / QR',
                color: const Color(0xFF6366F1),
                onPressed: () {
                  provider.setPaymentMethod('UPI');
                  HapticFeedback.lightImpact();
                },
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _buildPaymentButton(
                icon: Icons.account_balance_wallet_rounded,
                iconSize: 20,
                label: 'Credit',
                color: const Color(0xFFF59E0B),
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  await provider.saveAsCredit();
                },
              ),
            ),
          ],
        ),
        
        // Keyboard shortcuts reminder
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.keyboard, size: 16, color: const Color(0xFF6366F1)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Shortcuts: Ctrl+G Generate Bill | Ctrl+S Save | Ctrl+P Print | Esc Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF6366F1),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required VoidCallback onPressed,
    bool isLoading = false,
    double iconSize = 20,
    String? shortcut,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        onTapDown: isLoading ? null : (_) => HapticFeedback.lightImpact(),
        borderRadius: BorderRadius.circular(12),
        splashColor: backgroundColor.withValues(alpha: 0.2),
        child: Container(
          height: AccessibilityHelper.minTouchTargetSize + 12,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                backgroundColor,
                backgroundColor.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: iconSize),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (shortcut != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          shortcut,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPaymentButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    double iconSize = 18,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        onTapDown: (_) => HapticFeedback.lightImpact(),
        borderRadius: BorderRadius.circular(12),
        splashColor: color.withValues(alpha: 0.1),
        child: Container(
          height: AccessibilityHelper.minTouchTargetSize,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 2,
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: iconSize),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keyboard shortcuts help dialog
class KeyboardShortcutsDialog extends StatelessWidget {
  const KeyboardShortcutsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final shortcuts = [
      {'shortcut': 'Ctrl+G', 'action': 'Generate Bill', 'icon': Icons.receipt_long},
      {'shortcut': 'Ctrl+S', 'action': 'Save Sale', 'icon': Icons.save},
      {'shortcut': 'Ctrl+P', 'action': 'Print Invoice', 'icon': Icons.print},
      {'shortcut': 'Ctrl+N', 'action': 'New Sale', 'icon': Icons.add},
      {'shortcut': 'Esc', 'action': 'Cancel / Go Back', 'icon': Icons.arrow_back},
      {'shortcut': 'F1', 'action': 'Help', 'icon': Icons.help},
    ];

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.keyboard, color: const Color(0xFF6366F1)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Keyboard Shortcuts',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: shortcuts.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final item = shortcuts[index];
            return ListTile(
              leading: Container(
                width: 60,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  item['shortcut']?.toString() ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ),
              title: Text(
                item['action']?.toString() ?? '',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              trailing: Icon(item['icon'] as IconData, color: const Color(0xFF64748B)),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
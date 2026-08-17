import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../controllers/sales_entry_provider.dart';

class SmartPaymentSection extends StatefulWidget {
  const SmartPaymentSection({Key? key}) : super(key: key);

  @override
  State<SmartPaymentSection> createState() => _SmartPaymentSectionState();
}

class _SmartPaymentSectionState extends State<SmartPaymentSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SalesEntryProvider>(
      builder: (context, provider, child) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PAYMENT METHOD',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF4B5563),
                  fontSize: 10,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),

              // Segmented payment control
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _PayModeSegment(
                        label: 'Cash',
                        icon: Icons.money_rounded,
                        isSelected: !provider.isOnlinePayment,
                        onTap: () => provider.setOnlinePayment(false),
                      ),
                    ),
                    Expanded(
                      child: _PayModeSegment(
                        label: 'UPI / QR',
                        icon: Icons.qr_code_2_rounded,
                        isSelected: provider.isOnlinePayment,
                        onTap: () => provider.setOnlinePayment(true),
                      ),
                    ),
                  ],
                ),
              ),

              if (provider.isOnlinePayment) ...[
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF4F46E5,
                              ).withValues(alpha: 0.15),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                          border: Border.all(
                            color: const Color(
                              0xFF4F46E5,
                            ).withValues(alpha: 0.1),
                            width: 2,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: QrImageView(
                          data:
                              'upi://pay?pa=test@upi&pn=${Uri.encodeComponent(provider.shopName)}&am=${provider.totalAmount.toStringAsFixed(2)}&cu=INR',
                          version: QrVersions.auto,
                          size: 160.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) => Text(
                          'Scan to Pay Exactly ₹${provider.totalAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color.lerp(
                              const Color(0xFF4F46E5),
                              const Color(0xFF6366F1),
                              _pulseController.value,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PayModeSegment extends StatelessWidget {
  const _PayModeSegment({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFF111827)
                  : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF111827)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

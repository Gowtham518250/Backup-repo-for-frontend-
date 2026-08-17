import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../controllers/sales_entry_provider.dart';

class CompactTotalCard extends StatelessWidget {
  const CompactTotalCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SalesEntryProvider>(
      builder: (context, provider, child) {
        final double subtotal = provider.subtotalAmount;
        final double totalAmount = provider.totalAmount;
        final double cgst = provider.withTax ? subtotal * 0.09 : 0.0;
        final double sgst = provider.withTax ? subtotal * 0.09 : 0.0;

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header row ---
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt, color: Color(0xFF4F46E5), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'BILL SUMMARY',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6B7280),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  // GST status chip
                  GestureDetector(
                    onTap: provider.toggleTax,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: provider.withTax
                            ? const Color(0xFF10B981).withValues(alpha: 0.1)
                            : const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: provider.withTax
                              ? const Color(0xFF10B981).withValues(alpha: 0.4)
                              : const Color(0xFFEF4444).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            provider.withTax ? Icons.check_circle : Icons.cancel,
                            size: 11,
                            color: provider.withTax ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            provider.withTax ? 'GST ON' : 'GST OFF',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: provider.withTax ? const Color(0xFF059669) : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // --- Main Amount ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹',
                    style: GoogleFonts.spaceMono(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    totalAmount.toStringAsFixed(0),
                    style: GoogleFonts.spaceMono(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: -1.5,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Items pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${provider.entries.length} items',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ],
              ),
              
              if (provider.withTax && subtotal > 0) ...[
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFF3F4F6), height: 1),
                const SizedBox(height: 12),
                _TaxRow(label: 'Subtotal', value: '₹${subtotal.toStringAsFixed(2)}', isLight: true),
                const SizedBox(height: 4),
                _TaxRow(label: 'CGST (9%)', value: '₹${cgst.toStringAsFixed(2)}', color: const Color(0xFF6366F1)),
                const SizedBox(height: 4),
                                _TaxRow(label: 'SGST (9%)', value: '\u20b9', color: const Color(0xFF6366F1)),
              ],
            ],
          ),
         ),
        ),
       );
      },
    );
  }
}

class _TaxRow extends StatelessWidget {
  const _TaxRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.isLight = false,
    this.color,
  });

  final String label;
  final String value;
  final bool isBold;
  final bool isLight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? (isLight ? Colors.black54 : Colors.black87);
    final fontSize = isBold ? 14.0 : 11.5;
    final weight = (isBold || !isLight) ? FontWeight.w700 : FontWeight.w500;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: fontSize, fontWeight: weight, color: textColor),
        ),
        Text(
          value,
          style: GoogleFonts.spaceMono(fontSize: fontSize, fontWeight: weight, color: textColor),
        ),
      ],
    );
  }
}

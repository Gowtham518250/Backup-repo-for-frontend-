import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 🎨 MODERN SAAS DESIGN SYSTEM - Startup Grade Product
// Premium, clean, professional - inspired by Stripe, Shopify, Linear, Notion
// ═══════════════════════════════════════════════════════════════════════════

// ── PRIMARY COLOR PALETTE ─────────────────────────────────────────────────
class AppColors {

  // Semantic tokens for SalesEntryPage
  static const brand        = Color(0xFF6366F1);
  static const brandLight   = Color(0xFFEEF2FF);
  static const brandHover   = Color(0xFF4F46E5);
  static const brandSubtle  = Color(0xFF818CF8);
  static const positive     = Color(0xFF10B981);
  static const listening    = Color(0xFF22C55E);
  static const caution      = Color(0xFFF59E0B);
  static const critical     = Color(0xFFEF4444);
  static const rowSurface   = Color(0xFFF9FAFB);
  static const rowBorder    = Color(0xFFE5E7EB);
  static const subtotalSurface = Color(0xFFF1F5F9);
  static const subtotalText    = Color(0xFF0F172A);

  // Brand Colors (Professional Navy Theme)
  static const primary        = Color(0xFF1B3A6B);   // Navy Blue - Main Brand
  static const primaryHover   = Color(0xFF142B52);   // Darker Navy
  static const primaryLight   = Color(0xFFE8EEF8);   // Navy Tint
  
  // Status Colors
  static const success        = Color(0xFF10B981);   // Green
  static const warning        = Color(0xFFF59E0B);   // Amber
  static const danger         = Color(0xFFEF4444);   // Red
  static const info           = Color(0xFF3B82F6);   // Blue
  
  // Background & Surface
  static const background     = Color(0xFFF8FAFC);   // Light Slate Gray
  static const surface        = Color(0xFFFFFFFF);   // Pure White
  static const surfaceAlt     = Color(0xFFF1F5F9);   // Slate 100
  static const surfaceHover   = Color(0xFFE2E8F0);   // Slate 200
  
  // Text Colors
  static const textPrimary    = Color(0xFF0F172A);   // Slate 900
  static const textSecondary  = Color(0xFF475569);   // Slate 600
  static const textTertiary   = Color(0xFF94A3B8);   // Slate 400
  static const textMuted      = textTertiary;
  static const textInverse    = Color(0xFFFFFFFF);   // White Text
  
  // Borders & Dividers
  static const border         = Color(0xFFE5E7EB);   // Light Border
  static const borderDark     = Color(0xFFD1D5DB);   // Darker Border
  static const divider        = Color(0xFFF3F4F6);   // Divider Color
  
  // Legacy Aliases (for compatibility)
  static const secondary      = primary;
  static const accent         = primary;
  static const electric       = primary;
  static const coral          = danger;
  static const cardDark       = Color(0xFF1E293B);   // Slate 800
  static const surfaceDark    = Color(0xFF0F172A);   // Slate 900
  static const surfaceDark2   = Color(0xFF1E293B);   // Slate 800
  static const borderDark2    = Color(0xFF334155);   // Slate 700
  static const text1          = textPrimary;
  static const text2          = textSecondary;
  static const error          = danger;
}

// ── SPACING SYSTEM (ONLY 8, 16, 24, 32) ──────────────────────────────────
class AppSpacing {
  static const double xs   = 8.0;     // Extra Small
  static const double sm   = 16.0;    // Small
  static const double md   = 24.0;    // Medium
  static const double lg   = 32.0;    // Large
  
  // Common combinations
  static const EdgeInsets paddingXs  = EdgeInsets.all(8);
  static const EdgeInsets paddingSm  = EdgeInsets.all(16);
  static const EdgeInsets paddingMd  = EdgeInsets.all(24);
  static const EdgeInsets paddingLg  = EdgeInsets.all(32);
}

// ── TYPOGRAPHY SYSTEM (Google Fonts Inter) ─────────────────────────────
class AppTypography {
  // Dashboard Title - 32px Bold
  static TextStyle titleLarge = GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );
  
  // Section Title - 22px SemiBold
  static TextStyle titleMedium = GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );
  
  // Card Title - 18px SemiBold
  static TextStyle titleSmall = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  // Body Text - 16px
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  
  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  
  // Small Text - 13px
  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
  
  // Caption - 12px
  static TextStyle caption = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );
}

// ── SHADOW SYSTEM ─────────────────────────────────────────────────────────
class AppShadows {
  // Subtle shadow for cards (primary)
  static final subtle = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 6,
      offset: const Offset(0, 8),
    ),
  ];
  
  // Elevated shadow for interactive elements
  static final elevated = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 8,
      offset: const Offset(0, 12),
    ),
  ];
  
  // None
  static final none = <BoxShadow>[];
}

// ── BORDER RADIUS ─────────────────────────────────────────────────────────
class AppRadii {
  static const double card    = 24.0;   // Card radius
  static const double button  = 16.0;   // Button radius
  static const double input   = 12.0;   // Input radius
  static const double small   = 8.0;    // Small elements
  static const double large   = 32.0;   // Large elements
}

// ── COMPONENT STYLES ─────────────────────────────────────────────────────
class AppComponentStyles {
  // Card decoration
  static BoxDecoration cardDecoration = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadii.card),
    border: Border.all(color: AppColors.border),
    boxShadow: AppShadows.subtle,
  );
  
  // Input decoration
  static InputDecoration inputDecoration = InputDecoration(
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.input),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    hintStyle: AppTypography.bodySmall,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// 🎨 MODERN SAAS COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

// ── MODERN APP BACKGROUND ─────────────────────────────────────────────────
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: child,
    );
  }
}

// ── MODERN CARD COMPONENT ──────────────────────────────────────────────────
class SaasCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final bool elevated;
  final bool interactive;

  const SaasCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.onTap,
    this.backgroundColor = AppColors.surface,
    this.elevated = false,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: interactive ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.border),
            boxShadow: elevated ? AppShadows.elevated : AppShadows.subtle,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

// ── MODERN BUTTON COMPONENT ────────────────────────────────────────────────
class SaasButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isEnabled;
  final IconData? icon;
  final bool fullWidth;
  final bool outlined;
  final Color? color;

  const SaasButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.icon,
    this.fullWidth = false,
    this.outlined = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? AppColors.primary;
    
    return Material(
      child: InkWell(
        onTap: isEnabled && !isLoading ? onPressed : null,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: Container(
          height: 56,
          width: fullWidth ? double.infinity : null,
          decoration: BoxDecoration(
            color: outlined ? AppColors.surface : bgColor,
            border: outlined ? Border.all(color: AppColors.border) : null,
            borderRadius: BorderRadius.circular(AppRadii.button),
            boxShadow: !outlined && isEnabled ? AppShadows.subtle : [],
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        outlined ? AppColors.primary : AppColors.textInverse,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          color: outlined ? AppColors.textPrimary : AppColors.textInverse,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: outlined ? AppColors.textPrimary : AppColors.textInverse,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── PREMIUM BACKEND LOADER OVERLAY ───────────────────────────────────────
class BackendLoadingOverlay extends StatefulWidget {
  final Widget child;
  final bool isVisible;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const BackendLoadingOverlay({
    super.key,
    required this.child,
    required this.isVisible,
    this.title = 'Connecting to backend',
    this.subtitle = 'Please wait while we sync your data',
    this.icon = Icons.cloud_sync_rounded,
    this.accentColor = AppColors.primary,
  });

  @override
  State<BackendLoadingOverlay> createState() => _BackendLoadingOverlayState();
}

class _BackendLoadingOverlayState extends State<BackendLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.isVisible)
          Positioned.fill(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: widget.isVisible ? 1 : 0,
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        width: 310,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: widget.accentColor.withValues(alpha: 0.18)),
                          boxShadow: [
                            BoxShadow(
                              color: widget.accentColor.withValues(alpha: 0.16),
                              blurRadius: 30,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _controller,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _controller.value * 2 * math.pi,
                                  child: child,
                                );
                              },
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [widget.accentColor, widget.accentColor.withValues(alpha: 0.7)],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.accentColor.withValues(alpha: 0.22),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(widget.icon, color: Colors.white, size: 32),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.subtitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 8,
                                backgroundColor: AppColors.surfaceAlt,
                                valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── MODERN SECTION HEADER ──────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: AppTypography.bodySmall),
            ],
          ],
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: Text(
              'See All',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

// ── MODERN STAT CARD ───────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? change;
  final IconData icon;
  final Color? iconColor;
  final bool isNegative;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.change,
    required this.icon,
    this.iconColor,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    return SaasCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
            child: Icon(icon, color: iconColor ?? AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(label, style: AppTypography.bodySmall),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.titleSmall),
          if (change != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isNegative ? Icons.trending_down : Icons.trending_up,
                  color: isNegative ? AppColors.danger : AppColors.success,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  change!,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isNegative ? AppColors.danger : AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── GLASS CONTAINER (for compatibility with existing code) ────────────────
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final double blurSigma;
  final double? width;
  final double? height;
  final Color? accentColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blurSigma = 20,
    this.width,
    this.height,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SaasCard(
      padding: padding,
      child: child,
    );
  }
}

// ── KPI GLASS CARD (Modern SaaS Version) ───────────────────────────────────
class KpiGlassCard extends StatefulWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final double? trendPercent;
  final VoidCallback? onTap;
  final bool isHighlighted;
  final bool isWhite;

  const KpiGlassCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    this.color = AppColors.primary,
    this.trendPercent,
    this.onTap,
    this.isHighlighted = false,
    this.isWhite = false,
  });

  @override
  State<KpiGlassCard> createState() => _KpiGlassCardState();
}

class _KpiGlassCardState extends State<KpiGlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: widget.isHighlighted
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.card),
              gradient: widget.isWhite ? const LinearGradient(colors: [Colors.white, Colors.white]) : LinearGradient(
                colors: [
                  widget.color.withValues(alpha: 0.15),
                  const Color(0xFF151525).withValues(alpha: 0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: widget.isWhite ? Colors.grey.withValues(alpha: 0.2) : widget.color.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : null,
      child: SaasCard(
        onTap: widget.onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: widget.isHighlighted ? Colors.transparent : AppColors.surface,
        elevated: widget.isHighlighted,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.small),
              ),
              child: Icon(widget.icon, color: widget.color, size: 20),
            ),
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Label
                  Text(
                    widget.label, 
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: widget.isHighlighted 
                        ? AppTypography.bodySmall.copyWith(color: widget.isWhite ? Colors.grey[800] : Colors.white70) 
                        : AppTypography.bodySmall
                  ),
                  const SizedBox(height: 2),
                  // Value
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                    widget.value, 
                    style: widget.isHighlighted 
                        ? AppTypography.titleSmall.copyWith(color: widget.isWhite ? Colors.black : Colors.white, fontWeight: FontWeight.bold) 
                        : AppTypography.titleSmall.copyWith(fontSize: 18)
                  ),
                  ),
                ],
              ),
            ),
            // Trend
            if (widget.trendPercent != null) ...[
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    widget.trendPercent! >= 0 
                      ? Icons.trending_up 
                      : Icons.trending_down,
                    color: widget.trendPercent! >= 0 
                      ? AppColors.success 
                      : AppColors.danger,
                    size: 16,
                  ),
                  Text(
                    '%',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.trendPercent! >= 0 
                        ? AppColors.success 
                        : AppColors.danger,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}




class CompactProductRow extends StatefulWidget {
  final Map<String, TextEditingController> entry;
  final int index;
  final bool showDelete;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final VoidCallback? onScan;
  final Function(String, String, String, String)? onPriceLearned;
  final bool isHighlighted;
  final bool startExpanded;

  const CompactProductRow({
    super.key,
    required this.entry,
    required this.index,
    required this.showDelete,
    required this.onDelete,
    required this.onChanged,
    this.onScan,
    this.onPriceLearned,
    this.isHighlighted = false,
    this.startExpanded = false,
  });

  @override
  State<CompactProductRow> createState() => _CompactProductRowState();
}

class _CompactProductRowState extends State<CompactProductRow> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.startExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final name  = widget.entry['item']?.text ?? '';
    final qtyText = widget.entry['qty']?.text ?? '1';
    final priceText = widget.entry['price']?.text ?? '';
    final qty = double.tryParse(qtyText) ?? 1.0;
    final price = double.tryParse(priceText) ?? 0.0;
    final subtotal = qty * price;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: widget.isHighlighted
            ? AppColors.positive.withValues(alpha: 0.08)
            : AppColors.rowSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isHighlighted ? AppColors.positive : AppColors.rowBorder,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.index + 1}',
                      style: GoogleFonts.poppins(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name.isEmpty ? 'Product name…' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: name.isEmpty ? AppColors.textTertiary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (price > 0) ...[
                    Text(
                      '${qty.toStringAsFixed(0)}×₹${price.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Icon(
                    _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                  if (widget.showDelete) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: widget.onDelete,
                      child: const Icon(Icons.close_rounded, size: 16, color: AppColors.critical),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: ExpandedProductFields(
                entry: widget.entry,
                index: widget.index,
                showDelete: false,
                onDelete: () {},
                onChanged: widget.onChanged,
                onScan: widget.onScan,
                onPriceLearned: widget.onPriceLearned,
              ),
            ),
        ],
      ),
    );
  }
}



class ExpandedProductFields extends StatefulWidget {
  final int index;
  final Map<String, TextEditingController> entry;
  final bool showDelete;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final VoidCallback? onScan;
  final Function(String, String, String, String)? onPriceLearned;
  final bool isHighlighted;

  const ExpandedProductFields({
    super.key,
    required this.index,
    required this.entry,
    required this.showDelete,
    required this.onDelete,
    required this.onChanged,
    this.onScan,
    this.onPriceLearned,
    this.isHighlighted = false,
  });

  @override
  State<ExpandedProductFields> createState() => _ExpandedProductFieldsState();
}

class _ExpandedProductFieldsState extends State<ExpandedProductFields> {
  late final FocusNode _itemFocusNode;

  @override
  void initState() {
    super.initState();
    _itemFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _itemFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final index = widget.index;
    final showDelete = widget.showDelete;
    final isHighlighted = widget.isHighlighted;

    final double price = double.tryParse(entry['price']!.text) ?? 0;
    final double discount = double.tryParse(entry['discount']?.text ?? '0') ?? 0;
    final double qty = double.tryParse(entry['qty']!.text) ?? 0;
    final double subtotal = qty * (price - discount);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighlighted 
            ? AppColors.positive.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted 
              ? AppColors.positive
              : Colors.white.withValues(alpha: 0.08),
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.brand, Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Product ${index + 1}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: Colors.white,
                          letterSpacing: .3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (showDelete)
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 15),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          RawAutocomplete<Map<String, dynamic>>(
            textEditingController: entry['item']!,
            focusNode: _itemFocusNode,
            optionsBuilder: (TextEditingValue t) {
              if (t.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
              // Simplified mock autocomplete since it doesn't have access to global datasets easily here
              return const Iterable<Map<String, dynamic>>.empty();
            },
            displayStringForOption: (o) => o['name'].toString(),
            onSelected: (Map<String, dynamic> selection) {
              entry['item']!.text = selection['name'].toString();
              if (selection['price'] != null && selection['price'].toString() != '0') {
                entry['price']?.text = selection['price'].toString();
              }
              if (selection['gst'] != null) {
                entry['gst']?.text = selection['gst'].toString();
              }
              if (selection['barcode'] != null && selection['barcode'].toString().isNotEmpty) {
                entry['barcode']?.text = selection['barcode'].toString();
              }
              widget.onChanged();
            },
            fieldViewBuilder: (ctx, ctrl, focus, onSub) {
              return SalesField(
                controller: ctrl,
                focusNode: focus,
                label: 'Product Name',
                icon: Icons.inventory_2_outlined,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter product name' : null,
                onChanged: (newName) {
                  widget.onChanged();
                },
              );
            },
            optionsViewBuilder: (ctx, onSelect, options) {
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 10),

          SalesField(
            controller: entry['barcode'] ?? TextEditingController(),
            label: 'Barcode (Optional)',
            hint: 'Scan or enter barcode (optional)',
            icon: Icons.qr_code_2_rounded,
            accentColor: const Color(0xFF8B5CF6),
            suffixIcon: IconButton(
              icon: const Icon(Icons.barcode_reader, size: 18),
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.8),
              onPressed: () { if (widget.onScan != null) widget.onScan!(); },
              tooltip: 'Scan barcode',
            ),
            textInputAction: TextInputAction.next,
            onSubmitted: (val) {
              if (val.trim().isNotEmpty && widget.onScan != null) {
                 widget.onScan!();
              }
            },
            onChanged: (_) => widget.onChanged(),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                flex: 1,
                child: SalesField(
                  controller: entry['qty']!,
                  label: 'Qty',
                  icon: Icons.add_box_rounded, 
                  keyboardType: TextInputType.number,
                  accentColor: const Color(0xFF059669),
                  onChanged: (_) => widget.onChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: SalesField(
                  controller: entry['price']!,
                  label: 'Price',
                  icon: Icons.currency_rupee_rounded,
                  keyboardType: TextInputType.number,
                  accentColor: const Color(0xFF0284C7),
                  onChanged: (_) => widget.onChanged(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class SalesField extends StatefulWidget {
  const SalesField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.accentColor = AppColors.brand,
    this.suffixIcon,
    this.hint,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final Color accentColor;
  final Widget? suffixIcon;
  final String? hint;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<SalesField> createState() => _SalesFieldState();
}

class _SalesFieldState extends State<SalesField> {
  bool _focused = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _focused = _focusNode.hasFocus);
      if (_focusNode.hasFocus) {
        FocusScope.of(context).requestFocus(_focusNode);
      }
    }
  }

  @override
  void didUpdateWidget(SalesField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChange);
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction ?? TextInputAction.next,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      onTap: () {
        FocusScope.of(context).requestFocus(_focusNode);
      },
      style: GoogleFonts.poppins(
        fontSize: 16,
        color: Colors.black,
        fontWeight: FontWeight.bold
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        labelStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: _focused
              ? widget.accentColor
              : const Color(0xFF6B7280),
        ),
        prefixIcon: Icon(
          widget.icon,
          size: 20,
          color: _focused
              ? widget.accentColor
              : const Color(0xFF9CA3AF)
        ),
        isDense: true,
        filled: true,
        fillColor: _focused
            ? widget.accentColor.withValues(alpha: 0.08)
            : const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.accentColor, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.critical),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.critical, width: 2.0),
        ),
        errorStyle: GoogleFonts.poppins(
          fontSize: 12,
          color: AppColors.critical,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: widget.suffixIcon,
      ),
    );
  }
}

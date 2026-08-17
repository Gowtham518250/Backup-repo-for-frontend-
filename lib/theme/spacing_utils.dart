import 'package:flutter/material.dart';

/// 📐 Spacing & Whitespace Utilities
/// Provides consistent spacing throughout the app for better UX
class AppSpacing {
  // Base spacing unit (4px)
  static const double unit = 4.0;

  // Spacing scale
  static const double xs = unit;      // 4px
  static const double sm = unit * 2;  // 8px
  static const double md = unit * 4;  // 16px
  static const double lg = unit * 6;  // 24px
  static const double xl = unit * 8;  // 32px
  static const double xxl = unit * 10; // 40px
  static const double xxxl = unit * 12; // 48px

  // Padding helpers
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  // Horizontal padding
  static const EdgeInsets paddingHorizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets paddingHorizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingHorizontalLg = EdgeInsets.symmetric(horizontal: lg);

  // Vertical padding
  static const EdgeInsets paddingVerticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets paddingVerticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets paddingVerticalLg = EdgeInsets.symmetric(vertical: lg);

  // Card padding
  static const EdgeInsets cardPaddingMd = EdgeInsets.all(md);
  static const EdgeInsets cardPaddingLg = EdgeInsets.all(lg);

  // Section spacing
  static const SizedBox spacingXs = SizedBox(height: xs);
  static const SizedBox spacingSm = SizedBox(height: sm);
  static const SizedBox spacingMd = SizedBox(height: md);
  static const SizedBox spacingLg = SizedBox(height: lg);
  static const SizedBox spacingXl = SizedBox(height: xl);

  // Horizontal spacing between widgets
  static const SizedBox hSpacingXs = SizedBox(width: xs);
  static const SizedBox hSpacingSm = SizedBox(width: sm);
  static const SizedBox hSpacingMd = SizedBox(width: md);
  static const SizedBox hSpacingLg = SizedBox(width: lg);
}

/// Spaced Row widget for consistent spacing
class SpacedRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  const SpacedRow({
    super.key,
    required this.children,
    this.spacing = AppSpacing.md,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: _buildChildren(),
    );
  }

  List<Widget> _buildChildren() {
    if (children.isEmpty) return [];
    
    return children.asMap().entries.map((entry) {
      final index = entry.key;
      final child = entry.value;
      
      if (index == children.length - 1) {
        return [child];
      }
      
      return [
        child,
        SizedBox(width: spacing),
      ];
    }).expand((element) => element).toList();
  }
}

/// Spaced Column widget for consistent spacing
class SpacedColumn extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  const SpacedColumn({
    super.key,
    required this.children,
    this.spacing = AppSpacing.md,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: _buildChildren(),
    );
  }

  List<Widget> _buildChildren() {
    if (children.isEmpty) return [];
    
    return children.asMap().entries.map((entry) {
      final index = entry.key;
      final child = entry.value;
      
      if (index == children.length - 1) {
        return [child];
      }
      
      return [
        child,
        SizedBox(height: spacing),
      ];
    }).expand((element) => element).toList();
  }
}

/// Whitespace wrapper for better breathing room
class Whitespace extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double width;
  final double height;

  const Whitespace({
    super.key,
    required this.child,
    this.padding = AppSpacing.paddingMd,
    this.margin = EdgeInsets.zero,
    this.width = 0,
    this.height = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      margin: margin,
      width: width > 0 ? width : null,
      height: height > 0 ? height : null,
      child: child,
    );
  }
}

/// Safe area wrapper with consistent padding
class SafeAreaWrapper extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;

  const SafeAreaWrapper({
    super.key,
    required this.child,
    this.padding = AppSpacing.paddingMd,
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Screen padding wrapper
class ScreenPadding extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const ScreenPadding({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: child,
    );
  }
}
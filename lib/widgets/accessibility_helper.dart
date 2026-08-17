import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ♿ Accessibility Helper for RETAIL MIND
/// Provides accessibility utilities and widgets to improve app accessibility score
class AccessibilityHelper {
  // Minimum touch target size (WCAG 2.1 AA standard: 44x44px)
  static const double minTouchTargetSize = 44.0;
  
  // Minimum font size for readability (WCAG AA: 16px for body text)
  static const double minFontSize = 16.0;
  
  // Minimum contrast ratio (WCAG AA: 4.5:1 for normal text, 3:1 for large text)
  static const double minContrastRatio = 4.5;

  /// Check if text has sufficient contrast against background
  static bool hasSufficientContrast(Color foreground, Color background) {
    final luminance1 = foreground.computeLuminance();
    final luminance2 = background.computeLuminance();
    final lighter = luminance1 > luminance2 ? luminance1 : luminance2;
    final darker = luminance1 > luminance2 ? luminance2 : luminance1;
    final contrastRatio = (lighter + 0.05) / (darker + 0.05);
    return contrastRatio >= minContrastRatio;
  }

  /// Get accessible color (adjusts for contrast)
  static Color getAccessibleColor(Color foreground, Color background) {
    if (hasSufficientContrast(foreground, background)) {
      return foreground;
    }
    // Adjust to white or black based on background luminance
    return background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  /// Create accessible button with proper touch target and semantics
  static Widget accessibleButton({
    required Widget child,
    required VoidCallback onPressed,
    String? semanticLabel,
    String? hint,
    bool enabled = true,
    Widget? icon,
  }) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      hint: hint,
      excludeSemantics: true,
      child: SizedBox(
        width: minTouchTargetSize,
        height: minTouchTargetSize,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            splashColor: Colors.black.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }

  /// Accessible text with semantic labels
  static Widget accessibleText(
    String text, {
    TextStyle? style,
    String? semanticLabel,
    bool isHeading = false,
    int? maxLines,
  }) {
    return Semantics(
      label: semanticLabel ?? text,
      child: Text(
        text,
        style: (style ?? const TextStyle(fontSize: minFontSize)).copyWith(
          fontSize: (style?.fontSize ?? minFontSize) < minFontSize
              ? minFontSize
              : style?.fontSize,
        ),
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
      ),
    );
  }

  /// Accessible card with proper semantics
  static Widget accessibleCard({
    required Widget child,
    String? semanticLabel,
    VoidCallback? onTap,
    bool isSelectable = false,
  }) {
    final interactive = onTap != null || isSelectable;
    
    return Semantics(
      label: semanticLabel,
      button: interactive && !isSelectable,
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }

  /// Announce message to screen readers
  static void announce(String message, BuildContext context) {
    // SemanticsService is not available in standard Flutter
    // This is a placeholder - actual implementation would use the AccessibilityFeatures API
  }

  /// Focus management helper
  static void requestFocus(FocusNode focusNode, BuildContext context) {
    focusNode.requestFocus();
    announce(focusNode.debugLabel ?? 'Focused', context);
  }

  /// Accessible input field with label and error
  static Widget accessibleTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? errorText,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? semanticLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: semanticLabel ?? label,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: minFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16, // Ensure 44px minimum touch target
            ),
          ),
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(fontSize: minFontSize),
        ),
        if (errorText != null)
          Semantics(
            label: 'Error: $errorText',
            child: Text(
              errorText!,
              style: TextStyle(
                fontSize: minFontSize,
                color: Colors.red,
              ),
            ),
          ),
      ],
    );
  }

  /// Accessible icon button with proper touch target
  static Widget accessibleIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? semanticLabel,
    String? hint,
    bool enabled = true,
  }) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      hint: hint,
      excludeSemantics: true,
      child: SizedBox(
        width: minTouchTargetSize,
        height: minTouchTargetSize,
        child: IconButton(
          icon: Icon(icon, size: 24),
          onPressed: enabled ? onPressed : null,
          tooltip: semanticLabel,
          padding: const EdgeInsets.all(8),
        ),
      ),
    );
  }

  /// Accessible switch/toggle
  static Widget accessibleSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
    String? semanticLabel,
    String? hint,
  }) {
    return Semantics(
      toggled: value,
      label: semanticLabel,
      hint: hint,
      onTap: () => onChanged(!value),
      excludeSemantics: true,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF6366F1),
      ),
    );
  }

  /// Accessible slider
  static Widget accessibleSlider({
    required double value,
    required ValueChanged<double> onChanged,
    String? semanticLabel,
    String? hint,
    double min = 0.0,
    double max = 1.0,
    int? divisions,
  }) {
    return Semantics(
      label: semanticLabel,
      value: value.toString(),
      hint: hint,
      increasedValue: divisions != null 
          ? '${(value + (max - min) / divisions).clamp(min, max)}'
          : '${max}',
      decreasedValue: divisions != null 
          ? '${(value - (max - min) / divisions).clamp(min, max)}'
          : '${min}',
      excludeSemantics: true,
      child: Slider(
        value: value,
        onChanged: onChanged,
        min: min,
        max: max,
        divisions: divisions,
        activeColor: const Color(0xFF6366F1),
      ),
    );
  }

  /// Accessible list tile with proper semantics
  static Widget accessibleListTile({
    required Widget title,
    Widget? subtitle,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
    bool isThreeLine = false,
    String? semanticLabel,
  }) {
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: ListTile(
        title: title,
        subtitle: subtitle,
        leading: leading,
        trailing: trailing,
        onTap: onTap,
        isThreeLine: isThreeLine,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12, // Ensure 44px height
        ),
      ),
    );
  }

  /// Check if screen reader is active
  static Future<bool> isScreenReaderActive() async {
    // This would require platform-specific implementation
    // For now, return false
    return false;
  }

  /// Reduce motion preference (respect user settings)
  static bool get reduceMotion {
    // Would check system accessibility settings
    // For now, return false
    return false;
  }

  /// Font scale preference (respect user settings)
  static double get fontScale {
    // Would check system accessibility settings
    // For now, return 1.0
    return 1.0;
  }
}

/// ♿ Accessible Card Widget with enhanced semantics
class AccessibleCard extends StatelessWidget {
  final Widget child;
  final String? semanticLabel;
  final VoidCallback? onTap;
  final bool isSelectable;
  final EdgeInsets? padding;

  const AccessibleCard({
    super.key,
    required this.child,
    this.semanticLabel,
    this.onTap,
    this.isSelectable = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return AccessibilityHelper.accessibleCard(
      semanticLabel: semanticLabel,
      onTap: onTap,
      isSelectable: isSelectable,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

/// ♿ Accessible Button Widget
class AccessibleButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isLoading;
  final String? semanticHint;

  const AccessibleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.isLoading = false,
    this.semanticHint,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      hint: semanticHint,
      enabled: !isLoading && onPressed != null,
      excludeSemantics: true,
      child: SizedBox(
        height: AccessibilityHelper.minTouchTargetSize,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: textColor ?? Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : icon != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: const TextStyle(fontSize: AccessibilityHelper.minFontSize),
                        ),
                      ],
                    )
                  : Text(
                      label,
                      style: const TextStyle(fontSize: AccessibilityHelper.minFontSize),
                    ),
        ),
      ),
    );
  }
}
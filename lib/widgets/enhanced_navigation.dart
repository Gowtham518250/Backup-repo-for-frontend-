import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'accessibility_helper.dart';

/// 🧭 Enhanced Navigation Component
/// Provides clear, accessible, and intuitive navigation with keyboard support
class EnhancedNavigation extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavItem> items;
  final Color? backgroundColor;
  final Color? activeColor;
  final bool showLabels;
  final bool isFloating;

  const EnhancedNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.backgroundColor,
    this.activeColor,
    this.showLabels = true,
    this.isFloating = false,
  });

  @override
  State<EnhancedNavigation> createState() => _EnhancedNavigationState();
}

class _EnhancedNavigationState extends State<EnhancedNavigation> {
  List<FocusNode> _focusNodes = [];
  int _focusedIndex = -1;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(widget.items.length, (_) => FocusNode());
    
    // Add keyboard listener
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Handle left/right arrow keys
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _navigateToNext();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _navigateToPrevious();
        return true;
      }
      // Handle Enter key for focused item
      else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_focusedIndex >= 0 && _focusedIndex < widget.items.length) {
          widget.onTap(_focusedIndex);
          return true;
        }
      }
    }
    return false;
  }

  void _navigateToNext() {
    if (widget.currentIndex < widget.items.length - 1) {
      widget.onTap(widget.currentIndex + 1);
      _focusNext();
    }
  }

  void _navigateToPrevious() {
    if (widget.currentIndex > 0) {
      widget.onTap(widget.currentIndex - 1);
      _focusPrevious();
    }
  }

  void _focusNext() {
    if (_focusedIndex < widget.items.length - 1) {
      setState(() {
        _focusedIndex = _focusedIndex + 1;
        _focusNodes[_focusedIndex].requestFocus();
      });
    }
  }

  void _focusPrevious() {
    if (_focusedIndex > 0) {
      setState(() {
        _focusedIndex = _focusedIndex - 1;
        _focusNodes[_focusedIndex].requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFloating) {
      return _buildFloatingNavigation();
    }
    return _buildBottomNavigation();
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: widget.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isActive = widget.currentIndex == index;
              
              return Expanded(
                child: AccessibilityHelper.accessibleButton(
                  semanticLabel: item.label,
                  hint: 'Navigate to ${item.label}',
                  onPressed: () => widget.onTap(index),
                  child: _buildNavItem(item, isActive, index),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingNavigation() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: widget.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isActive = widget.currentIndex == index;
            
            return _buildNavItem(item, isActive, index);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNavItem(NavItem item, bool isActive, int index) {
    final activeColor = widget.activeColor ?? const Color(0xFF6366F1);
    
    return Focus(
      focusNode: _focusNodes[index],
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          setState(() => _focusedIndex = index);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: widget.showLabels ? 12 : 16,
          vertical: widget.showLabels ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              size: 24,
              color: isActive ? activeColor : const Color(0xFF94A3B8),
            ),
            if (widget.showLabels) ...[
              const SizedBox(height: 4),
              Text(
                item.label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? activeColor : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Navigation item model
class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? semanticLabel;

  NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.semanticLabel,
  });
}

/// Enhanced drawer navigation with better structure
class EnhancedDrawer extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<DrawerItem> items;
  final Widget? header;
  final Widget? footer;

  const EnhancedDrawer({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.header,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          if (header != null) header!,
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                final isActive = currentIndex == index;
                
                return _DrawerTile(
                  item: item,
                  isActive: isActive,
                  onTap: () {
                    onTap(index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

/// Drawer tile with accessibility support
class _DrawerTile extends StatelessWidget {
  final DrawerItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AccessibilityHelper.accessibleListTile(
      title: Text(
        item.label,
        style: GoogleFonts.poppins(
          fontSize: AccessibilityHelper.minFontSize,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          color: isActive ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
        ),
      ),
      leading: Icon(
        isActive ? item.activeIcon : item.icon,
        color: isActive ? const Color(0xFF6366F1) : const Color(0xFF64748B),
        size: 22,
      ),
      trailing: item.trailing,
      onTap: onTap,
      semanticLabel: item.semanticLabel ?? item.label,
    );
  }
}

/// Drawer item model
class DrawerItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? semanticLabel;
  final Widget? trailing;
  final List<DrawerItem>? subItems;

  DrawerItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.semanticLabel,
    this.trailing,
    this.subItems,
  });
}

/// Breadcrumb navigation for deep navigation
class BreadcrumbNavigation extends StatelessWidget {
  final List<BreadcrumbItem> items;
  final BreadcrumbStyle style;

  const BreadcrumbNavigation({
    super.key,
    required this.items,
    this.style = BreadcrumbStyle.arrow,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _buildBreadcrumbs(),
      ),
    );
  }

  List<Widget> _buildBreadcrumbs() {
    final List<Widget> breadcrumbs = [];
    
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final isLast = i == items.length - 1;
      
      if (i > 0) {
        breadcrumbs.add(_buildSeparator());
      }
      
      breadcrumbs.add(
        _buildBreadcrumbItem(item, isLast),
      );
    }
    
    return breadcrumbs;
  }

  Widget _buildBreadcrumbItem(BreadcrumbItem item, bool isLast) {
    return GestureDetector(
      onTap: isLast ? null : item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.icon != null)
              Icon(item.icon, size: 16, color: _getItemColor(isLast)),
            if (item.icon != null && item.label != null)
              const SizedBox(width: 4),
            if (item.label != null)
              Text(
                item.label!,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
                  color: _getItemColor(isLast),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeparator() {
    switch (style) {
      case BreadcrumbStyle.arrow:
        return const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8));
      case BreadcrumbStyle.slash:
        return const Text('/', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14));
      case BreadcrumbStyle.dot:
        return const Text('•', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14));
      case BreadcrumbStyle.greater:
        return const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF94A3B8));
    }
  }

  Color _getItemColor(bool isLast) {
    return isLast ? const Color(0xFF6366F1) : const Color(0xFF64748B);
  }
}

/// Breadcrumb item model
class BreadcrumbItem {
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final String? semanticLabel;

  BreadcrumbItem({
    this.label,
    this.icon,
    this.onTap,
    this.semanticLabel,
  });
}

/// Breadcrumb style enum
enum BreadcrumbStyle {
  arrow,
  slash,
  dot,
  greater,
}

/// Quick action chips for navigation shortcuts
class QuickActionChips extends StatelessWidget {
  final List<QuickActionItem> actions;
  final ValueChanged<QuickActionItem>? onActionTap;

  const QuickActionChips({
    super.key,
    required this.actions,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: actions.map((action) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _QuickActionChip(
              action: action,
              onTap: () => onActionTap?.call(action),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final QuickActionItem action;
  final VoidCallback? onTap;

  const _QuickActionChip({
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: action.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: action.color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 16, color: action.color),
            const SizedBox(width: 6),
            Text(
              action.label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: action.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick action item model
class QuickActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final String? semanticLabel;

  QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    this.semanticLabel,
  });
}
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/spacing_utils.dart';
import '../widgets/accessibility_helper.dart';

/// 🎨 Personalization Features with Drag-and-Drop Widgets and Preferences
class PersonalizationDashboard extends StatefulWidget {
  const PersonalizationDashboard({super.key});

  @override
  State<PersonalizationDashboard> createState() => _PersonalizationDashboardState();
}

class _PersonalizationDashboardState extends State<PersonalizationDashboard> {
  final List<DashboardWidget> _widgets = [
    DashboardWidget(
      id: 'revenue',
      title: 'Revenue',
      icon: Icons.account_balance_wallet_rounded,
      color: const Color(0xFF10B981),
      isPinned: true,
    ),
    DashboardWidget(
      id: 'orders',
      title: 'Orders',
      icon: Icons.shopping_cart_rounded,
      color: const Color(0xFF6366F1),
      isPinned: true,
    ),
    DashboardWidget(
      id: 'inventory',
      title: 'Inventory',
      icon: Icons.inventory_2_rounded,
      color: const Color(0xFFF59E0B),
      isPinned: false,
    ),
    DashboardWidget(
      id: 'weather',
      title: 'Weather',
      icon: Icons.wb_sunny_rounded,
      color: const Color(0xFF3B82F6),
      isPinned: false,
    ),
    DashboardWidget(
      id: 'tips',
      title: 'Tips',
      icon: Icons.lightbulb_rounded,
      color: const Color(0xFF8B5CF6),
      isPinned: false,
    ),
    DashboardWidget(
      id: 'customers',
      title: 'Customers',
      icon: Icons.people_rounded,
      color: const Color(0xFFEC4899),
      isPinned: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadWidgetPreferences();
  }

  Future<void> _loadWidgetPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final widgetOrder = prefs.getStringList('widget_order');
    final pinnedWidgets = prefs.getStringList('pinned_widgets');
    
    if (widgetOrder != null) {
      setState(() {
        _widgets.sort((a, b) {
          final indexA = widgetOrder!.indexOf(a.id);
          final indexB = widgetOrder!.indexOf(b.id);
          return indexA.compareTo(indexB);
        });
      });
    }
    
    if (pinnedWidgets != null) {
      setState(() {
        for (final widget in _widgets) {
          widget.isPinned = pinnedWidgets.contains(widget.id);
        }
      });
    }
  }

  Future<void> _saveWidgetPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final widgetOrder = _widgets.map((w) => w.id).toList();
    final pinnedWidgets = _widgets.where((w) => w.isPinned).map((w) => w.id).toList();
    
    await prefs.setStringList('widget_order', widgetOrder);
    await prefs.setStringList('pinned_widgets', pinnedWidgets);
  }

  void _togglePin(DashboardWidget widget) {
    setState(() {
      widget.isPinned = !widget.isPinned;
      _saveWidgetPreferences();
    });
    HapticFeedback.lightImpact();
  }

  void _removeWidget(DashboardWidget widget) {
    setState(() {
      _widgets.remove(widget);
      _saveWidgetPreferences();
    });
    HapticFeedback.mediumImpact();
  }

  void _addWidget() {
    // Show widget selection dialog
  }

  void _reorderWidgets(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final widget = _widgets.removeAt(oldIndex);
      _widgets.insert(newIndex, widget);
      _saveWidgetPreferences();
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Customize Dashboard',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _addWidget,
            icon: const Icon(Icons.add),
            tooltip: 'Add Widget',
          ),
        ],
      ),
      body: ReorderableListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        onReorder: _reorderWidgets,
        children: [
          ..._widgets.map((widget) => _buildWidgetCard(widget)),
        ],
      ),
    );
  }

  Widget _buildWidgetCard(DashboardWidget widget) {
    return Container(
      key: Key(widget.id),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(widget.icon, color: widget.color),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _togglePin(widget),
              icon: Icon(
                widget.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: widget.isPinned ? const Color(0xFF6366F1) : const Color(0xFF64748B),
              ),
              tooltip: widget.isPinned ? 'Unpin' : 'Pin',
            ),
            IconButton(
              onPressed: () => _removeWidget(widget),
              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
              tooltip: 'Remove',
            ),
            const Icon(Icons.drag_handle, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

class DashboardWidget {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  bool isPinned;

  DashboardWidget({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    this.isPinned = false,
  });
}

/// Weather widget
class WeatherWidget extends StatelessWidget {
  final String location;
  final double temperature;
  final String condition;
  final String iconCode;

  const WeatherWidget({
    super.key,
    required this.location,
    required this.temperature,
    required this.condition,
    required this.iconCode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: const Color(0xFF3B82F6)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  location,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              Icon(Icons.wb_sunny, color: const Color(0xFFF59E0B), size: 24),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${temperature.toInt()}°',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                condition,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tips widget
class TipsWidget extends StatefulWidget {
  const TipsWidget({super.key});

  @override
  State<TipsWidget> createState() => _TipsWidgetState();
}

class _TipsWidgetState extends State<TipsWidget> {
  final List<String> _tips = [
    'Tip: Use voice commands to quickly add products to the cart.',
    'Tip: Set up low stock alerts to never run out of popular items.',
    'Tip: Regularly review your sales reports to identify trends.',
    'Tip: Use keyboard shortcuts (Ctrl+S, Ctrl+G) for faster billing.',
    'Tip: Export sales data monthly for tax preparation.',
  ];
  int _currentTipIndex = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 8), (timer) {
      setState(() {
        _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: const Color(0xFF8B5CF6)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Tip of the Day',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _tips[_currentTipIndex],
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF1E293B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              ...List.generate(_tips.length, (index) {
                return Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: index == _currentTipIndex
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

/// Customizable quick actions
class CustomizableQuickActions extends StatefulWidget {
  final List<QuickAction> actions;
  final ValueChanged<QuickAction>? onActionPressed;

  const CustomizableQuickActions({
    super.key,
    required this.actions,
    this.onActionPressed,
  });

  @override
  State<CustomizableQuickActions> createState() => _CustomizableQuickActionsState();
}

class _CustomizableQuickActionsState extends State<CustomizableQuickActions> {
  late List<QuickAction> _actions;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _actions = List.from(widget.actions);
    _loadQuickActionPreferences();
  }

  Future<void> _loadQuickActionPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final actionOrder = prefs.getStringList('quick_action_order');
    
    if (actionOrder != null) {
      setState(() {
        _actions.sort((a, b) {
          final indexA = actionOrder!.indexOf(a.id);
          final indexB = actionOrder!.indexOf(b.id);
          return indexA.compareTo(indexB);
        });
      });
    }
  }

  Future<void> _saveQuickActionPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final actionOrder = _actions.map((a) => a.id).toList();
    await prefs.setStringList('quick_action_order', actionOrder);
  }

  void _toggleEditMode() {
    setState(() => _isEditMode = !_isEditMode);
    HapticFeedback.mediumImpact();
  }

  void _removeAction(QuickAction action) {
    setState(() {
      _actions.remove(action);
      _saveQuickActionPreferences();
    });
    HapticFeedback.lightImpact();
  }

  void _addAction() {
    // Show action selection dialog
  }

  void _reorderActions(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final action = _actions.removeAt(oldIndex);
      _actions.insert(newIndex, action);
      _saveQuickActionPreferences();
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick Actions',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _addAction,
                    icon: const Icon(Icons.add, size: 18),
                    tooltip: 'Add Action',
                  ),
                  IconButton(
                    onPressed: _toggleEditMode,
                    icon: Icon(
                      _isEditMode ? Icons.check : Icons.edit,
                      size: 18,
                    ),
                    tooltip: _isEditMode ? 'Done' : 'Edit',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          
          if (_isEditMode)
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: _reorderActions,
              children: [
                ..._actions.map((action) => _buildEditableAction(action)),
              ],
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                ..._actions.map((action) => _buildActionChip(action)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionChip(QuickAction action) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onActionPressed?.call(action);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: action.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: action.color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 16, color: action.color),
            const SizedBox(width: AppSpacing.sm),
            Text(
              action.label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: action.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableAction(QuickAction action) {
    return Container(
      key: Key(action.id),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(action.icon, size: 16, color: action.color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              action.label,
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ),
          IconButton(
            onPressed: () => _removeAction(action),
            icon: const Icon(Icons.remove_circle_outline, size: 16, color: Color(0xFFEF4444)),
          ),
          const Icon(Icons.drag_handle, size: 16, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }
}

class QuickAction {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  QuickAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// User preferences manager
class UserPreferences {
  static const String _keyTheme = 'theme_mode';
  static const String _keyLanguage = 'language';
  static const String _keyNotifications = 'notifications_enabled';
  static const String _keyLowStockAlert = 'low_stock_alert_enabled';
  static const String _keyLowStockThreshold = 'low_stock_threshold';
  static const String _keyWidgetOrder = 'widget_order';
  static const String _keyQuickActionOrder = 'quick_action_order';

  static Future<String> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTheme) ?? 'system';
  }

  static Future<void> setTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, theme);
  }

  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage) ?? 'en';
  }

  static Future<void> setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, language);
  }

  static Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotifications) ?? true;
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifications, enabled);
  }

  static Future<bool> getLowStockAlertEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLowStockAlert) ?? true;
  }

  static Future<void> setLowStockAlertEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLowStockAlert, enabled);
  }

  static Future<int> getLowStockThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLowStockThreshold) ?? 10;
  }

  static Future<void> setLowStockThreshold(int threshold) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLowStockThreshold, threshold);
  }

  static Future<void> resetAllPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
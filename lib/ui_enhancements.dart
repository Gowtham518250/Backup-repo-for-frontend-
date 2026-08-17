/// 🎨 UI ENHANCEMENTS - Safe widgets for 90+/100 rating
/// No logic changes - pure UI improvements

import 'package:flutter/material.dart';

/// ### 5️⃣ PROFIT MARGIN DISPLAY WIDGET
class ProfitMarginDisplay extends StatelessWidget {
  final double saleAmount;
  final double costAmount;
  
  const ProfitMarginDisplay({
    required this.saleAmount,
    required this.costAmount,
    super.key,
  });

  double get profitAmount => saleAmount - costAmount;
  double get profitMarginPercent => costAmount > 0 
    ? ((saleAmount - costAmount) / costAmount * 100)
    : 0;

  @override
  Widget build(BuildContext context) {
    final isPositive = profitAmount >= 0;
    final marginColor = isPositive ? Colors.green : Colors.red;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: marginColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: marginColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: marginColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Profit Margin',
                style: TextStyle(
                  color: marginColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${profitMarginPercent.toStringAsFixed(1)}%',
            style: TextStyle(
              color: marginColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹ ${profitAmount.toStringAsFixed(2)} profit',
            style: TextStyle(
              color: marginColor.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// ### 6️⃣ INVOICE TEMPLATES DROPDOWN
class InvoiceTemplateSelector extends StatefulWidget {
  final Function(Map<String, dynamic>) onTemplateSelected;
  final List<Map<String, dynamic>> templates;
  
  const InvoiceTemplateSelector({
    required this.onTemplateSelected,
    this.templates = const [],
    super.key,
  });

  @override
  State<InvoiceTemplateSelector> createState() => _InvoiceTemplateSelectorState();
}

class _InvoiceTemplateSelectorState extends State<InvoiceTemplateSelector> {
  String? selectedTemplate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, color: Colors.blue[700], size: 16),
              const SizedBox(width: 6),
              Text(
                'Use Template',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.templates.isEmpty)
            Text(
              '📝 No saved templates yet',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            )
          else
            DropdownButton<String>(
              value: selectedTemplate,
              hint: const Text('Select a template...'),
              isExpanded: true,
              items: widget.templates.map((template) {
                return DropdownMenuItem(
                  value: template['id']?.toString(),
                  child: Text(template['name']?.toString() ?? 'Template'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  final template = widget.templates.firstWhere(
                    (t) => t['id'].toString() == value,
                    orElse: () => {},
                  );
                  widget.onTemplateSelected(template);
                  setState(() => selectedTemplate = value);
                }
              },
            ),
        ],
      ),
    );
  }
}

/// ### 7️⃣ PAGINATION - LOAD MORE BUTTON
class LoadMoreButton extends StatefulWidget {
  final Future<void> Function() onLoadMore;
  final bool isLoading;
  final bool hasMore;
  
  const LoadMoreButton({
    required this.onLoadMore,
    required this.isLoading,
    required this.hasMore,
    super.key,
  });

  @override
  State<LoadMoreButton> createState() => _LoadMoreButtonState();
}

class _LoadMoreButtonState extends State<LoadMoreButton> {
  @override
  Widget build(BuildContext context) {
    if (!widget.hasMore) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ElevatedButton.icon(
          onPressed: widget.isLoading ? null : widget.onLoadMore,
          icon: widget.isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
          label: Text(widget.isLoading ? 'Loading...' : 'Load More'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[300],
            foregroundColor: Colors.grey[800],
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
    );
  }
}

/// ### 8️⃣ SEARCH & FILTER BAR
class SearchFilterBar extends StatefulWidget {
  final Function(String) onSearch;
  final Function(String)? onFilterChange;
  final List<String> filterOptions;
  final String hint;
  
  const SearchFilterBar({
    required this.onSearch,
    this.onFilterChange,
    this.filterOptions = const [],
    this.hint = 'Search...',
    super.key,
  });

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: widget.onSearch,
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (widget.filterOptions.isNotEmpty)
            DropdownButton<String>(
              value: _selectedFilter,
              hint: const Icon(Icons.filter_list),
              items: widget.filterOptions.map((option) {
                return DropdownMenuItem(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedFilter = value);
                widget.onFilterChange?.call(value ?? '');
              },
            ),
        ],
      ),
    );
  }
}

/// ### 9️⃣ SKELETON LOADER (Shimmer effect)
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  
  const SkeletonLoader({
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    super.key,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.95, end: 1.05)
          .animate(_animationController),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: widget.borderRadius,
        ),
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey[300]!,
                  Colors.grey[100]!,
                  Colors.grey[300]!,
                ],
              ),
              borderRadius: widget.borderRadius,
            ),
          ),
        ),
      ),
    );
  }
}

/// ### 🔟 DARK MODE TOGGLE BUTTON
class DarkModeToggle extends StatefulWidget {
  final Function(bool isDarkMode) onToggle;
  
  const DarkModeToggle({
    required this.onToggle,
    super.key,
  });

  @override
  State<DarkModeToggle> createState() => _DarkModeToggleState();
}

class _DarkModeToggleState extends State<DarkModeToggle> {
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Tooltip(
      message: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
      child: IconButton(
        icon: Icon(
          isDark ? Icons.light_mode : Icons.dark_mode,
          color: isDark ? Colors.yellow : Colors.grey[700],
        ),
        onPressed: () {
          setState(() => _isDarkMode = !_isDarkMode);
          widget.onToggle(_isDarkMode);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isDarkMode 
                  ? '🌙 Dark Mode enabled'
                  : '☀️ Light Mode enabled',
              ),
              duration: const Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }
}

/// ### SAMPLE USAGE CARD
class UIEnhancementShowcase extends StatelessWidget {
  const UIEnhancementShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profit Margin
          const Text('Profit Margin Display:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const ProfitMarginDisplay(
            saleAmount: 1000,
            costAmount: 600,
          ),
          
          const SizedBox(height: 24),
          
          // Templates
          const Text('Invoice Templates:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          InvoiceTemplateSelector(
            templates: [
              {'id': 1, 'name': 'Standard Invoice'},
              {'id': 2, 'name': 'Bulk Order'},
            ],
            onTemplateSelected: (template) {
              print('Selected: $template');
            },
          ),
          
          const SizedBox(height: 24),
          
          // Search
          const Text('Search & Filter:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SearchFilterBar(
            onSearch: (query) => print('Search: $query'),
            filterOptions: ['Recent', 'Oldest', 'Amount'],
          ),
          
          const SizedBox(height: 24),
          
          // Skeleton Loaders
          const Text('Loading State:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const SkeletonLoader(height: 20),
          const SizedBox(height: 8),
          const SkeletonLoader(height: 40),
          
          const SizedBox(height: 24),
          
          // Load More
          const Text('Pagination:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          LoadMoreButton(
            hasMore: true,
            isLoading: false,
            onLoadMore: () async {
              print('Loading more...');
              await Future.delayed(const Duration(seconds: 1));
            },
          ),
        ],
      ),
    );
  }
}

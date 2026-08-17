import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'accessibility_helper.dart';

/// 🔍 Enhanced Search & Filter Component
/// Provides advanced search capabilities with filters, suggestions, and history
class EnhancedSearchBar extends StatefulWidget {
  final String? hintText;
  final ValueChanged<String>? onSearch;
  final List<SearchSuggestion>? suggestions;
  final VoidCallback? onFilterTap;
  final bool showVoiceSearch;
  final VoidCallback? onVoiceSearchTap;
  final List<SearchHistoryItem>? searchHistory;
  final ValueChanged<SearchFilter>? onFilterChanged;

  const EnhancedSearchBar({
    super.key,
    this.hintText,
    this.onSearch,
    this.suggestions,
    this.onFilterTap,
    this.showVoiceSearch = true,
    this.onVoiceSearchTap,
    this.searchHistory,
    this.onFilterChanged,
  });

  @override
  State<EnhancedSearchBar> createState() => _EnhancedSearchBarState();
}

class _EnhancedSearchBarState extends State<EnhancedSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSearching = false;
  SearchFilter _currentFilter = SearchFilter.all;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && widget.searchHistory != null) {
      setState(() {});
    }
  }

  void _performSearch(String query) {
    if (query.isEmpty) return;
    
    setState(() => _isSearching = true);
    
    // Simulate search delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _isSearching = false);
        widget.onSearch?.call(query);
      }
    });
  }

  void _clearSearch() {
    _controller.clear();
    widget.onSearch?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main search bar
        Container(
          height: AccessibilityHelper.minTouchTargetSize,
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
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: widget.hintText ?? 'Search products...',
                    hintStyle: GoogleFonts.poppins(
                      color: const Color(0xFF94A3B8),
                      fontSize: AccessibilityHelper.minFontSize,
                    ),
                    border: InputBorder.none,
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: AccessibilityHelper.minFontSize,
                    color: const Color(0xFF1E293B),
                  ),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      widget.onSearch?.call('');
                    }
                  },
                  onSubmitted: _performSearch,
                ),
              ),
              if (_controller.text.isNotEmpty)
                AccessibilityHelper.accessibleIconButton(
                  icon: Icons.clear,
                  semanticLabel: 'Clear search',
                  onPressed: _clearSearch,
                ),
              if (widget.showVoiceSearch && widget.onVoiceSearchTap != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: AccessibilityHelper.accessibleIconButton(
                      icon: Icons.mic,
                      semanticLabel: 'Voice search',
                      onPressed: widget.onVoiceSearchTap ?? () {},
                    ),
                  ),
                ),
              if (widget.onFilterTap != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 16),
                  child: AccessibilityHelper.accessibleIconButton(
                    icon: Icons.filter_list,
                    semanticLabel: 'Filter results',
                    onPressed: widget.onFilterTap!,
                  ),
                ),
            ],
          ),
        ),
        
        // Filter chips
        if (widget.onFilterChanged != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SearchFilter.values.map((filter) {
                return _FilterChip(
                  label: filter.label,
                  isSelected: _currentFilter == filter,
                  onTap: () {
                    setState(() => _currentFilter = filter);
                    widget.onFilterChanged?.call(filter);
                  },
                );
              }).toList(),
            ),
          ),

        // Search suggestions
        if (_focusNode.hasFocus && widget.suggestions != null && widget.suggestions!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.suggestions!.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final suggestion = widget.suggestions![index];
                return AccessibilityHelper.accessibleListTile(
                  title: Text(
                    suggestion.text,
                    style: GoogleFonts.poppins(fontSize: AccessibilityHelper.minFontSize),
                  ),
                  subtitle: suggestion.subtitle != null
                      ? Text(
                          suggestion.subtitle!,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        )
                      : null,
                  leading: suggestion.icon != null
                      ? Icon(suggestion.icon, size: 20, color: const Color(0xFF6366F1))
                      : null,
                  onTap: () {
                    _controller.text = suggestion.text;
                    _focusNode.unfocus();
                    _performSearch(suggestion.text);
                  },
                  semanticLabel: suggestion.text,
                );
              },
            ),
          ),

        // Search history
        if (_focusNode.hasFocus && 
            widget.searchHistory != null && 
            widget.searchHistory!.isNotEmpty &&
            _controller.text.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Searches',
                      style: GoogleFonts.poppins(
                        fontSize: AccessibilityHelper.minFontSize,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        // Clear search history
                      },
                      child: Text(
                        'Clear',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.searchHistory!.map((item) {
                    return _HistoryChip(
                      text: item.query,
                      onTap: () {
                        _controller.text = item.query;
                        _focusNode.unfocus();
                        _performSearch(item.query);
                      },
                      onDelete: () {
                        // Delete from history
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Filter chip widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

/// History chip widget
class _HistoryChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _HistoryChip({
    required this.text,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history, size: 14, color: Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF1E293B),
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(
                Icons.close,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Search filter enum
enum SearchFilter {
  all('All'),
  inStock('In Stock'),
  lowStock('Low Stock'),
  outOfStock('Out of Stock');

  const SearchFilter(this.label);
  final String label;
}

/// Search suggestion model
class SearchSuggestion {
  final String text;
  final String? subtitle;
  final IconData? icon;

  SearchSuggestion({
    required this.text,
    this.subtitle,
    this.icon,
  });
}

/// Search history item
class SearchHistoryItem {
  final String query;
  final DateTime timestamp;

  SearchHistoryItem({
    required this.query,
    required this.timestamp,
  });
}

/// Advanced filter bottom sheet
class AdvancedFilterSheet extends StatefulWidget {
  final SearchFilter currentFilter;
  final double? minPrice;
  final double? maxPrice;
  final ValueChanged<Map<String, dynamic>> onApply;

  const AdvancedFilterSheet({
    super.key,
    required this.currentFilter,
    this.minPrice,
    this.maxPrice,
    required this.onApply,
  });

  @override
  State<AdvancedFilterSheet> createState() => _AdvancedFilterSheetState();
}

class _AdvancedFilterSheetState extends State<AdvancedFilterSheet> {
  late double _minPrice;
  late double _maxPrice;
  late SearchFilter _selectedFilter;
  final RangeValues _priceRange = const RangeValues(0, 10000);

  @override
  void initState() {
    super.initState();
    _minPrice = widget.minPrice ?? 0;
    _maxPrice = widget.maxPrice ?? 10000;
    _selectedFilter = widget.currentFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Advanced Filters',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AccessibilityHelper.accessibleIconButton(
                icon: Icons.close,
                semanticLabel: 'Close filters',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Stock filter
          Text(
            'Stock Status',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SearchFilter.values.map((filter) {
              return _FilterChip(
                label: filter.label,
                isSelected: _selectedFilter == filter,
                onTap: () {
                  setState(() => _selectedFilter = filter);
                },
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          
          // Price range
          Text(
            'Price Range',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: const Color(0xFF6366F1),
                  inactiveTrackColor: const Color(0xFFE2E8F0),
                  thumbColor: const Color(0xFF6366F1),
                ),
                child: RangeSlider(
                  values: _priceRange,
                  min: 0,
                  max: 10000,
                  divisions: 100,
                  labels: RangeLabels(
                    '₹${_priceRange.start.round()}',
                    '₹${_priceRange.end.round()}',
                  ),
                  onChanged: (values) {
                    setState(() {
                      _minPrice = values.start;
                      _maxPrice = values.end;
                    });
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Apply button
          SizedBox(
            width: double.infinity,
            height: AccessibilityHelper.minTouchTargetSize,
            child: AccessibleButton(
              label: 'Apply Filters',
              onPressed: () {
                widget.onApply.call({
                  'filter': _selectedFilter,
                  'minPrice': _minPrice,
                  'maxPrice': _maxPrice,
                });
                Navigator.pop(context);
              },
              backgroundColor: const Color(0xFF6366F1),
            ),
          ),
        ],
      ),
    );
  }
}
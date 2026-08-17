import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'empty_state.dart';
import 'empty_state.dart';

/// Modern Search Bar with Filters
/// Provides search functionality with filter options
class ModernSearchBar extends StatefulWidget {
  final String hintText;
  final Function(String) onSearch;
  final List<FilterOption>? filters;
  final Function(List<FilterOption>)? onFilterChange;

  const ModernSearchBar({
    super.key,
    required this.hintText,
    required this.onSearch,
    this.filters,
    this.onFilterChange,
  });

  @override
  State<ModernSearchBar> createState() => _ModernSearchBarState();
}

class _ModernSearchBarState extends State<ModernSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<FilterOption> _selectedFilters = [];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleFilter(FilterOption filter) {
    setState(() {
      if (_selectedFilters.contains(filter)) {
        _selectedFilters.remove(filter);
      } else {
        _selectedFilters.add(filter);
      }
    });
    widget.onFilterChange?.call(_selectedFilters);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              const Icon(
                Icons.search_rounded,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF1E293B),
                  ),
                  onChanged: widget.onSearch,
                ),
              ),
              if (_controller.text.isNotEmpty)
                IconButton(
                  onPressed: () {
                    _controller.clear();
                    widget.onSearch('');
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF94A3B8),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              if (widget.filters != null && widget.filters!.isNotEmpty)
                IconButton(
                  onPressed: () => _showFilterBottomSheet(),
                  icon: const Icon(
                    Icons.tune_rounded,
                    color: Color(0xFF6366F1),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
        // Selected Filters
        if (_selectedFilters.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedFilters.map((filter) => _FilterChip(
              filter: filter,
              onRemove: () => _toggleFilter(filter),
            )).toList(),
          ),
        ],
      ],
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _selectedFilters.clear());
                    widget.onFilterChange?.call(_selectedFilters);
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Clear All',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF6366F1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...widget.filters!.map((filter) => CheckboxListTile(
              value: _selectedFilters.contains(filter),
              onChanged: (_) => _toggleFilter(filter),
              title: Text(
                filter.label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF1E293B),
                ),
              ),
              activeColor: const Color(0xFF6366F1),
            )),
          ],
        ),
      ),
    );
  }
}

/// Filter Option Model
class FilterOption {
  final String label;
  final String value;

  FilterOption({required this.label, required this.value});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterOption && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Filter Chip Widget
class _FilterChip extends StatelessWidget {
  final FilterOption filter;
  final VoidCallback onRemove;

  const _FilterChip({
    required this.filter,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            filter.label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: Color(0xFF6366F1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Search Results List
class SearchResultsList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(T) itemBuilder;
  final String searchQuery;
  final bool Function(T, String) searchPredicate;

  const SearchResultsList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.searchQuery,
    required this.searchPredicate,
  });

  @override
  Widget build(BuildContext context) {
    final filteredItems = searchQuery.isEmpty
        ? items
        : items.where((item) => searchPredicate(item, searchQuery)).toList();

    if (filteredItems.isEmpty) {
      return const EmptySearchState(searchTerm: '');
    }

    return ListView.builder(
      itemCount: filteredItems.length,
      itemBuilder: (context, index) => itemBuilder(filteredItems[index]),
    );
  }
}

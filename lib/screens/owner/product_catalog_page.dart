import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/product_catalog_service.dart';
import '../../local_storage_service.dart';
import '../../visual_widgets.dart';

import 'dart:convert';
import '../../api_client.dart';

/// 🔧 FLIPKART-LEVEL: Product Catalog Page
/// Comprehensive product catalog with categories, subcategories, and product grid
class ProductCatalogPage extends StatefulWidget {
  final String? shopId;
  final String? shopName;
  const ProductCatalogPage({super.key, this.shopId, this.shopName});

  @override
  State<ProductCatalogPage> createState() => _ProductCatalogPageState();
}

class _ProductCatalogPageState extends State<ProductCatalogPage> {
  List<Map<String, dynamic>> _categories = [];
  Map<String, dynamic>? _selectedCategory;
  Map<String, dynamic>? _selectedSubcategory;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // 🔧 FLIPKART-LEVEL: Advanced filters
  double _minPrice = 0;
  double _maxPrice = 10000;
  double _selectedMinPrice = 0;
  double _selectedMaxPrice = 10000;
  bool _inStockOnly = false;
  String _sortBy = 'relevance'; // relevance, price_low, price_high, rating, newest
  List<String> _selectedBrands = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final categories = await ProductCatalogService.getCategories();
    List<Map<String, dynamic>> products = [];
    if (widget.shopId != null && widget.shopId!.isNotEmpty) {
      try {
        final res = await ApiClient.getJson('/store/shops/${widget.shopId}/products');
        if (res.statusCode == 200) {
          final d = jsonDecode(res.body);
          final rawProducts = d is List ? d : (d['products'] ?? []);
          products = List<Map<String, dynamic>>.from(rawProducts);
        }
      } catch (e) {
        debugPrint('Failed to load shop products: $e');
      }
    } else {
      products = await LocalStorageService.loadBackendProducts();
    }
    
    // Calculate price range from products
    if (products.isNotEmpty) {
      final prices = products.map((p) {
        final price = p['price'] ?? p['selling_price'] ?? 0;
        return price is num ? price.toDouble() : double.tryParse(price.toString()) ?? 0.0;
      }).toList();
      
      if (prices.isNotEmpty) {
        _minPrice = prices.reduce((a, b) => a < b ? a : b);
        _maxPrice = prices.reduce((a, b) => a > b ? a : b);
        _selectedMinPrice = _minPrice;
        _selectedMaxPrice = _maxPrice;
      }
    }
    
    setState(() {
      _categories = categories;
      _products = products.cast<Map<String, dynamic>>();
      _filteredProducts = products.cast<Map<String, dynamic>>();
      _isLoading = false;
    });
  }

  Future<void> _filterProducts() async {
    List<Map<String, dynamic>> filtered = List.from(_products);
    
    // Category filter
    if (_selectedCategory != null) {
      final categoryId = _selectedCategory!['id'] as String;
      final subcategoryId = _selectedSubcategory?['id'] as String?;
      
      final productIds = await ProductCatalogService.getProductsByCategory(
        categoryId,
        subcategoryId: subcategoryId,
      );
      
      filtered = filtered.where((product) {
        final productId = (product['id'] ?? product['product_id']).toString();
        return productIds.contains(productId);
      }).toList();
    }
    
    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) {
        final name = (product['name'] ?? '').toString().toLowerCase();
        final category = (product['category'] ?? '').toString().toLowerCase();
        final brand = (product['brand'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) || 
               category.contains(_searchQuery) || 
               brand.contains(_searchQuery);
      }).toList();
    }
    
    // Price range filter
    filtered = filtered.where((product) {
      final price = product['price'] ?? product['selling_price'] ?? 0;
      final productPrice = price is num ? price.toDouble() : double.tryParse(price.toString()) ?? 0.0;
      return productPrice >= _selectedMinPrice && productPrice <= _selectedMaxPrice;
    }).toList();
    
    // Stock filter
    if (_inStockOnly) {
      filtered = filtered.where((product) {
        final stock = product['current_stock'] ?? product['stock'] ?? 0;
        return stock > 0;
      }).toList();
    }
    
    // Brand filter
    if (_selectedBrands.isNotEmpty) {
      filtered = filtered.where((product) {
        final brand = (product['brand'] ?? '').toString().toLowerCase();
        return _selectedBrands.any((selectedBrand) => 
          brand.contains(selectedBrand.toLowerCase())
        );
      }).toList();
    }
    
    // Sort
    filtered = _sortProducts(filtered);
    
    setState(() {
      _filteredProducts = filtered;
    });
  }

  List<Map<String, dynamic>> _sortProducts(List<Map<String, dynamic>> products) {
    switch (_sortBy) {
      case 'price_low':
        return products..sort((a, b) {
          final priceA = _getProductPrice(a);
          final priceB = _getProductPrice(b);
          return priceA.compareTo(priceB);
        });
      case 'price_high':
        return products..sort((a, b) {
          final priceA = _getProductPrice(a);
          final priceB = _getProductPrice(b);
          return priceB.compareTo(priceA);
        });
      case 'rating':
        return products..sort((a, b) {
          final ratingA = a['rating'] ?? 0.0;
          final ratingB = b['rating'] ?? 0.0;
          return ratingB.compareTo(ratingA);
        });
      case 'newest':
        return products..sort((a, b) {
          final dateA = a['created_at'] ?? '';
          final dateB = b['created_at'] ?? '';
          return dateB.compareTo(dateA);
        });
      default:
        return products;
    }
  }

  double _getProductPrice(Map<String, dynamic> product) {
    final price = product['price'] ?? product['selling_price'] ?? 0;
    return price is num ? price.toDouble() : double.tryParse(price.toString()) ?? 0.0;
  }

  Future<void> _onSearch(String query) async {
    setState(() => _searchQuery = query.toLowerCase());
    await _filterProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Product Catalog',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFF1F2937)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE5E7EB)),
        ),
        actions: [
          // 🔧 FLIPKART-LEVEL: Filter button
          IconButton(
            icon: const Icon(Icons.tune, color: Color(0xFF1F2937)),
            onPressed: _showFilterBottomSheet,
            tooltip: 'Filters',
          ),
          // 🔧 FLIPKART-LEVEL: Sort dropdown
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: Color(0xFF1F2937)),
            onSelected: (value) {
              setState(() => _sortBy = value);
              _filterProducts();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'relevance', child: Text('Relevance')),
              const PopupMenuItem(value: 'price_low', child: Text('Price: Low to High')),
              const PopupMenuItem(value: 'price_high', child: Text('Price: High to Low')),
              const PopupMenuItem(value: 'rating', child: Text('Customer Rating')),
              const PopupMenuItem(value: 'newest', child: Text('Newest First')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 🔧 FLIPKART-LEVEL: Search bar
                _buildSearchBar(),
                // 🔧 FLIPKART-LEVEL: Category tabs
                _buildCategoryTabs(),
                // 🔧 FLIPKART-LEVEL: Subcategory chips
                if (_selectedCategory != null) _buildSubcategoryChips(),
                // 🔧 FLIPKART-LEVEL: Product grid
                Expanded(
                  child: _buildProductGrid(),
                ),
              ],
            ),
    );
  }

  /// 🔧 FLIPKART-LEVEL: Show filter bottom sheet
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filters',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedMinPrice = _minPrice;
                              _selectedMaxPrice = _maxPrice;
                              _inStockOnly = false;
                              _selectedBrands.clear();
                            });
                          },
                          child: Text(
                            'Clear All',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF6366F1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Filter options
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Price range filter
                    _buildPriceRangeFilter(setModalState),
                    const SizedBox(height: 24),
                    // Stock filter
                    _buildStockFilter(setModalState),
                    const SizedBox(height: 24),
                    // Brand filter
                    _buildBrandFilter(setModalState),
                  ],
                ),
              ),
              // Apply button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        // Apply filters from modal state
                      });
                      _filterProducts();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Apply Filters',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRangeFilter(StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price Range',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        RangeSlider(
          values: RangeValues(_selectedMinPrice, _selectedMaxPrice),
          min: _minPrice,
          max: _maxPrice,
          divisions: 20,
          labels: RangeLabels(
            '₹${_selectedMinPrice.toInt()}',
            '₹${_selectedMaxPrice.toInt()}',
          ),
          onChanged: (values) {
            setModalState(() {
              _selectedMinPrice = values.start;
              _selectedMaxPrice = values.end;
            });
          },
          activeColor: const Color(0xFF6366F1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${_selectedMinPrice.toInt()}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                ),
              ),
              Text(
                '₹${_selectedMaxPrice.toInt()}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStockFilter(StateSetter setModalState) {
    return SwitchListTile(
      title: Text(
        'In Stock Only',
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1F2937),
        ),
      ),
      subtitle: Text(
        'Show only products with available stock',
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: const Color(0xFF6B7280),
        ),
      ),
      value: _inStockOnly,
      onChanged: (value) {
        setModalState(() => _inStockOnly = value);
      },
      activeColor: const Color(0xFF6366F1),
    );
  }

  Widget _buildBrandFilter(StateSetter setModalState) {
    // Extract unique brands from products
    final brands = _products
        .map((p) => (p['brand'] ?? '').toString())
        .where((b) => b.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (brands.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Brand',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: brands.take(10).map((brand) {
            final isSelected = _selectedBrands.contains(brand);
            return FilterChip(
              label: Text(brand),
              selected: isSelected,
              onSelected: (selected) {
                setModalState(() {
                  if (selected) {
                    _selectedBrands.add(brand);
                  } else {
                    _selectedBrands.remove(brand);
                  }
                });
              },
              selectedColor: const Color(0xFF6366F1),
              checkmarkColor: Colors.white,
              labelStyle: GoogleFonts.poppins(
                fontSize: 14,
                color: isSelected ? Colors.white : const Color(0xFF4B5563),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search products...',
          hintStyle: GoogleFonts.poppins(color: const Color(0xFF9CA3AF)),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF6B7280)),
                  onPressed: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: _onSearch,
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All" option
            return _buildCategoryChip(
              name: 'All',
              icon: Icons.grid_view,
              isSelected: _selectedCategory == null,
              onTap: () {
                setState(() {
                  _selectedCategory = null;
                  _selectedSubcategory = null;
                });
                _filterProducts();
              },
            );
          }

          final category = _categories[index - 1];
          final isSelected = _selectedCategory?['id'] == category['id'];
          return _buildCategoryChip(
            name: category['name'],
            icon: _getIconForCategory(category['icon']),
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _selectedCategory = category;
                _selectedSubcategory = null;
              });
              _filterProducts();
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip({
    required String name,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : const Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubcategoryChips() {
    final subcategories = _selectedCategory?['subcategories'] as List<dynamic>?;
    if (subcategories == null || subcategories.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: subcategories.length,
        itemBuilder: (context, index) {
          final subcategory = subcategories[index] as Map<String, dynamic>;
          final isSelected = _selectedSubcategory?['id'] == subcategory['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedSubcategory = isSelected ? null : subcategory;
                });
                _filterProducts();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF10B981) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Text(
                  subcategory['name'],
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF4B5563),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different category or search term',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _filteredProducts.length,
        itemBuilder: (context, index) {
          final product = _filteredProducts[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = product['name'] ?? 'Unknown Product';
    final price = product['price'] ?? product['selling_price'] ?? 0;
    final stock = product['current_stock'] ?? product['stock'] ?? 0;
    final imageUrl = product['image_url'] ?? '';

    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image placeholder
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.grey[300]),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Product name
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Price
          Text(
            '₹${price.toString()}',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 4),
          // Stock status
          Row(
            children: [
              Icon(
                stock > 0 ? Icons.check_circle : Icons.cancel,
                size: 14,
                color: stock > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
              const SizedBox(width: 4),
              Text(
                stock > 0 ? 'In Stock ($stock)' : 'Out of Stock',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: stock > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconForCategory(String? iconName) {
    switch (iconName) {
      case 'devices': return Icons.devices;
      case 'checkroom': return Icons.checkroom;
      case 'shopping_basket': return Icons.shopping_basket;
      case 'home': return Icons.home;
      case 'face': return Icons.face;
      case 'sports_soccer': return Icons.sports_soccer;
      default: return Icons.category;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Flipkart-level Advanced Product Catalog
/// Features: Advanced filtering, smart search, product comparisons, reviews, ratings, wishlists
class AdvancedProductCatalog extends StatefulWidget {
  const AdvancedProductCatalog({super.key});

  @override
  State<AdvancedProductCatalog> createState() => _AdvancedProductCatalogState();
}

class _AdvancedProductCatalogState extends State<AdvancedProductCatalog> {
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<Product> _wishlist = [];
  Map<int, ProductComparison> _comparisons = {};
  
  // Search and filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  PriceRange _priceRange = PriceRange.all;
  List<String> _selectedCategories = [];
  List<String> _selectedBrands = [];
  double _minRating = 0.0;
  SortOption _sortBy = SortOption.popularity;
  bool _inStockOnly = false;
  bool _discountOnly = false;

  // Available filters
  final List<String> _categories = [
    'Grocery', 'Electronics', 'Fashion', 'Home & Kitchen', 
    'Beauty & Personal Care', 'Sports & Fitness', 'Toys & Games'
  ];
  
  final List<String> _brands = [
    'Apple', 'Samsung', 'Nike', 'Adidas', 'Sony', 'LG', 'Dell', 'HP'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Load products from backend or local storage
    await _loadProducts();
    await _loadWishlist();
    _applyFilters();
  }

  Future<void> _loadProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final productsJson = prefs.getString('advanced_products');
    
    if (productsJson != null) {
      final List<dynamic> decoded = json.decode(productsJson);
      setState(() {
        _allProducts = decoded.map((e) => Product.fromJson(e)).toList();
      });
    } else {
      // Load sample products for demo
      _loadSampleProducts();
    }
  }

  Future<void> _loadWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    final wishlistJson = prefs.getString('user_wishlist');
    
    if (wishlistJson != null) {
      final List<dynamic> decoded = json.decode(wishlistJson);
      setState(() {
        _wishlist = decoded.map((e) => Product.fromJson(e)).toList();
      });
    }
  }

  void _loadSampleProducts() {
    setState(() {
      _allProducts = [
        Product(
          id: 1,
          name: 'iPhone 15 Pro Max 256GB',
          brand: 'Apple',
          category: 'Electronics',
          price: 149900,
          originalPrice: 159900,
          rating: 4.6,
          reviewCount: 2847,
          inStock: true,
          discount: 6,
          images: ['https://example.com/iphone15.jpg'],
          description: 'Latest iPhone with A17 Pro chip, titanium design, and advanced camera system',
          specifications: {
            'Display': '6.7-inch Super Retina XDR',
            'Processor': 'A17 Pro',
            'Storage': '256GB',
            'Battery': '4422 mAh',
          },
        ),
        Product(
          id: 2,
          name: 'Samsung Galaxy S24 Ultra',
          brand: 'Samsung',
          category: 'Electronics',
          price: 129999,
          originalPrice: 144999,
          rating: 4.5,
          reviewCount: 1923,
          inStock: true,
          discount: 10,
          images: ['https://example.com/galaxy24.jpg'],
          description: 'Premium Android flagship with S Pen, 200MP camera, and AI features',
          specifications: {
            'Display': '6.8-inch Dynamic AMOLED',
            'Processor': 'Snapdragon 8 Gen 3',
            'Storage': '256GB',
            'Battery': '5000 mAh',
          },
        ),
        // Add more sample products...
      ];
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredProducts = _allProducts.where((product) {
        // Search filter
        if (_searchQuery.isNotEmpty && 
            !product.name.toLowerCase().contains(_searchQuery) &&
            !product.brand.toLowerCase().contains(_searchQuery) &&
            !product.category.toLowerCase().contains(_searchQuery)) {
          return false;
        }

        // Price range filter
        if (_priceRange != PriceRange.all) {
          final price = product.price;
          switch (_priceRange) {
            case PriceRange.under1000:
              if (price >= 1000) return false;
              break;
            case PriceRange.range1000to5000:
              if (price < 1000 || price >= 5000) return false;
              break;
            case PriceRange.range5000to10000:
              if (price < 5000 || price >= 10000) return false;
              break;
            case PriceRange.range10000to25000:
              if (price < 10000 || price >= 25000) return false;
              break;
            case PriceRange.above25000:
              if (price < 25000) return false;
              break;
            case PriceRange.all:
              break;
          }
        }

        // Category filter
        if (_selectedCategories.isNotEmpty && 
            !_selectedCategories.contains(product.category)) {
          return false;
        }

        // Brand filter
        if (_selectedBrands.isNotEmpty && 
            !_selectedBrands.contains(product.brand)) {
          return false;
        }

        // Rating filter
        if (product.rating < _minRating) {
          return false;
        }

        // Stock filter
        if (_inStockOnly && !product.inStock) {
          return false;
        }

        // Discount filter
        if (_discountOnly && product.discount == 0) {
          return false;
        }

        return true;
      }).toList();

      // Apply sorting
      _sortProducts();
    });
  }

  void _sortProducts() {
    switch (_sortBy) {
      case SortOption.popularity:
        _filteredProducts.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
        break;
      case SortOption.priceLowToHigh:
        _filteredProducts.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortOption.priceHighToLow:
        _filteredProducts.sort((a, b) => b.price.compareTo(a.price));
        break;
      case SortOption.rating:
        _filteredProducts.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case SortOption.newest:
        _filteredProducts.sort((a, b) => b.id.compareTo(a.id));
        break;
      case SortOption.discount:
        _filteredProducts.sort((a, b) => b.discount.compareTo(a.discount));
        break;
    }
  }

  Future<void> _toggleWishlist(Product product) async {
    final prefs = await SharedPreferences.getInstance();
    List<Product> currentWishlist = [];
    
    final wishlistJson = prefs.getString('user_wishlist');
    if (wishlistJson != null) {
      final List<dynamic> decoded = json.decode(wishlistJson);
      currentWishlist = decoded.map((e) => Product.fromJson(e)).toList();
    }

    if (_wishlist.any((p) => p.id == product.id)) {
      currentWishlist.removeWhere((p) => p.id == product.id);
    } else {
      currentWishlist.add(product);
    }

    await prefs.setString('user_wishlist', json.encode(currentWishlist.map((e) => e.toJson()).toList()));
    
    setState(() {
      _wishlist = currentWishlist;
    });
  }

  void _addToComparison(Product product) {
    if (_comparisons.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can compare up to 4 products')),
      );
      return;
    }

    setState(() {
      _comparisons[product.id] = ProductComparison(
        product: product,
        addedAt: DateTime.now(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Shop', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: Badge(
              label: Text(_comparisons.length.toString()),
              child: const Icon(Icons.compare_arrows),
            ),
            onPressed: () => _showComparisonSheet(),
          ),
          IconButton(
            icon: Badge(
              label: Text(_wishlist.length.toString()),
              child: const Icon(Icons.favorite_border),
            ),
            onPressed: () => _showWishlistSheet(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          _buildFilterButton(),
          Expanded(
            child: _filteredProducts.isEmpty
                ? _buildEmptyState()
                : _buildProductGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search for products, brands and more',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    if (_selectedCategories.isEmpty && _selectedBrands.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ..._selectedCategories.map((category) => _buildFilterChip(category, true)),
            ..._selectedBrands.map((brand) => _buildFilterChip(brand, true)),
            if (_priceRange != PriceRange.all)
              _buildFilterChip(_priceRange.label, true),
            if (_minRating > 0)
              _buildFilterChip('Rating $_minRating+', true),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        deleteIcon: const Icon(Icons.close, size: 18),
        onDeleted: () {
          setState(() {
            _selectedCategories.remove(label);
            _selectedBrands.remove(label);
            _priceRange = PriceRange.all;
            _minRating = 0.0;
            _applyFilters();
          });
        },
        backgroundColor: Colors.blue[100],
        labelStyle: GoogleFonts.poppins(fontSize: 12),
      ),
    );
  }

  Widget _buildFilterButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SortOption>(
                value: _sortBy,
                isExpanded: true,
                items: SortOption.values.map((option) {
                  return DropdownMenuItem(
                    value: option,
                    child: Text(option.label),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _sortBy = value!;
                    _applyFilters();
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _showFilterBottomSheet,
            icon: const Icon(Icons.filter_list),
            label: const Text('Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or search terms',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        return _buildProductCard(_filteredProducts[index]);
      },
    );
  }

  Widget _buildProductCard(Product product) {
    final isWishlisted = _wishlist.any((p) => p.id == product.id);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showProductDetails(product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: product.images.isNotEmpty
                        ? Image.network(product.images[0], fit: BoxFit.cover, errorBuilder: (_, __, ___) {
                            return Center(child: Icon(Icons.image, color: Colors.grey[400]));
                          })
                        : Center(child: Icon(Icons.image, color: Colors.grey[400])),
                  ),
                  if (product.discount > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${product.discount}% OFF',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: Icon(
                        isWishlisted ? Icons.favorite : Icons.favorite_border,
                        color: isWishlisted ? Colors.red : Colors.white,
                      ),
                      onPressed: () => _toggleWishlist(product),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getRatingColor(product.rating),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, size: 12, color: Colors.white),
                            const SizedBox(width: 2),
                            Text(
                              product.rating.toString(),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${product.reviewCount})',
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '₹${product.price}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      if (product.discount > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '₹${product.originalPrice}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _addToComparison(product),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[300]!),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Text('Compare', style: GoogleFonts.poppins(fontSize: 10)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Add to cart logic
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Text('Add', style: GoogleFonts.poppins(fontSize: 10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.0) return Colors.green;
    if (rating >= 3.0) return Colors.orange;
    return Colors.red;
  }

  void _showProductDetails(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ProductDetailSheet(product: product),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FilterBottomSheet(
        categories: _categories,
        brands: _brands,
        selectedCategories: _selectedCategories,
        selectedBrands: _selectedBrands,
        priceRange: _priceRange,
        minRating: _minRating,
        inStockOnly: _inStockOnly,
        discountOnly: _discountOnly,
        onApply: (filters) {
          setState(() {
            _selectedCategories = filters.categories;
            _selectedBrands = filters.brands;
            _priceRange = filters.priceRange;
            _minRating = filters.minRating;
            _inStockOnly = filters.inStockOnly;
            _discountOnly = filters.discountOnly;
            _applyFilters();
          });
        },
      ),
    );
  }

  void _showComparisonSheet() {
    if (_comparisons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products added to comparison')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ProductComparisonSheet(
        comparisons: _comparisons.values.toList(),
      ),
    );
  }

  void _showWishlistSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => WishlistSheet(
        wishlist: _wishlist,
        onRemove: (product) => _toggleWishlist(product),
      ),
    );
  }
}

// Models and supporting classes
class Product {
  final int id;
  final String name;
  final String brand;
  final String category;
  final double price;
  final double originalPrice;
  final double rating;
  final int reviewCount;
  final bool inStock;
  final int discount;
  final List<String> images;
  final String description;
  final Map<String, String> specifications;

  Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.price,
    required this.originalPrice,
    required this.rating,
    required this.reviewCount,
    required this.inStock,
    required this.discount,
    required this.images,
    required this.description,
    required this.specifications,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      brand: json['brand'] as String,
      category: json['category'] as String,
      price: (json['price'] as num).toDouble(),
      originalPrice: (json['originalPrice'] as num).toDouble(),
      rating: (json['rating'] as num).toDouble(),
      reviewCount: json['reviewCount'] as int,
      inStock: json['inStock'] as bool,
      discount: json['discount'] as int,
      images: List<String>.from(json['images'] as List),
      description: json['description'] as String,
      specifications: Map<String, String>.from(json['specifications'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'category': category,
      'price': price,
      'originalPrice': originalPrice,
      'rating': rating,
      'reviewCount': reviewCount,
      'inStock': inStock,
      'discount': discount,
      'images': images,
      'description': description,
      'specifications': specifications,
    };
  }
}

class ProductComparison {
  final Product product;
  final DateTime addedAt;

  ProductComparison({required this.product, required this.addedAt});
}

enum SortOption {
  popularity('Popularity'),
  priceLowToHigh('Price: Low to High'),
  priceHighToLow('Price: High to Low'),
  rating('Customer Rating'),
  newest('Newest First'),
  discount('Discount');

  final String label;
  const SortOption(this.label);
}

enum PriceRange {
  all('All Prices'),
  under1000('Under ₹1,000'),
  range1000to5000('₹1,000 - ₹5,000'),
  range5000to10000('₹5,000 - ₹10,000'),
  range10000to25000('₹10,000 - ₹25,000'),
  above25000('Above ₹25,000');

  final String label;
  const PriceRange(this.label);
}

// Filter data class
class FilterOptions {
  final List<String> categories;
  final List<String> brands;
  final PriceRange priceRange;
  final double minRating;
  final bool inStockOnly;
  final bool discountOnly;

  FilterOptions({
    required this.categories,
    required this.brands,
    required this.priceRange,
    required this.minRating,
    required this.inStockOnly,
    required this.discountOnly,
  });
}

// Filter bottom sheet widget
class FilterBottomSheet extends StatefulWidget {
  final List<String> categories;
  final List<String> brands;
  final List<String> selectedCategories;
  final List<String> selectedBrands;
  final PriceRange priceRange;
  final double minRating;
  final bool inStockOnly;
  final bool discountOnly;
  final Function(FilterOptions) onApply;

  const FilterBottomSheet({
    super.key,
    required this.categories,
    required this.brands,
    required this.selectedCategories,
    required this.selectedBrands,
    required this.priceRange,
    required this.minRating,
    required this.inStockOnly,
    required this.discountOnly,
    required this.onApply,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late List<String> _selectedCategories;
  late List<String> _selectedBrands;
  late PriceRange _priceRange;
  late double _minRating;
  late bool _inStockOnly;
  late bool _discountOnly;

  @override
  void initState() {
    super.initState();
    _selectedCategories = List.from(widget.selectedCategories);
    _selectedBrands = List.from(widget.selectedBrands);
    _priceRange = widget.priceRange;
    _minRating = widget.minRating;
    _inStockOnly = widget.inStockOnly;
    _discountOnly = widget.discountOnly;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filters', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: _resetFilters,
                  child: Text('Reset All', style: GoogleFonts.poppins(color: Colors.blue[600])),
                ),
              ],
            ),
          ),
          // Filter content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('Price Range', _buildPriceFilter()),
                  _buildSection('Categories', _buildCategoryFilter()),
                  _buildSection('Brands', _buildBrandFilter()),
                  _buildSection('Customer Rating', _buildRatingFilter()),
                  _buildSection('Availability', _buildAvailabilityFilter()),
                ],
              ),
            ),
          ),
          // Apply button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('Apply Filters', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        content,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPriceFilter() {
    return Wrap(
      spacing: 8,
      children: PriceRange.values.map((range) {
        final isSelected = _priceRange == range;
        return FilterChip(
          label: Text(range.label),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _priceRange = range;
            });
          },
          selectedColor: Colors.orange[100],
          checkmarkColor: Colors.orange[900],
        );
      }).toList(),
    );
  }

  Widget _buildCategoryFilter() {
    return Wrap(
      spacing: 8,
      children: widget.categories.map((category) {
        final isSelected = _selectedCategories.contains(category);
        return FilterChip(
          label: Text(category),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedCategories.add(category);
              } else {
                _selectedCategories.remove(category);
              }
            });
          },
          selectedColor: Colors.orange[100],
          checkmarkColor: Colors.orange[900],
        );
      }).toList(),
    );
  }

  Widget _buildBrandFilter() {
    return Wrap(
      spacing: 8,
      children: widget.brands.map((brand) {
        final isSelected = _selectedBrands.contains(brand);
        return FilterChip(
          label: Text(brand),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedBrands.add(brand);
              } else {
                _selectedBrands.remove(brand);
              }
            });
          },
          selectedColor: Colors.orange[100],
          checkmarkColor: Colors.orange[900],
        );
      }).toList(),
    );
  }

  Widget _buildRatingFilter() {
    return Column(
      children: [
        Slider(
          value: _minRating,
          min: 0,
          max: 5,
          divisions: 10,
          label: '$_minRating+',
          onChanged: (value) {
            setState(() {
              _minRating = value;
            });
          },
        ),
        Text('$_minRating+ Rating', style: GoogleFonts.poppins(color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildAvailabilityFilter() {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('In Stock Only'),
          value: _inStockOnly,
          onChanged: (value) {
            setState(() {
              _inStockOnly = value ?? false;
            });
          },
        ),
        CheckboxListTile(
          title: const Text('With Discount Only'),
          value: _discountOnly,
          onChanged: (value) {
            setState(() {
              _discountOnly = value ?? false;
            });
          },
        ),
      ],
    );
  }

  void _resetFilters() {
    setState(() {
      _selectedCategories.clear();
      _selectedBrands.clear();
      _priceRange = PriceRange.all;
      _minRating = 0.0;
      _inStockOnly = false;
      _discountOnly = false;
    });
  }

  void _applyFilters() {
    widget.onApply(FilterOptions(
      categories: _selectedCategories,
      brands: _selectedBrands,
      priceRange: _priceRange,
      minRating: _minRating,
      inStockOnly: _inStockOnly,
      discountOnly: _discountOnly,
    ));
    Navigator.pop(context);
  }
}

// Product detail sheet
class ProductDetailSheet extends StatelessWidget {
  final Product product;

  const ProductDetailSheet({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Images
                  SizedBox(
                    height: 300,
                    child: PageView.builder(
                      itemCount: product.images.length,
                      itemBuilder: (context, index) {
                        return Image.network(
                          product.images[index],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return Center(child: Icon(Icons.image, size: 64, color: Colors.grey[400]));
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and price
                        Text(
                          product.name,
                          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '₹${product.price}',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            if (product.discount > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '₹${product.originalPrice}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${product.discount}% OFF',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Rating
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getRatingColor(product.rating),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star, size: 16, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    product.rating.toString(),
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${product.reviewCount} Ratings & Reviews'),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Description
                        Text(
                          'Description',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.description,
                          style: GoogleFonts.poppins(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 24),
                        // Specifications
                        Text(
                          'Specifications',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...product.specifications.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    entry.key,
                                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    entry.value,
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 24),
                        // Add to buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.favorite_border),
                                label: const Text('Wishlist'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.shopping_cart),
                                label: const Text('Add to Cart'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[600],
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.0) return Colors.green;
    if (rating >= 3.0) return Colors.orange;
    return Colors.red;
  }
}

// Product comparison sheet
class ProductComparisonSheet extends StatelessWidget {
  final List<ProductComparison> comparisons;

  const ProductComparisonSheet({super.key, required this.comparisons});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Product Comparison', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Comparison content
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Specification column
                  _buildSpecColumn(),
                  // Product columns
                  ...comparisons.map((comparison) => _buildProductColumn(comparison.product)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecColumn() {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Specifications', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          const Text('Product Name'),
          const SizedBox(height: 16),
          const Text('Brand'),
          const SizedBox(height: 16),
          const Text('Price'),
          const SizedBox(height: 16),
          const Text('Rating'),
          const SizedBox(height: 16),
          const Text('Discount'),
        ],
      ),
    );
  }

  Widget _buildProductColumn(Product product) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          product.images.isNotEmpty
              ? Image.network(product.images[0], height: 100, fit: BoxFit.cover)
              : Container(height: 100, color: Colors.grey[200]),
          const SizedBox(height: 8),
          Text(product.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Text(product.brand),
          const SizedBox(height: 16),
          Text('₹${product.price}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.orange[600])),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.star, size: 16, color: Colors.orange),
              const SizedBox(width: 4),
              Text('${product.rating}'),
            ],
          ),
          const SizedBox(height: 16),
          if (product.discount > 0)
            Text('${product.discount}% OFF', style: GoogleFonts.poppins(color: Colors.green)),
        ],
      ),
    );
  }
}

// Wishlist sheet
class WishlistSheet extends StatelessWidget {
  final List<Product> wishlist;
  final Function(Product) onRemove;

  const WishlistSheet({super.key, required this.wishlist, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Wishlist (${wishlist.length})', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Wishlist content
          Expanded(
            child: wishlist.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('Your wishlist is empty', style: GoogleFonts.poppins(color: Colors.grey[600])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: wishlist.length,
                    itemBuilder: (context, index) {
                      return _buildWishlistItem(wishlist[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistItem(Product product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: product.images.isNotEmpty
                  ? Image.network(product.images[0], fit: BoxFit.cover)
                  : Icon(Icons.image, color: Colors.grey[400]),
            ),
            const SizedBox(width: 12),
            // Product details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${product.price}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[600],
                    ),
                  ),
                ],
              ),
            ),
            // Remove button
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => onRemove(product),
            ),
          ],
        ),
      ),
    );
  }
}
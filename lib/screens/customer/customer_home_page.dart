import 'package:flutter/material.dart';
import '../../visual_widgets.dart';
import '../../customer_shop_service.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  final List<Map<String, dynamic>> _cart = [];
  List<Map<String, dynamic>> _products = [];
  String _shopId = '';
  String _shopName = 'Storefront';
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    final newId = args?.toString() ?? '';
    if (newId.isNotEmpty && newId != _shopId) {
      _shopId = newId;
      _loadShop();
    } else if (_shopId.isEmpty && _loading) {
      _loadShop();
    }
  }

  Future<void> _loadShop() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (_shopId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No shop selected. Go back and choose a shop from Nearby Stores.';
      });
      return;
    }

    try {
      _shopName = await CustomerShopService.fetchShopName(_shopId);
      final products = await CustomerShopService.fetchProducts(_shopId);
      if (!mounted) return;
      setState(() {
        _products = products.where((p) => (p['price'] as num) > 0).toList();
        _loading = false;
        if (_products.isEmpty) {
          _error = 'This shop has no online products yet. Ask the owner to enable Online Store.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load products: $e';
      });
    }
  }

  void _addToCart(Map<String, dynamic> product) {
    final stock = product['stock'] as int? ?? 99;
    final inCart = _cart.where((c) => c['id'] == product['id']).fold<int>(0, (s, c) => s + (c['qty'] as int));
    if (inCart >= stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No more stock available')),
      );
      return;
    }

    setState(() {
      final idx = _cart.indexWhere((item) => item['id'] == product['id']);
      if (idx >= 0) {
        _cart[idx]['qty'] = (_cart[idx]['qty'] as int) + 1;
      } else {
        _cart.add({...product, 'qty': 1});
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product['name']} added to cart!'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        title: Text(_shopName, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('${_cart.length}'),
              isLabelVisible: _cart.isNotEmpty,
              child: const Icon(Icons.shopping_cart, color: Colors.white),
            ),
            onPressed: _cart.isEmpty
                ? null
                : () {
                    Navigator.pushNamed(context, '/customer-cart', arguments: {
                      'cart': _cart,
                      'shopId': _shopId,
                      'shopName': _shopName,
                    });
                  },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white54),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 24),
                        ElevatedButton(onPressed: _loadShop, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadShop,
                  color: AppColors.primary,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      return GlassContainer(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _productImage(product['image_url']?.toString()),
                            ),
                            const SizedBox(height: 8),
                            Text(product['name'],
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text('₹${product['price']}',
                                style: const TextStyle(
                                    color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Stock: ${product['stock']}',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _addToCart(product),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: const Text('Add to Cart',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _productImage(String? url) {
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => _productPlaceholder(),
        ),
      );
    }
    return _productPlaceholder();
  }

  Widget _productPlaceholder() {
    return Center(
      child: Icon(Icons.shopping_bag_outlined,
          size: 48, color: AppColors.primary.withValues(alpha: 0.7)),
    );
  }
}

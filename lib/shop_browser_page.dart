import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'api_client.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'checkout_page.dart';
import 'screens/owner/product_catalog_page.dart';

class ShopBrowserPage extends StatefulWidget {
  const ShopBrowserPage({super.key});
  @override
  State<ShopBrowserPage> createState() => _ShopBrowserPageState();
}

class _ShopBrowserPageState extends State<ShopBrowserPage> {
  bool _loading = true;
  List<dynamic> _shops = [];

  @override
  void initState() {
    super.initState();
    _fetchShops();
  }

  Future<void> _fetchShops() async {
    try {
      final res = await ApiClient.getJson('/store/shops/nearby');
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        setState(() => _shops = d is List ? d : (d['shops'] ?? []));
      }
    } catch (e) {
      debugPrint('Shop fetch error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: Text('Browse Shops', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
          : RefreshIndicator(
              onRefresh: _fetchShops,
              child: _shops.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.store_rounded, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('No shops nearby', style: GoogleFonts.poppins(color: Colors.grey)),
                    ]))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85),
                      itemCount: _shops.length,
                      itemBuilder: (ctx, i) {
                        final s = _shops[i];
                        final shopId = s['id']?.toString() ?? '';
                        final shopName = s['shop_name']?.toString() ?? 'Shop';
                        return GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductCatalogPage(shopId: shopId, shopName: shopName))),
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))]),
                                padding: const EdgeInsets.all(16),
                                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  CircleAvatar(radius: 28, backgroundColor: Colors.indigo.shade50, child: const Icon(Icons.store, color: Colors.indigo, size: 28)),
                                  const SizedBox(height: 12),
                                  Text(shopName, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(s['city']?.toString() ?? '', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (star) => Icon(Icons.star, size: 14, color: star < (s['rating'] ?? 4) ? Colors.amber : Colors.grey.shade300))),
                                ]),
                              ),
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Material(
                                  color: Colors.transparent,
                                  child: IconButton(
                                    icon: const Icon(Icons.share_rounded, size: 20, color: Colors.indigo),
                                    tooltip: 'Share Shop',
                                    onPressed: () async {
                                      try {
                                        final shopUrl = 'https://retail-mind-web.onrender.com/shop/$shopId';
                                        await Share.share('🛍️ Browse products from $shopName\n$shopUrl', subject: 'Visit $shopName');
                                      } catch (e) {
                                        debugPrint('Share failed: $e');
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not share shop')));
                                      }
                                    },
                                  ),
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
}

class ShopProductsPage extends StatefulWidget {
  final String shopId;
  final String shopName;
  const ShopProductsPage({super.key, required this.shopId, required this.shopName});
  @override
  State<ShopProductsPage> createState() => _ShopProductsPageState();
}

class _ShopProductsPageState extends State<ShopProductsPage> {
  bool _loading = true;
  List<dynamic> _products = [];
  final Map<int, int> _cart = {};

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final res = await ApiClient.getJson('/store/shops/${widget.shopId}/products');
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        setState(() => _products = d is List ? d : (d['products'] ?? []));
      }
    } catch (e) {
      debugPrint('Products fetch error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  int get _cartCount => _cart.values.fold(0, (s, v) => s + v);

  void _addToCart(int index) {
    setState(() => _cart[index] = (_cart[index] ?? 0) + 1);
  }

  void _goToCheckout() {
    final items = _cart.entries.map((e) {
      final p = _products[e.key];
      return {'product_id': p['id'], 'product_name': p['product_name'], 'quantity': e.value, 'price': p['unit_price'] ?? p['price'] ?? 0};
    }).toList();
    Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutPage(cartItems: items, shopId: widget.shopId)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(backgroundColor: Colors.indigo, title: Text(widget.shopName, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))),
      floatingActionButton: _cartCount > 0
          ? FloatingActionButton.extended(
              onPressed: _goToCheckout,
              backgroundColor: Colors.indigo,
              icon: const Icon(Icons.shopping_cart),
              label: Text('Cart ($_cartCount)', style: const TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _products.length,
              itemBuilder: (ctx, i) {
                final p = _products[i];
                final inCart = _cart[i] ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
                  child: Row(children: [
                    CircleAvatar(backgroundColor: Colors.indigo.shade50, child: const Icon(Icons.inventory_2, color: Colors.indigo, size: 20)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p['product_name']?.toString() ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      Text('Rs ${p['unit_price'] ?? p['price'] ?? 0}', style: GoogleFonts.poppins(color: Colors.indigo, fontWeight: FontWeight.bold)),
                    ])),
                    if (inCart > 0) Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text('x$inCart', style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.indigo),
                      onPressed: () => _addToCart(i),
                    ),
                  ]),
                );
              },
            ),
    );
  }
}
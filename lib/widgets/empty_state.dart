import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modern Empty State Widget
/// Provides consistent empty states across the app
class ModernEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ModernEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: const Color(0xFF6366F1),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty State for No Sales
class EmptySalesState extends StatelessWidget {
  final VoidCallback? onAddSale;

  const EmptySalesState({super.key, this.onAddSale});

  @override
  Widget build(BuildContext context) {
    return ModernEmptyState(
      icon: Icons.receipt_long_rounded,
      title: 'No Sales Yet',
      subtitle: 'Start making sales to see your transactions here',
      actionLabel: 'Add Sale',
      onAction: onAddSale,
    );
  }
}

/// Empty State for No Products
class EmptyProductsState extends StatelessWidget {
  final VoidCallback? onAddProduct;

  const EmptyProductsState({super.key, this.onAddProduct});

  @override
  Widget build(BuildContext context) {
    return ModernEmptyState(
      icon: Icons.inventory_2_rounded,
      title: 'No Products',
      subtitle: 'Add products to your inventory to get started',
      actionLabel: 'Add Product',
      onAction: onAddProduct,
    );
  }
}

/// Empty State for No Customers
class EmptyCustomersState extends StatelessWidget {
  final VoidCallback? onAddCustomer;

  const EmptyCustomersState({super.key, this.onAddCustomer});

  @override
  Widget build(BuildContext context) {
    return ModernEmptyState(
      icon: Icons.people_rounded,
      title: 'No Customers',
      subtitle: 'Add customers to start tracking their purchases',
      actionLabel: 'Add Customer',
      onAction: onAddCustomer,
    );
  }
}

/// Empty State for No Low Stock
class EmptyLowStockState extends StatelessWidget {
  const EmptyLowStockState({super.key});

  @override
  Widget build(BuildContext context) {
    return ModernEmptyState(
      icon: Icons.check_circle_rounded,
      title: 'Stock Levels Healthy',
      subtitle: 'All products are well stocked',
    );
  }
}

/// Empty State for Search Results
class EmptySearchState extends StatelessWidget {
  final String searchTerm;
  final VoidCallback? onClear;

  const EmptySearchState({
    super.key,
    required this.searchTerm,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ModernEmptyState(
      icon: Icons.search_off_rounded,
      title: 'No Results Found',
      subtitle: 'No items match "$searchTerm"',
      actionLabel: 'Clear Search',
      onAction: onClear,
    );
  }
}

/// Empty State for No Data (Generic)
class EmptyDataState extends StatelessWidget {
  final String? customMessage;

  const EmptyDataState({super.key, this.customMessage});

  @override
  Widget build(BuildContext context) {
    return ModernEmptyState(
      icon: Icons.inbox_rounded,
      title: 'No Data Available',
      subtitle: customMessage ?? 'There\'s no data to display right now',
    );
  }
}

/// Empty State for Network Error
class EmptyNetworkErrorState extends StatelessWidget {
  final VoidCallback? onRetry;

  const EmptyNetworkErrorState({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ModernEmptyState(
      icon: Icons.wifi_off_rounded,
      title: 'No Connection',
      subtitle: 'Check your internet connection and try again',
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../analytics_engine.dart';
import '../visual_widgets.dart';
import '../dashboard_page.dart';

/// Modern Analytics Hub - Displays all analytics with SaaS design
/// Reuses existing AnalyticsEngine without any changes
class ModernAnalyticsHub extends StatefulWidget {
  final List<dynamic> analyticsSales;
  final String selectedTimeFilter;
  final Function(String) onTimeFilterChanged;

  const ModernAnalyticsHub({
    Key? key,
    required this.analyticsSales,
    required this.selectedTimeFilter,
    required this.onTimeFilterChanged,
  }) : super(key: key);

  @override
  State<ModernAnalyticsHub> createState() => _ModernAnalyticsHubState();
}

class _ModernAnalyticsHubState extends State<ModernAnalyticsHub> {
  int _selectedChartIndex = 0;
  bool _isLoading = false;

  static const List<String> _chartLabels = ['Bar', 'Line', 'Pie', 'Radar'];
  static const List<String> _filterLabels = ['Today', 'Week', 'Month', 'Year'];

  // Real metrics calculated from API data (initialized with defaults)
  double _totalRevenue = 0.0;
  int _totalTransactions = 0;
  double _averageSale = 0.0;
  int _uniqueProducts = 0;
  double _growthPercentage = 0.0;
  String _topProduct = 'No data';

  @override
  void initState() {
    super.initState();
    _calculateMetrics();
  }

  @override
  void didUpdateWidget(ModernAnalyticsHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.analyticsSales != widget.analyticsSales ||
        oldWidget.selectedTimeFilter != widget.selectedTimeFilter) {
      _calculateMetrics();
    }
  }

  /// Calculate all metrics from actual API data (analyticsSales)
  void _calculateMetrics() {
    final sales = widget.analyticsSales;
    
    if (sales.isEmpty) {
      _totalRevenue = 0.0;
      _totalTransactions = 0;
      _averageSale = 0.0;
      _uniqueProducts = 0;
      _growthPercentage = 0.0;
      _topProduct = 'No data';
      return;
    }

    // Calculate Total Revenue
    _totalRevenue = sales.fold(0.0, (sum, sale) {
      final total = _toDouble(sale['total'] ?? sale['amount'] ?? 0);
      return sum + total;
    });

    // Total Transactions
    _totalTransactions = sales.length;

    // Average Sale
    _averageSale = _totalTransactions > 0 ? _totalRevenue / _totalTransactions : 0.0;

    // Unique Products
    final uniqueProductIds = <String>{};
    for (final sale in sales) {
      final productId = (sale['product_id'] ?? 
                        sale['barcode'] ?? 
                        sale['product_name'] ?? 
                        sale['product'] ?? 
                        sale['item'] ?? 
                        'Unknown').toString().trim();
      if (productId.isNotEmpty) {
        uniqueProductIds.add(productId);
      }
    }
    _uniqueProducts = uniqueProductIds.length;

    // Top Product (by revenue)
    final productRevenue = <String, double>{};
    for (final sale in sales) {
      final productName = (sale['product_name'] ?? 
                          sale['product'] ?? 
                          sale['item'] ?? 
                          'Unknown').toString().trim();
      final saleAmount = _toDouble(sale['total'] ?? sale['amount'] ?? 0);
      productRevenue.update(
        productName,
        (existing) => existing + saleAmount,
        ifAbsent: () => saleAmount,
      );
    }
    
    if (productRevenue.isNotEmpty) {
      _topProduct = productRevenue.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    } else {
      _topProduct = 'No data';
    }

    // Growth Percentage (today vs yesterday or period comparison)
    _calculateGrowthPercentage();
  }

  /// Calculate growth percentage based on selected time filter
  void _calculateGrowthPercentage() {
    final sales = widget.analyticsSales;
    if (sales.length < 2) {
      _growthPercentage = 0.0;
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (widget.selectedTimeFilter == 'Today') {
      // Today vs Yesterday
      double todayRevenue = 0.0;
      double yesterdayRevenue = 0.0;

      for (final sale in sales) {
        final saleDate = _parseDate(sale['created_at'] ?? sale['sale_date'] ?? '');
        final saleDateNormalized = DateTime(saleDate.year, saleDate.month, saleDate.day);
        final saleAmount = _toDouble(sale['total'] ?? sale['amount'] ?? 0);

        if (saleDateNormalized == today) {
          todayRevenue += saleAmount;
        } else if (saleDateNormalized == today.subtract(const Duration(days: 1))) {
          yesterdayRevenue += saleAmount;
        }
      }

      if (yesterdayRevenue > 0) {
        _growthPercentage = ((todayRevenue - yesterdayRevenue) / yesterdayRevenue) * 100;
      } else {
        _growthPercentage = todayRevenue > 0 ? 100.0 : 0.0;
      }
    } else if (widget.selectedTimeFilter == 'Week') {
      // This week vs last week
      final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
      final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
      double thisWeekRevenue = 0.0;
      double lastWeekRevenue = 0.0;

      for (final sale in sales) {
        final saleDate = _parseDate(sale['created_at'] ?? sale['sale_date'] ?? '');
        final saleAmount = _toDouble(sale['total'] ?? sale['amount'] ?? 0);

        if (saleDate.isAfter(thisWeekStart) || saleDate == thisWeekStart) {
          thisWeekRevenue += saleAmount;
        } else if ((saleDate.isAfter(lastWeekStart) || saleDate == lastWeekStart) &&
                   saleDate.isBefore(thisWeekStart)) {
          lastWeekRevenue += saleAmount;
        }
      }

      if (lastWeekRevenue > 0) {
        _growthPercentage = ((thisWeekRevenue - lastWeekRevenue) / lastWeekRevenue) * 100;
      } else {
        _growthPercentage = thisWeekRevenue > 0 ? 100.0 : 0.0;
      }
    } else if (widget.selectedTimeFilter == 'Month') {
      // This month vs last month
      final thisMonthStart = DateTime(now.year, now.month, 1);
      final lastMonthStart = DateTime(
        now.month == 1 ? now.year - 1 : now.year,
        now.month == 1 ? 12 : now.month - 1,
        1,
      );
      double thisMonthRevenue = 0.0;
      double lastMonthRevenue = 0.0;

      for (final sale in sales) {
        final saleDate = _parseDate(sale['created_at'] ?? sale['sale_date'] ?? '');
        final saleAmount = _toDouble(sale['total'] ?? sale['amount'] ?? 0);

        if ((saleDate.year == thisMonthStart.year && saleDate.month == thisMonthStart.month)) {
          thisMonthRevenue += saleAmount;
        } else if ((saleDate.year == lastMonthStart.year && saleDate.month == lastMonthStart.month)) {
          lastMonthRevenue += saleAmount;
        }
      }

      if (lastMonthRevenue > 0) {
        _growthPercentage = ((thisMonthRevenue - lastMonthRevenue) / lastMonthRevenue) * 100;
      } else {
        _growthPercentage = thisMonthRevenue > 0 ? 100.0 : 0.0;
      }
    } else {
      _growthPercentage = 0.0;
    }
  }

  /// Convert value to double safely
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Parse date from string
  DateTime _parseDate(String dateStr) {
    try {
      if (dateStr.isEmpty) return DateTime.now();
      final parsed = DateTime.tryParse(dateStr.trim());
      if (parsed == null) return DateTime.now();
      // Handle timezone conversion if needed
      if (dateStr.contains('Z') || dateStr.contains('+')) {
        return parsed.toLocal();
      }
      return parsed;
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          _buildHeader(),
          const SizedBox(height: 32),

          // TIME FILTER
          _buildTimeFilter(context),
          const SizedBox(height: 32),

          // KEY METRICS
          _buildKeyMetrics(),
          const SizedBox(height: 32),

          // CHART SELECTOR
          _buildChartSelector(context),
          const SizedBox(height: 32),

          // CHART DISPLAY
          _buildChartDisplay(),
          const SizedBox(height: 32),

          // ANALYTICS SECTIONS
          _buildAnalyticsSections(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analytics Hub',
          style: AppTypography.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Real-time business insights and performance metrics',
          style: AppTypography.bodySmall,
        ),
      ],
    );
  }

  Widget _buildTimeFilter(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Period', style: AppTypography.bodySmall),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _filterLabels.length,
            itemBuilder: (context, index) {
              final label = _filterLabels[index];
              final isSelected = widget.selectedTimeFilter == label;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => widget.onTimeFilterChanged(label),
                    borderRadius: BorderRadius.circular(AppRadii.button),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.button),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                        boxShadow: isSelected ? AppShadows.subtle : null,
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                              ? AppColors.textInverse
                              : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKeyMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Key Metrics', style: AppTypography.titleSmall),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            StatCard(
              label: 'Revenue',
              value: '₹${_formatNumber(_totalRevenue)}',
              icon: Icons.trending_up,
              iconColor: AppColors.primary,
              change: _growthPercentage >= 0 
                ? '+${_growthPercentage.toStringAsFixed(1)}%' 
                : '${_growthPercentage.toStringAsFixed(1)}%',
            ),
            StatCard(
              label: 'Transactions',
              value: _totalTransactions.toString(),
              icon: Icons.receipt,
              iconColor: AppColors.info,
              change: 'Total',
            ),
            StatCard(
              label: 'Products',
              value: _uniqueProducts.toString(),
              icon: Icons.shopping_bag,
              iconColor: AppColors.success,
            ),
            StatCard(
              label: 'Avg. Sale',
              value: '₹${_formatNumber(_averageSale)}',
              icon: Icons.pie_chart,
              iconColor: AppColors.warning,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chart Type', style: AppTypography.bodySmall),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _chartLabels.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedChartIndex == index;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _selectedChartIndex = index),
                    borderRadius: BorderRadius.circular(AppRadii.button),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.button),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _chartLabels[index],
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                              ? AppColors.textInverse
                              : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChartDisplay() {
    if (_isLoading) {
      return SaasCard(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    return SaasCard(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        height: 300,
        child: _buildChartByType(),
      ),
    );
  }

  Widget _buildChartByType() {
    final sales = widget.analyticsSales;
    if (sales.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: AppTypography.bodySmall,
        ),
      );
    }

    switch (_selectedChartIndex) {
      case 0:
        return BarChartWidget(sales: sales);
      case 1:
        return LineChartWidget(sales: sales);
      case 2:
        return PieChartWidget(sales: sales);
      case 3:
        return RadarChartWidget(sales: sales);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAnalyticsSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // REVENUE ANALYTICS
        _buildAnalyticsSection(
          title: 'Revenue Analytics',
          subtitle: 'Sales trends and distribution',
          icon: Icons.trending_up,
          items: [
            _MetricItem(
              label: 'Total Sales',
              value: '₹${_formatNumber(_totalRevenue)}',
              subtext: '$_totalTransactions transactions',
            ),
            _MetricItem(
              label: 'Growth',
              value: _growthPercentage >= 0 
                ? '+${_growthPercentage.toStringAsFixed(1)}%'
                : '${_growthPercentage.toStringAsFixed(1)}%',
              subtext: 'vs previous period',
            ),
          ],
        ),
        const SizedBox(height: 32),

        // PRODUCT ANALYTICS
        _buildAnalyticsSection(
          title: 'Product Analytics',
          subtitle: 'Top performing products',
          icon: Icons.shopping_bag,
          items: [
            _MetricItem(
              label: 'Unique Products',
              value: _uniqueProducts.toString(),
              subtext: 'Different items sold',
            ),
            _MetricItem(
              label: 'Top Product',
              value: _topProduct,
              subtext: 'Best seller',
            ),
          ],
        ),
        const SizedBox(height: 32),

        // CUSTOMER ANALYTICS
        _buildAnalyticsSection(
          title: 'Customer Analytics',
          subtitle: 'Customer behavior and patterns',
          icon: Icons.people,
          items: [
            _MetricItem(
              label: 'Avg Transaction',
              value: '₹${_formatNumber(_averageSale)}',
              subtext: 'Average bill value',
            ),
            _MetricItem(
              label: 'Transactions',
              value: _totalTransactions.toString(),
              subtext: 'Total customer orders',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnalyticsSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<_MetricItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.small),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleSmall),
                Text(subtitle, style: AppTypography.bodySmall),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        SaasCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: items
              .asMap()
              .entries
              .map((entry) => _buildMetricItem(
                entry.value,
                isLast: entry.key == items.length - 1,
              ))
              .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem(_MetricItem item, {required bool isLast}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: AppTypography.bodySmall),
                const SizedBox(height: 4),
                Text(item.subtext, style: AppTypography.caption),
              ],
            ),
            Text(item.value, style: AppTypography.titleSmall),
          ],
        ),
        if (!isLast) ...[
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  String _formatNumber(double num) {
    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(1)}M';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}K';
    }
    return num.toStringAsFixed(0);
  }
}

// ============ CHART WIDGETS ============

/// Bar Chart displaying product revenue
class BarChartWidget extends StatelessWidget {
  final List<dynamic> sales;

  const BarChartWidget({Key? key, required this.sales}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final productRevenue = <String, double>{};
    
    for (final sale in sales) {
      final productName = (sale['product_name'] ?? 
                          sale['product'] ?? 
                          sale['item'] ?? 
                          'Unknown').toString().trim();
      final amount = _toDouble(sale['total'] ?? sale['amount'] ?? 0);
      productRevenue.update(
        productName,
        (existing) => existing + amount,
        ifAbsent: () => amount,
      );
    }

    final topProducts = productRevenue.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
    final topProductsList = topProducts.take(5).toList();

    if (topProductsList.isEmpty) {
      return Center(
        child: Text('No product data', style: AppTypography.bodySmall),
      );
    }

    final maxValue = topProductsList.first.value;
    
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(topProductsList.length, (index) {
              final product = topProductsList[index];
              final height = (product.value / maxValue) * 200;
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: double.infinity,
                      height: height,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.7),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.key.substring(0, (product.key.length < 8 ? product.key.length : 8)),
                      style: GoogleFonts.poppins(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Top 5 Products by Revenue',
          style: AppTypography.caption,
        ),
      ],
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Line Chart displaying daily revenue trend
class LineChartWidget extends StatelessWidget {
  final List<dynamic> sales;

  const LineChartWidget({Key? key, required this.sales}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dailyRevenue = <DateTime, double>{};
    
    for (final sale in sales) {
      final saleDate = _parseDate(sale['created_at'] ?? sale['sale_date'] ?? '');
      final normalized = DateTime(saleDate.year, saleDate.month, saleDate.day);
      final amount = _toDouble(sale['total'] ?? sale['amount'] ?? 0);
      dailyRevenue.update(
        normalized,
        (existing) => existing + amount,
        ifAbsent: () => amount,
      );
    }

    final sortedDays = dailyRevenue.entries
        .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
    final sortedDaysList = sortedDays.take(7).toList();

    if (sortedDaysList.isEmpty) {
      return Center(
        child: Text('No daily data', style: AppTypography.bodySmall),
      );
    }

    final maxRevenue = sortedDaysList.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(sortedDaysList.length, (index) {
                final day = sortedDaysList[index];
                final height = (day.value / maxRevenue) * 200;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: double.infinity,
                        height: height,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withValues(alpha: 0.4),
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        day.key.day.toString(),
                        style: GoogleFonts.poppins(fontSize: 10),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Last 7 Days Revenue',
          style: AppTypography.caption,
        ),
      ],
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime _parseDate(String dateStr) {
    try {
      if (dateStr.isEmpty) return DateTime.now();
      final parsed = DateTime.tryParse(dateStr.trim());
      if (parsed == null) return DateTime.now();
      if (dateStr.contains('Z') || dateStr.contains('+')) {
        return parsed.toLocal();
      }
      return parsed;
    } catch (_) {
      return DateTime.now();
    }
  }
}

/// Pie Chart displaying product distribution
class PieChartWidget extends StatelessWidget {
  final List<dynamic> sales;

  const PieChartWidget({Key? key, required this.sales}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final productCount = <String, int>{};
    
    for (final sale in sales) {
      final String rawName = (sale['product_name'] ?? 
                          sale['product'] ?? 
                          sale['item'] ?? 
                          sale['description'] ??
                          'Unknown').toString().trim();
      final String productName = AnalyticsEngine.formatProductName(rawName);
      productCount.update(
        productName,
        (existing) => existing + 1,
        ifAbsent: () => 1,
      );
    }

    final topProducts = productCount.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
    final topProductsList = topProducts.take(5).toList();

    if (topProductsList.isEmpty) {
      return Center(
        child: Text('No product data', style: AppTypography.bodySmall),
      );
    }

    final total = topProductsList.fold<double>(0.0, (sum, e) => sum + e.value.toDouble()).toInt();
    final colors = [
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      AppColors.info,
      AppColors.danger,
    ];

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary.withValues(alpha: 0.1),
                              AppColors.primary.withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            topProducts.length.toString(),
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Products',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    topProductsList.length,
                    (index) {
                      final product = topProductsList[index];
                      final percentage = (product.value / total * 100).toStringAsFixed(1);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: colors[index % colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${percentage}%',
                                style: GoogleFonts.poppins(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Product Mix',
          style: AppTypography.caption,
        ),
      ],
    );
  }
}

/// Radar/Summary Chart
class RadarChartWidget extends StatelessWidget {
  final List<dynamic> sales;

  const RadarChartWidget({Key? key, required this.sales}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double totalRevenue = 0.0;
    int totalTransactions = 0;
    double avgSale = 0.0;
    int uniqueProducts = 0;

    if (sales.isNotEmpty) {
      totalRevenue = sales.fold(0.0, (sum, sale) {
        final amount = _toDouble(sale['total'] ?? sale['amount'] ?? 0);
        return sum + amount;
      });

      totalTransactions = sales.length;
      avgSale = totalRevenue / totalTransactions;

      final productIds = <String>{};
      for (final sale in sales) {
        final id = (sale['product_id'] ?? sale['barcode'] ?? 'Unknown').toString();
        if (id.isNotEmpty) productIds.add(id);
      }
      uniqueProducts = productIds.length;
    }

    final maxValue = totalRevenue > 0 ? totalRevenue : 100;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: CustomPaint(
            painter: RadarChartPainter(
              metrics: [
                totalRevenue / maxValue,
                totalTransactions / (totalTransactions > 0 ? totalTransactions : 100),
                avgSale / (avgSale > 0 ? avgSale * 2 : 100),
                uniqueProducts / (uniqueProducts > 0 ? uniqueProducts : 10),
              ],
              labels: ['Revenue', 'Transactions', 'Avg Sale', 'Products'],
            ),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Key Metrics Summary',
          style: AppTypography.caption,
        ),
      ],
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Custom Radar Chart Painter
class RadarChartPainter extends CustomPainter {
  final List<double> metrics;
  final List<String> labels;

  RadarChartPainter({required this.metrics, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;
    const sides = 4;

    // Draw grid
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final r = radius * (i / 3);
      final path = Path();
      for (int j = 0; j < sides; j++) {
        final angle = (j / sides) * 2 * pi;
        final x = center.dx + r * cos(angle);
        final y = center.dy + r * sin(angle);
        if (j == 0) path.moveTo(x, y);
        else path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Draw metric points and fill
    final path = Path();
    for (int i = 0; i < sides && i < metrics.length; i++) {
      final angle = (i / sides) * 2 * pi;
      final r = radius * (metrics[i].clamp(0.0, 1.0));
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(RadarChartPainter oldDelegate) => true;
}

class _MetricItem {
  final String label;
  final String value;
  final String subtext;

  _MetricItem({
    required this.label,
    required this.value,
    required this.subtext,
  });
}

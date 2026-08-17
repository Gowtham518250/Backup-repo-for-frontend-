import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// ─────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────

enum OrderStatus { processing, shipped, outForDelivery, delivered, cancelled, returned }

enum OrderFilter { all, active, delivered, cancelled }

class OrderItem {
  final String name;
  final double price;
  final int quantity;
  final String? imageUrl;

  OrderItem({
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        name: json['name'] ?? '',
        price: (json['price'] ?? 0).toDouble(),
        quantity: json['quantity'] ?? 1,
        imageUrl: json['imageUrl'],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'quantity': quantity,
        'imageUrl': imageUrl,
      };
}

class TrackingEvent {
  final String title;
  final String description;
  final DateTime timestamp;
  final String location;

  TrackingEvent({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.location,
  });

  factory TrackingEvent.fromJson(Map<String, dynamic> json) => TrackingEvent(
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
        location: json['location'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'location': location,
      };
}

class Order {
  final String id;
  final DateTime orderDate;
  OrderStatus status;
  final List<OrderItem> items;
  final double totalAmount;
  final String deliveryAddress;
  final String trackingId;
  final DateTime estimatedDelivery;
  final DateTime? actualDelivery;
  final String paymentMethod;
  final String deliverySlot;
  final List<TrackingEvent> trackingEvents;
  final String? deliveryPartner;
  final String? deliveryPersonName;
  final String? deliveryPersonPhone;

  Order({
    required this.id,
    required this.orderDate,
    required this.status,
    required this.items,
    required this.totalAmount,
    required this.deliveryAddress,
    required this.trackingId,
    required this.estimatedDelivery,
    this.actualDelivery,
    required this.paymentMethod,
    required this.deliverySlot,
    this.trackingEvents = const [],
    this.deliveryPartner,
    this.deliveryPersonName,
    this.deliveryPersonPhone,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] ?? '',
        orderDate: DateTime.tryParse(json['orderDate'] ?? '') ?? DateTime.now(),
        status: OrderStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => OrderStatus.processing,
        ),
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => OrderItem.fromJson(e))
            .toList(),
        totalAmount: (json['totalAmount'] ?? 0).toDouble(),
        deliveryAddress: json['deliveryAddress'] ?? '',
        trackingId: json['trackingId'] ?? '',
        estimatedDelivery:
            DateTime.tryParse(json['estimatedDelivery'] ?? '') ?? DateTime.now().add(const Duration(days: 3)),
        actualDelivery: json['actualDelivery'] != null ? DateTime.tryParse(json['actualDelivery']) : null,
        paymentMethod: json['paymentMethod'] ?? 'UPI',
        deliverySlot: json['deliverySlot'] ?? 'Standard Delivery',
        trackingEvents: (json['trackingEvents'] as List<dynamic>? ?? [])
            .map((e) => TrackingEvent.fromJson(e))
            .toList(),
        deliveryPartner: json['deliveryPartner'],
        deliveryPersonName: json['deliveryPersonName'],
        deliveryPersonPhone: json['deliveryPersonPhone'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderDate': orderDate.toIso8601String(),
        'status': status.name,
        'items': items.map((e) => e.toJson()).toList(),
        'totalAmount': totalAmount,
        'deliveryAddress': deliveryAddress,
        'trackingId': trackingId,
        'estimatedDelivery': estimatedDelivery.toIso8601String(),
        'actualDelivery': actualDelivery?.toIso8601String(),
        'paymentMethod': paymentMethod,
        'deliverySlot': deliverySlot,
        'trackingEvents': trackingEvents.map((e) => e.toJson()).toList(),
        'deliveryPartner': deliveryPartner,
        'deliveryPersonName': deliveryPersonName,
        'deliveryPersonPhone': deliveryPersonPhone,
      };
}

// ─────────────────────────────────────────────
// MAIN PAGE
// ─────────────────────────────────────────────

/// Flipkart-level Order Management with Real-time Tracking
class OrderManagementTracking extends StatefulWidget {
  const OrderManagementTracking({super.key});

  @override
  State<OrderManagementTracking> createState() => _OrderManagementTrackingState();
}

class _OrderManagementTrackingState extends State<OrderManagementTracking>
    with SingleTickerProviderStateMixin {
  List<Order> _orders = [];
  OrderFilter _filter = OrderFilter.all;
  bool _isLoading = true;
  late TabController _tabController;

  static const _tabFilters = [
    OrderFilter.all,
    OrderFilter.active,
    OrderFilter.delivered,
    OrderFilter.cancelled,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _filter = _tabFilters[_tabController.index]);
      }
    });
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final ordersJson = prefs.getString('user_orders');
    if (ordersJson != null) {
      final List<dynamic> decoded = json.decode(ordersJson);
      setState(() {
        _orders = decoded.map((e) => Order.fromJson(e)).toList();
        _isLoading = false;
      });
    } else {
      _loadSampleOrders();
    }
  }

  void _loadSampleOrders() {
    setState(() {
      _orders = [
        Order(
          id: 'ORD-2024-001',
          orderDate: DateTime.now().subtract(const Duration(days: 2)),
          status: OrderStatus.shipped,
          items: [
            OrderItem(name: 'iPhone 15 Pro', price: 149900, quantity: 1),
            OrderItem(name: 'AirPods Pro', price: 24900, quantity: 1),
          ],
          totalAmount: 174800,
          deliveryAddress: '123 Tech Street, Bangalore - 560001',
          trackingId: 'TRK123456789',
          estimatedDelivery: DateTime.now().add(const Duration(days: 3)),
          paymentMethod: 'UPI',
          deliverySlot: 'Standard Delivery (3-5 days)',
          deliveryPartner: 'BlueDart',
          deliveryPersonName: 'Ravi Kumar',
          deliveryPersonPhone: '+91-9876543210',
          trackingEvents: [
            TrackingEvent(
              title: 'Order Placed',
              description: 'Your order has been placed successfully',
              timestamp: DateTime.now().subtract(const Duration(days: 2)),
              location: 'Online',
            ),
            TrackingEvent(
              title: 'Order Confirmed',
              description: 'Seller has confirmed your order',
              timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 2)),
              location: 'Mumbai Warehouse',
            ),
            TrackingEvent(
              title: 'Shipped',
              description: 'Package picked up by BlueDart',
              timestamp: DateTime.now().subtract(const Duration(days: 1)),
              location: 'Mumbai Hub',
            ),
            TrackingEvent(
              title: 'In Transit',
              description: 'Package is on its way to your city',
              timestamp: DateTime.now().subtract(const Duration(hours: 6)),
              location: 'Bangalore Transit Hub',
            ),
          ],
        ),
        Order(
          id: 'ORD-2024-002',
          orderDate: DateTime.now().subtract(const Duration(days: 7)),
          status: OrderStatus.delivered,
          items: [
            OrderItem(name: 'Samsung Galaxy S24', price: 129999, quantity: 1),
          ],
          totalAmount: 129999,
          deliveryAddress: '456 Mobile Road, Chennai - 600001',
          trackingId: 'TRK987654321',
          estimatedDelivery: DateTime.now().subtract(const Duration(days: 2)),
          actualDelivery: DateTime.now().subtract(const Duration(days: 2)),
          paymentMethod: 'Credit Card',
          deliverySlot: 'Express Delivery (1-2 days)',
          deliveryPartner: 'Delhivery',
          trackingEvents: [
            TrackingEvent(
              title: 'Order Placed',
              description: 'Order placed',
              timestamp: DateTime.now().subtract(const Duration(days: 7)),
              location: 'Online',
            ),
            TrackingEvent(
              title: 'Delivered',
              description: 'Package delivered to your address',
              timestamp: DateTime.now().subtract(const Duration(days: 2)),
              location: 'Chennai',
            ),
          ],
        ),
        Order(
          id: 'ORD-2024-003',
          orderDate: DateTime.now().subtract(const Duration(days: 1)),
          status: OrderStatus.outForDelivery,
          items: [
            OrderItem(name: 'Nike Air Max 270', price: 12999, quantity: 2),
          ],
          totalAmount: 25998,
          deliveryAddress: '789 Sports Avenue, Mumbai - 400001',
          trackingId: 'TRK456789123',
          estimatedDelivery: DateTime.now(),
          paymentMethod: 'COD',
          deliverySlot: 'Same Day Delivery',
          deliveryPartner: 'Ekart',
          deliveryPersonName: 'Suresh M.',
          deliveryPersonPhone: '+91-9988776655',
          trackingEvents: [
            TrackingEvent(
              title: 'Order Placed',
              description: 'Order confirmed',
              timestamp: DateTime.now().subtract(const Duration(days: 1)),
              location: 'Online',
            ),
            TrackingEvent(
              title: 'Out for Delivery',
              description: 'Your package is out for delivery',
              timestamp: DateTime.now().subtract(const Duration(hours: 2)),
              location: 'Mumbai Local Hub',
            ),
          ],
        ),
        Order(
          id: 'ORD-2024-004',
          orderDate: DateTime.now().subtract(const Duration(days: 10)),
          status: OrderStatus.cancelled,
          items: [
            OrderItem(name: 'Sony WH-1000XM5', price: 29990, quantity: 1),
          ],
          totalAmount: 29990,
          deliveryAddress: '321 Audio Lane, Delhi - 110001',
          trackingId: 'TRK111222333',
          estimatedDelivery: DateTime.now().subtract(const Duration(days: 6)),
          paymentMethod: 'Net Banking',
          deliverySlot: 'Standard Delivery',
          trackingEvents: [
            TrackingEvent(
              title: 'Order Placed',
              description: 'Order placed',
              timestamp: DateTime.now().subtract(const Duration(days: 10)),
              location: 'Online',
            ),
            TrackingEvent(
              title: 'Cancelled',
              description: 'Order cancelled by customer',
              timestamp: DateTime.now().subtract(const Duration(days: 9)),
              location: '',
            ),
          ],
        ),
      ];
      _isLoading = false;
    });
  }

  List<Order> get _filteredOrders {
    switch (_filter) {
      case OrderFilter.all:
        return _orders;
      case OrderFilter.active:
        return _orders
            .where((o) =>
                o.status == OrderStatus.processing ||
                o.status == OrderStatus.shipped ||
                o.status == OrderStatus.outForDelivery)
            .toList();
      case OrderFilter.delivered:
        return _orders.where((o) => o.status == OrderStatus.delivered || o.status == OrderStatus.returned).toList();
      case OrderFilter.cancelled:
        return _orders.where((o) => o.status == OrderStatus.cancelled).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text('My Orders', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF6366F1),
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: const Color(0xFF6366F1),
            indicatorWeight: 3,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Active'),
              Tab(text: 'Delivered'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : RefreshIndicator(
              color: const Color(0xFF6366F1),
              onRefresh: _loadOrders,
              child: _filteredOrders.isEmpty ? _buildEmptyState() : _buildOrdersList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No orders found', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Pull to refresh or start shopping!', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400])),
          ],
        ),
      ],
    );
  }

  Widget _buildOrdersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredOrders.length,
      itemBuilder: (context, index) => _buildOrderCard(_filteredOrders[index]),
    );
  }

  Widget _buildOrderCard(Order order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showOrderDetails(order),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.id, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(
                        _formatDate(order.orderDate),
                        style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                  _buildStatusChip(order.status),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Items preview
              ...order.items.take(2).map((item) => _buildOrderItemRow(item)),
              if (order.items.length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+ ${order.items.length - 2} more items',
                    style: GoogleFonts.poppins(color: const Color(0xFF6366F1), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              const SizedBox(height: 12),
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹${order.totalAmount.toInt()}',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.black87),
                      ),
                      Text(
                        '${order.items.length} item${order.items.length > 1 ? 's' : ''} · ${order.paymentMethod}',
                        style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                  // Delivery info
                  if (order.status == OrderStatus.shipped || order.status == OrderStatus.outForDelivery)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_shipping, size: 14, color: Color(0xFF6366F1)),
                          const SizedBox(width: 4),
                          Text(
                            order.status == OrderStatus.outForDelivery
                                ? 'Out for delivery'
                                : 'By ${_formatDateShort(order.estimatedDelivery)}',
                            style: GoogleFonts.poppins(color: const Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  if (order.status == OrderStatus.delivered)
                    Row(
                      children: [
                        const Icon(Icons.check_circle, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Delivered ${_formatDateShort(order.actualDelivery ?? order.estimatedDelivery)}',
                          style: GoogleFonts.poppins(color: Colors.green[700], fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                ],
              ),
              // Delivery person card (out for delivery)
              if (order.status == OrderStatus.outForDelivery && order.deliveryPersonName != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.green[100],
                        child: Icon(Icons.delivery_dining, color: Colors.green[700], size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.deliveryPersonName!, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text('Delivery Partner · ${order.deliveryPartner ?? ''}',
                                style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 11)),
                          ],
                        ),
                      ),
                      if (order.deliveryPersonPhone != null)
                        IconButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Calling ${order.deliveryPersonPhone}...')),
                            );
                          },
                          icon: const Icon(Icons.call, color: Colors.green, size: 20),
                          style: IconButton.styleFrom(backgroundColor: Colors.green[100]),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderItemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF6366F1)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(item.name, style: GoogleFonts.poppins(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text('×${item.quantity}', style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12)),
          const SizedBox(width: 8),
          Text('₹${item.price.toInt()}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    final config = _statusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: config['bg'] as Color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config['icon'] as IconData, size: 12, color: config['color'] as Color),
          const SizedBox(width: 4),
          Text(
            config['label'] as String,
            style: GoogleFonts.poppins(color: config['color'] as Color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _statusConfig(OrderStatus status) {
    switch (status) {
      case OrderStatus.processing:
        return {'label': 'Processing', 'color': Colors.orange[800]!, 'bg': Colors.orange[50]!, 'icon': Icons.hourglass_top};
      case OrderStatus.shipped:
        return {'label': 'Shipped', 'color': Colors.blue[800]!, 'bg': Colors.blue[50]!, 'icon': Icons.local_shipping};
      case OrderStatus.outForDelivery:
        return {'label': 'Out for Delivery', 'color': Colors.purple[800]!, 'bg': Colors.purple[50]!, 'icon': Icons.delivery_dining};
      case OrderStatus.delivered:
        return {'label': 'Delivered', 'color': Colors.green[800]!, 'bg': Colors.green[50]!, 'icon': Icons.check_circle};
      case OrderStatus.cancelled:
        return {'label': 'Cancelled', 'color': Colors.red[800]!, 'bg': Colors.red[50]!, 'icon': Icons.cancel};
      case OrderStatus.returned:
        return {'label': 'Returned', 'color': Colors.purple[800]!, 'bg': Colors.purple[50]!, 'icon': Icons.assignment_return};
    }
  }

  String _formatDate(DateTime date) => '${date.day} ${_month(date.month)} ${date.year}';
  String _formatDateShort(DateTime date) => '${date.day} ${_month(date.month)}';
  String _month(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];

  void _showOrderDetails(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OrderDetailSheet(
        order: order,
        onTrackOrder: () { Navigator.pop(context); _showTrackingSheet(order); },
        onReturnOrder: () { Navigator.pop(context); _showReturnSheet(order); },
        onCancelOrder: () { Navigator.pop(context); _showCancelSheet(order); },
        onContactSupport: () { Navigator.pop(context); _showSupportSheet(order); },
      ),
    );
  }

  void _showTrackingSheet(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OrderTrackingSheet(order: order),
    );
  }

  void _showReturnSheet(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReturnRequestSheet(order: order),
    );
  }

  void _showCancelSheet(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CancelOrderSheet(order: order),
    );
  }

  void _showSupportSheet(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomerSupportSheet(order: order),
    );
  }
}

// ─────────────────────────────────────────────
// ORDER DETAIL SHEET
// ─────────────────────────────────────────────

class OrderDetailSheet extends StatelessWidget {
  final Order order;
  final VoidCallback onTrackOrder;
  final VoidCallback onReturnOrder;
  final VoidCallback onCancelOrder;
  final VoidCallback onContactSupport;

  const OrderDetailSheet({
    super.key,
    required this.order,
    required this.onTrackOrder,
    required this.onReturnOrder,
    required this.onCancelOrder,
    required this.onContactSupport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F6FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle + header
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.id, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(
                            'Ordered ${_formatDate(order.orderDate)}',
                            style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSection(
                    title: 'Order Items (${order.items.length})',
                    child: Column(
                      children: order.items.map((item) => _buildItemRow(item)).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    title: 'Price Details',
                    child: Column(
                      children: [
                        _buildPriceRow('Item Total', order.totalAmount),
                        _buildPriceRow('Delivery Fee', 0, valueText: 'FREE'),
                        const Divider(height: 20),
                        _buildPriceRow('Order Total', order.totalAmount, isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    title: 'Delivery Address',
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.location_on, color: Color(0xFF6366F1), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(order.deliveryAddress, style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    title: 'Payment & Delivery',
                    child: Column(
                      children: [
                        _buildInfoRow(Icons.payment, 'Payment Method', order.paymentMethod),
                        const SizedBox(height: 10),
                        _buildInfoRow(Icons.schedule, 'Delivery Slot', order.deliverySlot),
                        if (order.deliveryPartner != null) ...[
                          const SizedBox(height: 10),
                          _buildInfoRow(Icons.local_shipping, 'Delivery Partner', order.deliveryPartner!),
                        ],
                        if (order.trackingId.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildInfoRow(Icons.qr_code, 'Tracking ID', order.trackingId, copyable: true, context: context),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          // Action buttons
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -3))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (order.status == OrderStatus.shipped || order.status == OrderStatus.outForDelivery)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onTrackOrder,
                      icon: const Icon(Icons.location_on),
                      label: Text('Track Order', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                if (order.status == OrderStatus.delivered) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onReturnOrder,
                      icon: const Icon(Icons.assignment_return),
                      label: Text('Return / Exchange', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onContactSupport,
                        icon: const Icon(Icons.support_agent, size: 18),
                        label: Text('Support', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    if (order.status == OrderStatus.processing) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onCancelOrder,
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildItemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF6366F1)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(item.name, style: GoogleFonts.poppins(fontSize: 14))),
          Text('×${item.quantity}', style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(width: 12),
          Text('₹${item.price.toInt()}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isBold = false, String? valueText}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontWeight: isBold ? FontWeight.w700 : FontWeight.normal, fontSize: 14)),
          Text(
            valueText ?? '₹${amount.toInt()}',
            style: GoogleFonts.poppins(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
              color: valueText == 'FREE' ? Colors.green[700] : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool copyable = false, BuildContext? context}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[500]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 11)),
              Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
        if (copyable && context != null)
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tracking ID copied!')));
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  String _formatDate(DateTime d) => '${d.day} ${_month(d.month)} ${d.year}';
  String _month(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];
}

// ─────────────────────────────────────────────
// ORDER TRACKING SHEET
// ─────────────────────────────────────────────

class OrderTrackingSheet extends StatelessWidget {
  final Order order;

  const OrderTrackingSheet({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final events = order.trackingEvents.reversed.toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F6FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('Track Order', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(order.id, style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Tracking ID card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_shipping, color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tracking ID', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
                              Text(order.trackingId, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                              if (order.deliveryPartner != null)
                                Text('via ${order.deliveryPartner}', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: order.trackingId));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tracking ID copied!')));
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Progress steps
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Delivery Progress', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 16),
                        _buildProgressStep(context, 'Order Placed', Icons.shopping_bag_outlined,
                            true, isFirst: true),
                        _buildProgressStep(context, 'Processing', Icons.inventory_outlined,
                            order.status != OrderStatus.processing),
                        _buildProgressStep(context, 'Shipped', Icons.local_shipping_outlined,
                            [OrderStatus.shipped, OrderStatus.outForDelivery, OrderStatus.delivered, OrderStatus.returned].contains(order.status)),
                        _buildProgressStep(context, 'Out for Delivery', Icons.delivery_dining_outlined,
                            [OrderStatus.outForDelivery, OrderStatus.delivered, OrderStatus.returned].contains(order.status)),
                        _buildProgressStep(context, 'Delivered', Icons.home_outlined,
                            [OrderStatus.delivered, OrderStatus.returned].contains(order.status),
                            isLast: true,
                            estimatedDate: order.actualDelivery ?? order.estimatedDelivery),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tracking events timeline
                  if (events.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tracking History', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 16),
                          ...events.asMap().entries.map((entry) => _buildTrackingEvent(entry.value, entry.key == 0)),
                        ],
                      ),
                    ),
                  // Delivery person
                  if (order.deliveryPersonName != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.green[100],
                            child: Icon(Icons.delivery_dining, color: Colors.green[700], size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Delivery Partner', style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 11)),
                                Text(order.deliveryPersonName!, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                                Text(order.deliveryPartner ?? '', style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12)),
                              ],
                            ),
                          ),
                          if (order.deliveryPersonPhone != null)
                            ElevatedButton.icon(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Calling ${order.deliveryPersonPhone}...')),
                                );
                              },
                              icon: const Icon(Icons.call, size: 16),
                              label: const Text('Call'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(BuildContext context, String label, IconData icon, bool isCompleted,
      {bool isFirst = false, bool isLast = false, DateTime? estimatedDate}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCompleted ? const Color(0xFF6366F1) : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: isCompleted ? Colors.white : Colors.grey[400]),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: isCompleted ? const Color(0xFF6366F1) : Colors.grey[200],
              ),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
                  color: isCompleted ? Colors.black87 : Colors.grey[400],
                  fontSize: 14,
                ),
              ),
              if (isLast && estimatedDate != null)
                Text(
                  _formatDate(estimatedDate),
                  style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 11),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingEvent(TrackingEvent event, bool isLatest) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isLatest ? const Color(0xFF6366F1) : Colors.grey[300],
                shape: BoxShape.circle,
              ),
            ),
            Container(width: 2, height: 40, color: Colors.grey[200]),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: GoogleFonts.poppins(
                    fontWeight: isLatest ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                    color: isLatest ? const Color(0xFF6366F1) : Colors.black87,
                  ),
                ),
                Text(event.description, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12)),
                if (event.location.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 11, color: Colors.grey[400]),
                      const SizedBox(width: 2),
                      Text(event.location, style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 11)),
                    ],
                  ),
                Text(
                  _formatDateTime(event.timestamp),
                  style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) => '${d.day} ${_month(d.month)} ${d.year}';
  String _formatDateTime(DateTime d) => '${d.day} ${_month(d.month)} ${d.year}, ${_time(d)}';
  String _time(DateTime d) {
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final m = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }
  String _month(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];
}

// ─────────────────────────────────────────────
// RETURN REQUEST SHEET
// ─────────────────────────────────────────────

class ReturnRequestSheet extends StatefulWidget {
  final Order order;
  const ReturnRequestSheet({super.key, required this.order});

  @override
  State<ReturnRequestSheet> createState() => _ReturnRequestSheetState();
}

class _ReturnRequestSheetState extends State<ReturnRequestSheet> {
  String? _selectedReason;
  String _type = 'return'; // 'return' or 'exchange'
  final _notesController = TextEditingController();

  final _reasons = [
    'Item damaged or defective',
    'Wrong item delivered',
    'Item not as described',
    'Size / fit issue',
    'Changed my mind',
    'Other',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
            child: Row(
              children: [
                Expanded(child: Text('Return / Exchange', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type selector
                  Text('Request Type', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _typeButton('Return', 'return', Icons.assignment_return)),
                      const SizedBox(width: 10),
                      Expanded(child: _typeButton('Exchange', 'exchange', Icons.swap_horiz)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Order items
                  Text('Items to Return', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 10),
                  ...widget.order.items.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F6FA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, color: Color(0xFF6366F1), size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Text(item.name, style: GoogleFonts.poppins(fontSize: 13))),
                            Text('₹${item.price.toInt()}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
                  const SizedBox(height: 20),
                  // Reason
                  Text('Reason for Return', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 10),
                  ..._reasons.map((reason) => RadioListTile<String>(
                        value: reason,
                        groupValue: _selectedReason,
                        onChanged: (v) => setState(() => _selectedReason = v),
                        title: Text(reason, style: GoogleFonts.poppins(fontSize: 13)),
                        dense: true,
                        activeColor: const Color(0xFF6366F1),
                        contentPadding: EdgeInsets.zero,
                      )),
                  const SizedBox(height: 16),
                  // Notes
                  Text('Additional Notes (optional)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Describe the issue...',
                      hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: const Color(0xFFF5F6FA),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedReason == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${_type == 'return' ? 'Return' : 'Exchange'} request submitted!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Submit ${_type == 'return' ? 'Return' : 'Exchange'} Request',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
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

  Widget _typeButton(String label, String value, IconData icon) {
    final selected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEEF2FF) : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? const Color(0xFF6366F1) : Colors.transparent, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? const Color(0xFF6366F1) : Colors.grey[400]),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.poppins(fontWeight: selected ? FontWeight.w600 : FontWeight.normal, color: selected ? const Color(0xFF6366F1) : Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CANCEL ORDER SHEET
// ─────────────────────────────────────────────

class CancelOrderSheet extends StatefulWidget {
  final Order order;
  const CancelOrderSheet({super.key, required this.order});

  @override
  State<CancelOrderSheet> createState() => _CancelOrderSheetState();
}

class _CancelOrderSheetState extends State<CancelOrderSheet> {
  String? _selectedReason;

  final _reasons = [
    'Changed my mind',
    'Found better price elsewhere',
    'Ordered by mistake',
    'Delivery time too long',
    'Payment issue',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Cancel Order', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero),
            ],
          ),
          const SizedBox(height: 4),
          Text(widget.order.id, style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.red[700], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cancellation may not be possible if the order has been shipped.',
                    style: GoogleFonts.poppins(color: Colors.red[700], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Reason for Cancellation', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          ..._reasons.map((reason) => RadioListTile<String>(
                value: reason,
                groupValue: _selectedReason,
                onChanged: (v) => setState(() => _selectedReason = v),
                title: Text(reason, style: GoogleFonts.poppins(fontSize: 13)),
                dense: true,
                activeColor: Colors.red,
                contentPadding: EdgeInsets.zero,
              )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedReason == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Order cancellation request submitted.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Confirm Cancellation', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CUSTOMER SUPPORT SHEET
// ─────────────────────────────────────────────

class CustomerSupportSheet extends StatelessWidget {
  final Order order;

  const CustomerSupportSheet({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer Support', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                      Text('Order: ${order.id}', style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSupportOption(
                  context: context,
                  icon: Icons.chat_bubble_outline,
                  iconColor: const Color(0xFF6366F1),
                  title: 'Live Chat',
                  subtitle: 'Typically replies in 2 minutes',
                  badge: 'FAST',
                  badgeColor: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Live chat coming soon!')));
                  },
                ),
                const Divider(height: 24),
                _buildSupportOption(
                  context: context,
                  icon: Icons.phone_outlined,
                  iconColor: Colors.green,
                  title: 'Call Support',
                  subtitle: '+91 1800-123-4567 · Available 9AM–9PM',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calling support...')));
                  },
                ),
                const Divider(height: 24),
                _buildSupportOption(
                  context: context,
                  icon: Icons.email_outlined,
                  iconColor: Colors.orange,
                  title: 'Email Support',
                  subtitle: 'support@retailmind.com',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening email...')));
                  },
                ),
                const Divider(height: 24),
                _buildSupportOption(
                  context: context,
                  icon: Icons.help_outline,
                  iconColor: Colors.blue,
                  title: 'Help Center / FAQ',
                  subtitle: 'Browse common questions and guides',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FAQ coming soon!')));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportOption({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
    Color? badgeColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor ?? Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(badge, style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  Text(subtitle, style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

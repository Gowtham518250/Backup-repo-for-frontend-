import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'delivery_tracking.dart';
import 'delivery_tracking_websocket.dart';

class DeliveryTrackingPage extends StatefulWidget {
  final int orderId;
  
  const DeliveryTrackingPage({required this.orderId, super.key});

  @override
  State<DeliveryTrackingPage> createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends State<DeliveryTrackingPage> {
  late Future<DeliveryEntry?> _deliveryFuture;
  late DeliveryTrackingWebSocket _wsService;
  DeliveryEntry? _currentDelivery;

  @override
  void initState() {
    super.initState();
    _wsService = DeliveryTrackingWebSocket();
    _loadDelivery();
  }

  void _loadDelivery() {
    // Mock loading - replace with actual API call
    _deliveryFuture = Future.delayed(
      const Duration(milliseconds: 500),
      () {
        final delivery = DeliveryEntry(
          orderId: 'ORD-${widget.orderId}',
          customerPhone: '+91-98765-43210',
          customerAddress: '123 Main Street, City, State - 560001',
          orderAmount: 2499.0,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          dispatchedAt: DateTime.now().subtract(const Duration(hours: 1)),
          status: DeliveryStatus.dispatched,
        );
        _currentDelivery = delivery;
        
        // Connect to WebSocket for real-time updates
        Future.microtask(() {
          _wsService.connect(
            orderId: delivery.orderId,
            token: 'mock_jwt_token',
          );
        });
        
        return delivery;
      },
    );
  }
  
  @override
  void dispose() {
    _wsService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Order Tracking',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF635BFF),
        elevation: 0,
      ),
      body: FutureBuilder<DeliveryEntry?>(
        future: _deliveryFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final delivery = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 📦 Order Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey[200]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Order ${delivery.orderId}',
                              style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.bold)),
                          // 🔴 Real-time status badge with WebSocket updates
                          StreamBuilder<DeliveryUpdate>(
                            stream: _wsService.updateStream,
                            initialData: null,
                            builder: (context, snapshot) {
                              final status = snapshot.data?.status ?? delivery.status;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Text(_formatStatus(status),
                                        style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white)),
                                    if (_wsService.isConnected)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 6),
                                        child: SizedBox(
                                          width: 6,
                                          height: 6,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('₹${delivery.orderAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // 🚚 Tracking Timeline
                Text('Tracking Timeline',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildTimelineItem(
                  status: 'Order Placed',
                  time: _formatTime(delivery.createdAt),
                  completed: true,
                  current: false,
                ),
                _buildTimelineConnector(true),
                _buildTimelineItem(
                  status: 'Dispatched',
                  time: delivery.dispatchedAt != null 
                      ? _formatTime(delivery.dispatchedAt!) 
                      : 'Pending',
                  completed: delivery.dispatchedAt != null,
                  current: delivery.status == DeliveryStatus.dispatched,
                ),
                _buildTimelineConnector(delivery.deliveredAt != null),
                _buildTimelineItem(
                  status: 'Delivered',
                  time: delivery.deliveredAt != null 
                      ? _formatTime(delivery.deliveredAt!) 
                      : 'Pending',
                  completed: delivery.deliveredAt != null,
                  current: delivery.status == DeliveryStatus.delivered,
                ),
                const SizedBox(height: 24),
                
                // 📍 Delivery Address
                Text('Delivery Address',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFF635BFF)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(delivery.customerAddress ?? 'N/A',
                                style: GoogleFonts.poppins(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.phone, color: Color(0xFF635BFF)),
                          const SizedBox(width: 8),
                          Text(delivery.customerPhone ?? 'N/A',
                              style: GoogleFonts.poppins(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // 💬 Contact Support
                if (delivery.status != DeliveryStatus.delivered)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Open WhatsApp support
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Contacting support...')),
                        );
                      },
                      icon: const Icon(Icons.message),
                      label: const Text('Contact Support'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF635BFF)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimelineItem({
    required String status,
    required String time,
    required bool completed,
    required bool current,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: completed ? const Color(0xFF635BFF) : Colors.grey[300],
                shape: BoxShape.circle,
                border: current ? Border.all(color: const Color(0xFF635BFF), width: 3) : null,
              ),
              child: Center(
                child: completed
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : const SizedBox(),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status,
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.bold)),
                Text(time,
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineConnector(bool completed) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: SizedBox(
        height: 24,
        child: Center(
          child: Container(
            width: 2,
            color: completed ? const Color(0xFF635BFF) : Colors.grey[300],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return Colors.grey;
      case DeliveryStatus.dispatched:
        return Colors.orange;
      case DeliveryStatus.delivered:
        return Colors.green;
      case DeliveryStatus.paid:
        return Colors.blue;
      case DeliveryStatus.cancelled:
        return Colors.red;
    }
  }

  String _formatStatus(DeliveryStatus status) {
    return status.toString().split('.').last.toUpperCase();
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final day = dateTime.day;
    final month = dateTime.month;
    return '$hour:$minute, $day/$month';
  }
}

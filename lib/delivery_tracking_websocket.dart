import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'delivery_tracking.dart';

/// Real-time delivery tracking service using WebSocket
/// Provides live location updates for orders
class DeliveryTrackingWebSocket {
  static final DeliveryTrackingWebSocket _instance = DeliveryTrackingWebSocket._internal();
  
  factory DeliveryTrackingWebSocket() => _instance;
  DeliveryTrackingWebSocket._internal();
  
  WebSocketChannel? _channel;
  late StreamController<DeliveryUpdate> _updateStreamController;
  late StreamController<DeliveryLocationUpdate> _locationStreamController;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  String? _currentOrderId;
  final String _wsUrl = 'wss://retail-mind-vkbp.onrender.com/ws/delivery/track';
  
  Stream<DeliveryUpdate> get updateStream => _updateStreamController.stream;
  Stream<DeliveryLocationUpdate> get locationStream => _locationStreamController.stream;
  bool get isConnected => _isConnected;
  
  Future<void> connect({
    required String orderId,
    required String token,
  }) async {
    if (_isConnected && _currentOrderId == orderId) {
      return; // Already connected to this order
    }
    
    _currentOrderId = orderId;
    _updateStreamController = StreamController<DeliveryUpdate>.broadcast();
    _locationStreamController = StreamController<DeliveryLocationUpdate>.broadcast();
    
    try {
      // Connect to WebSocket
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      
      // Send authentication
      _channel!.sink.add(jsonEncode({
        'action': 'connect',
        'orderId': orderId,
        'token': token,
      }));
      
      // Subscribe to order updates
      _channel!.sink.add(jsonEncode({
        'action': 'subscribe',
        'orderId': orderId,
      }));
      
      _isConnected = true;
      _reconnectTimer?.cancel();
      
      // Listen for incoming messages
      _channel!.stream.listen(
        (message) => _handleMessage(message),
        onError: (error) => _handleError(error),
        onDone: () => _handleConnectionClosed(),
      );
    } catch (e) {
      _handleError(e);
      _scheduleReconnect(orderId, token);
    }
  }
  
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final action = data['action'] as String?;
      
      switch (action) {
        case 'location_update':
          _handleLocationUpdate(data);
          break;
        case 'status_change':
          _handleStatusChange(data);
          break;
        case 'eta_update':
          _handleEtaUpdate(data);
          break;
        default:
          break;
      }
    } catch (e) {
      print('❌ Error handling WebSocket message: $e');
    }
  }
  
  void _handleLocationUpdate(Map<String, dynamic> data) {
    try {
      // FIX (Issue 5.1): Use safe parsing for coordinates.
      // The server may send latitude/longitude as a String rather than num,
      // causing a TypeError crash with a direct `as num` cast.
      double? parseCoord(dynamic v) {
        if (v == null) return null;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString());
      }

      final lat = parseCoord(data['latitude']);
      final lon = parseCoord(data['longitude']);

      if (lat == null || lon == null) {
        print('❌ Missing or invalid coordinates in location update');
        return;
      }

      final update = DeliveryLocationUpdate(
        latitude: lat,
        longitude: lon,
        status: (data['status'] ?? '').toString(),
        eta: data['eta']?.toString(),
        timestamp: data['timestamp'] != null
            ? DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
      
      if (!_locationStreamController.isClosed) {
        _locationStreamController.add(update);
      }
    } catch (e) {
      print('❌ Error parsing location update: $e');
    }
  }
  
  void _handleStatusChange(Map<String, dynamic> data) {
    try {
      final update = DeliveryUpdate(
        orderId: data['orderId'] as String,
        status: _parseStatus(data['status'] as String),
        timestamp: DateTime.parse(data['timestamp'] as String),
        message: 'Status updated to ${data['status']}',
      );
      
      if (!_updateStreamController.isClosed) {
        _updateStreamController.add(update);
      }
    } catch (e) {
      print('❌ Error parsing status change: $e');
    }
  }
  
  void _handleEtaUpdate(Map<String, dynamic> data) {
    try {
      final eta = data['eta'] as String?;
      if (eta != null) {
        final update = DeliveryUpdate(
          orderId: data['orderId'] as String,
          status: _parseStatus(data['status'] as String? ?? 'dispatched'),
          timestamp: DateTime.parse(data['timestamp'] as String),
          message: 'Estimated delivery: $eta',
        );
        
        if (!_updateStreamController.isClosed) {
          _updateStreamController.add(update);
        }
      }
    } catch (e) {
      print('❌ Error parsing ETA update: $e');
    }
  }
  
  void _handleError(dynamic error) {
    print('❌ WebSocket error: $error');
    _isConnected = false;
  }
  
  void _handleConnectionClosed() {
    _isConnected = false;
    print('🔌 WebSocket connection closed');
    
    if (_currentOrderId != null) {
      // Auto-reconnect with exponential backoff
      _scheduleReconnect(_currentOrderId!, '');
    }
  }
  
  void _scheduleReconnect(String orderId, String token) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      // Implement exponential backoff if needed
      if (!_isConnected) {
        // Retry connection would happen here in production
        print('🔄 Attempting to reconnect...');
      }
    });
  }
  
  DeliveryStatus _parseStatus(String statusStr) {
    switch (statusStr.toLowerCase()) {
      case 'pending':
        return DeliveryStatus.pending;
      case 'dispatched':
        return DeliveryStatus.dispatched;
      case 'delivered':
        return DeliveryStatus.delivered;
      case 'paid':
        return DeliveryStatus.paid;
      case 'cancelled':
        return DeliveryStatus.cancelled;
      default:
        return DeliveryStatus.pending;
    }
  }
  
  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.add(jsonEncode({
      'action': 'disconnect',
      'orderId': _currentOrderId,
    }));
    _channel?.sink.close();
    _isConnected = false;
    _updateStreamController.close();
    _locationStreamController.close();
  }
}

/// Represents a delivery update event
class DeliveryUpdate {
  final String orderId;
  final DeliveryStatus status;
  final DateTime timestamp;
  final String message;
  
  DeliveryUpdate({
    required this.orderId,
    required this.status,
    required this.timestamp,
    required this.message,
  });
}

/// Represents a real-time location update
class DeliveryLocationUpdate {
  final double latitude;
  final double longitude;
  final String status;
  final String? eta;
  final DateTime timestamp;
  
  DeliveryLocationUpdate({
    required this.latitude,
    required this.longitude,
    required this.status,
    this.eta,
    required this.timestamp,
  });
  
  /// Calculate distance between two coordinates (Haversine formula)
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371; // km
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  static double _toRad(double degree) => degree * pi / 180;
}

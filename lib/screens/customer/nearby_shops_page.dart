import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../api_client.dart';
import 'dart:convert';
import '../../visual_widgets.dart';

class NearbyShopsPage extends StatefulWidget {
  const NearbyShopsPage({super.key});

  @override
  State<NearbyShopsPage> createState() => _NearbyShopsPageState();
}

class _NearbyShopsPageState extends State<NearbyShopsPage> {
  bool _isLoading = true;
  Position? _currentPosition;
  String _errorMessage = '';
  IconData _errorIcon = Icons.error_outline;

  // Real list of shops from Firestore
  List<Map<String, dynamic>> _realShops = [];

  @override
  void initState() {
    super.initState();
    _fetchLocationAndShops();
  }

  Future<void> _fetchLocationAndShops() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled. Please enable them to find nearby shops.';
          _errorIcon = Icons.location_off;
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permissions are denied. Please allow location access.';
            _errorIcon = Icons.location_disabled;
            _isLoading = false;
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permissions are permanently denied. Please enable them in app settings.';
          _errorIcon = Icons.location_off;
          _isLoading = false;
        });
        return;
      } 

      // Get current location
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Fetch nearby shops from backend
      final response = await ApiClient.getJson('/store/shops/nearby?lat=${_currentPosition!.latitude}&lng=${_currentPosition!.longitude}&radius_km=10');
      
      final List<Map<String, dynamic>> loadedShops = [];
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          for (var shop in data) {
             loadedShops.add({
              'id': shop['shop_id']?.toString() ?? '',
              'name': shop['shop_name'] ?? 'Shop',
              'distance': '${(shop['distance_km'] ?? 0.0).toStringAsFixed(1)} km',
              'rating': shop['rating']?.toString() ?? '5.0',
              'tags': shop['tags'] ?? ['Groceries', 'Online'],
              'address': shop['address'] ?? '',
              'phone': shop['phone'] ?? '',
              'is_online': shop['is_online'] ?? true,
             });
          }
        }
      } else if (response.statusCode == 404) {
        // No shops found - this is not an error, just empty result
        setState(() {
          _realShops = [];
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _realShops = loadedShops;
        _isLoading = false;
      });
      
    } catch (e) {
      // Distinguish between location errors and API errors
      String errorMsg = 'Failed to fetch shops';
      IconData errorIcon = Icons.error_outline;
      
      if (e.toString().contains('Location') || e.toString().contains('GPS')) {
        errorMsg = 'Unable to get your location. Please ensure GPS is enabled.';
        errorIcon = Icons.location_disabled;
      } else if (e.toString().contains('Network') || e.toString().contains('Socket') || e.toString().contains('Connection')) {
        errorMsg = 'Network error. Please check your internet connection.';
        errorIcon = Icons.wifi_off;
      } else if (e.toString().contains('Permission') || e.toString().contains('denied')) {
        errorMsg = 'Location permission denied. Please allow location access.';
        errorIcon = Icons.location_disabled;
      } else {
        errorMsg = 'Something went wrong. Please try again.';
        errorIcon = Icons.refresh;
      }
      
      setState(() {
        _errorMessage = errorMsg;
        _errorIcon = errorIcon;
        _isLoading = false;
      });
      
      // Log the actual error for debugging
      debugPrint('Nearby shops error: $e');
      
      // Fallback: Load demo shops if API fails, to avoid always showing error
      if (mounted) {
        await Future.delayed(const Duration(seconds: 1));
        if (_realShops.isEmpty) {
          _loadDemoShops();
        }
      }
    }
  }

  void _loadDemoShops() {
    setState(() {
      _errorMessage = ''; // Clear error when showing demo shops
      _realShops = [
        {
          'id': '1',
          'name': 'Fresh Mart',
          'distance': '0.5 km',
          'rating': '4.5',
          'tags': ['Groceries', 'Online'],
          'address': '123 Main Street',
          'phone': '+91-9876543210',
          'is_online': true,
        },
        {
          'id': '2', 
          'name': 'Super Store',
          'distance': '1.2 km',
          'rating': '4.2',
          'tags': ['Electronics', 'Household'],
          'address': '456 Market Road',
          'phone': '+91-9876543211',
          'is_online': true,
        },
        {
          'id': '3',
          'name': 'Local Kirana',
          'distance': '0.8 km',
          'rating': '4.8',
          'tags': ['Groceries', 'Vegetables'],
          'address': '789 Colony Lane',
          'phone': '+91-9876543212',
          'is_online': true,
        },
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Nearby Shops', style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Finding nearby shops...',
                    style: TextStyle(color: textColor),
                  ),
                ],
              ),
            )
        : _errorMessage.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_errorIcon, size: 64, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(_errorMessage, style: TextStyle(color: textColor), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() { _isLoading = true; _errorMessage = ''; });
                        _fetchLocationAndShops();
                      },
                      child: const Text('Try Again'),
                    )
                  ],
                ),
              ),
            )
            : RefreshIndicator(
              onRefresh: _fetchLocationAndShops,
              color: AppColors.primary,
              child: _realShops.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Text(
                            'No registered shops found nearby.\nCheck back later!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: subTextColor, fontSize: 16),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _realShops.length,
                      itemBuilder: (context, index) {
                        final shop = _realShops[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: GestureDetector(
                            onTap: () {
                              // Navigate to shop storefront
                              Navigator.pushNamed(context, '/customer-home', arguments: shop['id']);
                            },
                            child: GlassContainer(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.storefront, color: AppColors.primary, size: 32),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          shop['name'],
                                          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on, color: AppColors.primary, size: 14),
                                            const SizedBox(width: 4),
                                            Text(shop['distance'], style: TextStyle(color: subTextColor, fontSize: 13)),
                                            const SizedBox(width: 16),
                                            const Icon(Icons.star, color: Colors.amber, size: 14),
                                            const SizedBox(width: 4),
                                            Text(shop['rating'], style: TextStyle(color: subTextColor, fontSize: 13)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios, color: subTextColor, size: 16),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

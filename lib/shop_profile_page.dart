import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:crypto/crypto.dart';
import 'backup_service.dart';
import 'app_localizations.dart';
import 'visual_widgets.dart';
import 'security_service.dart';
import 'qr_scanner_page.dart';
import 'retail_growth_kit.dart';
import 'api_client.dart';
import 'secure_token_storage.dart';
import 'validation_helper.dart';
import 'shop_profile_persistence_service.dart';

class ShopProfilePage extends StatefulWidget {
  const ShopProfilePage({super.key});

  @override
  State<ShopProfilePage> createState() => _ShopProfilePageState();
}

class _ShopProfilePageState extends State<ShopProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController shopNameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController shopTypeController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();
  final TextEditingController playStoreUrlController = TextEditingController();
  final TextEditingController taglineController = TextEditingController();
  final TextEditingController upiIdController = TextEditingController();
  final TextEditingController gstController = TextEditingController();
  
  Uint8List? logoBytes;
  bool isLoading = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _onlineShoppingEnabled = false;
  bool _togglingOnline = false;
  String? successMessage;
  String? errorMessage;
  String? _scannedStateCode;

  @override
  void initState() {
    super.initState();
    _loadShopData();
  }

  Future<void> _loadShopData() async {
    final prefs = await SharedPreferences.getInstance();
    final biometricAvailable = await SecurityService.isBiometricHardwareAvailable();
    final biometricEnabled = await SecurityService.isBiometricEnabled();

    setState(() {
      shopNameController.text = prefs.getString('shop_name') ?? '';
      locationController.text = prefs.getString('location') ?? '';
      shopTypeController.text = prefs.getString('shop_type') ?? '';
      phoneController.text = prefs.getString('shop_phone') ?? '';
      websiteController.text = prefs.getString('website') ?? '';
      playStoreUrlController.text = prefs.getString(RetailGrowthKit.kPlayStoreHint) ?? '';
      taglineController.text = prefs.getString('shop_tagline') ?? prefs.getString('tagline') ?? '';  // 🔧 Try backend key first
      upiIdController.text = prefs.getString('primary_upi_id') ?? prefs.getString('upi_id') ?? '';  // 🔧 Try backend key first
      gstController.text = prefs.getString('shop_gst') ?? prefs.getString('gst_number') ?? '';
      _scannedStateCode = prefs.getString('state') ?? prefs.getString('shop_state');  // 🔧 Try backend key first
      
      final logoBase64 = prefs.getString('logo_base64');
      if (logoBase64 != null && logoBase64.isNotEmpty) {
        try {
          logoBytes = base64Decode(logoBase64);
        } catch (e) {
          print('Error decoding logo: $e');
        }
      }

      _biometricAvailable = biometricAvailable;
      _biometricEnabled = biometricEnabled;
      _onlineShoppingEnabled = prefs.getBool('online_shopping_enabled') ?? false;
    });

    await _loadShopDataFromBackend();
  }

  Future<int> _resolveUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0;
  }

  Future<String> _resolveAuthToken() async {
    // 🛡️ SECURITY FIX #1: Always use SecureTokenStorage, never fallback to plain prefs
    final token = await SecureTokenStorage.getToken();
    return token ?? '';
  }

  Map<String, dynamic> _buildShopPayload(int userId) {
    return {
      'user_id': userId,
      'shop_name': shopNameController.text.trim(),
      'location': locationController.text.trim(),
      'shop_type': shopTypeController.text.trim(),
      'shop_phone': phoneController.text.trim(),
      'website': websiteController.text.trim(),
      'shop_tagline': taglineController.text.trim(),
      'primary_upi_id': upiIdController.text.trim(),
      'gst_number': gstController.text.trim(),
      'state': _scannedStateCode ?? '',
    };
  }

  void _applyShopMapToControllers(Map<String, dynamic> shop) {
    String _pick(List<String> keys) {
      for (final key in keys) {
        final raw = shop[key];
        if (raw != null) {
          final txt = raw.toString().trim();
          if (txt.isNotEmpty) return txt;
        }
      }
      return '';
    }

    if (!mounted) return;
    setState(() {
      final shopName = _pick(['shop_name', 'name']);
      final location = _pick(['location', 'address']);
      final shopType = _pick(['shop_type', 'type']);
      final phone = _pick(['shop_phone', 'phone', 'mobile']);
      final website = _pick(['website']);
      final tagline = _pick(['shop_tagline', 'tagline']);  // 🔧 Try backend key first
      final upiId = _pick(['primary_upi_id', 'upi_id', 'upi']);  // 🔧 Try backend key first
      final gst = _pick(['shop_gst', 'gst_number', 'gstin']);
      final state = _pick(['state', 'shop_state']);  // 🔧 Try backend key first
      final playStore = _pick(['play_store_url', 'play_store_link', 'app_link']);

      if (shopName.isNotEmpty) shopNameController.text = shopName;
      if (location.isNotEmpty) locationController.text = location;
      if (shopType.isNotEmpty) shopTypeController.text = shopType;
      if (phone.isNotEmpty) phoneController.text = phone;
      if (website.isNotEmpty) websiteController.text = website;
      if (tagline.isNotEmpty) taglineController.text = tagline;
      if (upiId.isNotEmpty) upiIdController.text = upiId;
      if (gst.isNotEmpty) gstController.text = gst;
      if (state.isNotEmpty) _scannedStateCode = state;
      if (playStore.isNotEmpty) playStoreUrlController.text = playStore;
    });
  }

  Future<void> _persistShopFieldsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shop_name', shopNameController.text.trim());
    await prefs.setString('location', locationController.text.trim());
    await prefs.setString('shop_type', shopTypeController.text.trim());
    await prefs.setString('shop_phone', phoneController.text.trim());
    await prefs.setString('website', websiteController.text.trim());
    await prefs.setString(RetailGrowthKit.kPlayStoreHint, playStoreUrlController.text.trim());
    await prefs.setString('shop_tagline', taglineController.text.trim());
    await prefs.setString('primary_upi_id', upiIdController.text.trim());
    await prefs.setString('upi_id', upiIdController.text.trim()); // 🔧 Backwards compatibility
    await prefs.setString('shop_gst', gstController.text.trim());
    await prefs.setString('gst_number', gstController.text.trim());

    if (_scannedStateCode != null) {
      await prefs.setString('state', _scannedStateCode!);
    }
    if (logoBytes != null) {
      await prefs.setString('logo_base64', base64Encode(logoBytes!));
    }
    
    // 🔐 SECURITY: Don't save full profile as JSON locally - rely only on backend as source of truth
    // When dashboard loads, it will fetch fresh data from backend
    // This prevents stale data from being shared across different user accounts
  }

  Future<void> _loadShopDataFromBackend() async {
    try {
      final userId = await _resolveUserId();
      if (userId <= 0) {
        if (kDebugMode) debugPrint('⚠️ User ID not found for backend load');
        return;
      }

      final token = await _resolveAuthToken();
      if (token.isEmpty) {
        if (kDebugMode) debugPrint('⚠️ Auth token not found for backend load');
        return;
      }

      if (kDebugMode) debugPrint('🔄 Loading shop profile from backend...');
      
      final resp = await ApiClient.getJson(
        '${ApiClient.shopProfile}?user_id=$userId',
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      if (kDebugMode) debugPrint('📥 Backend response: ${resp.statusCode} - ${resp.body}');

      if (resp.statusCode != 200) {
        if (kDebugMode) debugPrint('⚠️ Backend load failed with status ${resp.statusCode}');
        return;
      }
      
      final decoded = json.decode(resp.body);
      Map<String, dynamic>? map;
      
      if (decoded is Map<String, dynamic>) {
        final dynamic nested = decoded['profile'] ?? decoded['shop'] ?? decoded['data'];
        if (nested is Map<String, dynamic>) {
          map = nested;
        } else {
          map = decoded;
        }
      }
      
      if (map == null || map.isEmpty) {
        if (kDebugMode) debugPrint('⚠️ Backend response is empty or invalid');
        return;
      }
      
      if (kDebugMode) debugPrint('✅ Shop profile loaded from backend successfully');
      _applyShopMapToControllers(map);
      await _persistShopFieldsLocally();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Backend load error: $e');
      // Keep local-first behavior if backend is unavailable.
    }
  }

  Future<bool> _saveShopProfileToBackend() async {
    final userId = await _resolveUserId();
    if (userId <= 0) {
      if (kDebugMode) debugPrint('❌ User ID not found');
      return false;
    }

    final token = await _resolveAuthToken();
    if (token.isEmpty) {
      if (kDebugMode) debugPrint('❌ Auth token not found');
      return false;
    }

    final payload = _buildShopPayload(userId);
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    try {
      if (kDebugMode) debugPrint('🔄 Attempting to save shop profile to backend...');
      if (kDebugMode) debugPrint('📤 Payload: ${_redactSensitiveData(payload)}');

      // Try PUT method first for updates
      try {
        final putResp = await ApiClient.putJson(
          '${ApiClient.shopProfile}?user_id=$userId',
          payload,
          headers: headers,
        ).timeout(const Duration(seconds: 15));

        if (kDebugMode) debugPrint('📥 PUT response: ${putResp.statusCode} - ${putResp.body}');

        if (putResp.statusCode == 200 || putResp.statusCode == 201) {
          if (kDebugMode) debugPrint('✅ Shop profile updated successfully via PUT');
          return true;
        }
        if (kDebugMode) debugPrint('⚠️ PUT to profile failed with status ${putResp.statusCode}: ${putResp.body}');
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ PUT to profile request failed: $e');
      }

      // If PUT fails, try CREATE (new shop) using POST
      try {
        if (kDebugMode) debugPrint('🔄 Trying CREATE endpoint with POST...');
        final postResp = await ApiClient.postJson(
          '${ApiClient.shopCreate}?user_id=$userId',
          payload,
          headers: headers,
        ).timeout(const Duration(seconds: 15));

        if (kDebugMode) debugPrint('📥 POST create response: ${postResp.statusCode} - ${postResp.body}');

        if (postResp.statusCode == 200 || postResp.statusCode == 201) {
          if (kDebugMode) debugPrint('✅ Shop profile created successfully via POST');
          return true;
        }
        if (kDebugMode) debugPrint('⚠️ POST to create failed with status ${postResp.statusCode}: ${postResp.body}');
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ POST to create request failed: $e');
      }

      // Last fallback: try POST to profile endpoint
      try {
        if (kDebugMode) debugPrint('🔄 Trying POST method as fallback...');
        final postResp = await ApiClient.postJson(
          ApiClient.shopProfile,
          payload,
          headers: headers,
        ).timeout(const Duration(seconds: 15));

        if (kDebugMode) debugPrint('📥 POST profile response: ${postResp.statusCode} - ${postResp.body}');

        if (postResp.statusCode == 200 || postResp.statusCode == 201) {
          if (kDebugMode) debugPrint('✅ Shop profile created/updated successfully via POST');
          return true;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ POST to profile request failed: $e');
      }

      if (kDebugMode) debugPrint('❌ All backend sync attempts failed');
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Backend sync error: $e');
      return false;
    }
  }

  // Helper to redact sensitive data for logging
  Map<String, dynamic> _redactSensitiveData(Map<String, dynamic> data) {
    final sensitiveKeys = ['token', 'password', 'upi_id', 'gst', 'phone'];
    final redacted = Map<String, dynamic>.from(data);
    sensitiveKeys.forEach((key) {
      if (redacted.containsKey(key) && redacted[key] != null) {
        final value = redacted[key].toString();
        if (value.length > 3) {
          redacted[key] = '${value.substring(0, 3)}***';
        } else {
          redacted[key] = '***';
        }
      }
    });
    return redacted;
  }

  Future<void> scanUpiQr() async {
    final String? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerPage()),
    );

    if (result != null && result.isNotEmpty) {
      // Parse UPI URL: upi://pay?pa=address@bank&pn=Name...
      try {
        final uri = Uri.parse(result);
        if (uri.scheme == 'upi') {
          final upiId = uri.queryParameters['pa'];
          if (upiId != null) {
            setState(() {
              upiIdController.text = upiId;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ UPI ID detected: $upiId'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          } else {
            throw 'UPI ID (pa) missing in code';
          }
        } else {
           // Maybe it's just the raw ID?
           if (result.contains('@')) {
             setState(() => upiIdController.text = result);
           } else {
             throw 'Invalid UPI QR format';
           }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Could not read UPI ID: $e')),
        );
      }
    }
  }



  Future<void> pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (kIsWeb) {
          setState(() {
            logoBytes = file.bytes;
          });
        } else {
          final bytes = await File(file.path!).readAsBytes();
          setState(() {
            logoBytes = bytes;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  /// 🔧 Upload logo to backend using POST /api/shop/upload-logo
  Future<bool> _uploadLogoToBackend() async {
    if (logoBytes == null || logoBytes!.isEmpty) {
      return false; // No logo to upload
    }

    try {
      final userId = await _resolveUserId();
      if (userId <= 0) return false;

      final token = await _resolveAuthToken();
      if (token.isEmpty) return false;

      // Create multipart file from bytes
      final multipartFile = http.MultipartFile.fromBytes(
        'logo_file',
        logoBytes!,
        filename: 'shop_logo_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      // Upload to backend
      final resp = await ApiClient.postMultipart(
        ApiClient.shopUploadLogo,
        {
          'user_id': userId.toString(),
          'userId': userId.toString(),
        },
        headers: {
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        files: [multipartFile],
      ).timeout(const Duration(seconds: 30));

      final statusCode = resp.statusCode;
      if (kDebugMode) debugPrint('✅ Logo upload response: $statusCode');

      return statusCode == 200 || statusCode == 201;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Logo upload failed: $e');
      return false;
    }
  }

  Future<void> _fetchLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied forever. Please enable in settings.')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fetching address details...')),
      );

      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse'
          '?format=jsonv2&lat=${position.latitude}&lon=${position.longitude}&addressdetails=1&accept-language=en');
          
      try {
        final resp = await http.get(
          url,
          headers: kIsWeb ? {} : {'User-Agent': 'AiShopkeeperApp/1.0'},
        ).timeout(const Duration(seconds: 8));

        if (resp.statusCode == 200) {
          final data = json.decode(resp.body) as Map<String, dynamic>;
          final addr = data['address'] as Map<String, dynamic>? ?? {};

          final stateName = (addr['state'] ?? addr['state_district'] ?? '').toString().trim();
          String discoveredStateCode = 'MH'; // Default
          if (stateName.toLowerCase().contains('maharashtra')) discoveredStateCode = 'MH';
          else if (stateName.toLowerCase().contains('uttar pradesh')) discoveredStateCode = 'UP';
          else if (stateName.toLowerCase().contains('karnataka')) discoveredStateCode = 'KA';
          else if (stateName.toLowerCase().contains('delhi')) discoveredStateCode = 'DL';
          else if (stateName.toLowerCase().contains('tamil nadu')) discoveredStateCode = 'TN';
          else if (stateName.toLowerCase().contains('gujarat')) discoveredStateCode = 'GJ';
          else if (stateName.toLowerCase().contains('telangana')) discoveredStateCode = 'TS';

          final parts = <String>[
            if ((addr['road'] ?? addr['street'] ?? addr['pedestrian'] ?? '').toString().trim().isNotEmpty)
              (addr['road'] ?? addr['street'] ?? addr['pedestrian']).toString().trim(),
            if ((addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter'] ?? '').toString().trim().isNotEmpty)
              (addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter']).toString().trim(),
            if ((addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'] ?? '').toString().trim().isNotEmpty)
              (addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county']).toString().trim(),
            if (stateName.isNotEmpty) stateName,
            if ((addr['country'] ?? '').toString().trim().isNotEmpty)
              (addr['country']).toString().trim(),
          ];

          String readableAddress;
          if (parts.length >= 2) {
            readableAddress = parts.join(', ');
          } else if (data['display_name'] != null) {
            final displayParts = (data['display_name'] as String).split(', ');
            final meaningful = displayParts
                .where((p) => !RegExp(r'^\d+$').hasMatch(p.trim()))
                .toList();
            readableAddress = meaningful.length > 4
                ? meaningful.sublist(meaningful.length - 4).join(', ')
                : meaningful.join(', ');
          } else {
            readableAddress =
                '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
          }

          setState(() {
            locationController.text = readableAddress;
            _scannedStateCode = discoveredStateCode;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('📍 Bound to State: $stateName ($discoveredStateCode) for Auto-Pricing!')),
          );
        } else {
          throw Exception('HTTP ${resp.statusCode}');
        }
      } catch (e) {
        // Fallback to coordinates
        setState(() {
          locationController.text = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get address, showing coordinates.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching location: $e')),
      );
    }
  }
  
  Future<void> _forceRetrySync() async {
    try {
      setState(() {
        isLoading = true;
        successMessage = 'Retrying sync...';
        errorMessage = null;
      });
      
      final success = await ShopProfilePersistenceService.forceSyncPending();
      
      setState(() {
        isLoading = false;
        if (success) {
          successMessage = '✅ Sync completed successfully!';
        } else {
          successMessage = null;
          errorMessage = '⚠️ Sync still pending - will retry automatically';
        }
      });
      
      // Reload data after sync
      await _loadShopDataFromBackend();
    } catch (e) {
      setState(() {
        isLoading = false;
        successMessage = null;
        errorMessage = 'Sync failed: $e';
      });
    }
  }

  Future<void> _toggleOnlineShopping(bool enable) async {
    setState(() {
      _togglingOnline = true;
      errorMessage = null;
      successMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('shop_id') ?? prefs.getInt('user_id')?.toString() ?? '';

      // Optimistic update
      setState(() => _onlineShoppingEnabled = enable);

      // Backend expects 'enable' as query param, not JSON body
      final enableParam = enable ? 'true' : 'false';
      final resp = await ApiClient.postJson(
        '${ApiClient.shopToggleOnlineStore}?enable=$enableParam',
        {},
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        await prefs.setBool('online_shopping_enabled', enable);
        setState(() {
          successMessage = enable ? 'Online store enabled ✅' : 'Online store disabled';
        });
      } else {
        // Revert optimistic
        setState(() => _onlineShoppingEnabled = !enable);
        final body = resp.body;
        setState(() {
          errorMessage = 'Failed to update online store (${resp.statusCode})';
        });
        if (kDebugMode) debugPrint('Toggle online store failed: $body');
      }
    } catch (e) {
      setState(() {
        _onlineShoppingEnabled = !_onlineShoppingEnabled;
        errorMessage = 'Network error: $e';
      });
    } finally {
      setState(() => _togglingOnline = false);
      // Clear messages after a few seconds
      Future.delayed(const Duration(seconds: 4), () {
        if (!mounted) return;
        setState(() {
          successMessage = null;
          errorMessage = null;
        });
      });
    }
  }
  
  Widget _buildSyncStatusIndicator() {
  return FutureBuilder<Map<String, dynamic>>(
    future: ShopProfilePersistenceService.getSyncStatus(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox.shrink();

      final status = snapshot.data!;
      final hasPending = status['has_pending_sync'] == true;
      final isSyncing = status['is_syncing'] == true;

      if (!hasPending && !isSyncing) return const SizedBox.shrink();

      final Color bgColor;
      final Color iconColor;
      final IconData icon;
      final String message;

      if (isSyncing) {
        bgColor = Colors.blue.shade50;
        iconColor = Colors.blue.shade700;
        icon = Icons.sync;
        message = 'Syncing profile...';
      } else if (hasPending) {
        bgColor = Colors.orange.shade50;
        iconColor = Colors.orange.shade700;
        icon = Icons.cloud_off;
        message = 'Profile pending sync - will retry automatically';
      } else {
        return const SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: bgColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: iconColor, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    },
  );
}
  Future<void> saveShopProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    // First check sync status before saving
    final syncStatus = await ShopProfilePersistenceService.getSyncStatus();
    if (syncStatus['has_pending_sync'] == true) {
      // Try to sync pending first
      if (kDebugMode) debugPrint('🔄 Attempting to sync pending profile before save...');
      await ShopProfilePersistenceService.forceSyncPending();
    }
    
    setState(() {
      isLoading = true;
      successMessage = null;
      errorMessage = null;
    });

    try {
      // Build the profile payload
      final userId = await _resolveUserId();
      final profile = _buildShopPayload(userId);
      
      // 🔧 IMPORTANT: Use ShopProfilePersistenceService to save and sync
      await ShopProfilePersistenceService.saveProfileLocally(profile);
      if (kDebugMode) debugPrint('✅ Shop profile saved locally');

      // 🔧 Try to sync to backend
      final syncResult = await ShopProfilePersistenceService.syncProfileToBackend(profile);
      final synced = syncResult['success'] == true;
      if (kDebugMode) debugPrint('🔄 Backend sync result: $syncResult');

      // 🔧 If sync failed, mark for background retry
      if (!synced) {
        await ShopProfilePersistenceService.markForSync(profile);
        if (kDebugMode) debugPrint('📝 Profile marked for background sync');
      }

      // 🔧 NEW: Upload logo if available
      bool logoUploaded = false;
      if (logoBytes != null && logoBytes!.isNotEmpty) {
        logoUploaded = await _uploadLogoToBackend();
        if (kDebugMode) debugPrint('🔄 Logo upload result: $logoUploaded');
      }

      // Also persist individual fields for backwards compatibility
      await _persistShopFieldsLocally();

      setState(() {
        if (synced && logoUploaded) {
          successMessage = '✅ Shop profile & logo saved to cloud! 🎉';
          errorMessage = null;
        } else if (synced && !logoUploaded && logoBytes != null) {
          successMessage = '✅ Profile saved to cloud. Logo upload pending...';
          errorMessage = null;
        } else if (synced) {
          successMessage = '✅ Shop profile saved to cloud! 🎉';
          errorMessage = null;
        } else {
          // Saved locally, waiting for sync
          successMessage = '💾 Profile saved locally. Will sync when internet is available.';
          errorMessage = syncResult['error'] != null ? '⚠️ Backend sync failed: ${syncResult['error']}' : '⚠️ Backend sync failed - will retry automatically';
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              synced
                  ? (logoUploaded ? '✅ Profile & logo synced to backend!' : '✅ Profile synced to backend!')
                  : '💾 Profile saved locally. Will sync online.',
            ),
            backgroundColor: synced ? const Color(0xFF10B981) : Colors.orange[600],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error saving profile: $e');
      setState(() {
        errorMessage = 'Error: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackendLoadingOverlay(
      isVisible: isLoading,
      title: 'Saving your profile',
      subtitle: 'Uploading your shop details and syncing with the backend',
      icon: Icons.cloud_upload_rounded,
      accentColor: AppColors.primary,
      child: PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) return;
        // Check if form has changes before allowing back
        final hasChanges = shopNameController.text.isNotEmpty ||
            locationController.text.isNotEmpty ||
            taglineController.text.isNotEmpty ||
            upiIdController.text.isNotEmpty;
        
        if (hasChanges) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Discard Changes?'),
              content: const Text('You have unsaved shop profile changes.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Keep Editing'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
        } else {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF020617),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            'Shop Profile',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        // Share shop action
                        IconButton(
                          icon: const Icon(Icons.share_rounded, color: Colors.white70),
                          tooltip: 'Share Shop',
                          onPressed: () async {
                            try {
                              final prefs = await SharedPreferences.getInstance();
                              final shopId = prefs.getString('shop_id') ?? prefs.getInt('user_id')?.toString() ?? '1';
                              final shopName = prefs.getString('shop_name') ?? shopNameController.text.trim();
                              final shopUrl = 'https://retail-mind-web.onrender.com/shop/$shopId';
                              await Share.share('🛍️ Browse products from $shopName\n$shopUrl', subject: 'Visit $shopName');
                            } catch (e) {
                              if (kDebugMode) debugPrint('Share failed: $e');
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not share shop')));
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827).withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 18,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildLogoPicker(),
                          const SizedBox(height: 24),
                          _buildForm(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildLogoPicker() {
    return Column(
      children: [
        GestureDetector(
          onTap: pickLogo,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surfaceDark2,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
              image: logoBytes != null
                  ? DecorationImage(image: MemoryImage(logoBytes!), fit: BoxFit.cover)
                  : null,
            ),
            child: logoBytes == null
                ? Icon(Icons.add_a_photo_rounded, size: 40, color: AppColors.primary)
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Upload Shop Logo',
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }



  Widget _buildForm() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _StyledField(
              controller: shopNameController,
              label: 'Shop Name',
              icon: Icons.storefront_rounded,
              validator: (v) => v!.isEmpty ? 'Please enter shop name' : null,
            ),
            const SizedBox(height: 16),
            _StyledField(
              controller: locationController,
              label: 'Location',
              icon: Icons.location_on_rounded,
              suffixIcon: IconButton(
                icon: const Icon(Icons.my_location, color: Colors.white70),
                onPressed: _fetchLocation,
              ),
              validator: (v) => v!.isEmpty ? 'Please enter location' : null,
            ),
            const SizedBox(height: 16),
            _StyledField(
              controller: shopTypeController,
              label: 'Shop Type',
              icon: Icons.category_rounded,
              hint: 'e.g. Grocery, Electronics',
            ),
            const SizedBox(height: 16),
            _StyledField(
              controller: phoneController,
              label: 'Shop Phone Number',
              icon: Icons.phone_android_rounded,
              hint: 'e.g. +91 9876543210',
            ),
            const SizedBox(height: 16),
            _StyledField(
              controller: websiteController,
              label: 'Website',
              icon: Icons.language_rounded,
              hint: 'optional',
            ),
            const SizedBox(height: 16),
            _StyledField(
              controller: playStoreUrlController,
              label: 'Play Store / invite link',
              icon: Icons.shop_two_rounded,
              hint: 'https://play.google.com/... (optional, for Share from dashboard)',
              keyboardType: TextInputType.url,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return null;
                final u = Uri.tryParse(t);
                if (u == null || !u.hasScheme || (u.scheme != 'http' && u.scheme != 'https')) {
                  return 'Use a full URL starting with https://';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _StyledField(
              controller: upiIdController,
              label: 'UPI ID (VPA) for Payments',
              hint: 'e.g. shopname@okicici',
              icon: Icons.alternate_email_rounded,
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.indigoAccent),
                onPressed: scanUpiQr,
                tooltip: 'Scan existing QR to auto-fill',
              ),
              validator: (v) => InputValidator.validateUpiId(v),  // 🔧 Added UPI validation
            ),
            const SizedBox(height: 16),
            _StyledField(
              controller: taglineController,
              label: 'Shop Tagline (Optional)',
              icon: Icons.auto_awesome_rounded,
            ),
            const SizedBox(height: 16),
            _StyledField(
              controller: gstController,
              label: 'GSTIN (Optional)',
              hint: 'e.g. 27AAAAA0000A1Z5',
              icon: Icons.receipt_long_rounded,
            ),
            const SizedBox(height: 16),
            // Enable Online Shopping toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_rounded, color: Colors.white70),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Enable Online Shopping', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Allow customers to browse & order online', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _onlineShoppingEnabled,
                    onChanged: _togglingOnline ? null : (v) => _toggleOnlineShopping(v),
                    activeColor: Colors.greenAccent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // --- QR CODE PREVIEW ---
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: upiIdController,
              builder: (context, value, _) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return Center(
                  child: Column(
                    children: [
                      const Text(
                        'Live Payment QR',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                              blurRadius: 25,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: "upi://pay?pa=${value.text.trim()}&pn=${shopNameController.text.trim()}&cu=INR",
                          version: QrVersions.auto,
                          size: 180.0,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF1E293B),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        value.text,
                        style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              }
            ),

            const SizedBox(height: 24),
            _buildBiometricSection(),
            const SizedBox(height: 24),
            _buildBackupSection(),
            const SizedBox(height: 24),
            _buildSecuritySection(),
            const SizedBox(height: 24),
            _buildDeleteAccountSection(),
            const SizedBox(height: 24),
            if (errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(errorMessage!, style: const TextStyle(color: Colors.redAccent)),
            ],
            if (successMessage != null) ...[
                const SizedBox(height: 16),
                Text(successMessage!, style: const TextStyle(color: AppColors.secondary)),
            ],
            const SizedBox(height: 16),
            _buildSyncStatusIndicator(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : saveShopProfile,
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Profile'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 55,
                  width: 55,
                  child: IconButton(
                    icon: const Icon(Icons.sync),
                    onPressed: isLoading ? null : _forceRetrySync,
                    tooltip: 'Retry Sync',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
  );
}

  Widget _buildBackupSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.cloud_upload_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Text(
                AppLocalizations.of(context).translate('backup') ?? 'Backup & Restore',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Keep your shop data safe by creating periodic backups. You can restore your data if you switch devices.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleCreateBackup(),
                  icon: const Icon(Icons.backup_rounded, size: 18),
                  label: const Text('Backup Now'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: const BorderSide(color: AppColors.secondary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleRestoreBackup(),
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: const Text('Restore'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white10,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleCreateBackup() async {
    setState(() => isLoading = true);
    try {
      final result = await BackupService.createBackup();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_backup_time', DateTime.now().toIso8601String());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Backup created: ${result['size']} KB'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Backup failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
    setState(() => isLoading = false);
  }

  Future<void> _handleRestoreBackup() async {
    try {
      final backups = await BackupService.listBackups();
      if (backups.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No backups found to restore')),
          );
        }
        return;
      }

      if (!mounted) return;
      final selectedBackup = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: AppColors.surfaceDark,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select Backup to Restore', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              ...backups.map((b) => ListTile(
                leading: const Icon(Icons.insert_drive_file, color: AppColors.primary),
                title: Text(b['date'], style: const TextStyle(color: Colors.white)),
                subtitle: Text('${b['fileSize']} KB', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                onTap: () => Navigator.pop(ctx, b['path']),
              )).toList(),
            ],
          ),
        ),
      );

      if (selectedBackup != null) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            title: const Text('Confirm Restore?', style: TextStyle(color: Colors.white)),
            content: const Text('This will overwrite current data with backup data. Continue?', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
            ],
          ),
        );

        if (confirm == true) {
          setState(() => isLoading = true);
          await BackupService.restoreBackup(selectedBackup);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Restore complete! Please restart the app.'), backgroundColor: AppColors.secondary),
            );
          }
          setState(() => isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Restore failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildBiometricSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fingerprint_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Text(
                'Biometric Login',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Keep biometric access private on this device only. Use this setting to enable or disable fingerprint or face unlock for owner verification and protected sections.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _biometricAvailable ? 'Device biometrics ready' : 'Biometric unavailable',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _biometricAvailable
                          ? 'Fingerprint or face unlock can be managed here.'
                          : 'This device does not support biometric enrollment.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _biometricEnabled,
                onChanged: _biometricAvailable ? _toggleBiometric : null,
                activeColor: AppColors.primary,
              ),
            ],
          ),
          if (!_biometricAvailable)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Biometric login requires device support and must be activated after registration.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleBiometric(bool enabled) async {
    if (!await SecurityService.isBiometricHardwareAvailable()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric hardware unavailable on this device.'), backgroundColor: Colors.redAccent),
        );
      }
      return;
    }

    if (enabled) {
      final authenticated = await SecurityService.authenticateBiometrically(
        reason: 'Confirm to enable biometric login for Owner access',
      );
      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric verification failed. Login not enabled.'), backgroundColor: Colors.redAccent),
          );
        }
        return;
      }
      await SecurityService.setOwnerBiometricStatusVerified();
      await SecurityService.setBiometricEnabled(true);
      if (mounted) {
        setState(() => _biometricEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Biometric login enabled on this device.'), backgroundColor: AppColors.secondary),
        );
      }
    } else {
      await SecurityService.setBiometricEnabled(false);
      if (mounted) {
        setState(() => _biometricEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric login disabled.'), backgroundColor: AppColors.secondary),
        );
      }
    }
  }

  Widget _buildSecuritySection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.electric.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.security_rounded, color: AppColors.electric),
              ),
              const SizedBox(width: 16),
              Text(
                'Access Control',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'The Master PIN protects sensitive sections like Inventory, Shop Details, and Analytics from unauthorized employee access.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Master App PIN',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Default is 0000',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _showChangePinDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.electric.withValues(alpha: 0.2),
                  foregroundColor: AppColors.electric,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: AppColors.electric.withValues(alpha: 0.3)),
                ),
                child: const Text('Change PIN'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showChangePinDialog() {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Change Master PIN', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Current PIN',
                labelStyle: const TextStyle(color: Colors.white60),
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'New 4-Digit PIN',
                labelStyle: const TextStyle(color: Colors.white60),
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              final current = await SecurityService.getMasterPin();
              final h = sha256.convert(utf8.encode(oldController.text)).toString();
              if (h == current) {
                if (newController.text.length == 4) {
                  await SecurityService.setMasterPin(newController.text);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Master PIN updated!'), backgroundColor: AppColors.secondary)
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ New PIN must be 4 digits'), backgroundColor: Colors.red)
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('❌ Current PIN is incorrect'), backgroundColor: Colors.red)
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.electric),
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteAccountSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.warning_rounded, color: Colors.redAccent),
              ),
              const SizedBox(width: 16),
              Text(
                'Danger Zone',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Permanently delete your account and all associated data. This action cannot be undone.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/delete-account'),
              icon: const Icon(Icons.delete_forever_rounded, size: 20),
              label: const Text('Delete Account Permanently'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  const _StyledField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.validator,
    this.suffixIcon,
    this.keyboardType,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.9), fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 24),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }
}
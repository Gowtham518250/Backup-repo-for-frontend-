import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'secure_token_storage.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'api_client.dart';
import 'shop_profile_persistence_service.dart';
import 'role_selection_page.dart';

class ShopDetailsPage extends StatefulWidget {
  const ShopDetailsPage({super.key});

  @override
  State<ShopDetailsPage> createState() => _ShopDetailsPageState();
}

class _ShopDetailsPageState extends State<ShopDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController shopNameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController contactPersonController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController gstController = TextEditingController();
  final TextEditingController openingHourController = TextEditingController();
  final TextEditingController closingHourController = TextEditingController();
  
  String? selectedShopType;
  List<String> selectedCategories = [];
  
  // Shop type options
  final List<String> shopTypeOptions = [
    'General',
    'Grocery',
    'Electronics',
    'Fashion',
    'Clothing',
    'Pharmacy',
    'Beauty & Cosmetics',
    'Footwear',
    'Jewelry',
    'Home & Kitchen',
    'Books & Stationery',
    'Sports & Fitness',
    'Automotive',
    'Furniture',
    'Garden & Outdoor',
    'Toys & Games',
    'Other',
  ];

  // Category options
  final List<String> categoryOptions = [
    'Apparel',
    'Accessories',
    'Footwear',
    'Bags',
    'Electronics',
    'Mobile Phones',
    'Laptops',
    'Beauty',
    'Skincare',
    'Haircare',
    'Fragrances',
    'Home Appliances',
    'Kitchen',
    'Bedding',
    'Furniture',
    'Books',
    'Stationery',
    'Sports Equipment',
    'Fitness',
    'Outdoor Gear',
    'Jewelry',
    'Watches',
    'Toys',
    'Games',
    'Food & Beverages',
    'Groceries',
    'Snacks',
    'Beverages',
    'Fresh Produce',
  ];

  Uint8List? logoBytes;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  bool isLoading = false;
  String? successMessage;
  String? errorMessage;

  Future<void> _loadExistingData() async {
    try {
      final profile = await ShopProfilePersistenceService.getProfile();
      if (profile != null) {
        await ShopProfilePersistenceService.applyProfileToPrefs(profile);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error loading profile via persistence service: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      shopNameController.text = prefs.getString('shop_name') ?? '';
      locationController.text = prefs.getString('location') ?? '';
      selectedShopType = prefs.getString('shop_type');
      contactPersonController.text = prefs.getString('contact_person') ?? '';
      phoneController.text = prefs.getString('shop_phone') ?? '';
      emailController.text = prefs.getString('shop_email') ?? '';
      gstController.text = prefs.getString('gst_number') ?? '';

      final categoriesStr = prefs.getString('shop_categories');
      if (categoriesStr != null && categoriesStr.isNotEmpty) {
        selectedCategories = categoriesStr.split(',');
      }

      openingHourController.text = prefs.getString('opening_hour') ?? '09:00 AM';
      closingHourController.text = prefs.getString('closing_hour') ?? '09:00 PM';

      final logoBase64 = prefs.getString('logo_base64');
      if (logoBase64 != null && logoBase64.isNotEmpty) {
        try {
          logoBytes = base64Decode(logoBase64);
        } catch (e) {
          if (kDebugMode) debugPrint('Error decoding logo: $e');
        }
      }
    });

    try {
      await ShopProfilePersistenceService.fetchProfileFromBackend();
    } catch (_) {
      // Ignore backend refresh failures.
    }
  }

  Future<void> pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // Crucial for mobile to get bytes
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? pickedBytes;
        
        if (file.bytes != null) {
          pickedBytes = file.bytes;
        } else if (file.path != null) {
          final f = File(file.path!);
          pickedBytes = await f.readAsBytes();
        }

        if (pickedBytes != null) {
          setState(() {
            logoBytes = pickedBytes;
          });
          if (kDebugMode) debugPrint('Image picked: ${file.name}, Size: ${pickedBytes.length} bytes');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e'), backgroundColor: Colors.red),
      );
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
          const SnackBar(content: Text('Location permission denied. Please enable in settings.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fetching location...')),
      );

      final position = await Geolocator.getCurrentPosition();
      
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

          final parts = <String>[
            if ((addr['road'] ?? addr['street'] ?? '').toString().trim().isNotEmpty)
              (addr['road'] ?? addr['street']).toString().trim(),
            if ((addr['city'] ?? addr['town'] ?? '').toString().trim().isNotEmpty)
              (addr['city'] ?? addr['town']).toString().trim(),
            if ((addr['state'] ?? '').toString().trim().isNotEmpty)
              addr['state'].toString().trim(),
          ];

          String readableAddress = parts.isNotEmpty 
              ? parts.join(', ')
              : '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';

          setState(() {
            locationController.text = readableAddress;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location fetched successfully!')),
          );
        }
      } catch (e) {
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

  Future<void> _pickTime(TextEditingController controller) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    
    if (pickedTime != null) {
      final hours = pickedTime.hour.toString().padLeft(2, '0');
      final minutes = pickedTime.minute.toString().padLeft(2, '0');
      final period = pickedTime.period == DayPeriod.am ? 'AM' : 'PM';
      setState(() {
        controller.text = '$hours:$minutes $period';
      });
    }
  }

  Future<bool> _saveShopProfileToBackend(SharedPreferences prefs) async {
    final userId = prefs.getInt('user_id') ?? prefs.getInt('userId');
    if (userId == null || userId <= 0) {
      debugPrint('❌ SHOP SAVE: userId is 0 or null — not logged in properly');
      return false;
    }

    final token = await SecureTokenStorage.getToken() ?? '';
    if (token.isEmpty) {
      debugPrint('❌ SHOP SAVE: token is empty — authentication failed');
      return false;
    }

    final shopData = {
      "shop_name": shopNameController.text.trim(),
      "location": locationController.text.trim(),
      "shop_type": selectedShopType,
      "phone_number": phoneController.text.trim(),
      "email": emailController.text.trim(),
      "gst_number": gstController.text.trim(),
      "shop_categories": selectedCategories,
      "opening_hour": openingHourController.text.trim(),
      "closing_hour": closingHourController.text.trim(),
      "contact_person_name": contactPersonController.text.trim(),
    };
    final headers = {'Authorization': 'Bearer $token'};

    try {
      // Try PUT first (update existing profile)
      final putResp = await ApiClient.putJson(
        '${ApiClient.shopProfile}?user_id=$userId',
        shopData,
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      debugPrint('PUT ${ApiClient.shopProfile} → ${putResp.statusCode}: ${putResp.body}');
      if (putResp.statusCode == 200 || putResp.statusCode == 201) {
        if (mounted) {
          setState(() => successMessage = 'Shop profile synchronized with cloud! ✅');
        }
        return true;
      }

      // If PUT fails, try POST (create new profile)
      final postResp = await ApiClient.postJson(
        '${ApiClient.shopCreate}?user_id=$userId',
        shopData,
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      debugPrint('POST ${ApiClient.shopCreate} → ${postResp.statusCode}: ${postResp.body}');
      if (postResp.statusCode == 200 || postResp.statusCode == 201) {
        if (mounted) {
          setState(() => successMessage = 'Shop profile created in cloud! ✅');
        }
        return true;
      }

      debugPrint('❌ SHOP SAVE: Both PUT and POST failed. PUT: ${putResp.statusCode}, POST: ${postResp.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ SHOP SAVE EXCEPTION: $e'); // Now you'll see the real error
      return false;
    }
  }

  Future<void> saveShopDetails() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (selectedShopType == null || selectedShopType!.isEmpty) {
      setState(() => errorMessage = 'Please select a shop type');
      return;
    }
    
    if (selectedCategories.isEmpty) {
      setState(() => errorMessage = 'Please select at least one product category');
      return;
    }
    
    setState(() {
      isLoading = true;
      successMessage = null;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save basic details
      await prefs.setString('shop_name', shopNameController.text.trim());
      await prefs.setString('location', locationController.text.trim());
      await prefs.setString('shop_type', selectedShopType!);
      await prefs.setString('contact_person', contactPersonController.text.trim());
      await prefs.setString('shop_phone', phoneController.text.trim());
      await prefs.setString('shop_email', emailController.text.trim());
      await prefs.setString('gst_number', gstController.text.trim());
      await prefs.setString('shop_categories', selectedCategories.join(','));
      await prefs.setString('opening_hour', openingHourController.text.trim());
      await prefs.setString('closing_hour', closingHourController.text.trim());
      await prefs.setBool('shop_details_completed', true);
      final shopUserId = prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0;
      if (shopUserId > 0) {
        await prefs.setBool('shop_details_completed_$shopUserId', true);
        await prefs.setBool('shop_details_required_$shopUserId', false);
      }
      
      // Save logo image as base64
      if (logoBytes != null && logoBytes!.isNotEmpty) {
        final base64String = base64Encode(logoBytes!);
        await prefs.setString('logo_base64', base64String);
        if (kDebugMode) debugPrint('Logo saved successfully: ${base64String.length} characters');
      } else {
        // Clear logo if no image selected
        await prefs.remove('logo_base64');
      }

      setState(() {
        successMessage = 'Shop details saved successfully locally! 🎉';
      });

      // SYNC TO BACKEND via centralized persistence service
      final profile = {
        'profile': {
          'shop_name': shopNameController.text.trim(),
          'location': locationController.text.trim(),
          'shop_type': selectedShopType,
          'shop_phone': phoneController.text.trim(),
          'email': emailController.text.trim(),
          'shop_gst': gstController.text.trim(),
          'shop_categories': selectedCategories,
          'opening_hour': openingHourController.text.trim(),
          'closing_hour': closingHourController.text.trim(),
          'contact_person': contactPersonController.text.trim(),
          'logo_base64': logoBytes != null ? base64Encode(logoBytes!) : null,
        },
        'version': DateTime.now().millisecondsSinceEpoch,
      };

      await ShopProfilePersistenceService.saveProfileLocally(profile);
      final syncResult = await ShopProfilePersistenceService.syncProfileToBackend(profile);
      if (syncResult['success'] == true) {
        setState(() => successMessage = 'Shop profile synchronized with cloud! ✅');
      } else {
        setState(() => successMessage = 'Saved locally — will sync when online');
      }
      
      // Delay before navigation to show success message
      await Future.delayed(const Duration(milliseconds: 1200));

      if (mounted) {
        // Navigate to role verification instead of directly to dashboard
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString('email') ?? '';
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (ctx) => RoleSelectionPage(email: email),
          ),
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to save: $e';
      });
      print('Error saving shop details: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF020617),
              Color(0xFF020617),
              Color(0xFF0B1120),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App header
                    ClipOval(
                      child: Image.asset(
                        'assets/shop_logo.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF111827),
                          ),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Complete Your Shop Details',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Form section
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Color(0xFF111827).withValues(alpha: 0.96),
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
                      child: _buildFormSection(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo Upload
            Center(
              child: GestureDetector(
                onTap: pickLogo,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF6366F1),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF6366F1).withValues(alpha: 0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                    image: logoBytes != null
                        ? DecorationImage(image: MemoryImage(logoBytes!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: logoBytes == null
                      ? Icon(
                          Icons.add_a_photo_rounded,
                          size: 40,
                          color: const Color(0xFF6366F1),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Tap to upload shop logo',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Basic Information
            _buildSectionHeader('Basic Information'),
            const SizedBox(height: 16),
            
            // Shop Name
            _StyledFormField(
              controller: shopNameController,
              label: 'Shop Name',
              icon: Icons.storefront_rounded,
              hint: 'e.g. My Retail Store',
              validator: (v) => v!.isEmpty ? 'Please enter shop name' : null,
            ),
            const SizedBox(height: 16),

            // Shop Type Dropdown
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shop Type / Category',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 1),
                    color: const Color(0xFF020617),
                  ),
                  child: DropdownButton<String>(
                    value: selectedShopType,
                    underline: const SizedBox(),
                    isExpanded: true,
                    dropdownColor: const Color(0xFF111827), // Fix: explicitly set dark dropdown background
                    hint: Text(
                      'Select shop type',
                      style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    onChanged: (value) => setState(() => selectedShopType = value),
                    items: shopTypeOptions
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(
                                type,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Product Categories Multi-Select
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Product Categories',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 1),
                    color: const Color(0xFF020617),
                  ),
                  child: selectedCategories.isEmpty
                      ? Text(
                          'Select categories (tap to add)',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: selectedCategories
                              .map(
                                (cat) => Chip(
                                  label: Text(
                                    cat,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  onDeleted: () => setState(
                                      () => selectedCategories.remove(cat)),
                                  backgroundColor: const Color(0xFF6366F1)
                                      .withValues(alpha: 0.1),
                                  deleteIconColor: const Color(0xFF6366F1),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView(
                    children: categoryOptions
                        .map(
                          (cat) => CheckboxListTile(
                            value: selectedCategories.contains(cat),
                            onChanged: (bool? checked) {
                              setState(() {
                                if (checked == true) {
                                  selectedCategories.add(cat);
                                } else {
                                  selectedCategories.remove(cat);
                                }
                              });
                            },
                            title: Text(
                              cat,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.white, // Fix: ensure text is visible on dark background
                              ),
                            ),
                            checkColor: Colors.white,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // â”€ Contact Information â”€
            _buildSectionHeader('Contact Information'),
            const SizedBox(height: 16),
            
            // Contact Person Name
            _StyledFormField(
              controller: contactPersonController,
              label: 'Contact Person Name',
              icon: Icons.person_rounded,
              hint: 'Owner or manager name',
              validator: (v) => v!.isEmpty ? 'Please enter contact person name' : null,
            ),
            const SizedBox(height: 16),

            // Phone Number
            _StyledFormField(
              controller: phoneController,
              label: 'Shop Phone Number',
              icon: Icons.phone_rounded,
              hint: '+91 (10-digit mobile)',
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v!.isEmpty) return 'Please enter phone number';
                if (!RegExp(r'^\d{10,}$').hasMatch(v.replaceAll(RegExp(r'[^0-9]'), ''))) {
                  return 'Please enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email
            _StyledFormField(
              controller: emailController,
              label: 'Shop Email',
              icon: Icons.email_rounded,
              hint: 'shop@example.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v!.isEmpty) return 'Please enter email';
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // â”€ Business Details â”€
            _buildSectionHeader('Business Details'),
            const SizedBox(height: 16),
            
            // GST Number
            _StyledFormField(
              controller: gstController,
              label: 'GST Number (Optional)',
              icon: Icons.receipt_long_rounded,
              hint: '15-digit GST ID',
              validator: (v) {
                if (v != null && v.isNotEmpty && !RegExp(r'^\d{15}$').hasMatch(v.replaceAll(RegExp(r'[^0-9]'), ''))) {
                  return 'Please enter a valid 15-digit GST number';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // â”€ Working Hours â”€
            _buildSectionHeader('Working Hours'),
            const SizedBox(height: 16),
            
            // Opening Hour
            _StyledTimeField(
              controller: openingHourController,
              label: 'Opening Time',
              icon: Icons.schedule_rounded,
              onTap: () => _pickTime(openingHourController),
              validator: (v) => v!.isEmpty ? 'Please set opening time' : null,
            ),
            const SizedBox(height: 16),

            // Closing Hour
            _StyledTimeField(
              controller: closingHourController,
              label: 'Closing Time',
              icon: Icons.schedule_rounded,
              onTap: () => _pickTime(closingHourController),
              validator: (v) => v!.isEmpty ? 'Please set closing time' : null,
            ),
            const SizedBox(height: 20),

            // â”€ Location â”€
            _buildSectionHeader('Location'),
            const SizedBox(height: 16),

            // Location
            _StyledFormField(
              controller: locationController,
              label: 'Shop Address',
              icon: Icons.location_on_rounded,
              hint: 'Your shop address',
              suffixIcon: IconButton(
                icon: const Icon(Icons.my_location_rounded, color: Color(0xFF4F46E5)),
                onPressed: _fetchLocation,
              ),
              validator: (v) => v!.isEmpty ? 'Please enter location' : null,
            ),

            // Messages
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFDC2626),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (successMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        successMessage!,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF059669),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : saveShopDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: const Color(0xFF020617),
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Continue to Dashboard',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
  }

  @override
  void dispose() {
    shopNameController.dispose();
    locationController.dispose();
    contactPersonController.dispose();
    phoneController.dispose();
    emailController.dispose();
    gstController.dispose();
    openingHourController.dispose();
    closingHourController.dispose();
    super.dispose();
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF6366F1),
        letterSpacing: 0.5,
      ),
    );
  }
}

class _StyledFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  const _StyledFormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.validator,
    this.suffixIcon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFF020617),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _StyledTimeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? Function(String?)? validator;

  const _StyledTimeField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.onTap,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          validator: validator,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
            suffixIcon: const Icon(Icons.access_time_rounded, color: Color(0xFF4F46E5), size: 20),
            filled: true,
            fillColor: const Color(0xFF020617),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

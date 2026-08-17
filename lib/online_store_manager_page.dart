import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'online_store_service.dart';
import 'secure_token_storage.dart';

class OnlineStoreManagerPage extends StatefulWidget {
  const OnlineStoreManagerPage({super.key});

  @override
  State<OnlineStoreManagerPage> createState() => _OnlineStoreManagerPageState();
}

class _OnlineStoreManagerPageState extends State<OnlineStoreManagerPage> {
  bool _isStoreActive = false;
  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _minOrderController = TextEditingController();
  final TextEditingController _deliveryFeeController = TextEditingController();
  
  bool _offerDelivery = true;
  bool _offerPickup = true;
  bool _acceptCOD = true;
  bool _acceptOnline = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isStoreActive = prefs.getBool('online_store_active') ?? false;
      _storeNameController.text = prefs.getString('shop_name') ?? 'My Kirana Store';
      _minOrderController.text = (prefs.getInt('online_min_order') ?? 100).toString();
      _deliveryFeeController.text = (prefs.getInt('online_delivery_fee') ?? 20).toString();
      _offerDelivery = prefs.getBool('online_offer_delivery') ?? true;
      _offerPickup = prefs.getBool('online_offer_pickup') ?? true;
      _acceptCOD = prefs.getBool('online_accept_cod') ?? true;
      _acceptOnline = prefs.getBool('online_accept_online') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 🔧 PHASE 6 FIX: Sync online store status with backend
      if (_isStoreActive) {
        // Publish shop to marketplace
        final publishResult = await OnlineStoreService.setShopOnlineStatus(true);
        
        if (publishResult['success'] != true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to enable: ${publishResult['error'] ?? "Unknown error"}'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isSaving = false);
          return;
        }
        
        if (kDebugMode) debugPrint('✅ Online store enabled via backend');
      } else {
        // Unpublish from marketplace
        final unpublishResult = await OnlineStoreService.setShopOnlineStatus(false);
        
        if (unpublishResult['success'] != true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to disable: ${unpublishResult['error'] ?? "Unknown error"}'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isSaving = false);
          return;
        }
        
        if (kDebugMode) debugPrint('✅ Online store disabled via backend');
      }
      
      // Save local settings
      await prefs.setBool('online_store_active', _isStoreActive);
      await prefs.setInt('online_min_order', int.tryParse(_minOrderController.text) ?? 100);
      await prefs.setInt('online_delivery_fee', int.tryParse(_deliveryFeeController.text) ?? 20);
      await prefs.setBool('online_offer_delivery', _offerDelivery);
      await prefs.setBool('online_offer_pickup', _offerPickup);
      await prefs.setBool('online_accept_cod', _acceptCOD);
      await prefs.setBool('online_accept_online', _acceptOnline);

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isStoreActive 
                ? '✅ Online Store enabled! Customers can find you nearby.'
                : '✅ Online Store disabled.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error saving settings: $e');
      
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String get _storeLink {
    final slug = _storeNameController.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
    return 'https://shop.retailmind.com/$slug';
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _storeLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Store link copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Online Store Manager', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: Text('Save', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Master Switch
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: _isStoreActive ? Colors.green[50] : Colors.white,
              child: SwitchListTile(
                title: Text('Enable Online Store', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                subtitle: Text('Allow customers to order directly from you via WhatsApp or Web.'),
                value: _isStoreActive,
                activeColor: Colors.green,
                onChanged: (val) {
                  setState(() => _isStoreActive = val);
                  HapticFeedback.lightImpact();
                },
              ),
            ),
            const SizedBox(height: 24),
            
            if (_isStoreActive) ...[
              // Store Link Share
              Text('Your Store Link', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(_storeLink, style: GoogleFonts.poppins(color: Colors.blue[900], fontWeight: FontWeight.w500))),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.blue),
                      onPressed: _copyLink,
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.blue),
                      onPressed: () {
                        // TODO: Implement actual share
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Settings
              Text('Delivery & Pickup', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text('Offer Delivery', style: GoogleFonts.poppins()),
                      value: _offerDelivery,
                      onChanged: (v) => setState(() => _offerDelivery = v),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text('Offer Store Pickup', style: GoogleFonts.poppins()),
                      value: _offerPickup,
                      onChanged: (v) => setState(() => _offerPickup = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Fees & Limits
              Text('Order Constraints', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minOrderController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Min Order (₹)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _deliveryFeeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Delivery Fee (₹)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Payment Methods
              Text('Accepted Payments', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text('Cash on Delivery (COD)', style: GoogleFonts.poppins()),
                      value: _acceptCOD,
                      onChanged: (v) => setState(() => _acceptCOD = v),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text('Online Payments (UPI/Cards)', style: GoogleFonts.poppins()),
                      value: _acceptOnline,
                      onChanged: (v) => setState(() => _acceptOnline = v),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

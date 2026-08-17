import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'api_client.dart';
import 'smart_reorder_ai.dart';
import 'local_storage_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// RETAIL INTELLIGENCE PAGE — 100 CRORE STARTUP EDITION
// ═══════════════════════════════════════════════════════════════════════════

class RetailIntelligencePage extends StatefulWidget {
  const RetailIntelligencePage({super.key});

  @override
  State<RetailIntelligencePage> createState() => _RetailIntelligencePageState();
}

class _RetailIntelligencePageState extends State<RetailIntelligencePage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _FlashSaleTab(),
          _ChurnRiskTab(),
          _AutoPOTab(),
          _SmartReorderTab(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (_, __) => ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  Color.lerp(const Color(0xFF6366F1), const Color(0xFF8B5CF6), _glowAnimation.value)!,
                  Color.lerp(const Color(0xFF06B6D4), const Color(0xFF3B82F6), _glowAnimation.value)!,
                ],
              ).createShader(bounds),
              child: Text(
                'Retail Intelligence',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w900, // Black bold text as requested
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Text(
            'AI-Powered Business Operations',
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: const Color(0xFF6366F1),
        indicatorWeight: 3,
        labelColor: Colors.black, // Changed to black
        unselectedLabelColor: Colors.black38, // Changed to black
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
        tabs: const [
          Tab(icon: Icon(Icons.flash_on_rounded, size: 18, color: Colors.orange), text: 'Flash Sale'),
          Tab(icon: Icon(Icons.person_off_rounded, size: 18, color: Colors.red), text: 'Churn Risk'),
          Tab(icon: Icon(Icons.inventory_2_rounded, size: 18, color: Colors.indigo), text: 'Auto-PO'),
          Tab(icon: Icon(Icons.trending_up_rounded, size: 18, color: Colors.green), text: 'Smart Reorder'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  const _GlassCard({required this.child, this.padding, this.borderColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.withValues(alpha: 0.08),
              Colors.grey.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor ?? Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

Widget _buildStatPill(String label, String value, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Column(
      children: [
        Text(value, style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w700, fontSize: 16)),
        Text(label, style: GoogleFonts.poppins(color: color.withValues(alpha: 0.8), fontSize: 10)),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1: FLASH SALE ENGINE
// ═══════════════════════════════════════════════════════════════════════════

class _FlashSaleTab extends StatefulWidget {
  const _FlashSaleTab();

  @override
  State<_FlashSaleTab> createState() => _FlashSaleTabState();
}

class _FlashSaleTabState extends State<_FlashSaleTab> with SingleTickerProviderStateMixin {
  final _categoryController = TextEditingController();
  final _discountController = TextEditingController(text: '20');
  final _hoursController = TextEditingController(text: '2');
  bool _isLoading = false;
  Map<String, dynamic>? _activeFlashSale;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final _presetCategories = [
    'All',
    'Beverages',
    'Snacks',
    'Dairy',
    'Grains',
    'FMCG',
    'Electronics',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadActiveFlashSale();
  }

  void _loadActiveFlashSale() async {
    try {
      // Load from local storage first for immediate response (offline-first)
      final prefs = await SharedPreferences.getInstance();
      final localFlashSaleData = prefs.getString('active_flash_sale');
      
      if (localFlashSaleData != null && localFlashSaleData.isNotEmpty) {
        try {
          final data = jsonDecode(localFlashSaleData);
          final expiry = DateTime.parse(data['expiry']);
          
          // Check if flash sale is still valid
          if (DateTime.now().isBefore(expiry) && mounted) {
            setState(() {
              _activeFlashSale = data;
            });
            if (kDebugMode) debugPrint('✅ Active flash sale loaded from local storage');
          } else {
            // Expired, clear local data
            await prefs.remove('active_flash_sale');
            if (kDebugMode) debugPrint('⏰ Flash sale expired, cleared local data');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Error parsing local flash sale data: $e');
        }
      }
      
      // Then sync with backend for latest data
      try {
        final res = await ApiClient.getJson('/api/flash-sale/active');
        if (res.statusCode == 200 && mounted) {
          final data = jsonDecode(res.body);
          final flashSaleData = {
            'category': data['category'],
            'discount': data['discount_pct']?.toString(),
            'hours': data['hours_duration']?.toString(),
            'expiry': data['end_time'],
          };
          
          // Check if backend flash sale is still valid
          final expiry = DateTime.parse(data['end_time']);
          if (DateTime.now().isBefore(expiry)) {
            setState(() {
              _activeFlashSale = flashSaleData;
            });
            // Save to local storage for offline use
            await prefs.setString('active_flash_sale', json.encode(flashSaleData));
            if (kDebugMode) debugPrint('✅ Active flash sale synced from backend');
          } else {
            // Backend flash sale expired, clear local data
            await prefs.remove('active_flash_sale');
            setState(() => _activeFlashSale = null);
            if (kDebugMode) debugPrint('⏰ Backend flash sale expired');
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Backend flash sale sync failed, using local data: $e');
        // Keep using local data if backend sync fails
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Flash sale load failed: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _activateFlashSale() async {
    final selectedCategory = _categoryController.text.trim();

    if (selectedCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ Select a category first',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final normalizedCategory =
        selectedCategory.toLowerCase() == 'all' ? 'ALL' : selectedCategory;

    final discount =
        double.tryParse(_discountController.text.trim()) ?? 20.0;
    final hours = int.tryParse(_hoursController.text.trim()) ?? 2;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final res = await ApiClient.postJson(
        '/api/flash-sale/setup',
        {
          'category': normalizedCategory,
          'discount_pct': discount,
          'hours': hours,
        },
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(
          'Flash sale setup failed (${res.statusCode})',
        );
      }

      Map<String, dynamic> serverData = {};
      if (res.body.isNotEmpty) {
        try {
          final decoded = jsonDecode(res.body);
          if (decoded is Map) {
            serverData = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {
          // Some successful endpoints may return an empty/non-JSON body.
        }
      }

      final serverExpiry =
          serverData['end_time']?.toString().trim() ?? '';
      final expiry = serverExpiry.isNotEmpty
          ? serverExpiry
          : DateTime.now()
              .add(Duration(hours: hours))
              .toIso8601String();

      final flashSaleData = <String, dynamic>{
        'category': normalizedCategory,
        'discount': discount.toString(),
        'hours': hours.toString(),
        'expiry': expiry,
      };

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'active_flash_sale',
        jsonEncode(flashSaleData),
      );

      if (!mounted) return;

      setState(() {
        _activeFlashSale = flashSaleData;
        _categoryController.text =
            normalizedCategory == 'ALL' ? 'All' : normalizedCategory;
      });

      HapticFeedback.heavyImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            normalizedCategory == 'ALL'
                ? '⚡ Flash Sale launched for all products'
                : '⚡ Flash Sale launched for $normalizedCategory',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Flash sale setup failed: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Flash Sale could not be launched. Please check your connection and try again.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_activeFlashSale != null) _buildActiveFlashSaleCard(),
          _GlassCard(
            borderColor: Colors.orangeAccent.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.flash_on_rounded, color: Colors.orangeAccent),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Flash Sale Engine', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
                        Text('Timed discount across a category or all products', style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Category presets
                Text('Quick Presets:', style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presetCategories.map((cat) => GestureDetector(
                    onTap: () => setState(() => _categoryController.text = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _categoryController.text == cat
                            ? Colors.orangeAccent.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _categoryController.text == cat
                              ? Colors.orangeAccent
                              : Colors.white12,
                        ),
                      ),
                      child: Text(cat, style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      )),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                _buildDarkField(_categoryController, 'Category', Icons.category_rounded, hint: 'Choose All or a category'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildDarkField(_discountController, 'Discount %', Icons.percent_rounded, keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDarkField(_hoursController, 'Duration (hrs)', Icons.timer_rounded, keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _activateFlashSale,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: Colors.orangeAccent.withValues(alpha: 0.5),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.campaign_rounded, size: 22),
                              const SizedBox(width: 8),
                              Text('LAUNCH FLASH SALE ⚡', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 15)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFlashSaleCard() {
    return _GlassCard(
      borderColor: Colors.greenAccent.withValues(alpha: 0.5),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, child) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('ACTIVE FLASH SALE', style: GoogleFonts.poppins(color: Colors.greenAccent, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatPill(
                'Category',
                (_activeFlashSale!['category']?.toString().toUpperCase() == 'ALL')
                    ? 'All Products'
                    : (_activeFlashSale!['category']?.toString() ?? 'Unknown'),
                Colors.orangeAccent,
              ),
              _buildStatPill('Discount', '${_activeFlashSale!['discount']}%', Colors.greenAccent),
              _buildStatPill('Duration', '${_activeFlashSale!['hours']}h', Colors.cyanAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDarkField(TextEditingController c, String label, IconData icon,
      {String? hint, TextInputType? keyboardType}) {
    return TextField(
      controller: c,
      style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w600),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500),
        labelStyle: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, color: Colors.grey.shade700, size: 20),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.orangeAccent, width: 1.5),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2: CHURN RISK PREDICTOR
// ═══════════════════════════════════════════════════════════════════════════

class _ChurnRiskTab extends StatefulWidget {
  const _ChurnRiskTab();

  @override
  State<_ChurnRiskTab> createState() => _ChurnRiskTabState();
}

class _ChurnRiskTabState extends State<_ChurnRiskTab> {
  List<dynamic> _customers = [];
  bool _isLoading = true;
  bool _hasFailed = false;
  int _selectedDays = 30;

  @override
  void initState() {
    super.initState();
    _loadChurn();
  }

  void _loadChurn() async {
    setState(() { _isLoading = true; _hasFailed = false; });
    try {
      // Load from local storage first for immediate response (offline-first)
      final prefs = await SharedPreferences.getInstance();
      final localChurnData = prefs.getString('churn_risk_data');
      
      if (localChurnData != null && localChurnData.isNotEmpty) {
        try {
          final data = jsonDecode(localChurnData);
          if (mounted) {
            setState(() {
              _customers = data['customers'] ?? [];
              _isLoading = false;
            });
          }
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Error parsing local churn data: $e');
        }
      }
      
      // Then sync with backend for latest data
      try {
        final res = await ApiClient.getJson('/api/analytics/churn-risk?days=$_selectedDays');
        if (mounted && res.statusCode == 200) {
          final data = jsonDecode(res.body);
          setState(() {
            _customers = data['customers'] ?? [];
            _isLoading = false;
          });
          // Save to local storage for offline use
          await prefs.setString('churn_risk_data', json.encode(data));
          if (kDebugMode) debugPrint('✅ Churn risk data synced from backend');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Backend churn sync failed, using local data: $e');
        // Keep using local data if backend sync fails
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _hasFailed = true; });
      if (kDebugMode) debugPrint('❌ Churn data load failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header stats
        _GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.person_off_rounded, color: Colors.redAccent, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Churn Risk Predictor', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('Customers inactive for ${_selectedDays}+ days', style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ),
              // Days selector
              PopupMenuButton<int>(
                color: const Color(0xFF1E293B),
                initialValue: _selectedDays,
                onSelected: (v) { setState(() => _selectedDays = v); _loadChurn(); },
                itemBuilder: (_) => [15, 30, 45, 60].map((d) =>
                  PopupMenuItem(value: d, child: Text('$d days', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w600)))
                ).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Text('${_selectedDays}d', style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 12)),
                      const Icon(Icons.arrow_drop_down, color: Colors.black54, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!_customers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildStatPill('At Risk', '${_customers.length}', Colors.redAccent),
                const SizedBox(width: 10),
                _buildStatPill('Est. Revenue Loss', '₹${(_customers.length * 850).toStringAsFixed(0)}', Colors.orangeAccent),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : _hasFailed || _customers.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _customers.length,
                      itemBuilder: (ctx, i) => _buildChurnCard(_customers[i], i),
                    ),
        ),
      ],
    );
  }

  Widget _buildChurnCard(dynamic c, int index) {
    final riskLevel = index < 3 ? 'HIGH' : index < 7 ? 'MEDIUM' : 'LOW';
    final riskColor = index < 3 ? Colors.redAccent : index < 7 ? Colors.orangeAccent : Colors.yellowAccent;

    return _GlassCard(
      borderColor: riskColor.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [riskColor.withValues(alpha: 0.4), riskColor.withValues(alpha: 0.1)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                (c['name'] ?? 'U').substring(0, 1).toUpperCase(),
                style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(c['name'] ?? 'Unknown', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(riskLevel, style: GoogleFonts.poppins(color: riskColor, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                Text('Last visit: ${(c['last_visit'] ?? '').toString().split('T').first}',
                    style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 11)),
              ],
            ),
          ),
          // WhatsApp CTA
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              final phone = (c['phone'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
              final msg = Uri.encodeComponent(
                  '🙏 Hello ${c['name']}, we miss you at our store!\n\n'
                  '🎁 Come back and get *10% OFF* your next purchase.\n'
                  'This offer is exclusively for you! ❤️');
              launchUrlString('https://wa.me/$phone?text=$msg');
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.greenAccent, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_alt_rounded, color: Colors.greenAccent, size: 48),
          ),
          const SizedBox(height: 20),
          Text('All Customers Active! 🎉', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 8),
          Text('No churn risk detected in the last $_selectedDays days.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadChurn,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Refresh', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3: AUTO PURCHASE ORDER GENERATOR
// ═══════════════════════════════════════════════════════════════════════════

class _AutoPOTab extends StatefulWidget {
  const _AutoPOTab();

  @override
  State<_AutoPOTab> createState() => _AutoPOTabState();
}

class _AutoPOTabState extends State<_AutoPOTab> {
  Map<String, dynamic> _pos = {};
  bool _isLoading = true;
  int _totalItems = 0;

  @override
  void initState() {
    super.initState();
    _loadPOs();
  }

  void _loadPOs() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.getJson('/api/inventory/generate-purchase-orders');
      if (mounted) {
        final orders = jsonDecode(res.body)['purchase_orders'] as Map<String, dynamic>? ?? {};
        int count = 0;
        orders.forEach((_, items) { count += (items as List).length; });
        setState(() {
          _pos = orders;
          _totalItems = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _shareAllPOs() {
    String msg = '📦 *Purchase Orders — ${DateTime.now().toString().split(' ').first}*\n\n';
    _pos.forEach((supplier, items) {
      msg += '🏭 *$supplier*\n';
      for (var i in (items as List)) {
        msg += '  • ${i['product']} — Qty: ${i['recommended_order_qty']}\n';
      }
      msg += '\n';
    });
    launchUrlString('https://wa.me/?text=${Uri.encodeComponent(msg)}');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GlassCard(
          borderColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF6366F1), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Auto PO Generator', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('${_pos.length} suppliers • $_totalItems items need restock', style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ),
              if (_pos.isNotEmpty)
                GestureDetector(
                  onTap: _shareAllPOs,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.greenAccent, size: 22),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : _pos.isEmpty
                  ? _buildHealthyState()
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: _pos.entries.map((e) => _buildSupplierCard(e.key, e.value as List)).toList(),
                    ),
        ),
      ],
    );
  }

  Widget _buildSupplierCard(String supplier, List items) {
    return _GlassCard(
      borderColor: Colors.purpleAccent.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(0),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: Colors.white54,
          collapsedIconColor: Colors.white54,
          title: Text(supplier, style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w700)),
          subtitle: Text('${items.length} items need restock', style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 11)),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purpleAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.purpleAccent, size: 20),
          ),
          children: [
            ...items.map((i) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Icon(Icons.shopping_bag_outlined, color: Colors.grey[700], size: 16),
                  const SizedBox(width: 10),
                  Expanded(child: Text(i['product'] ?? '', style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13))),
                  Text('Stock: ${i['current_stock']}', style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 12)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text('Order ${i['recommended_order_qty']}', style: GoogleFonts.poppins(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  var msg = '📦 Order Request to *$supplier*\n\n';
                  for (var i in items) { msg += '• ${i['product']} — Qty: ${i['recommended_order_qty']}\n'; }
                  msg += '\nKindly confirm availability. 🙏';
                  launchUrlString('https://wa.me/?text=${Uri.encodeComponent(msg)}');
                },
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text('Send PO to $supplier', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 64),
          const SizedBox(height: 16),
          Text('Inventory is Healthy! ✅', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 8),
          Text('No purchase orders needed right now.', textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 4: SMART REORDER AI (Local Velocity Engine)
// ═══════════════════════════════════════════════════════════════════════════

class _SmartReorderTab extends StatefulWidget {
  const _SmartReorderTab();

  @override
  State<_SmartReorderTab> createState() => _SmartReorderTabState();
}

class _SmartReorderTabState extends State<_SmartReorderTab> {
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;
  String _shopName = 'My Shop';

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  void _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final inventory = await LocalStorageService.loadBackendProducts();
      final stockList = inventory.map((p) => {
        'name': p['product_name'] ?? '',
        'stock': int.tryParse(p['current_stock']?.toString() ?? '0') ?? 0,
        'supplier_whatsapp': p['supplier_phone'] ?? '',
      }).toList();

      final alerts = await SmartReorderAIService.getReorderAlerts(inventory: stockList);
      if (mounted) setState(() { _alerts = alerts; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GlassCard(
          borderColor: Colors.cyanAccent.withValues(alpha: 0.4),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.trending_up_rounded, color: Colors.cyanAccent, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Smart Reorder AI', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('Stockout predictions from sales velocity', style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ),
              if (_alerts.isNotEmpty)
                _buildStatPill('Urgent', '${_alerts.length}', Colors.redAccent),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
              : _alerts.isEmpty
                  ? _buildNoAlertsState()
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _alerts.length,
                      itemBuilder: (ctx, i) => _buildAlertCard(_alerts[i]),
                    ),
        ),
      ],
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final days = alert['days_until_stockout'] as int? ?? 0;
    final urgencyColor = days <= 1 ? Colors.redAccent
        : days <= 3 ? Colors.orangeAccent
        : Colors.yellowAccent;
    final velocity = (alert['daily_velocity'] as double? ?? 0).toStringAsFixed(1);
    final reorderQty = alert['suggested_reorder_qty'] as int? ?? 0;

    return _GlassCard(
      borderColor: urgencyColor.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(alert['product_name'] ?? '', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: urgencyColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: urgencyColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  days <= 1 ? '🔴 CRITICAL' : days <= 3 ? '🟠 URGENT' : '🟡 WARNING',
                  style: GoogleFonts.poppins(color: urgencyColor, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatPill('Days Left', '$days', urgencyColor),
              _buildStatPill('Stock', '${alert['current_stock']}', Colors.white70),
              _buildStatPill('Avg/Day', velocity, Colors.cyanAccent),
              _buildStatPill('Reorder', '$reorderQty', Colors.greenAccent),
            ],
          ),
          const SizedBox(height: 12),
          // Stockout progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (days / 5.0).clamp(0.0, 1.0),
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(urgencyColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final msg = SmartReorderAIService.generateReorderMessage(
                      productName: alert['product_name'] ?? '',
                      suggestedQty: reorderQty,
                      shopName: _shopName,
                    );
                    final phone = (alert['supplier_whatsapp'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
                    final encoded = Uri.encodeComponent(msg);
                    launchUrlString(phone.isNotEmpty
                        ? 'https://wa.me/$phone?text=$encoded'
                        : 'https://wa.me/?text=$encoded');
                  },
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: Text('WhatsApp Supplier', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoAlertsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Colors.cyanAccent, size: 56),
          ),
          const SizedBox(height: 20),
          Text('Stock Levels Safe! 📦', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 8),
          Text('No products running critically low.\nKeep selling! 🚀',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadAlerts,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent.withValues(alpha: 0.15),
              foregroundColor: Colors.cyanAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.cyanAccent, width: 1),
              ),
            ),
            child: Text('Refresh Analysis', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }
}

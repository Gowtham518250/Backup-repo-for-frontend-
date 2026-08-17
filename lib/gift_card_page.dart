import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import 'app_localizations.dart';
import 'visual_widgets.dart'; // AppBackground, GlassContainer, AppColors

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  GiftCardPage
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// A beautiful, flip-able gift card that displays shopkeeper details
/// prominently on the front and a QR code with all information on the back.
enum CardLayout { professional, creative, elegant, elite, minimalist }

class GiftCardTheme {
  final String name;
  final String mindsetName;
  final List<Color> gradient;
  final Color border;
  final Color text;
  final Color subtext;
  final Color accent;
  final CardLayout layout;
  final String? font;

  GiftCardTheme({
    required this.name,
    required this.mindsetName,
    required this.gradient,
    required this.border,
    required this.text,
    required this.subtext,
    required this.accent,
    required this.layout,
    this.font,
  });
}

class GiftCardPage extends StatefulWidget {
  final String userName;
  final String shopName;
  final String location;
  final String? shopType;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? gstNumber;
  final String? categories;
  final String? openingHour;
  final String? closingHour;
  final Uint8List? logoBytes;
  final String? website;
  final String? tagline;
  final bool reversed;

  const GiftCardPage({
    this.userName = 'Valued User',
    this.shopName = 'Digital Store',
    this.location = 'Global City',
    this.shopType,
    this.contactPerson,
    this.phone,
    this.email,
    this.gstNumber,
    this.categories,
    this.openingHour,
    this.closingHour,
    this.logoBytes,
    this.website,
    this.tagline,
    this.reversed = false,
    Key? key,
  }) : super(key: key);

  @override
  State<GiftCardPage> createState() => _GiftCardPageState();
}

class _GiftCardPageState extends State<GiftCardPage>
    with TickerProviderStateMixin {
  bool _showBack = false;
  bool _isEditing = false;
  int _selectedThemeIndex = 0;

  // Edit Controllers
  late TextEditingController _userNameController;
  late TextEditingController _shopNameController;
  late TextEditingController _locationController;
  late TextEditingController _phoneController;
  late TextEditingController _taglineController;

  final List<GiftCardTheme> _themes = [
    GiftCardTheme(
      name: 'Midnight Indigo',
      mindsetName: 'The Professional',
      gradient: [const Color(0xFF1E1B4B), const Color(0xFF312E81), const Color(0xFF4338CA)],
      border: const Color(0xFF818CF8),
      text: Colors.white,
      subtext: Colors.white70,
      accent: const Color(0xFF6366F1),
      layout: CardLayout.professional,
    ),
    GiftCardTheme(
      name: 'Electric Neon',
      mindsetName: 'The Future-Bound',
      gradient: [const Color(0xFF000000), const Color(0xFF1A0033), const Color(0xFF4F46E5)],
      border: const Color(0xFF00F2FF),
      text: Colors.white,
      subtext: const Color(0xFFE0E0E0),
      accent: const Color(0xFF00F2FF),
      layout: CardLayout.creative,
      font: 'Space Mono',
    ),
    GiftCardTheme(
      name: 'Ocean Deep',
      mindsetName: 'The Sophisticated',
      gradient: [const Color(0xFF0C4A6E), const Color(0xFF0369A1), const Color(0xFF0284C7)],
      border: const Color(0xFF38BDF8),
      text: Colors.white,
      subtext: const Color(0xFFBAE6FD),
      accent: const Color(0xFF7DD3FC),
      layout: CardLayout.elite,
    ),
    GiftCardTheme(
      name: 'Soft Petal',
      mindsetName: 'The Elegant',
      gradient: [const Color(0xFFFDF2F8), const Color(0xFFFCE7F3), const Color(0xFFFBCFE8)],
      border: const Color(0xFFEC4899),
      text: const Color(0xFF831843),
      subtext: const Color(0xFF9D174D),
      accent: const Color(0xFFDB2777),
      layout: CardLayout.elegant,
    ),
    GiftCardTheme(
      name: 'Zen Moss',
      mindsetName: 'The Minimalist',
      gradient: [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7), const Color(0xFFBBF7D0)],
      border: const Color(0xFF166534),
      text: const Color(0xFF064E3B),
      subtext: const Color(0xFF065F46),
      accent: const Color(0xFF15803D),
      layout: CardLayout.minimalist,
    ),
    GiftCardTheme(
      name: 'Cosmic Purple',
      mindsetName: 'The Visionary',
      gradient: [const Color(0xFF5B21B6), const Color(0xFF7C3AED), const Color(0xFFA855F7)],
      border: const Color(0xFFD8B4FE),
      text: Colors.white,
      subtext: const Color(0xFFE9D5FF),
      accent: const Color(0xFFC084FC),
      layout: CardLayout.creative,
    ),
  ];
  
  // Global key to capture card as image
  final GlobalKey _cardKey = GlobalKey();

  // Flip animation
  late final AnimationController _flipController;
  late final Animation<double> _flipAnim;

  // Entrance animation
  late final AnimationController _entranceController;
  late final Animation<double> _entranceFade;
  late final Animation<Offset> _entranceSlide;

  // Shimmer animation
  late final AnimationController _shimmerController;

  // Pulse animation for avatar ring
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _userNameController = TextEditingController(text: widget.userName);
    _shopNameController = TextEditingController(text: widget.shopName);
    _locationController = TextEditingController(text: widget.location);
    _phoneController = TextEditingController(text: widget.phone ?? '');
    _taglineController = TextEditingController(text: widget.tagline ?? '');

    // â”€â”€ Flip â”€â”€
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _flipAnim = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
    );

    // â”€â”€ Entrance â”€â”€
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _entranceFade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, .08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));
    _entranceController.forward();

    // â”€â”€ Shimmer â”€â”€
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // â”€â”€ Avatar pulse â”€â”€
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 6, end: 14).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // â”€â”€ Countdown â”€â”€
    // No auto-redirect: user should see the card and decide actions.
  }

  @override
  void dispose() {
    _flipController.dispose();
    _entranceController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    _userNameController.dispose();
    _shopNameController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  String _buildFullDetails() {
    final name = _isEditing ? _userNameController.text : widget.userName;
    final shop = _isEditing ? _shopNameController.text : widget.shopName;
    final loc = _isEditing ? _locationController.text : widget.location;
    final phone = _isEditing ? _phoneController.text : widget.phone;
    final tagline = _isEditing ? _taglineController.text : widget.tagline;

    final buf = StringBuffer()
      ..writeln('Shop: $shop')
      ..writeln('Owner: $name')
      ..writeln('Location: $loc');
    if (widget.shopType?.isNotEmpty == true) buf.writeln('Shop Type: ${widget.shopType}');
    if (widget.contactPerson?.isNotEmpty == true) buf.writeln('Contact Person: ${widget.contactPerson}');
    if (phone?.isNotEmpty == true) buf.writeln('Phone: $phone');
    if (widget.email?.isNotEmpty == true) buf.writeln('Email: ${widget.email}');
    if (widget.gstNumber?.isNotEmpty == true) buf.writeln('GST Number: ${widget.gstNumber}');
    if (widget.categories?.isNotEmpty == true) buf.writeln('Categories: ${widget.categories}');
    if (widget.openingHour?.isNotEmpty == true) buf.writeln('Opens: ${widget.openingHour}');
    if (widget.closingHour?.isNotEmpty == true) buf.writeln('Closes: ${widget.closingHour}');
    if (widget.website?.isNotEmpty == true) buf.writeln('Website: ${widget.website}');
    if (tagline?.isNotEmpty == true) buf.writeln('"$tagline"');
    return buf.toString();
  }

  /// Captures the card widget as an image and shares it along with details
  Future<void> _shareCard() async {
    try {
      // Wait a moment to ensure the widget is rendered
      await Future.delayed(const Duration(milliseconds: 100));
      
      // First, make sure we're showing the front side
      if (_showBack) {
        _toggleCard();
        await Future.delayed(const Duration(milliseconds: 900)); // Wait for flip animation
      }

      // Capture the card as an image
      if (_cardKey.currentContext == null) {
        throw Exception('Card context not available');
      }
      
      final RenderRepaintBoundary? boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary == null) {
        throw Exception('Cannot render card');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception('Cannot convert image to bytes');
      }
      
      final bytes = byteData.buffer.asUint8List();

      // Create a temporary file for the image
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.shopName
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
      final imageFile = File('${tempDir.path}/giftcard_$fileName.png');
      await imageFile.writeAsBytes(bytes);

      // Share both the image and text details
      final subject = 'Check out ${widget.shopName}';
      final text = _buildFullDetails();
      await Share.shareXFiles([XFile(imageFile.path)],
        subject: subject,
        text: text,
      );

      // Clean up the temp file
      if (await imageFile.exists()) {
        await imageFile.delete();
      }
    } catch (e) {
      print('Share error: $e');
      // Fallback to text-only sharing
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sharing card with details...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      Share.share(
        _buildFullDetails(),
        subject: 'Check out ${widget.shopName}',
      );
    }
  }

  void _toggleCard() {
    if (_showBack) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _showBack = !_showBack);
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F), // Slightly lighter more visible dark
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Background components directly here for better control
          _AmbientOrbs(theme: _themes[_selectedThemeIndex]),
          const _ParticleLayer(),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBrandHeader(),
                        const SizedBox(height: 20),
                        _buildFlipCard(),
                        const SizedBox(height: 16),
                        _buildThemeSelector(),
                        const SizedBox(height: 28),
                        _buildHintPill(),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _shareCard,
                              icon: const Icon(Icons.share_outlined),
                              label: Text(AppLocalizations.of(context).shareCard),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF06B6D4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _toggleCard,
                              icon: const Icon(Icons.flip_outlined),
                              label: Text(_showBack ? AppLocalizations.of(context).viewFront : AppLocalizations.of(context).viewBack),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildDashboardButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        AppLocalizations.of(context).giftCard,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: BackdropFilter(
            filter: _blurFilter,
            child: const SizedBox.expand(),
          ),
        ),
      ),
      actions: [
        _IconBtn(
          icon: _isEditing ? Icons.check_rounded : Icons.edit_rounded,
          onTap: () async {
            if (_isEditing) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('shop_name', _shopNameController.text);
              await prefs.setString('user_name', _userNameController.text);
              await prefs.setString('username', _userNameController.text);
              await prefs.setString('phone', _phoneController.text);
              await prefs.setString('location', _locationController.text);
              await prefs.setString('tagline', _taglineController.text);
            }
            setState(() => _isEditing = !_isEditing);
          },
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _IconBtn(icon: Icons.share_rounded, onTap: _shareCard),
        ),
      ],
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        // App logo with glow ring
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                blurRadius: 25,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/shop_logo.png',
              width: 70,
              height: 70,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                ),
                child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 30),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // App name
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFB0B8FF), Colors.white],
          ).createShader(bounds),
          child: Text(
            AppLocalizations.of(context).appTitle,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppLocalizations.of(context).tagline,
        ),
      ],
    );
  }

  Widget _buildFlipCard() {
    final width = MediaQuery.of(context).size.width * 0.88;

    Widget card = RepaintBoundary(
      key: _cardKey,
      child: GestureDetector(
        onTap: _toggleCard,
        child: AnimatedBuilder(
          animation: _flipAnim,
          builder: (context, _) {
            final angle = _flipAnim.value * math.pi;
            final isFront = angle < math.pi / 2;
            
            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              alignment: Alignment.center,
              child: isFront 
                  ? _buildFront(width)
                  : Transform(
                      transform: Matrix4.identity()..rotateY(math.pi),
                      alignment: Alignment.center,
                      child: _buildBack(width),
                    ),
            );
          },
        ),
      ),
    );

    if (widget.reversed) {
      card = Transform.rotate(
        angle: math.pi,
        child: card,
      );
    }

    return card;
  }

  Widget _buildFront(double width) {
    final theme = _themes[_selectedThemeIndex];
    
    // Switch between different mindsets/layouts
    switch (theme.layout) {
      case CardLayout.creative:
        return _buildCreativeFront(width, theme);
      case CardLayout.elegant:
        return _buildElegantFront(width, theme);
      case CardLayout.elite:
        return _buildEliteFront(width, theme);
      case CardLayout.minimalist:
        return _buildMinimalistFront(width, theme);
      default:
        return _buildProfessionalFront(width, theme);
    }
  }

  Widget _buildProfessionalFront(double width, GiftCardTheme theme) {
    final l = AppLocalizations.of(context);
    return Container(
      width: width,
      constraints: BoxConstraints(minHeight: width * 1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.gradient[0].withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.12,
              child: CustomPaint(painter: _GiftCardPatternPainter(_selectedThemeIndex)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAvatar(theme),
                    _buildCompactQr(),
                  ],
                ),
                const SizedBox(height: 30),
                if (_isEditing)
                  _buildEditField(_userNameController, 'Owner Name', theme)
                else
                  Text(
                    _userNameController.text.toUpperCase(),
                    style: GoogleFonts.poppins(fontSize: 12, letterSpacing: 3, color: theme.text.withValues(alpha: 0.7), fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 8),
                if (_isEditing)
                  _buildEditField(_shopNameController, 'Shop Name', theme, isLarge: true)
                else
                  Text(
                    _shopNameController.text,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(fontSize: 32, fontWeight: FontWeight.w900, color: theme.text, height: 1.1),
                  ),
                const SizedBox(height: 40),
                _buildDetailSection(l, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreativeFront(double width, GiftCardTheme theme) {
    final l = AppLocalizations.of(context);
    return Container(
      width: width,
      constraints: BoxConstraints(minHeight: width * 1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: theme.gradient,
        ),
      ),
      child: Stack(
        children: [
          // Slanted divider
          Positioned(
            top: -50,
            right: -50,
            child: Transform.rotate(
              angle: -0.2,
              child: Container(
                width: width * 1.2,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
            ),
          ),
          Positioned(
            top: 24,
            right: 24,
            child: _buildCompactQr(size: 70),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: _buildAvatar(theme, size: 110)),
                const SizedBox(height: 35),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _userNameController.text,
                    style: GoogleFonts.spaceMono(color: theme.text, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _shopNameController.text,
                  style: GoogleFonts.archivoBlack(fontSize: 38, color: theme.text, height: 1, letterSpacing: -1.5),
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SimpleDetail(icon: Icons.phone_rounded, value: _phoneController.text, theme: theme),
                          const SizedBox(height: 10),
                          _SimpleDetail(icon: Icons.location_on_rounded, value: _locationController.text, theme: theme),
                        ],
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElegantFront(double width, GiftCardTheme theme) {
    return Container(
      width: width,
      constraints: BoxConstraints(minHeight: width * 1.5),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.border.withValues(alpha: 0.2),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.gradient,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text('E S T . 2 0 2 6', style: GoogleFonts.montserrat(fontSize: 10, letterSpacing: 4, color: theme.subtext)),
            const SizedBox(height: 25),
            _buildAvatar(theme, size: 120),
            const SizedBox(height: 30),
            Text(
              _shopNameController.text,
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(fontSize: 42, fontWeight: FontWeight.w300, color: theme.text, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 10),
            Container(width: 50, height: 1, color: theme.border.withValues(alpha: 0.3)),
            const SizedBox(height: 10),
            Text(_userNameController.text, style: GoogleFonts.montserrat(fontSize: 14, letterSpacing: 2, color: theme.subtext)),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone_outlined, size: 14, color: theme.accent),
                      const SizedBox(width: 8),
                      Text(_phoneController.text, style: GoogleFonts.poppins(color: theme.text, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                   ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: theme.accent),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_locationController.text, style: GoogleFonts.poppins(color: theme.subtext, fontSize: 11), textAlign: TextAlign.center)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEliteFront(double width, GiftCardTheme theme) {
    return Container(
      width: width,
      constraints: BoxConstraints(minHeight: width * 1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.gradient,
        ),
        border: Border.all(color: theme.border.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Stack(
        children: [
          // Gold corner patterns
          Positioned(top: -20, left: -20, child: Icon(Icons.auto_awesome, color: theme.accent.withValues(alpha: 0.1), size: 100)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
            child: Column(
              children: [
                Align(alignment: Alignment.topRight, child: _buildCompactQr(size: 60)),
                const SizedBox(height: 20),
                _buildAvatar(theme, size: 100),
                const SizedBox(height: 40),
                Text(
                  _shopNameController.text.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(fontSize: 34, fontWeight: FontWeight.w900, color: theme.text, letterSpacing: 2),
                ),
                const SizedBox(height: 15),
                Text(
                   _userNameController.text,
                   style: GoogleFonts.poppins(fontSize: 14, color: theme.accent, letterSpacing: 3, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.border.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.phone_outlined, color: theme.accent, size: 16),
                          const SizedBox(width: 10),
                          Text(_phoneController.text, style: TextStyle(color: theme.text)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _locationController.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.text.withValues(alpha: 0.7), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalistFront(double width, GiftCardTheme theme) {
    return Container(
      width: width,
      constraints: BoxConstraints(minHeight: width * 1.5),
      decoration: BoxDecoration(
        color: theme.gradient[0],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.text.withValues(alpha: 0.03),
            ),
            child: Center(child: _buildAvatar(theme, size: 80)),
          ),
          Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _shopNameController.text.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: theme.text, letterSpacing: 1.2),
                ),
                const SizedBox(height: 4),
                Text(_userNameController.text, style: GoogleFonts.inter(color: theme.subtext, fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                const SizedBox(height: 40),
                _MinimalRow(icon: Icons.call_outlined, value: _phoneController.text, theme: theme),
                const SizedBox(height: 12),
                _MinimalRow(icon: Icons.map_outlined, value: _locationController.text, theme: theme),
                const SizedBox(height: 50),
                Center(child: _buildCompactQr(size: 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(GiftCardTheme theme, {double size = 90}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: theme.text.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: ClipOval(
        child: widget.logoBytes != null
            ? Image.memory(widget.logoBytes!, fit: BoxFit.cover)
            : _buildProfileFallback(),
      ),
    );
  }

  Widget _buildCompactQr({double size = 70.0}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: QrImageView(
        data: 'Shop: ${widget.shopName}\nContact: ${widget.phone}\nOwner: ${widget.userName}',
        version: QrVersions.auto,
        size: size,
        gapless: false,
      ),
    );
  }

  Widget _buildDetailSection(AppLocalizations l, GiftCardTheme theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          if (_isEditing)
            _buildEditField(_locationController, l.location, theme)
          else
            _DetailRow(icon: Icons.location_on_rounded, label: l.location, value: _locationController.text, theme: theme),
          const SizedBox(height: 16),
          if (_isEditing)
            _buildEditField(_phoneController, l.phone, theme)
          else
            _DetailRow(icon: Icons.phone_rounded, label: l.phone, value: _phoneController.text, theme: theme),
          if (widget.email?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _DetailRow(icon: Icons.email_rounded, label: l.email, value: widget.email!, theme: theme),
          ],
          if (widget.gstNumber?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _DetailRow(icon: Icons.receipt_long_rounded, label: 'GSTIN', value: widget.gstNumber!, theme: theme),
          ],
          if (widget.shopType?.isNotEmpty == true || widget.categories?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.storefront_rounded, 
              label: 'Identity', 
              value: [widget.shopType ?? '', widget.categories ?? ''].where((s) => s.isNotEmpty).join(' • '), 
              theme: theme
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHoursBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time_filled_rounded, size: 14, color: Colors.white70),
          const SizedBox(width: 8),
          Text(
            '${widget.openingHour} – ${widget.closingHour}',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(TextEditingController controller, String label, GiftCardTheme theme, {bool isLarge = false}) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      style: isLarge 
        ? GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: theme.text)
        : GoogleFonts.poppins(fontSize: 13, color: theme.text),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: theme.text.withValues(alpha: 0.3)),
        contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        isDense: true,
        border: UnderlineInputBorder(borderSide: BorderSide(color: theme.text.withValues(alpha: 0.3))),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.text.withValues(alpha: 0.2))),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.accent, width: 2)),
      ),
    );
  }

  Widget _buildShimmer(double width) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (_, __) {
        final t = _shimmerController.value;
        return Positioned.fill(
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            child: Transform.translate(
              offset: Offset((t * 2 - 0.5) * width, 0),
              child: Container(
                width: width * 0.4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.05),
                      Colors.white.withValues(alpha: 0.03),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.3, 0.7, 1],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLargePhotoColumn() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
      ),
      child: widget.logoBytes != null
          ? Image.memory(
              widget.logoBytes!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildProfileFallbackCover(),
            )
          : _buildProfileFallbackCover(),
    );
  }

  Widget _buildProfileFallbackCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
      ),
      child: Center(
        child: Opacity(
          opacity: 0.6,
          child: Image.asset(
            'assets/shop_logo.png',
            width: 100,
            height: 100,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.store_rounded,
              size: 60,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileFallback() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
      ),
      child: Center(
        child: Image.asset(
          'assets/shop_logo.png',
          width: 80,
          height: 80,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.person_rounded,
              size: 70,
              color: Colors.white,
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailedInfoColumn() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Colors.white.withValues(alpha: 0.98),
            Colors.white.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Spread details vertically
          children: [
            // Shop name area
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.shopName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    AppLocalizations.of(context).shopkeeper,
                    style: GoogleFonts.spaceMono(
                      fontSize: 8,
                      letterSpacing: 1,
                      color: const Color(0xFF059669),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ], // Close children of Column at 915
            ), // Close Column at 915
            _buildDetailsListView(), 
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsListView() {
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(
            icon: Icons.person_rounded,
            label: l.owner,
            value: widget.userName,
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.location_on_rounded,
            label: l.location,
            value: widget.location,
          ),

          if (widget.shopType?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.store_mall_directory_rounded,
              label: 'Shop Type',
              value: widget.shopType!,
            ),
          ],
          if (widget.contactPerson?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.contact_phone_rounded,
              label: 'Contact Person',
              value: widget.contactPerson!,
            ),
          ],
          if (widget.phone?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.phone_rounded,
              label: l.phone,
              value: widget.phone!,
            ),
          ],
          if (widget.email?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.email_rounded,
              label: l.email,
              value: widget.email!,
            ),
          ],
          if (widget.gstNumber?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.receipt_long_rounded,
              label: 'GST Number',
              value: widget.gstNumber!,
            ),
          ],
          if (widget.categories?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.local_offer_rounded,
              label: 'Categories',
              value: widget.categories!,
            ),
          ],
          if (widget.openingHour?.isNotEmpty == true || widget.closingHour?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.schedule_rounded,
              label: 'Working Hours',
              value: '${widget.openingHour ?? "N/A"} - ${widget.closingHour ?? "N/A"}',
            ),
          ],
          if (widget.website?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.language_rounded,
              label: l.website,
              value: widget.website!,
            ),
          ],
          if (widget.tagline?.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded, size: 14, color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.tagline!,
                    maxLines: 2,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // â”€â”€ Back â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildBack(double width) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 520),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              ),
              child: QrImageView(
                data: _getQrData(),
                version: QrVersions.auto,
                size: 260.0,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF1F2937),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'SCAN FOR SHOP DETAILS',
              style: GoogleFonts.spaceMono(
                fontSize: 12,
                letterSpacing: 4,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.shopName.toUpperCase(),
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getQrData() {
    return [
      'Shop: ${widget.shopName}',
      'Owner: ${widget.userName}',
      'Location: ${widget.location}',
      if (widget.shopType?.isNotEmpty == true) 'Type: ${widget.shopType}',
      if (widget.contactPerson?.isNotEmpty == true) 'Contact: ${widget.contactPerson}',
      if (widget.phone?.isNotEmpty == true) 'Phone: ${widget.phone}',
      if (widget.email?.isNotEmpty == true) 'Email: ${widget.email}',
      if (widget.gstNumber?.isNotEmpty == true) 'GST: ${widget.gstNumber}',
      if (widget.website?.isNotEmpty == true) 'Web: ${widget.website}',
      if (widget.tagline?.isNotEmpty == true) 'Tagline: ${widget.tagline}',
    ].join('\n');
  }

  /// Builds a compact preview of the front card for the back side
  Widget _buildCardPreview() {
    final previewWidth = 200.0;
    return SizedBox(
      width: previewWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Shop name and logo preview
          Row(
            children: [
              // Mini logo
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF10B981)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: widget.logoBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          widget.logoBytes!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.store,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              // Shop info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.shopName,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0B1220),
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        AppLocalizations.of(context).shopkeeper,
                        style: GoogleFonts.spaceMono(
                          fontSize: 7,
                          letterSpacing: 1,
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Contact info preview
          _buildPreviewInfo(Icons.person_rounded, widget.userName, 9),
          const SizedBox(height: 6),
          _buildPreviewInfo(Icons.location_on_rounded, widget.location, 9),
          if (widget.shopType?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            _buildPreviewInfo(Icons.store_mall_directory_rounded, widget.shopType!, 9),
          ],
          if (widget.contactPerson?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            _buildPreviewInfo(Icons.contact_mail_rounded, widget.contactPerson!, 9),
          ],
          if (widget.phone?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            _buildPreviewInfo(Icons.phone_rounded, widget.phone!, 9),
          ],
          if (widget.email?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            _buildPreviewInfo(Icons.email_rounded, widget.email!, 9),
          ],
          if (widget.categories?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            _buildPreviewInfo(Icons.local_offer_rounded, widget.categories!, 9),
          ],
          if (widget.openingHour?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            _buildPreviewInfo(Icons.schedule_rounded, 'Opens: ${widget.openingHour}', 9),
          ],
          if (widget.website?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            _buildPreviewInfo(Icons.language_rounded, widget.website!, 9),
          ],
        ],
      ),
    );
  }

  /// Helper widget for preview info rows
  Widget _buildPreviewInfo(IconData icon, String value, double fontSize) {
    return Row(
      children: [
        Icon(icon, size: 12, color: const Color(0xFF10B981)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: fontSize,
              color: Colors.white70,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // â”€â”€ Hint pill â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildHintPill() {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      borderRadius: BorderRadius.circular(999),
      blurSigma: 18,
      child: Text(
        _showBack ? AppLocalizations.of(context).tapToSeeFront : AppLocalizations.of(context).tapToFlip,
        style: GoogleFonts.poppins(
          color: Colors.white70,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: .2,
        ),
      ),
    );
  }

  // â”€â”€ Dashboard button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildDashboardButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(width: 0),
        const SizedBox(width: 14),

        // Button
        ElevatedButton.icon(
          onPressed: () =>
              Navigator.of(context).pushReplacementNamed('/dashboard'),
          icon: const Icon(Icons.dashboard_rounded, size: 18),
          label: Text(
            AppLocalizations.of(context).goToDashboard,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            elevation: 12,
            shadowColor: Colors.black.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 30, vertical: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Choose Theme',
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 45,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _themes.length,
            itemBuilder: (context, index) {
              return _buildThemeOption(index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption(int index) {
    final theme = _themes[index];
    final isSelected = _selectedThemeIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedThemeIndex = index),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: theme.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(isSelected ? 14 : 10),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.2),
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: theme.gradient[0].withValues(alpha: 0.5), blurRadius: 10)]
                    : [],
              ),
              child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
            ),
            const SizedBox(height: 6),
            Text(
              theme.mindsetName.split(' ').last,
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleDetail extends StatelessWidget {
  final IconData icon;
  final String value;
  final GiftCardTheme theme;
  const _SimpleDetail({required this.icon, required this.value, required this.theme});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.text.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Text(value, style: GoogleFonts.poppins(color: theme.text, fontSize: 13)),
      ],
    );
  }
}

class _MinimalRow extends StatelessWidget {
  final IconData icon;
  final String value;
  final GiftCardTheme theme;
  const _MinimalRow({required this.icon, required this.value, required this.theme});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.accent),
        const SizedBox(width: 12),
        Expanded(child: Text(value, style: GoogleFonts.inter(color: theme.subtext, fontSize: 14))),
      ],
    );
  }
}


// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  Private sub-widgets
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Single info row (icon + text).
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.theme,
  });
  final IconData icon;
  final String label;
  final String value;
  final GiftCardTheme? theme;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? GiftCardTheme(
      name: 'Default',
      mindsetName: 'The Professional',
      gradient: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      border: const Color(0xFF818CF8),
      text: Colors.white,
      subtext: Colors.white70,
      accent: const Color(0xFF10B981),
      layout: CardLayout.professional,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: t.text.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: t.text.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(icon, size: 14, color: t.text.withValues(alpha: 0.8)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: t.text.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: t.text.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.28),
            ),
          ),
          child: Icon(icon, size: 13, color: const Color(0xFF10B981)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.65),
              fontWeight: FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Tagline gradient strip (shown only when tagline is not empty).
class _TaglineStrip extends StatelessWidget {
  const _TaglineStrip({required this.tagline, required this.width});
  final String tagline;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF0097A7)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x3310B981),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white.withValues(alpha: 0.12), Colors.transparent],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          Text(
            '"$tagline"',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 13.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pill stamp (e.g. "AI SHOPKEEPER").
class _StampBadge extends StatelessWidget {
  const _StampBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceMono(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
        ),
      ),
    );
  }
}

/// Circular countdown ring shown next to the Dashboard button.
class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final remaining = ((1 - controller.value) * 5).ceil();
          return Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 1 - controller.value,
                strokeWidth: 2.5,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primary.withValues(alpha: 0.8),
                ),
              ),
              Text(
                '$remaining',
                style: GoogleFonts.spaceMono(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Rounded icon button used in the AppBar.
class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.85)),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  Ambient orbs (animated blurred circles in background)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AmbientOrbs extends StatefulWidget {
  final GiftCardTheme theme;
  const _AmbientOrbs({required this.theme});

  @override
  State<_AmbientOrbs> createState() => _AmbientOrbsState();
}

class _AmbientOrbsState extends State<_AmbientOrbs>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<Offset>> _offsets;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) => AnimationController(
      vsync: this,
      duration: Duration(seconds: 9 + i * 2),
    )..repeat(reverse: true));

    _offsets = _controllers
        .map((c) => Tween<Offset>(
              begin: Offset.zero,
              end: Offset(
                30 + math.Random().nextDouble() * 20,
                20 + math.Random().nextDouble() * 15,
              ),
            ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width > 0 ? size.width : 400.0;
    final h = size.height > 0 ? size.height : 800.0;
    
    final positions = [
      Offset(-80, -80),
      Offset(w - 200, h - 200),
      Offset(w * .5, h * .4),
    ];

    return Stack(
      children: List.generate(3, (i) {
        final colors = [
          widget.theme.gradient[0],
          widget.theme.gradient.length > 1 ? widget.theme.gradient[1] : widget.theme.gradient[0],
          widget.theme.accent,
        ];
        final sizes = [320.0, 280.0, 200.0];
        final opacities = [0.15, 0.12, 0.10];
        
        return AnimatedBuilder(
          animation: _offsets[i],
          builder: (_, __) => Positioned(
            left: positions[i].dx + _offsets[i].value.dx,
            top: positions[i].dy + _offsets[i].value.dy,
            child: IgnorePointer(
              child: Container(
                width: sizes[i],
                height: sizes[i],
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors[i].withValues(alpha: opacities[i]),
                      blurRadius: sizes[i] * 0.9,
                      spreadRadius: sizes[i] * 0.1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  Floating particle layer
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ParticleLayer extends StatefulWidget {
  const _ParticleLayer();

  @override
  State<_ParticleLayer> createState() => _ParticleLayerState();
}

class _ParticleLayerState extends State<_ParticleLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  List<_Particle> _particles = [];
  bool _initialized = false;
  static final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(() => setState(() {}));

    // Generate particles lazily after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      final w = size.width > 0 ? size.width : 400.0;
      final h = size.height > 0 ? size.height : 800.0;
      
      _particles = List.generate(
        40,
        (_) => _Particle.random(Size(w, h), _rng),
      );
      _initialized = true;
      _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || !_controller.isAnimating) return const SizedBox.shrink();
    final size = MediaQuery.of(context).size;
    final w = size.width > 0 ? size.width : 400.0;
    final h = size.height > 0 ? size.height : 800.0;
    
    return CustomPaint(
      size: Size(w, h),
      painter: _ParticlePainter(_particles),
    );
  }
}

class _Particle {
  double x, y, vx, vy, radius, opacity;
  Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.opacity,
    required this.color,
  });

  static final _colors = [
    const Color(0xFF6366F1),
    const Color(0xFF10B981),
    const Color(0xFFF59E0B),
  ];

  factory _Particle.random(Size size, math.Random rng) => _Particle(
        x: rng.nextDouble() * size.width,
        y: rng.nextDouble() * size.height,
        vx: (rng.nextDouble() - .5) * .4,
        vy: (rng.nextDouble() - .5) * .4,
        radius: rng.nextDouble() * 1.6 + .4,
        opacity: rng.nextDouble() * .45 + .1,
        color: _colors[rng.nextInt(_colors.length)],
      );

  void update(Size size) {
    x += vx;
    y += vy;
    if (x < 0) x = size.width;
    if (x > size.width) x = 0;
    if (y < 0) y = size.height;
    if (y > size.height) y = 0;
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.particles);
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      p.update(size);
    }

    final dotPaint = Paint();
    final linePaint = Paint()..strokeWidth = .4;

    for (int i = 0; i < particles.length; i++) {
      final a = particles[i];
      dotPaint.color = a.color.withValues(alpha: a.opacity);
      canvas.drawCircle(Offset(a.x, a.y), a.radius, dotPaint);

      for (int j = i + 1; j < particles.length; j++) {
        final b = particles[j];
        final d = math.sqrt(
            math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
        if (d < 110) {
          linePaint.color =
              Colors.white.withValues(alpha: .08 * (1 - d / 110));
          canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  Card background pattern painter (matches original _GiftCardPatternPainter)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _GiftCardPatternPainter extends CustomPainter {
  final int themeIndex;
  _GiftCardPatternPainter(this.themeIndex);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.08);

    switch (themeIndex) {
      case 1: // Emerald Luxe (Hexagons)
        _drawHexagons(canvas, size, paint);
        break;
      case 2: // Ruby Crimson (Ripples)
        _drawRipples(canvas, size, paint);
        break;
      case 3: // Slate Carbon (Grid)
        _drawGrid(canvas, size, paint);
        break;
      case 4: // Ocean Azure (Waves)
        _drawWaves(canvas, size, paint);
        break;
      case 5: // Rose Petal (Dots)
        _drawDots(canvas, size, paint);
        break;
      case 6: // Gold Amber (Starburst)
        _drawStarburst(canvas, size, paint);
        break;
      case 7: // Mint Frost (Diamond)
        _drawDiamonds(canvas, size, paint);
        break;
      case 8: // Lavender Twilight (Cross-hatch)
        _drawCrossHatch(canvas, size, paint);
        break;
      case 9: // Sunset Glow (Triangles)
        _drawTriangles(canvas, size, paint);
        break;
      default: // Midnight Indigo (Lines)
        _drawLines(canvas, size, paint);
        break;
    }
  }

  void _drawLines(Canvas canvas, Size size, Paint paint) {
    for (double x = -size.height; x < size.width + size.height; x += 22) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  void _drawHexagons(Canvas canvas, Size size, Paint paint) {
    const side = 25.0;
    final h = math.sqrt(3) * side;
    for (double y = 0; y < size.height + h; y += h) {
      for (double x = 0; x < size.width + side * 3; x += side * 3) {
        final path = Path();
        path.moveTo(x, y);
        path.lineTo(x + side, y);
        path.lineTo(x + side * 1.5, y + h / 2);
        path.lineTo(x + side, y + h);
        path.lineTo(x, y + h);
        path.lineTo(x - side * 0.5, y + h / 2);
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawRipples(Canvas canvas, Size size, Paint paint) {
    for (double r = 40; r < size.height; r += 35) {
      canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.2), r, paint);
    }
  }

  void _drawGrid(Canvas canvas, Size size, Paint paint) {
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawWaves(Canvas canvas, Size size, Paint paint) {
    for (double y = 0; y < size.height; y += 40) {
      final path = Path();
      path.moveTo(0, y);
      for (double x = 0; x < size.width; x += 20) {
        path.quadraticBezierTo(x + 10, y + 20, x + 20, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawDots(Canvas canvas, Size size, Paint paint) {
    paint.style = PaintingStyle.fill;
    final rng = math.Random(42);
    for (int i = 0; i < 60; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 3 + 1,
        paint,
      );
    }
  }

  void _drawStarburst(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    for (double a = 0; a < 2 * math.pi; a += math.pi / 12) {
      canvas.drawLine(
        center,
        center + Offset(math.cos(a) * size.height, math.sin(a) * size.height),
        paint,
      );
    }
  }

  void _drawDiamonds(Canvas canvas, Size size, Paint paint) {
    const s = 40.0;
    for (double y = 0; y < size.height + s; y += s) {
      for (double x = 0; x < size.width + s; x += s) {
        final path = Path();
        path.moveTo(x + s / 2, y);
        path.lineTo(x + s, y + s / 2);
        path.lineTo(x + s / 2, y + s);
        path.lineTo(x, y + s / 2);
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawCrossHatch(Canvas canvas, Size size, Paint paint) {
    for (double x = -size.height; x < size.width; x += 25) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
      canvas.drawLine(Offset(x + size.height, 0), Offset(x, size.height), paint);
    }
  }

  void _drawTriangles(Canvas canvas, Size size, Paint paint) {
    const s = 60.0;
    for (double y = 0; y < size.height + s; y += s) {
      for (double x = 0; x < size.width + s; x += s) {
        canvas.drawPath(
          Path()
            ..moveTo(x, y)
            ..lineTo(x + s, y)
            ..lineTo(x + s/2, y + s)
            ..close(),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GiftCardPatternPainter oldDelegate) => 
      oldDelegate.themeIndex != themeIndex;
}

// â”€â”€ Blur filter constant â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
final _blurFilter = ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20);
// NOTE: imported dart:ui as ui at top of file

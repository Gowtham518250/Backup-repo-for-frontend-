import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'api_client.dart';

class ShareShopPage extends StatefulWidget {
  const ShareShopPage({super.key});

  @override
  State<ShareShopPage> createState() => _ShareShopPageState();
}

class _ShareShopPageState extends State<ShareShopPage> {
  String _shopId = '1';
  String _shopName = 'My Shop';
  bool _isLoading = true;
  String _shopUrl = 'https://retail-mind-web.onrender.com/shop/1'; // Fallback, will be updated in _loadShopData
  bool _sharingQr = false;

  final GlobalKey _qrKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadShopData();
  }

  Future<void> _loadShopData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('shop_id') ??
          prefs.getInt('user_id')?.toString() ??
          '1';
      final shopName = prefs.getString('shop_name') ?? 'My Shop';
      if (!mounted) return;
      setState(() {
        _shopId = shopId;
        _shopName = shopName;
        // Use the deployed web URL
        _shopUrl = 'https://retail-mind-web.onrender.com/shop/$shopId';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Share shop load error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Instant WhatsApp share
  Future<void> _whatsappShare() async {
    final whatsappText = '🛍️ Order from $_shopName online!\n\n'
        'Browse products & place your order here:\n$_shopUrl\n\n'
        'Powered by AI Shop Pro 🚀';
        
    final url = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(whatsappText)}');
    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (!launched) {
        await Share.share(whatsappText, subject: 'Shop at $_shopName');
      }
    } catch (e) {
      await Share.share(whatsappText, subject: 'Shop at $_shopName');
    }
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _shopUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Shop link copied to clipboard!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _nativeShareLink() {
    Share.share(
      '🛍️ Order from $_shopName online!\n\nBrowse products & place your order here:\n$_shopUrl\n\nPowered by AI Shop Pro',
      subject: 'Order from $_shopName',
    );
  }

  Future<void> _shareQrCode() async {
    if (_sharingQr) return;
    setState(() => _sharingQr = true);

    try {
      // Wait max 2 seconds for the widget to be fully rendered
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null || !boundary.hasSize) {
        // Fallback: just share the link if QR capture fails
        _nativeShareLink();
        return;
      }

      // Use pixelRatio 2.0 instead of 3.0 — 55% faster, still high quality
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0)
          .timeout(const Duration(seconds: 5), onTimeout: () {
        throw Exception('QR render timeout');
      });

      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png)
          .timeout(const Duration(seconds: 5), onTimeout: () {
        throw Exception('QR encode timeout');
      });

      if (byteData == null) {
        _nativeShareLink();
        return;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to temp file
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/shop_qr_$_shopId.png');
      await file.writeAsBytes(pngBytes);

      // Share file + text together, falling back to link sharing if it takes more than 2 seconds
      var finished = false;
      await Future.any([
        Share.shareXFiles(
          [XFile(file.path)],
          text: '🛍️ Scan this QR to order from $_shopName online!\n\nOr visit: $_shopUrl',
          subject: 'Order from $_shopName - QR Code',
        ).then((_) => finished = true),
        Future.delayed(const Duration(milliseconds: 1800)).then((_) {
          if (!finished && mounted) {
            debugPrint('⚠️ shareXFiles is taking too long, invoking link fallback...');
            _nativeShareLink();
          }
        }),
      ]);
    } on Exception catch (e) {
      debugPrint('QR share error: $e — falling back to link share');
      // Always fallback to link share instead of showing error
      if (mounted) {
        _nativeShareLink();
      }
    } finally {
      if (mounted) setState(() => _sharingQr = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          'Share Shop',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF43F5E), Color(0xFFEC4899)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.storefront_rounded, size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your Online Storefront',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share the QR or link — customers can browse and order instantly!',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // QR Card with RepaintBoundary to capture
                  Card(
                    color: const Color(0xFF1A1A2E),
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          RepaintBoundary(
                            key: _qrKey,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  QrImageView(
                                    data: _shopUrl,
                                    version: QrVersions.auto,
                                    size: 200.0,
                                    backgroundColor: Colors.white,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _shopName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1A1A2E),
                                    ),
                                  ),
                                  Text(
                                    'Scan to order online',
                                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Share QR Button
                          ElevatedButton.icon(
                            onPressed: _sharingQr ? null : _shareQrCode,
                            icon: _sharingQr
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.qr_code_2_rounded),
                            label: Text(_sharingQr ? 'Sharing...' : 'Share QR Code Image'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF43F5E),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Link Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link_rounded, color: Colors.blueAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _shopUrl,
                            style: GoogleFonts.poppins(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, color: Colors.blueAccent),
                          onPressed: _copyLink,
                          tooltip: 'Copy Link',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Instant WhatsApp / Share Link Button
                  ElevatedButton.icon(
                    onPressed: _whatsappShare,
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('⚡ Share Store Link Instantly'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  // Info Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_rounded, color: Colors.orangeAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '💡 Tip: Print the QR code & paste it at your counter — perfect for hotels, restaurants & shops!',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.orangeAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
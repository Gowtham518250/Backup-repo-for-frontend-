import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'payment_detection_service.dart';
import 'payment_event.dart';
import 'local_storage_service.dart';
import 'local_storage_service.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> with SingleTickerProviderStateMixin {
  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: [BarcodeFormat.all],
  );
  
  // Use TTS for reliable audio feedback since system sounds vary across devices
  final FlutterTts _tts = FlutterTts();
  
  late AnimationController _animationController;
  bool _isProcessing = false;
  final List<String> _scannedCodes = [];
  bool _isBatchMode = false; 
  String _lastScannedCode = '';
  DateTime _lastScanTime = DateTime.fromMillisecondsSinceEpoch(0);
  double _zoomFactor = 0.0;
  double _baseZoomScale = 0.0;
  String? _recentPaymentAlert;
  Timer? _alertTimer;
  StreamSubscription? _paymentSub;
  
  bool _heatmapEnabled = false;
  Map<String, dynamic>? _heatmapResult;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    // Quick scan confirmation settings
    _tts.setSpeechRate(0.8);
    _tts.setPitch(1.2);
    _tts.setVolume(1.0);

    // Real-time payment listener
    _paymentSub = PaymentDetectionService().onUiState.listen((event) {
      if (event.decision == PaymentDecision.confirmed) {
        if (!mounted) return;
        setState(() {
          _recentPaymentAlert = "Confirmed ₹${event.amount.toStringAsFixed(0)} - ${event.payerName ?? 'Success'}";
        });
        _alertTimer?.cancel();
        _alertTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _recentPaymentAlert = null);
        });
      }
    });
  }

  @override
  void dispose() {
    _paymentSub?.cancel();
    _alertTimer?.cancel();
    cameraController.dispose();
    _animationController.dispose();
    _tts.stop();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final String code = barcodes.first.rawValue ?? '';
    if (code.isEmpty) return;

    // 1-second Duplicate Protection
    final now = DateTime.now();
    if (code == _lastScannedCode && now.difference(_lastScanTime).inMilliseconds < 1000) {
      return;
    }

    _lastScannedCode = code;
    _lastScanTime = now;

    if (_heatmapEnabled) {
      _checkHeatmap(code);
      return;
    }

    if (_isBatchMode) {
      if (!_scannedCodes.contains(code)) {
        _scannedCodes.add(code);
        HapticFeedback.lightImpact();
        _tts.speak("Scan"); // Short confirmation for batch mode
        
        setState(() => _isProcessing = true);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _isProcessing = false);
        });
      }
    } else {
      _isProcessing = true;
      // Trigger multiple types of feedback to ensure it's heard
      SystemSound.play(SystemSoundType.click);
      _tts.speak("Ok"); 
      HapticFeedback.vibrate();
      
      // Delay pop slightly to ensure TTS is heard
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) Navigator.of(context).pop(code);
      });
    }
  }

  Future<void> _checkHeatmap(String code) async {
    try {
      final products = await LocalStorageService.loadBackendProducts();
      final product = products.firstWhere((p) => p['sku'].toString() == code, orElse: () => {});
      
      if (product.isEmpty) {
        setState(() => _heatmapResult = {'name': 'Unknown Product', 'status': 'Unknown', 'color': Colors.grey});
      } else {
        final stock = (product['current_stock'] as num).toDouble();
        final min = (product['min_stock'] as num).toDouble();
        
        Color color;
        String status;
        
        if (stock <= 0) {
          color = Colors.red; status = "Out of Stock (High Demand!)";
        } else if (stock <= min) {
          color = Colors.orange; status = "Low Stock Velocity";
        } else {
          color = Colors.green; status = "Healthy Profit Flow";
        }
        
        setState(() {
          _heatmapResult = {
            'name': product['product_name'],
            'status': status,
            'color': color,
            'price': '₹${product['unit_price']}',
            'sku': code
          };
        });
      }
      
      HapticFeedback.mediumImpact();
      
      // Auto-clear heatmap after 3 seconds
      Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _heatmapResult = null);
      });
      
    } catch (e) {
       print('Heatmap Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanWindowSize = size.width * 0.75;
    final scanWindow = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanWindowSize,
      height: scanWindowSize * 0.6,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Mobile Scanner with gesture detection
          GestureDetector(
            onScaleStart: (_) {
              _baseZoomScale = _zoomFactor;
            },
            onScaleUpdate: (ScaleUpdateDetails details) {
              setState(() {
                // Adjust zoom factor based on pinch scale
                _zoomFactor = (_baseZoomScale + (details.scale - 1.0) * 0.5).clamp(0.0, 1.0);
                _applyZoom();
              });
            },
            child: MobileScanner(
              controller: cameraController,
              onDetect: _onDetect,
              scanWindow: scanWindow,
            ),
          ),

          CustomPaint(
            painter: ScannerOverlayPainter(
              scanWindow: scanWindow,
              borderRadius: 20,
            ),
            child: Container(),
          ),

          // Scanning Line Animation
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Positioned(
                top: scanWindow.top + (scanWindow.height * _animationController.value),
                left: scanWindow.left + 10,
                right: scanWindow.left + scanWindow.width - 10,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                    gradient: const LinearGradient(
                      colors: [Colors.transparent, Color(0xFF4F46E5), Colors.transparent],
                    ),
                  ),
                ),
              );
            },
          ),

          _buildTopUI(),
          _buildBottomUI(),
          _buildZoomSlider(),
          if (_recentPaymentAlert != null) _buildPaymentOverlay(),
          if (_heatmapResult != null) _buildHeatmapOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeatmapOverlay() {
    return Positioned(
      bottom: 200,
      left: 30,
      right: 30,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (_heatmapResult!['color'] as Color).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)],
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_heatmapResult!['name'] ?? '', 
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_heatmapResult!['status'] ?? '', 
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            if (_heatmapResult!['price'] != null) ...[
              const SizedBox(height: 8),
              Text(_heatmapResult!['price'], 
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
            ],
            const SizedBox(height: 4),
            Text('SKU: ${_heatmapResult!['sku']}', 
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopUI() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const Expanded(
              child: Text(
                'Scan Barcode / QR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 48), // Balance for back button
          ],
        ),
      ),
    );
  }

  Widget _buildZoomSlider() {
    return Positioned(
      bottom: 120,
      left: 40,
      right: 40,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.zoom_out_rounded, color: Colors.white54, size: 16),
              Text(
                '${(_zoomFactor * 3 + 1).toStringAsFixed(1)}x',
                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const Icon(Icons.zoom_in_rounded, color: Colors.white54, size: 16),
            ],
          ),
          Slider(
            value: _zoomFactor,
            activeColor: const Color(0xFF4F46E5),
            inactiveColor: Colors.white24,
            onChanged: (v) {
              setState(() {
                _zoomFactor = v;
                _applyZoom();
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _applyZoom() async {
    try {
      if (cameraController.value.isInitialized) {
        await cameraController.setZoomScale(_zoomFactor);
      }
    } catch (e) {
      print('Zoom Error: $e');
    }
  }

  Widget _buildPaymentOverlay() {
    return Positioned(
      top: 100,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _recentPaymentAlert!,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomUI() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ActionButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: cameraController,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.white);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                  default:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                }
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
          _ActionButton(
            icon: Icon(Icons.insights_rounded, color: _heatmapEnabled ? Colors.orange : Colors.white),
            onPressed: () {
              setState(() {
                _heatmapEnabled = !_heatmapEnabled;
                _heatmapResult = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(_heatmapEnabled ? '🔥 Heatmap Velocity Mode ON' : '📷 Scanner Mode ON'),
                duration: const Duration(seconds: 1),
              ));
            },
          ),
          const SizedBox(width: 20),
          _ActionButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onPressed;

  const _ActionButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: IconButton(
            iconSize: 28,
            padding: const EdgeInsets.all(16),
            icon: icon,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final double borderRadius;

  ScannerOverlayPainter({
    required this.scanWindow,
    this.borderRadius = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanWindow, Radius.circular(borderRadius)));

    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final backgroundWithCutout = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    canvas.drawPath(backgroundWithCutout, backgroundPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF4F46E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final borderLength = borderRadius * 2;
    
    // Top Left
    canvas.drawArc(
      Rect.fromCircle(center: Offset(scanWindow.left + borderRadius, scanWindow.top + borderRadius), radius: borderRadius),
      3.14,
      1.57,
      false,
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanWindow.left + borderRadius, scanWindow.top),
      Offset(scanWindow.left + borderRadius + borderLength, scanWindow.top),
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanWindow.left, scanWindow.top + borderRadius),
      Offset(scanWindow.left, scanWindow.top + borderRadius + borderLength),
      borderPaint,
    );

    // Top Right
    canvas.drawArc(
      Rect.fromCircle(center: Offset(scanWindow.right - borderRadius, scanWindow.top + borderRadius), radius: borderRadius),
      -1.57,
      1.57,
      false,
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanWindow.right - borderRadius, scanWindow.top),
      Offset(scanWindow.right - borderRadius - borderLength, scanWindow.top),
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanWindow.right, scanWindow.top + borderRadius),
      Offset(scanWindow.right, scanWindow.top + borderRadius + borderLength),
      borderPaint,
    );

    // Bottom Left
    canvas.drawArc(
      Rect.fromCircle(center: Offset(scanWindow.left + borderRadius, scanWindow.bottom - borderRadius), radius: borderRadius),
      1.57,
      1.57,
      false,
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanWindow.left + borderRadius, scanWindow.bottom),
      Offset(scanWindow.left + borderRadius + borderLength, scanWindow.bottom),
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanWindow.left, scanWindow.bottom - borderRadius),
      Offset(scanWindow.left, scanWindow.bottom - borderRadius - borderLength),
      borderPaint,
    );

    // Bottom Right
    canvas.drawArc(
      Rect.fromCircle(center: Offset(scanWindow.right - borderRadius, scanWindow.bottom - borderRadius), radius: borderRadius),
      0,
      1.57,
      false,
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanWindow.right - borderRadius, scanWindow.bottom),
      Offset(scanWindow.right - borderRadius - borderLength, scanWindow.bottom),
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanWindow.right, scanWindow.bottom - borderRadius),
      Offset(scanWindow.right, scanWindow.bottom - borderRadius - borderLength),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

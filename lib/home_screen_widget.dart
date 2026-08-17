import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'local_storage_service.dart';
import 'payment_detection_service.dart';

class DailySummaryWidget {
  static const String groupId = 'daily_summary_group';
  static const String storageKey = 'daily_summary';

  static Future<void> updateWidget() async {
    try {
      final sales = await LocalStorageService.loadSales();
      
      double totalSales = 0;
      double upiSales = 0;
      int transactionCount = 0;
      
      final today = DateTime.now();
      
      for (var sale in sales) {
        final saleDate = sale is Map ? 
          DateTime.tryParse(sale['sale_date']?.toString() ?? '') :
          null;
        
        if (saleDate != null && 
            saleDate.year == today.year &&
            saleDate.month == today.month &&
            saleDate.day == today.day) {
          totalSales += double.tryParse(sale['total']?.toString() ?? '0') ?? 0;
          
          if (sale['payment_method'] == 'UPI') {
            upiSales += double.tryParse(sale['total']?.toString() ?? '0') ?? 0;
          }
          transactionCount++;
        }
      }
      
      // Store data for widget
      await HomeWidget.saveWidgetData(
        storageKey,
        {
          'totalSales': totalSales.toStringAsFixed(0),
          'transactionCount': transactionCount.toString(),
          'upiSales': upiSales.toStringAsFixed(0),
          'cashSales': (totalSales - upiSales).toStringAsFixed(0),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      // Update the widget
      await HomeWidget.updateWidget(
        name: 'DailySummaryWidget',
        iOSName: 'DailySummaryWidget',
      );
    } catch (e) {
      debugPrint('Error updating widget: $e');
    }
  }

  // Widget update scheduling removed (workmanager no longer supported due to Kotlin compatibility)
  // The widget will update manually when the app is opened
  static Future<void> initializeWidgetUpdates() async {
    // Periodic updates disabled - use onAppOpen instead
  }

  static Future<void> cancelWidgetUpdates() async {
    // No-op since workmanager was removed
  }
}

class WidgetVoiceSummary {
  static final FlutterTts _tts = FlutterTts();

  static Future<void> speakDailySummary({
    required double totalSales,
    required int transactionCount,
    required double creditPending,
    required VoiceLanguage language,
  }) async {
    String message = '';
    
    switch (language) {
      case VoiceLanguage.hindi:
        message = _buildHindiMessage(totalSales, transactionCount, creditPending);
        await _tts.setLanguage('hi-IN');
        break;
      case VoiceLanguage.tamil:
        message = _buildTamilMessage(totalSales, transactionCount, creditPending);
        await _tts.setLanguage('ta-IN');
        break;
      case VoiceLanguage.telugu:
        message = _buildTeluguMessage(totalSales, transactionCount, creditPending);
        await _tts.setLanguage('te-IN');
        break;
      case VoiceLanguage.kannada:
        message = _buildKannadaMessage(totalSales, transactionCount, creditPending);
        await _tts.setLanguage('kn-IN');
        break;
      case VoiceLanguage.english:
      default:
        message = _buildEnglishMessage(totalSales, transactionCount, creditPending);
        await _tts.setLanguage('en-IN');
    }
    
    await _tts.speak(message);
  }

  static String _buildHindiMessage(double total, int count, double credit) {
    return 'आज ₹${total.toStringAsFixed(0)} हुआ। $count बिक्री। '
        '₹${credit.toStringAsFixed(0)} उधार बाकी।';
  }

  static String _buildTamilMessage(double total, int count, double credit) {
    return 'இன்று ₹${total.toStringAsFixed(0)}. $count விற்பனை. '
        '₹${credit.toStringAsFixed(0)} கடன் உள்ளது.';
  }

  static String _buildTeluguMessage(double total, int count, double credit) {
    return 'ఈ రోజు ₹${total.toStringAsFixed(0)}. $count విక్రయాలు. '
        '₹${credit.toStringAsFixed(0)} రుణం పెండింగ్.';
  }

  static String _buildKannadaMessage(double total, int count, double credit) {
    return 'ಇಂದು ₹${total.toStringAsFixed(0)}. $count ಮಾರಾಟ. '
        '₹${credit.toStringAsFixed(0)} ಸಾಲ ಬಾಕಿ.';
  }

  static String _buildEnglishMessage(double total, int count, double credit) {
    return 'Today ₹${total.toStringAsFixed(0)}. $count sales. '
        '₹${credit.toStringAsFixed(0)} credit pending.';
  }
}

class HomeScreenWidgetPage extends StatefulWidget {
  const HomeScreenWidgetPage({super.key});

  @override
  State<HomeScreenWidgetPage> createState() => _HomeScreenWidgetPageState();
}

class _HomeScreenWidgetPageState extends State<HomeScreenWidgetPage> {
  Map<String, dynamic>? _widgetData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWidgetData();
    _initializeUpdates();
  }

  Future<void> _loadWidgetData() async {
    final data = await HomeWidget.getWidgetData(DailySummaryWidget.storageKey);
    setState(() {
      _widgetData = data;
      _isLoading = false;
    });
  }

  Future<void> _initializeUpdates() async {
    if (Theme.of(context).platform == TargetPlatform.android) {
      await DailySummaryWidget.initializeWidgetUpdates();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final totalSales = double.tryParse(_widgetData?['totalSales'] ?? '0') ?? 0;
    final transactionCount = int.tryParse(_widgetData?['transactionCount'] ?? '0') ?? 0;
    final upiSales = double.tryParse(_widgetData?['upiSales'] ?? '0') ?? 0;
    final cashSales = double.tryParse(_widgetData?['cashSales'] ?? '0') ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text('Widget Preview', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Widget Preview
            Container(
              width: 300,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${totalSales.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                  Text(
                    '$transactionCount sales',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _speakSummary(),
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Speak Summary'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            // Statistics
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today\'s Breakdown', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildStatRow('UPI Sales', '₹${upiSales.toStringAsFixed(0)}', Colors.blue),
                  const SizedBox(height: 8),
                  _buildStatRow('Cash Sales', '₹${cashSales.toStringAsFixed(0)}', Colors.green),
                  const SizedBox(height: 8),
                  _buildStatRow('Transactions', '$transactionCount', Colors.purple),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(color: Colors.grey.shade600)),
        Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Future<void> _speakSummary() async {
    final totalSales = double.tryParse(_widgetData?['totalSales'] ?? '0') ?? 0;
    final transactionCount = int.tryParse(_widgetData?['transactionCount'] ?? '0') ?? 0;
    
    await WidgetVoiceSummary.speakDailySummary(
      totalSales: totalSales,
      transactionCount: transactionCount,
      creditPending: 0,
      language: VoiceLanguage.english,
    );
  }
}

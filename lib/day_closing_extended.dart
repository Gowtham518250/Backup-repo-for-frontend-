import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'shop_profile_page.dart';
import 'whatsapp_message_service.dart';
import 'payment_detection_service.dart';
import 'local_storage_service.dart';

/// Day Closing Extension - WhatsApp owner report functionality
class DayClosingExtended {
  static const String _tag = '📋 DAY_CLOSING_EXT';
  
  final LocalStorageService _storage = LocalStorageService();
  
  /// Show manual cash input and WhatsApp option
  static Future<void> showCashInputDialog(
    BuildContext context, {
    required double recordedCash,
    required double upiSales,
    required String ownerPhone,
    required VoiceLanguage language,
  }) async {
    final TextEditingController cashCtrl = TextEditingController();
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('💰 Actual Cash Handed Over'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Recorded Cash: ₹${recordedCash.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cashCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Actual Cash (₹)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final actualCash = double.tryParse(cashCtrl.text);
              if (actualCash == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Invalid amount')),
                );
                return;
              }
              
              Navigator.pop(ctx);
              
              await showWhatsAppConfirmation(
                context: context,
                recordedCash: recordedCash,
                actualCash: actualCash,
                upiSales: upiSales,
                ownerPhone: ownerPhone,
                language: language,
              );
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
  
  /// Show WhatsApp preview and send button
  static Future<void> showWhatsAppConfirmation({
    required BuildContext context,
    required double recordedCash,
    required double actualCash,
    required double upiSales,
    required String ownerPhone,
    required VoiceLanguage language,
  }) async {
    final message = WhatsAppMessageService.buildDayClosingMessage(
      upiSales: upiSales,
      recordedCash: recordedCash,
      actualCash: actualCash,
      language: language,
    );
    
    final discrepancy = recordedCash - actualCash;
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('📱 Send to Owner via WhatsApp'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Message preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Discrepancy warning
              if (discrepancy.abs() > 10)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.amber[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Discrepancy: ₹${discrepancy.abs().toStringAsFixed(0)}',
                          style: TextStyle(color: Colors.amber[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 12),
              Text(
                'Owner: $ownerPhone',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _sendViaWhatsApp(message, ownerPhone);
            },
            icon: const Icon(Icons.send),
            label: const Text('Send to Owner'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Send message via WhatsApp
  static Future<void> _sendViaWhatsApp(String message, String phone) async {
    try {
      // Remove +91 prefix if present, add country code
      String formattedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (!formattedPhone.startsWith('91')) {
        formattedPhone = '91$formattedPhone';
      }
      
      final whatsappUrl = Uri.parse(
        'https://wa.me/$formattedPhone/?text=${Uri.encodeComponent(message)}',
      );
      
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch WhatsApp';
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
    }
  }
}

/// Widget wrapper for day closing flow
class DayClosingWithWhatsAppWidget extends StatefulWidget {
  final double recordedCash;
  final double upiSales;
  final double totalSales;
  final String ownerPhone;
  final VoiceLanguage language;
  final Function() onClosingComplete;
  
  const DayClosingWithWhatsAppWidget({
    required this.recordedCash,
    required this.upiSales,
    required this.totalSales,
    required this.ownerPhone,
    required this.language,
    required this.onClosingComplete,
    Key? key,
  }) : super(key: key);
  
  @override
  State<DayClosingWithWhatsAppWidget> createState() =>
      _DayClosingWithWhatsAppWidgetState();
}

class _DayClosingWithWhatsAppWidgetState
    extends State<DayClosingWithWhatsAppWidget> {
  
  bool _isConfirmingClose = false;
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[50]!, Colors.purple[50]!],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildSummarRow('UPI Sales', widget.upiSales),
                _buildSummarRow('Cash Sales', widget.totalSales - widget.upiSales),
                Divider(color: Colors.grey[400]),
                _buildSummarRow('Total', widget.totalSales, isBold: true),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Confirm Day Close Button
          ElevatedButton.icon(
            onPressed: _isConfirmingClose
                ? null
                : () async {
              setState(() => _isConfirmingClose = true);
              
              await DayClosingExtended.showCashInputDialog(
                context,
                recordedCash: widget.recordedCash,
                upiSales: widget.upiSales,
                ownerPhone: widget.ownerPhone,
                language: widget.language,
              );
              
              setState(() => _isConfirmingClose = false);
              widget.onClosingComplete();
            },
            icon: const Icon(Icons.check_circle),
            label: const Text('Confirm Day Close & Send Report'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummarRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: isBold ? 16 : 14,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: isBold ? 18 : 16,
              color: isBold ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'payment_detection_service.dart';
import 'whatsapp_message_service.dart';

/// Udhar Reminder DTO
class UdharReminder {
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final double amountDue;
  final int daysOverdue;
  final DateTime lastReminderDate;
  
  UdharReminder({
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.amountDue,
    required this.daysOverdue,
    required this.lastReminderDate,
  });
}

/// Udhar Reminder Service - Owner approval before WhatsApp send
class UdharReminderService {
  static const String _tag = '💳 UDHAR_REMINDER';
  static const String _skippedPrefix = 'udhar_skipped_';
  static const int skipDurationDays = 3;
  
  /// Check if reminder should be shown (not skipped)
  static Future<bool> shouldShowReminder(String customerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skippedKey = '$_skippedPrefix$customerId';
      final skippedUntil = prefs.getString(skippedKey);
      
      if (skippedUntil == null) return true;
      
      final skippedDate = DateTime.parse(skippedUntil);
      return DateTime.now().isAfter(skippedDate);
    } catch (e) {
      debugPrint('$_tag Error checking skip status: $e');
      return true;
    }
  }
  
  /// Mark reminder as skipped for N days
  static Future<void> skipReminder(String customerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skippedKey = '$_skippedPrefix$customerId';
      final skipUntil = DateTime.now().add(Duration(days: skipDurationDays));
      
      await prefs.setString(skippedKey, skipUntil.toIso8601String());
      debugPrint('$_tag Skipped reminder for $customerId until $skipUntil');
    } catch (e) {
      debugPrint('$_tag Error skipping reminder: $e');
    }
  }
  
  /// Clear skip for a customer (re-enable reminders)
  static Future<void> clearSkip(String customerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skippedKey = '$_skippedPrefix$customerId';
      await prefs.remove(skippedKey);
    } catch (e) {
      debugPrint('$_tag Error clearing skip: $e');
    }
  }
  
  /// Send reminder via WhatsApp
  static Future<void> sendReminderViaWhatsApp({
    required String customerPhone,
    required String customerName,
    required double amountDue,
    required VoiceLanguage language,
  }) async {
    try {
      String message = WhatsAppMessageService.buildUdharReminderMessage(
        customerName: customerName,
        amount: amountDue,
        language: language,
      );
      
      // Append UPI Deep Link
      final prefs = await SharedPreferences.getInstance();
      final upiId = prefs.getString('primary_upi_id') ?? prefs.getString('upi_id');
      final shopName = prefs.getString('shop_name') ?? 'Shop';
      if (upiId != null && upiId.isNotEmpty) {
        final upiLink = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(shopName)}&am=${amountDue.toStringAsFixed(2)}&cu=INR&tn=UdharPayment';
        message += '\n\n*Pay via UPI:*\n$upiLink';
      }
      
      String formattedPhone = customerPhone.replaceAll(RegExp(r'[^\d]'), '');
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
      debugPrint('$_tag Error sending reminder: $e');
    }
  }
}

/// UI Card for pending udhar reminder
class UdharReminderCard extends StatefulWidget {
  final UdharReminder reminder;
  final VoiceLanguage language;
  final Function() onSent;
  final Function() onSkipped;
  
  const UdharReminderCard({
    required this.reminder,
    required this.language,
    required this.onSent,
    required this.onSkipped,
    Key? key,
  }) : super(key: key);
  
  @override
  State<UdharReminderCard> createState() => _UdharReminderCardState();
}

class _UdharReminderCardState extends State<UdharReminderCard> {
  bool _isSending = false;
  
  @override
  Widget build(BuildContext context) {
    final message = WhatsAppMessageService.buildUdharReminderMessage(
      customerName: widget.reminder.customerName,
      amount: widget.reminder.amountDue,
      language: widget.language,
    );
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.orange[50]!, Colors.red[50]!],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.reminder.customerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.reminder.daysOverdue} days overdue',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '₹${widget.reminder.amountDue.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            Divider(color: Colors.grey[300]),
            const SizedBox(height: 12),
            
            // Message preview
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[800],
                  height: 1.4,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSending
                        ? null
                        : () async {
                      setState(() => _isSending = true);
                      
                      await UdharReminderService.skipReminder(
                        widget.reminder.customerId,
                      );
                      
                      widget.onSkipped();
                      
                      if (mounted) {
                        setState(() => _isSending = false);
                      }
                    },
                    child: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSending
                        ? null
                        : () async {
                      setState(() => _isSending = true);
                      
                      if (widget.reminder.customerPhone != null) {
                        await UdharReminderService.sendReminderViaWhatsApp(
                          customerPhone: widget.reminder.customerPhone!,
                          customerName: widget.reminder.customerName,
                          amountDue: widget.reminder.amountDue,
                          language: widget.language,
                        );
                      }
                      
                      widget.onSent();
                      
                      if (mounted) {
                        setState(() => _isSending = false);
                      }
                    },
                    icon: _isSending
                        ? SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.send),
                    label: const Text('Send Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Extension for khata_page.dart to show pending reminders
class UdharReminderListView extends StatefulWidget {
  final List<UdharReminder> pendingReminders;
  final VoiceLanguage language;
  final Function() onUpdate;
  
  const UdharReminderListView({
    required this.pendingReminders,
    required this.language,
    required this.onUpdate,
    Key? key,
  }) : super(key: key);
  
  @override
  State<UdharReminderListView> createState() => _UdharReminderListViewState();
}

class _UdharReminderListViewState extends State<UdharReminderListView> {
  late List<UdharReminder> reminders;
  
  @override
  void initState() {
    super.initState();
    reminders = List.from(widget.pendingReminders);
  }
  
  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.check_circle, size: 48, color: Colors.green),
              const SizedBox(height: 12),
              Text(
                'No pending reminders',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: reminders.length,
        itemBuilder: (ctx, idx) => UdharReminderCard(
          reminder: reminders[idx],
          language: widget.language,
          onSent: () {
            setState(() => reminders.removeAt(idx));
            widget.onUpdate();
          },
          onSkipped: () {
            setState(() => reminders.removeAt(idx));
            widget.onUpdate();
          },
        ),
      ),
    );
  }
}

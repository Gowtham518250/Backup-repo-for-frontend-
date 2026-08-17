import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Local retention + growth helpers (no backend). Implements the “5 suggestions” in-app.
class RetentionSnapshot {
  final int firstOpenMs;
  final int billsCompleted;
  final int? lastBillMs;
  final int? lastAppOpenMs;

  const RetentionSnapshot({
    required this.firstOpenMs,
    required this.billsCompleted,
    this.lastBillMs,
    this.lastAppOpenMs,
  });

  int get daysSinceFirstOpen {
    final first = DateTime.fromMillisecondsSinceEpoch(firstOpenMs);
    final now = DateTime.now();
    final firstDate = DateTime(first.year, first.month, first.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(firstDate).inDays.clamp(0, 9999);
  }

  String get streakHint {
    if (billsCompleted == 0) {
      return 'Habit metric: complete bills here and this counter grows — track how often you use the app.';
    }
    if (lastBillMs == null) {
      return 'Keep billing regularly to build a steady shop rhythm.';
    }
    final last = DateTime.fromMillisecondsSinceEpoch(lastBillMs!);
    final now = DateTime.now();
    final lastDate = DateTime(last.year, last.month, last.day);
    final today = DateTime(now.year, now.month, now.day);
    final days = today.difference(lastDate).inDays;
    if (days == 0) return 'You recorded a bill today. Strong retention signal.';
    if (days == 1) return 'You billed yesterday. One more today keeps momentum.';
    return 'Last bill was $days days ago — open Sales when you have a moment.';
  }
}

class RetailGrowthKit {
  static const kShopFocus = 'retail_shop_focus_v1';
  static const kFocusOnboardingDone = 'retail_focus_onboarding_v1_done';
  static const kFirstOpenMs = 'retail_first_open_ms';
  static const kBillCount = 'retail_bills_completed_count';
  static const kLastBillMs = 'retail_last_bill_completed_ms';
  static const kLastOpenMs = 'retail_last_app_open_ms';
  static const kPlayStoreHint = 'retail_play_store_url_hint';

  static const Map<String, String> focusLabels = {
    'general': 'General retail',
    'grocery': 'Kirana / grocery',
    'fashion': 'Fashion / garments',
    'electronics': 'Mobile & electronics',
    'pharmacy': 'Pharmacy',
    'other': 'Other',
  };

  static Future<void> ensureFirstOpenStamp() async {
    final p = await SharedPreferences.getInstance();
    if (!p.containsKey(kFirstOpenMs)) {
      await p.setInt(kFirstOpenMs, DateTime.now().millisecondsSinceEpoch);
    }
  }

  static Future<void> recordAppOpen() async {
    final p = await SharedPreferences.getInstance();
    await ensureFirstOpenStamp();
    await p.setInt(kLastOpenMs, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> recordBillCompleted() async {
    final p = await SharedPreferences.getInstance();
    await ensureFirstOpenStamp();
    final n = p.getInt(kBillCount) ?? 0;
    await p.setInt(kBillCount, n + 1);
    await p.setInt(kLastBillMs, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<RetentionSnapshot> loadRetention() async {
    final p = await SharedPreferences.getInstance();
    await ensureFirstOpenStamp();
    return RetentionSnapshot(
      firstOpenMs: p.getInt(kFirstOpenMs) ?? DateTime.now().millisecondsSinceEpoch,
      billsCompleted: p.getInt(kBillCount) ?? 0,
      lastBillMs: p.getInt(kLastBillMs),
      lastAppOpenMs: p.getInt(kLastOpenMs),
    );
  }

  static Future<String> getShopFocus() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(kShopFocus) ?? 'general';
  }

  static Future<bool> shouldShowFocusOnboarding() async {
    final p = await SharedPreferences.getInstance();
    return !(p.getBool(kFocusOnboardingDone) ?? false);
  }

  static Future<void> _persistFocus(String focusKey) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(kShopFocus, focusKey);
    await p.setBool(kFocusOnboardingDone, true);
  }

  static Future<void> presentFocusSetupSheet(BuildContext context, {bool locking = false}) async {
    final initial = await getShopFocus();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: !locking,
      enableDrag: !locking,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String selected = initial;
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: 24 + MediaQuery.of(ctx).padding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'What do you run?',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We highlight the flows that usually matter most for your type of shop. You can change this anytime.',
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700], height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.42),
                      child: ListView(
                        shrinkWrap: true,
                        children: focusLabels.entries
                            .map(
                              (e) => RadioListTile<String>(
                                dense: true,
                                value: e.key,
                                groupValue: selected,
                                onChanged: (v) => setSt(() => selected = v!),
                                title: Text(
                                  e.value,
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () async {
                        await _persistFocus(selected);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Save & continue'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Future<void> shareAppInvite() async {
    final p = await SharedPreferences.getInstance();
    final link = p.getString(kPlayStoreHint)?.trim() ?? '';
    final buf = StringBuffer()
      ..writeln('Try RETAIL MIND — billing, khata & shop tools in one app.')
      ..writeln('Share this with another shop you know.');
    if (link.isNotEmpty) buf.writeln('\n$link');
    await Share.share(buf.toString().trim());
  }

  static Future<void> openWhatsAppSupport(String phoneDigits) async {
    final clean = phoneDigits.replaceAll(RegExp(r'\D'), '');
    if (clean.length < 10) return;
    final uri = Uri.parse(
      'https://wa.me/$clean?text=${Uri.encodeComponent('Hi, I need help with RETAIL MIND app.')}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static String recommendationForFocus(String key) {
    switch (key) {
      case 'grocery':
        return 'Priority: fast billing, perishable stock, and khata for daily customers.';
      case 'fashion':
        return 'Priority: SKU/barcodes, returns, and size/colour notes on invoices.';
      case 'electronics':
        return 'Priority: IMEI/serial on bill, GST clarity, and warranty reminders.';
      case 'pharmacy':
        return 'Priority: batch-friendly billing, stock alerts, and invoice trail.';
      case 'other':
        return 'Priority: one clean daily closing habit and accurate khata.';
      default:
        return 'Priority: daily sales entry, khata, and month-end closing.';
    }
  }
}


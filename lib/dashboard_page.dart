import 'package:flutter/material.dart';
import 'whatsapp_orders_page.dart';
import 'marketing_page.dart';
import 'package:retail_mind/premium_ui.dart';
import 'sale_service.dart';
import 'agent_debug_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'sms_background_receiver.dart';
import 'financial_math.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:typed_data';
import 'secure_token_storage.dart';
import 'secure_preferences_service.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';
import 'app_localizations.dart';
import 'local_storage_service.dart';
import 'google_drive_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'invoices_page.dart' hide Expanded;
import 'gift_card_page.dart';
import 'visual_widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'language_provider.dart';
import 'tutorial_service.dart';
import 'security_service.dart';
import 'providers/payment_state.dart';
import 'providers/invoice_state.dart';
import 'role_selection_page.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'khata_page.dart';
import 'returns_page.dart';
import 'schemes_page.dart';
import 'gst_filing_page.dart';
import 'gst_compliance.dart';
import 'session_management.dart';
import 'scoped_shared_preferences.dart';

import 'charts/bar_chart.dart';
import 'charts/line_chart.dart';
import 'charts/pie_chart.dart';
import 'charts/radar_chart.dart';
import 'analytics_engine.dart';
import 'app_bottom_nav.dart';
import 'payment_announcement_service.dart';
import 'online_store_service.dart';
import 'online_order_service.dart';
import 'low_stock_alerts_service.dart';
import 'payment_detection_service.dart';
import 'package:record/record.dart' as record;
import 'package:path/path.dart' as p;
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'data_export_widget.dart';
import 'export_service.dart';
import 'auth_helper.dart';
import 'session_logout_service.dart';
import 'validation_helper.dart';
import 'sync_queue_manager.dart';
import 'sync_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'csv_import_service.dart';
import 'tally_export_service.dart';
import 'package:local_auth/local_auth.dart';
import 'format_helper.dart';
import 'user_data_clear_service.dart';
import 'payment_event.dart';
import 'notification_service.dart';
import 'inventory_management_service.dart';
import 'retail_intelligence_page.dart';
import 'retail_growth_kit.dart';
import 'daily_health_score_service.dart';
import 'investor_analytics_dashboard.dart';
import 'loyalty_network_dashboard.dart';
import 'commission_dashboard_page.dart';
import 'loyalty_program_page.dart';
import 'delivery_tracking_page.dart';
import 'smart_notifications_service.dart';
import 'widgets/dashboard/operations_reports_section.dart';
import 'widgets/dashboard/shop_modules_section.dart';
import 'widgets/dashboard/compact_quick_actions.dart';
import 'widgets/dashboard/printer_monetization_banner.dart';
import 'printer_settings_page.dart';
import 'daily_summary_notification_service.dart';
import 'screens/owner/online_store_hub_page.dart';
import 'online_store_manager_page.dart';
import 'widgets/online_analytics_card.dart';
import 'widgets/error_boundary.dart'; // Phase 3: Dashboard crash protection
import 'performance_optimizations.dart'; // 🚀 Advanced performance optimizations

// color constants for a cohesive shopkeeper-friendly theme
const Color kPrimaryColor = Color(0xFF6366F1);
const Color kSecondaryColor = Color(0xFF10B981); // Emerald instead of Cyan
const Color kAccentColor = Color(0xFFF59E0B); // Amber
const Color kInfoColor = Color(0xFF3B82F6); // Blue

// dashboard theme tokens - REDESIGNED FOR CLEAN WHITE BACKGROUND
const Color bg = Color(0xFFFFFFFF); // Changed from #0F172A to white
const Color indigo = Color(0xFF4F46E5); // Primary color
const Color violet = Color(0xFF6D28D9); // Secondary violet
const Color cyan = Color(0xFF4F46E5); // Using indigo
const Color amber = Color(0xFFF59E0B);
const Color orange = Color(0xFFF97316);
const Color emerald = Color(0xFF10B981);
const Color t1 = Color(0xFF1F2937); // Dark text for white bg
const Color t2 = Color(0xFF6B7280); // Medium text
const Color t3 = Color(0xFF9CA3AF); // Light text
const Color glass = Color(0xFFF5F7FA); // Light card background
const Color glass2 = Color(0xFFF3F4F6);
const Color border = Color(0xFFE5E7EB);
const Color border2 = Color(0xFFD1D5DB);
const Color glowB = Color(0xFF10B981);
const Color success = Color(0xFF10B981);
const Color warning = Color(0xFFF59E0B);
const Color errorRed = Color(0xFFEF4444);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin, WidgetsBindingObserver, OptimizedStateMixin {
  late final AnimationController _animationController;
  late final ScrollController _scrollController;
  late final AnimationController _paymentDetectionPulseController;
  late final Animation<double> _paymentDetectionPulse;
  Timer? _refreshTimer;

  // sales + insight state
  static const List<String> _chartLabels = [
    'Bar',
    'Line',
    'Pie',
    'Radar',
    'Month',
    'Week',
    'Year',
  ];
  List<Map<String, dynamic>> sales = [];
  int _selectedTimeFilter = 0;
  int _selectedChartIndex = 0;
  bool loading = false;
  bool insightLoading = false;
  bool showInsight = false;
  String todayInsight = '';
  String shopName = 'My Shop';
  Uint8List? logoBytes;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _slideAnimation;
  bool isDarkMode = false;
  bool _isSidebarOpen = false;
  bool _isShopSetup = true;
  String _userName = '';

  // 🔄 BACKEND SYNC: Shop and Worker data
  Map<String, dynamic>? _shopProfile;
  List<Map<String, dynamic>> _workers = [];
  bool _workersLoaded = false;

  // 📧 Daily Summary & Shop Closing
  bool _shopClosed = false;
  DateTime? _lastDayClosing;

  // Monthly expenses tracking for net profit calculation
  DateTime? _lastClosingDate;
  bool _closedToday = false;

  // Concurrency protection flags
  bool _isSaving = false;

  // payment qr image path (saved by user)
  String? _qrImagePath;
  Uint8List? _qrImageBytes;
  bool _paymentSoundEnabled = true;
  String _paymentSoundLang = 'en-US';
  double _successPitch = 0.85;
  double _warningPitch = 1.1;
  List<Map<String, dynamic>> _pendingInvoices = [];
  double _successRate = 0.55;
  double _warningRate = 0.65;
  String? _successAudioPath;
  String? _warningAudioPath;
  String? _criticalAudioPath;
  bool _useStitchedVoice = false;
  bool _isPermissionsMissing = false;
  bool _paymentPermissionCheckComplete = false;
  bool _paymentReminderShowing = false;
  String _upiId = '';
  String _shopType = '';
  String _location = '';
  String _tagline = '';
  String _website = '';
  String _shopPhone = '';
  bool _isStaffMode = false;
  RetentionSnapshot? _retentionSnapshot;
  bool _growthOnboardingQueued = false;
  bool _isMasterPinSet = false;
  List<Map<String, dynamic>> _lowStockProducts = [];
  int _dailyHealthScore = 0;
  bool _dailyHealthScoreLoading = true;
  
  // Performance optimization: Cache today's metrics to avoid recalculation
  double? _cachedTodaySales;
  int? _cachedTodayOrders;
  int? _cachedTodayOnlineOrders; // Cache today's online orders
  int? _cachedTotalOnlineOrders; // Canonical backend total online orders
  DateTime? _lastMetricsCacheDate;
  // Soundbox & Welcome Card state
  bool _soundboxActive = false;
  bool _welcomeCardDismissed = true; // Load from prefs in initState

  bool _realtimeConnected = false;
  bool _prevRealtimeConnected = false;
  String _realtimeStatusMessage = 'Checking network...';
  Map<String, dynamic>? _liveMetrics;
  int _liveLowStockCount = 0;
  int _remarketingCount = 0;
  int _liveActiveWorkers = 0;
  List<String> _activityFeed = [];
  String _lastRealtimeNotification = '';
  Timer? _connectivityCheckTimer;

  // connectivity_plus instance and subscription for cloud sync status
  late final Connectivity _connectivity;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  // Online Store status tracking
  bool _isOnlineStoreActive = false;
  bool _onlineStoreLoading = true;
  int _onlinePendingOrders = 0;
  int _onlineTodayOrders = 0;
  double _onlineTodayRevenue = 0.0;
  int _onlinePaidCount = 0;
  int _unsyncedBillsCount = 0; // Surfaced as a persistent dashboard warning, not just used for the health score

  void _addToActivityFeed(String activity) {
    setState(() {
      _activityFeed.insert(
        0,
        '${DateTime.now().toString().substring(11, 19)}: $activity',
      );
      if (_activityFeed.length > 10) _activityFeed.removeLast();
    });
  }

  Future<void> _recomputeDailyHealthScore() async {
    try {
      final queueItems = await SyncQueueManager.getAll();
      final unsyncedBills = queueItems.where((e) {
        final action = e['action']?.toString() ?? '';
        // These actions represent “not yet committed to backend”.
        return action == 'sync_sale' ||
            action == 'save_sale' ||
            action == 'update_payment' ||
            action == 'update_invoice_paid' ||
            action == 'update_invoice_unpaid';
      }).length;

      if (mounted) setState(() => _unsyncedBillsCount = unsyncedBills);

      final dayClosed = _shopClosed || _closedToday;
      final duesPending = _pendingInvoices.isNotEmpty;
      final lowStockItems = _lowStockProducts.length;

      // 📊 Calculate sales performance metrics
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      // Filter today's and yesterday's sales
      final todaysSales = sales.where((sale) {
        try {
          final saleDate = _getLocalDate(sale);
          final saleDateOnly = DateTime(
            saleDate.year,
            saleDate.month,
            saleDate.day,
          );
          return saleDateOnly == today;
        } catch (_) {
          return false;
        }
      }).toList();

      final yesterdaysSales = sales.where((sale) {
        try {
          final saleDate = _getLocalDate(sale);
          final saleDateOnly = DateTime(
            saleDate.year,
            saleDate.month,
            saleDate.day,
          );
          return saleDateOnly == yesterday;
        } catch (_) {
          return false;
        }
      }).toList();

      // Calculate totals and counts
      double todaySalesAmount = 0;
      double yesterdaySalesAmount = 0;

      double _parseSaleAmount(Map<String, dynamic> s) {
        final raw =
            s['invoice_total'] ??
            s['total_amount'] ??
            s['total'] ??
            s['grand_total'] ??
            s['final_amount'] ??
            s['totalAmount'] ??
            s['price'];
        if (raw is num) {
          if (raw.toDouble() > 0) return raw.toDouble();
        }

        final parsed = double.tryParse(raw?.toString() ?? '') ?? 0.0;
        if (parsed > 0) return parsed;

        final price = double.tryParse(s['price']?.toString() ?? '') ?? 0.0;
        final qty = double.tryParse(s['quantity']?.toString() ?? s['qty']?.toString() ?? '1') ?? 1.0;
        return (price * qty).clamp(0.0, double.infinity);
      }

      final Set<String> processedTodayBills = {};
      for (final sale in todaysSales) {
        final billId = (sale['_bill_id'] ?? sale['invoice_number'] ?? sale['sale_id'] ?? sale['id'])?.toString().trim() ?? '';
        final invoiceKey = billId.isNotEmpty
            ? billId
            : '${sale['product_name'] ?? sale['product'] ?? sale['item'] ?? ''}_${sale['date'] ?? sale['business_date'] ?? sale['sale_date'] ?? sale['created_at'] ?? ''}';
        if (processedTodayBills.contains(invoiceKey)) continue;
        processedTodayBills.add(invoiceKey);
        todaySalesAmount += _parseSaleAmount(sale);
      }

      final Set<String> processedYesterdayBills = {};
      for (final sale in yesterdaysSales) {
        final billId = (sale['_bill_id'] ?? sale['invoice_number'] ?? sale['sale_id'] ?? sale['id'])?.toString().trim() ?? '';
        final invoiceKey = billId.isNotEmpty
            ? billId
            : '${sale['product_name'] ?? sale['product'] ?? sale['item'] ?? ''}_${sale['date'] ?? sale['business_date'] ?? sale['sale_date'] ?? sale['created_at'] ?? ''}';
        if (processedYesterdayBills.contains(invoiceKey)) continue;
        processedYesterdayBills.add(invoiceKey);
        yesterdaySalesAmount += _parseSaleAmount(sale);
      }

      final score = DailyHealthScoreService.computeScore(
        dayClosed: dayClosed,
        unsyncedBills: unsyncedBills,
        lowStockItems: lowStockItems,
        duesPending: duesPending,
        todaySalesAmount: todaySalesAmount,
        yesterdaySalesAmount: yesterdaySalesAmount,
        todayBillCount: processedTodayBills.length,
        yesterdayBillCount: processedYesterdayBills.length,
      );

      if (!mounted) return;
      setState(() {
        _dailyHealthScore = score;
        _dailyHealthScoreLoading = false;
      });
    } catch (_) {
      // Keep previous score on errors.
    }
  }

  StreamSubscription<dynamic>? _paymentSubscription;
  StreamSubscription? _syncSubscription;

  DateTime _getLocalDate(Map<String, dynamic> sale) {
    final dateStr = (sale['business_date'] ?? sale['sale_date'] ?? sale['invoice_date'] ?? sale['date'] ?? sale['created_at'] ?? sale['createdAt'])?.toString().trim() ?? '';
    if (dateStr.isEmpty) return DateTime(1970);

    try {
      if (RegExp(r'^\d{4}-\d{2}-\d{2}\$').hasMatch(dateStr)) {
        return DateTime.parse(dateStr);
      }

      final parsed = DateTime.parse(dateStr);
      final hasExplicitZone = dateStr.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}\$').hasMatch(dateStr);
      return hasExplicitZone ? parsed.toLocal() : DateTime(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute, parsed.second, parsed.millisecond, parsed.microsecond);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Invalid sale date format: $dateStr');
      return DateTime(1970);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize connectivity instance
    _connectivity = Connectivity();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Persistent payment-detection CTA pulse. This animation only runs while
    // required permissions are missing; it stops immediately once both are
    // granted so the Dashboard does not waste resources while healthy.
    _paymentDetectionPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _paymentDetectionPulse = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _paymentDetectionPulseController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<double>(begin: 0.05, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuad),
    );
    _animationController.forward();
    _scrollController = ScrollController();
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _loadSales(),
    );
    // FIX BUG 6 — listen for inventory changes and reload analytics
    InventoryManagementService.onInventoryChanged = () {
      if (mounted) _loadSales();
    };
    // Defer all heavy loads to after the first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await Future.wait<dynamic>([
        _loadDailyInsightFromPrefs(),
        _loadSales(),
        _loadQr(),
        _checkPaymentsConfig(),
        _checkPermissions(),
        _replayBackgroundSms(),
        _showOnboardingIfNeeded(),
        _connectRealtime(),
        _loadWelcomeCardState(),
        _checkSoundboxStatus(),
        _loadOnlineStoreStatus(),
        (() async {
          try {
            final prefs = await SharedPreferences.getInstance();
            final userId = prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0;
            if (userId > 0) {
              if (kDebugMode) debugPrint('🔄 Fetching shop profile from backend first...');
              await _fetchShopProfileFromBackend(userId);
            }
          } catch (e) {
            if (kDebugMode) debugPrint('Error fetching shop profile: $e');
          }
        })(),
        (() async {
          try {
            if (kDebugMode) debugPrint('🔄 Fetching workers from backend first...');
            await _fetchWorkersFromBackend();
          } catch (e) {}
        })(),
        (() async {
          await _loadShopAndWorkerDataLocally();
        })(),
      ].map((future) => future.catchError((_) => null)));

      // 🔒 SECURITY: Use scoped SharedPreferences for staff mode check
      final scopedPrefsCheck = await ScopedSharedPreferences.getBool('is_staff_mode');
      if (!mounted) return;
      if (!(scopedPrefsCheck ?? false) && !kIsWeb) {
        await SecurityService.enforceBiometricLoginRequiresVerification();
        if (mounted && await SecurityService.shouldShowOwnerBiometricGate()) {
          Navigator.of(context).pushReplacementNamed('/owner-biometric-register');
        }
      }
    });

    // Listen for payment detections
    _paymentSubscription = PaymentDetectionService().onPaymentDetected.listen((
      event,
    ) {
      if (mounted) {
        final activity =
            'Payment: ₹${event.amount.toStringAsFixed(0)} via ${event.appDisplayName}';
        _addToActivityFeed(activity);
        _showRealtimeNotification('Payment Received', activity, true);
        try {
          context.read<PaymentStateNotifier>().addPayment(event);
        } catch (e) {
          if (kDebugMode) debugPrint('Provider error: $e');
        }
      }
    });

    // 🚀 100/100 Real-Time Sync: React to background pulse updates
    _syncSubscription = SyncService.refreshStream.listen((_) {
      if (mounted) {
        _loadSales(); // Auto-refresh UI when clouds sync in background
        _addToActivityFeed('Cloud Sync: UI updated');
      }
    });

    RetailGrowthKit.recordAppOpen();
  }

  Future<void> _checkPermissions({bool showReminderIfMissing = true}) async {
    // IMPORTANT:
    // This method ONLY CHECKS permission state.
    // It must never block billing by automatically opening Android permission dialogs.
    bool notifGranted = false;
    bool smsGranted = false;

    try {
      notifGranted = await NotificationListenerService.isPermissionGranted();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Notification permission check failed: $e');
    }

    try {
      smsGranted = (await Permission.sms.status).isGranted;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ SMS permission check failed: $e');
    }

    if (!mounted) return;

    final missing = !(notifGranted && smsGranted);

    setState(() {
      _isPermissionsMissing = missing;
      _paymentPermissionCheckComplete = true;
    });

    if (missing) {
      // Keep the persistent Dashboard CTA animated until Android reports that
      // every required permission is actually enabled.
      if (!_paymentDetectionPulseController.isAnimating) {
        _paymentDetectionPulseController.repeat(reverse: true);
      }
      // Intentionally do not open a blocking dialog here. The Dashboard card
      // is the single persistent reminder and remains usable for billing.
      return;
    }

    // All required permissions are now enabled. Stop the reminder animation
    // and start the payment-detection channels.
    _paymentDetectionPulseController.stop();
    _paymentDetectionPulseController.value = 1.0;

    try {
      // This only starts channels on the UI isolate's own
      // PaymentDetectionService instance (a no-op today since that
      // instance's .start() is never called on this isolate). The real,
      // long-lived detection engine runs in the separate background
      // service isolate (payment_background_service_mobile.dart), which
      // has its own independent instance and does not know permissions
      // just changed. Tell it explicitly to restart so it re-attaches its
      // notification/SMS listeners with the now-granted permissions.
      await PaymentDetectionService().ensureChannelsRunning();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Payment detection channel startup failed: $e');
      }
    }

    try {
      FlutterBackgroundService().invoke('restart_payment_detection');
      if (kDebugMode) {
        debugPrint('🔁 Signaled background isolate to restart payment detection');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to signal background service restart: $e');
      }
    }

    // FIX (critical): the restart signal above only re-attaches listeners —
    // it does nothing to stop Android from killing the background isolate
    // once the app is backgrounded, because the service was never promoted
    // to a real foreground service. Request POST_NOTIFICATIONS (required
    // for foreground mode on Android 13+) and battery-optimization
    // exemption (OEMs like Xiaomi/Oppo/Vivo/Samsung kill background
    // processes even in foreground mode unless whitelisted) here, then
    // promote the service now that both should be granted.
    try {
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        await Permission.notification.request();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ POST_NOTIFICATIONS request failed: $e');
    }

    try {
      final batteryOk = await PaymentDetectionService.isBatteryOptimizationIgnored();
      if (!batteryOk) {
        await PaymentDetectionService.requestBatteryExemption();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Battery exemption request failed: $e');
    }

    try {
      FlutterBackgroundService().invoke('setAsForeground');
      if (kDebugMode) {
        debugPrint('⬆️ Signaled background isolate to promote to foreground service');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to signal foreground promotion: $e');
      }
    }
  }

  Future<void> _schedulePaymentDetectionReminder() async {
    if (!mounted || !_isPermissionsMissing || _paymentReminderShowing) return;

    // Let the Dashboard paint before showing the reminder so the user can
    // continue using sales/billing normally even when permissions are missing.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || !_isPermissionsMissing || _paymentReminderShowing) return;

    _paymentReminderShowing = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
          contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFFDC2626),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Payment Detection is Disabled',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This is a core RETAIL MIND feature. Enable it to automatically detect eligible UPI and bank payment confirmations.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF374151),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              _buildPaymentPermissionStatusRow(
                'Notification Access',
                Icons.notifications_rounded,
                NotificationListenerService.isPermissionGranted(),
              ),
              const SizedBox(height: 8),
              _buildPaymentPermissionStatusRow(
                'SMS Access',
                Icons.sms_rounded,
                Permission.sms.status.then((s) => s.isGranted),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  'You can keep recording sales and billing even if this is not enabled. We will remind you again when you return to the Dashboard or resume the app.',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: const Color(0xFF991B1B),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'LATER',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await NotificationListenerService.requestPermission();
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('⚠️ Notification permission request failed: $e');
                  }
                }

                try {
                  final status = await Permission.sms.request();
                  if (kDebugMode) {
                    debugPrint('📱 SMS permission request result: $status');
                  }
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('⚠️ SMS permission request failed: $e');
                  }
                }

                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }

                // Re-check actual OS state after returning from permission flow.
                await Future<void>.delayed(const Duration(milliseconds: 500));
                await _checkPermissions(showReminderIfMissing: false);

                if (mounted && _isPermissionsMissing) {
                  // Still missing -> keep the red Dashboard card and remind again
                  // on the next Dashboard entry/resume.
                  _schedulePaymentDetectionReminder();
                }
              },
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: Text(
                'ENABLE PAYMENT DETECTION',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ],
        );
      },
    );

    _paymentReminderShowing = false;

    // If the dialog was dismissed without enabling permissions, keep the
    // Dashboard card visible. The next Dashboard/resume check will show it again.
  }

  Widget _buildPaymentPermissionStatusRow(
    String label,
    IconData icon,
    Future<bool> permissionFuture,
  ) {
    return FutureBuilder<bool>(
      future: permissionFuture,
      builder: (context, snapshot) {
        final granted = snapshot.data == true;
        final color = granted
            ? const Color(0xFF10B981)
            : const Color(0xFFEF4444);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: granted
                ? const Color(0xFFECFDF5)
                : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: granted
                  ? const Color(0xFFA7F3D0)
                  : const Color(0xFFFECACA),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ),
              ),
              Icon(
                granted ? Icons.check_circle_rounded : Icons.error_rounded,
                size: 17,
                color: color,
              ),
              const SizedBox(width: 5),
              Text(
                granted ? 'Enabled' : 'Required',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 🔄 BACKEND SYNC: Fetch workers from backend
  Future<void> _fetchWorkersFromBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0;

      if (userId <= 0) return;

      final response = await ApiClient.getJson(
        '/api/attendance/workers?user_id=$userId',
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && mounted) {
        final workersData = json.decode(response.body);
        if (workersData is List) {
          // 🔒 SECURITY: Save to scoped local storage to prevent data leakage
          await ScopedSharedPreferences.setString('workers_json', json.encode(workersData));

          setState(() {
            _workers = List<Map<String, dynamic>>.from(
              workersData.map((w) => w is Map ? w : {}),
            );
            _workersLoaded = true;
          });

          if (kDebugMode) {
            debugPrint('✅ Fetched ${_workers.length} workers from backend (scoped)');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to fetch workers: $e');
      }
    }
  }

  /// 📱 Load shop profile and workers from local storage if available
  Future<void> _loadShopAndWorkerDataLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 🔐 SECURITY: Verify user_id hasn't changed (prevent data leakage across accounts)
      final currentUserId =
          prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0;
      final cachedUserId = prefs.getInt('last_loaded_user_id') ?? 0;

      if (currentUserId > 0 &&
          cachedUserId > 0 &&
          currentUserId != cachedUserId) {
        if (kDebugMode)
          debugPrint(
            '⚠️ User ID changed ($cachedUserId → $currentUserId), clearing cached shop data',
          );
        // Different user - clear shop data to prevent leakage
        await ScopedSharedPreferences.remove('shop_profile_json');
        await ScopedSharedPreferences.remove('workers_json');
        await ScopedSharedPreferences.remove('shop_name');
        return;
      }

      // Remember which user this cache belongs to
      if (currentUserId > 0) {
        await prefs.setInt('last_loaded_user_id', currentUserId);
      }

      // Load shop profile JSON
      final shopJson = await ScopedSharedPreferences.getString('shop_profile_json');
      if (shopJson != null && mounted) {
        try {
          setState(() {
            _shopProfile = json.decode(shopJson);
          });
        } catch (_) {}
      }

      // Load workers JSON
      // FIX: written via ScopedSharedPreferences (line ~505 below), which
      // stores under 'user_<id>_workers_json' — reading the raw key here
      // was a self-inconsistent no-op.
      final workersJson = await ScopedSharedPreferences.getString('workers_json');
      if (workersJson != null && mounted) {
        try {
          final parsed = json.decode(workersJson);
          if (parsed is List) {
            setState(() {
              _workers = List<Map<String, dynamic>>.from(
                parsed.map((w) => w is Map ? w : {}),
              );
              _workersLoaded = true;
            });
          }
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading local shop/worker data: $e');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSales();
      (() async {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0;
        if (userId > 0) {
          _fetchShopProfileFromBackend(
            userId,
          ); // Sync shop profile when app resumes
        }
        // 🔧 FIX: Refresh session when app resumes
        try {
          final tokenValid = await SessionManagementService.isTokenValid();
          if (!tokenValid) {
            if (kDebugMode) debugPrint('🔐 Dashboard: Token invalid, attempting auto-login');
            await SessionManagementService.autoLogin();
          }
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Dashboard session refresh error: $e');
        }
      })();
      _fetchWorkersFromBackend(); // Sync workers when app resumes
      _connectRealtime();
      _checkPermissions();
      _replayBackgroundSms();
    } else if (state == AppLifecycleState.detached) {
      // Do nothing on detached to prevent Hive initialization crashes when app resumes
    }
  }

  Future<void> _showOnboardingIfNeeded() async {
    final isFirst = await TutorialService.isFirstTimeUser();
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // Safety: If we have an auth token, we are NOT a new user. Auto-complete onboarding.
    final token = await SecureTokenStorage.getToken();
    final hasToken = (token ?? '').isNotEmpty;
    if (hasToken && isFirst) {
      await TutorialService.completeOnboarding();
      return;
    }

    if (!isFirst) return;

    // Delay slightly to ensure UI is ready
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _showOnboardingDialog();
    });
  }

  void _showOnboardingDialog() {
    final steps = TutorialService.getOnboardingSteps();
    int currentStep = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 40,
          ),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Illustration/Icon
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      steps[currentStep].icon,
                      style: const TextStyle(fontSize: 110),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    children: [
                      Text(
                        steps[currentStep].title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        steps[currentStep].description,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Details list
                      ...steps[currentStep].details
                          .map(
                            (detail) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    semanticLabel: 'Check Circle Rounded',
                                    color: AppColors.secondary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      detail,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ],
                  ),
                ),
                // Footer Navigation
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      // Progress dots
                      Row(
                        children: List.generate(
                          steps.length,
                          (index) => Container(
                            width: index == currentStep ? 20 : 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: index == currentStep
                                  ? AppColors.primary
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (currentStep < steps.length - 1)
                        ElevatedButton(
                          onPressed: () => setModalState(() => currentStep++),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            'Next',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        ElevatedButton(
                          onPressed: () {
                            TutorialService.completeOnboarding();
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            'Get Started',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _replayBackgroundSms() async {
    final smsList = await getPendingBackgroundSms();
    for (final sms in smsList) {
      PaymentDetectionService().handleSms(
        sms['sender']?.toString() ?? '',
        sms['body']?.toString() ?? '',
      );
    }
  }

  Future<void> _checkPaymentsConfig() async {
    // Passive health check only. The Dashboard's persistent payment-detection
    // card is the single reminder; do not show a blocking dialog automatically.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    await _checkPermissions(showReminderIfMissing: false);
  }

  Future<void> _loadOnlineStoreStatus() async {
    try {
      // ⚡ INSTANT: Show cached value immediately so UI isn't stuck on loading
      final prefs = await SharedPreferences.getInstance();
      final cachedStatus = prefs.getBool('online_store_active') ?? false;
      if (mounted) {
        setState(() {
          _isOnlineStoreActive = cachedStatus;
          _onlineStoreLoading = false;
        });
        if (cachedStatus) {
          _loadOnlineStoreStats();
        }
      }

      // 🔄 BACKGROUND: Silently refresh from backend (doesn't block UI)
      try {
        final isPublished = await OnlineStoreService.getShopOnlineStatus();
        // Only update if value changed (avoid unnecessary rebuilds)
        if (mounted && isPublished != cachedStatus) {
          setState(() => _isOnlineStoreActive = isPublished);
          // 🔒 SECURITY: Also persist the fresh value locally (scoped)
          await ScopedSharedPreferences.setBool('online_store_active', isPublished);
          if (isPublished) {
            _loadOnlineStoreStats();
          }
        }
        if (kDebugMode) debugPrint('✅ Online store status refreshed from backend: $isPublished');
      } catch (e) {
        // Backend fetch failed — cached value already shown, no action needed
        if (kDebugMode) debugPrint('⚠️ Backend online store check failed (using cached): $e');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to load online store status: $e');
      if (mounted) setState(() => _onlineStoreLoading = false);
    }
  }

  Future<void> _loadOnlineStoreStats() async {
    // Online-order KPIs are business data, not a UI/store-publication flag.
    // Always reconcile them so existing orders cannot appear as zero merely
    // because the store toggle/cache is stale.

    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = (prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0).toString();
      final metrics = await OnlineOrderService.getAnalytics(shopId);
      if (!mounted) return;
      setState(() {
        _onlinePendingOrders = (metrics['pending'] as num?)?.toInt() ?? 0;
        _onlineTodayOrders = (metrics['todayCount'] as num?)?.toInt() ?? 0;
        _onlineTodayRevenue = (metrics['todayRevenue'] as num?)?.toDouble() ?? 0.0;
        _onlinePaidCount = (metrics['paidCount'] as num?)?.toInt() ?? 0;
        _cachedTodayOnlineOrders = _onlineTodayOrders;
        _cachedTotalOnlineOrders = (metrics['totalCount'] as num?)?.toInt() ?? 0;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to load online stats: $e');
    }
  }

  Future<void> _toggleOnlineStore(bool enable) async {
    setState(() {
      _onlineStoreLoading = true;
    });
    try {
      final result = await OnlineStoreService.setShopOnlineStatus(enable);
      final prefs = await SharedPreferences.getInstance();
      if (result['success'] == true) {
        setState(() {
          _isOnlineStoreActive = enable;
          _onlineStoreLoading = false;
        });
        // 🔒 SECURITY: Persist with scoped SharedPreferences
        await ScopedSharedPreferences.setBool('online_store_active', enable);
        await ScopedSharedPreferences.setBool('shop_published_online', enable);
        
        if (enable) {
          _loadOnlineStoreStats();
        } else {
          setState(() {
            _onlinePendingOrders = 0;
            _onlineTodayOrders = 0;
            _onlineTodayRevenue = 0.0;
            _onlinePaidCount = 0;
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(enable 
                ? '✅ Online Store enabled! Customers can find you nearby.' 
                : '✅ Online Store disabled.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _onlineStoreLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update status: ${result['error'] ?? "Unknown error"}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _onlineStoreLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildOnlineStoreStatusCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isOnlineStoreActive) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.storefront_rounded, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Online Store is Live',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_onlineStoreLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Switch.adaptive(
                      value: _isOnlineStoreActive,
                      activeColor: Colors.green,
                      onChanged: (val) => _toggleOnlineStore(val),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          OnlineAnalyticsCard(
            pendingOrders: _onlinePendingOrders,
            todayOrderCount: _onlineTodayOrders,
            todayRevenue: _onlineTodayRevenue,
            paidCount: _onlinePaidCount,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OnlineStoreHubPage()),
              ).then((_) => _loadOnlineStoreStatus());
            },
          ),
        ],
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF312E81), const Color(0xFF4C1D95)]
                : [const Color(0xFFEEF2FF), const Color(0xFFF5F3FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? const Color(0xFF4F46E5).withValues(alpha: 0.4)
                : const Color(0xFFC7D2FE).withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.15 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Color(0xFF4F46E5),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sell Products Online',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Start accepting online orders',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_onlineStoreLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch.adaptive(
                    value: _isOnlineStoreActive,
                    activeColor: Colors.green,
                    onChanged: (val) => _toggleOnlineStore(val),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Publish your product catalog online, let customers find your shop on the map, and process WhatsApp/Web orders directly.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? Colors.grey[300] : const Color(0xFF4B5563),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OnlineStoreManagerPage(),
                    ),
                  ).then((_) => _loadOnlineStoreStatus());
                },
                icon: const Icon(Icons.settings, size: 18),
                label: Text(
                  'Configure Online Store',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
  
  Future<void> _loadDailyInsightFromPrefs() async {
    // Skip loading cached data - always compute fresh from sales
    // This ensures we get latest data, not stale cached values
    return;
  }

  Future<bool> _fetchInvoicesFromBackend() async {
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) return false;
      
      final List<dynamic> allItems = [];
      
      // 1. Fetch sales from /auth/sales
      // Canonical cloud source: invoices. The legacy /auth/sales line-item feed
      // is intentionally not merged here because it can represent the same bill
      // a second time and corrupt dashboard totals/customer history.
      // 2. Fetch invoices from /api/invoices
      try {
        final invoicesRes = await ApiClient.getJson(
          ApiClient.invoicesList,
          headers: {'Authorization': 'Bearer $token'},
        );
        if (invoicesRes.statusCode == 200) {
          final invoiceData = json.decode(invoicesRes.body);
          // Handle both formats: list directly or inside {'invoices': [...]}
          if (invoiceData is List) {
            allItems.addAll(invoiceData);
          } else if (invoiceData is Map && invoiceData.containsKey('invoices')) {
            allItems.addAll(invoiceData['invoices'] as List);
          } else if (invoiceData is Map && invoiceData.containsKey('results')) {
            allItems.addAll(invoiceData['results'] as List);
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Failed to fetch invoices: $e');
      }

      if (allItems.isEmpty) return false;
      
      final List<dynamic> currentLocal = await LocalStorageService.loadSales();
      final Set<String> existingIds = currentLocal.map((e) => e['sale_id'].toString()).toSet();
      bool added = false;
      
      // Group by sale_id/invoice_number
      final Map<String, List<dynamic>> grouped = {};
      for (var item in allItems) {
        final id = item['sale_id']?.toString() ?? item['invoice_number']?.toString();
        if (id == null) continue;
        if (!grouped.containsKey(id)) {
          grouped[id] = [];
        }
        grouped[id]!.add(item);
      }

      for (var entry in grouped.entries) {
        final id = entry.key;
        final items = entry.value;
        if (!existingIds.contains(id)) {
          final firstItem = items.first;
          // Get line items (handle both line_items and items keys)
          // 🔧 FIX: previously this fell back to `items` (the raw grouped
          // invoice-level records for this id) when neither firstItem
          // ['line_items'] nor firstItem['items'] existed — e.g. for borrow
          // invoices, which store a flat 'product' string, not a nested
          // line-items array. That fallback then ran the invoice records
          // themselves through the line-item mapper below, which has no
          // 'product_name'/'price' keys to read, so every default fired:
          // product_name -> 'Product', price -> 0, and this phantom record
          // got permanently saved as a duplicate "sale". Only treat a real
          // line-items array as line items; otherwise synthesize a single
          // line item from the invoice's own total/product fields.
          final rawLineItemsField = firstItem['line_items'] ?? firstItem['items'];
          final List rawLineItems;
          if (rawLineItemsField is List && rawLineItemsField.isNotEmpty) {
            rawLineItems = rawLineItemsField;
          } else {
            final fallbackTotal = firstItem['total_amount'] ??
                firstItem['total'] ??
                firstItem['grand_total'] ??
                firstItem['invoice_total'] ??
                0;
            rawLineItems = [
              {
                'product_name': (firstItem['product'] ?? firstItem['product_name'] ?? 'Invoice').toString(),
                'price': fallbackTotal,
                'quantity': 1,
                'total': fallbackTotal,
              }
            ];
          }
          final processedItems = rawLineItems.map((s) {
            final rawName = (s['product_name'] ?? s['product'] ?? s['name'] ?? s['description'] ?? '').toString().trim();
            final displayName = rawName.isEmpty || rawName.toLowerCase() == 'product'
                ? 'Unknown Product'
                : AnalyticsEngine.formatProductName(rawName);
            return {
              'product_id': s['product_id'] ?? s['id'],
              'product_name': displayName,
              'product': displayName,
              'price': s['price'] ?? s['unit_price'] ?? 0,
              'quantity': s['quantity'] ?? s['qty'] ?? 1,
              'total': s['total'] ?? s['line_total'] ?? 0,
            };
          }).toList();

          currentLocal.add({
            'sale_id': id,
            'invoice_number': id,
            'date': firstItem['date'] ?? firstItem['created_at'] ?? firstItem['invoice_date'],
            'items': processedItems,
            'customer_name': firstItem['customer_name'] ?? '',
            'customer_phone': firstItem['customer_phone'] ?? '',
            'total': firstItem['totalAmount']?.toString() ?? firstItem['total']?.toString() ?? firstItem['total_amount']?.toString(),
            'payment_method': firstItem['payment_method'] ?? 'CASH',
            'payment_status': firstItem['payment_status'] ?? 'PAID',
            'sync_status': 'synced',
          });
          added = true;
        }
      }

      if (added) {
        await LocalStorageService.saveSales(currentLocal);
      }

      // #region agent log
      AgentDebugLog.log(
        location: 'dashboard_page.dart:_fetchInvoicesFromBackend',
        message: 'BACKEND FETCH MERGE',
        hypothesisId: 'H4',
        data: {
          'apiItemCount': allItems.length,
          'groupedBills': grouped.length,
          'addedNewBills': added,
        },
      );
      // #endregion

      return added;
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to fetch sales/invoices: $e');
      return false;
    }
  }

  /// 🔄 BACKEND SYNC: Fetch shop profile from backend and update local storage
  /// This ensures shop details are always synchronized with the backend
  Future<void> _fetchShopProfileFromBackend(int userId) async {
    if (userId <= 0) return;

    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      final response = await ApiClient.getJson(
        '${ApiClient.shopProfile}?user_id=$userId',
        headers: token.isNotEmpty ? {'Authorization': 'Bearer $token'} : null,
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        if (data['profile'] != null) {
          final profile = data['profile'];
          final prefs = await SharedPreferences.getInstance();

          // 🔒 SECURITY: Save shop profile fields to scoped SharedPreferences for quick access
          if (profile['shop_name'] != null) {
            await ScopedSharedPreferences.setString('shop_name', profile['shop_name'].toString());
          }
          if (profile['location'] != null) {
            await ScopedSharedPreferences.setString('location', profile['location'].toString());
          }
          if (profile['phone_number'] != null) {
            await ScopedSharedPreferences.setString(
              'shop_phone',
              profile['phone_number'].toString(),
            );
          }
          if (profile['email'] != null) {
            await ScopedSharedPreferences.setString('shop_email', profile['email'].toString());
          }
          if (profile['logo_url'] != null &&
              profile['logo_url'].toString().isNotEmpty) {
            await ScopedSharedPreferences.setString(
              'shop_logo_url',
              profile['logo_url'].toString(),
            );
          }

          // 🔒 SECURITY: Save full profile as JSON for detailed dashboard use (scoped)
          await ScopedSharedPreferences.setString('shop_profile_json', json.encode(profile));

          // Update UI if shop name changed
          if (mounted && (profile['shop_name'] ?? '').toString().isNotEmpty) {
            setState(() {
              shopName = profile['shop_name'].toString();
              _isShopSetup = shopName.isNotEmpty && shopName != 'AI Shop Pro';
            });
          }

          if (kDebugMode) {
            debugPrint(
              '✅ Shop profile synced from backend: ${profile['shop_name']}',
            );
          }
        }
      }
    } catch (e) {
      // Backend fetch failed - continue with local data
      if (kDebugMode) {
        debugPrint('⚠️ Failed to fetch shop profile from backend: $e');
      }
    }
  }

  Future<void> _loadQr() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // 🔒 SECURITY FIX: Load payment QR from encrypted SecureStorage, not SharedPreferences
    final b64 = await SecurePreferencesService.getPaymentQrB64();
    if (b64 != null && b64.isNotEmpty) {
      setState(() => _qrImageBytes = base64Decode(b64));
    }

    // 🔒 SECURITY FIX: Load UPI ID and Master PIN status from encrypted SecureStorage
    final upiId = await SecurePreferencesService.getUpiId();
    final isMasterPinSet = await SecurePreferencesService.isMasterPinSet();

    setState(() {
      _paymentSoundEnabled = prefs.getBool('payment_sound_enabled') ?? true;
      _paymentSoundLang = prefs.getString('payment_sound_lang') ?? 'en-US';
      _successPitch = prefs.getDouble('pds_success_pitch') ?? 0.85;
      _warningPitch = prefs.getDouble('pds_warning_pitch') ?? 1.1;
      _successRate = prefs.getDouble('pds_success_rate') ?? 0.55;
      _warningRate = prefs.getDouble('pds_warning_rate') ?? 0.75;
      _successAudioPath = prefs.getString('pds_success_audio');
      _warningAudioPath = prefs.getString('pds_warning_audio');
      _criticalAudioPath = prefs.getString('pds_critical_audio');
      _useStitchedVoice = prefs.getBool('pds_use_stitched') ?? false;
      _upiId = upiId ?? '';
      _shopType = prefs.getString('shop_type') ?? '';
      _location = prefs.getString('location') ?? '';
      _tagline = prefs.getString('tagline') ?? '';
      _website = prefs.getString('website') ?? '';
      _shopPhone =
          prefs.getString('shop_phone') ?? prefs.getString('phone') ?? '';
      _isMasterPinSet = isMasterPinSet;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // FIX BUG 11 — always cancel timer and null it to prevent ghost calls
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _connectivityCheckTimer?.cancel();
    _connectivityCheckTimer = null;
    // FIX BUG 6 cleanup — detach inventory observer
    InventoryManagementService.onInventoryChanged = null;
    _animationController.dispose();
    _paymentDetectionPulseController.dispose();
    _scrollController.dispose();
    // Clear analytics engine cache to prevent memory leak
    engine.sales.clear();
    _paymentSubscription?.cancel();
    _syncSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<bool> _checkActualInternetConnectivity() async {
    try {
      // 🔧 IMPROVED: Try multiple DNS servers for better reliability
      // Try Google DNS first (8.8.8.8)
      try {
        final result = await InternetAddress.lookup(
          '8.8.8.8',
          type: InternetAddressType.IPv4,
        ).timeout(const Duration(seconds: 3));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          return true;
        }
      } catch (_) {
        // Google DNS failed, try Cloudflare (1.1.1.1)
        try {
          final result = await InternetAddress.lookup(
            '1.1.1.1',
            type: InternetAddressType.IPv4,
          ).timeout(const Duration(seconds: 3));
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            return true;
          }
        } catch (_) {
          // Cloudflare failed, try Quad9 (9.9.9.9)
          try {
            final result = await InternetAddress.lookup(
              '9.9.9.9',
              type: InternetAddressType.IPv4,
            ).timeout(const Duration(seconds: 3));
            return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
          } catch (_) {
            // All DNS lookups failed, default to checking connectivity.checkConnectivity()
            final conn = await _connectivity.checkConnectivity();
            return conn != ConnectivityResult.none;
          }
        }
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('Internet check error: $e');
      // On error, assume connected if network is available
      final conn = await _connectivity.checkConnectivity();
      return conn != ConnectivityResult.none;
    }
  }

  // ── Welcome Card ─────────────────────────────────────────────────────────
  Future<void> _loadWelcomeCardState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool('welcome_card_dismissed') ?? false;
      if (mounted) setState(() => _welcomeCardDismissed = dismissed);
    } catch (_) {}
  }

  Future<void> _dismissWelcomeCard() async {
    // 🔒 SECURITY: Use scoped SharedPreferences
    await ScopedSharedPreferences.setBool('welcome_card_dismissed', true);
    if (mounted) setState(() => _welcomeCardDismissed = true);
  }

  // ── Soundbox Status ───────────────────────────────────────────────────────
  Future<void> _checkSoundboxStatus() async {
    try {
      final granted = await PaymentDetectionService.hasNotificationPermission();
      if (mounted) setState(() => _soundboxActive = granted);
    } catch (_) {
      if (mounted) setState(() => _soundboxActive = false);
    }
  }

  // ── First-Time Welcome Card Widget ────────────────────────────────────────
  Widget _buildWelcomeCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.waving_hand_rounded,
                    semanticLabel: 'Waving Hand Rounded',
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Shop Pro కి స్వాగతం! 👋',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Welcome! Start with these 3 quick actions:',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _dismissWelcomeCard,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      semanticLabel: 'Close Rounded',
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildWelcomeAction(
                    icon: Icons.receipt_long_rounded,
                    label: 'బిల్లు చేయి\nNew Bill',
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/sales-entry',
                    ).then((_) => _loadSales()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildWelcomeAction(
                    icon: Icons.currency_rupee_rounded,
                    label: 'నేటి సంపాదన\nToday Money',
                    onTap: () => _showDailyClosingSheet(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildWelcomeAction(
                    icon: Icons.inventory_2_rounded,
                    label: 'స్టాక్ చూడు\nCheck Stock',
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/inventory',
                    ).then((_) => _loadSales()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Soundbox Status Chip ──────────────────────────────────────────────────
  Widget _buildSoundboxStatusChip() {
    final isActive = _soundboxActive;
    return GestureDetector(
      onTap: () async {
        if (!isActive) {
          await PaymentDetectionService.openNotificationSettings();
          await Future<void>.delayed(const Duration(seconds: 1));
          _checkSoundboxStatus();
        } else {
          // Test the soundbox — speaks a test payment
          PaymentAnnouncementService().speakSimple(
            'రూపాయలు వచ్చాయి! Test OK.',
            'te-IN',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🔊 Soundbox test — listen for the voice!'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF10B981).withValues(alpha: 0.12)
              : const Color(0xFFEF4444).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                : const Color(0xFFEF4444).withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isActive ? 'Soundbox ON' : 'Soundbox OFF',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isActive ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              size: 13,
              color: isActive
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
            ),
          ],
        ),
      ),
    );
  }

  // ── Monetization Banner ───────────────────────────────────────────────────

  Future<void> _connectRealtime() async {
    try {
      // Check initial connectivity - returns single result
      final result = await _connectivity.checkConnectivity();
      await _handleConnectivityChange(result);

      // Listen to connectivity changes - stream emits single result
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
        result,
      ) async {
        if (mounted) await _handleConnectivityChange(result);
      });

      // Also run periodic internet checks (every 10 seconds) to catch WiFi-without-internet cases
      _connectivityCheckTimer = Timer.periodic(const Duration(seconds: 10), (
        _,
      ) async {
        if (mounted) {
          final hasInternet = await _checkActualInternetConnectivity();
          if (hasInternet != _realtimeConnected) {
            // Only re-check if changed
            final result = await _connectivity.checkConnectivity();
            await _handleConnectivityChange(result);
          }
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Connectivity check error: $e');
    }
  }

  Future<void> _handleConnectivityChange(ConnectivityResult result) async {
    if (!mounted) return;

    // First check network connection
    final hasNetworkConnection = result != ConnectivityResult.none;

    // Then verify actual internet connectivity if network is available
    bool isConnected = false;
    if (hasNetworkConnection) {
      isConnected = await _checkActualInternetConnectivity();
    }

    // Show notification when disconnected
    if (_prevRealtimeConnected && !isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ No internet - Cloud sync paused'),
          backgroundColor: Colors.red[600],
          duration: const Duration(seconds: 4),
        ),
      );
    }

    setState(() {
      _realtimeConnected = isConnected;
      _prevRealtimeConnected = isConnected;
      if (isConnected) {
        if (result == ConnectivityResult.wifi) {
          _realtimeStatusMessage = 'Connected via WiFi';
        } else if (result == ConnectivityResult.mobile) {
          _realtimeStatusMessage = 'Connected via Mobile Data';
        } else {
          _realtimeStatusMessage = 'Cloud Sync Active';
        }
      } else {
        _realtimeStatusMessage = 'Cloud Sync Offline';
      }
    });
  }

  void _handleRealtimeMessage(Map<String, dynamic> payload) {
    if (!mounted) return;

    final type = payload['type']?.toString() ?? '';
    switch (type) {
      case 'metrics_update':
        final data = Map<String, dynamic>.from(payload['data'] ?? {});
        setState(() {
          _liveMetrics = data;
          _liveLowStockCount = 0;
          _liveActiveWorkers = 0;
          _lastRealtimeNotification = 'Metrics updated';
        });
        break;
      case 'sales_update':
        final salesList = payload['data'] as List<dynamic>?;
        if (salesList != null && salesList.isNotEmpty) {
          final sale = salesList.first;
          final activity =
              'Sale: ₹${sale['total']?.toStringAsFixed(0) ?? '0'} - ${sale['product'] ?? 'Unknown'}';
          setState(() {
            _lastRealtimeNotification = activity;
          });
          _addToActivityFeed(activity);
          _showRealtimeNotification('New Sale', activity, true);
        }
        break;
      case 'inventory_update':
        final inventoryData = payload['data'] as List<dynamic>?;
        setState(() {
          _liveLowStockCount = inventoryData?.length ?? 0;
          _lastRealtimeNotification = 'Inventory refreshed';
        });
        if (inventoryData != null && inventoryData.isNotEmpty) {
          _showRealtimeNotification(
            'Low Stock Alert',
            '${inventoryData.first['name']} is low (${inventoryData.first['current_stock']})',
            false,
          );
        }
        break;
      case 'worker_status':
        final workers = payload['data'] as List<dynamic>?;
        setState(() {
          _liveActiveWorkers = workers?.length ?? 0;
          _lastRealtimeNotification = 'Worker status refreshed';
        });
        break;
      case 'pong':
        setState(() {
          _lastRealtimeNotification = 'Heartbeat received';
        });
        break;
      case 'new_sale':
      case 'payment_received':
        setState(() {
          _lastRealtimeNotification =
              payload['message']?.toString() ?? 'Realtime event';
        });
        _showRealtimeNotification(
          'Payment Received',
          payload['message']?.toString() ?? 'Payment processed',
          true,
        );
        break;
      case 'stock_alert':
        setState(() {
          _lastRealtimeNotification =
              payload['message']?.toString() ?? 'Stock alert';
        });
        _showRealtimeNotification(
          'Stock Alert',
          payload['message']?.toString() ?? 'Low stock warning',
          false,
        );
        break;
      default:
        break;
    }
  }

  void _showRealtimeNotification(
    String title,
    String body,
    bool isPositive,
  ) async {
    // Show local notification
    await NotificationService.showNotification(
      title: title,
      body: body,
      payload: 'realtime',
    );

    // Play sound if enabled
    if (_paymentSoundEnabled) {
      try {
        final player = AudioPlayer();
        if (isPositive) {
          if (_successAudioPath != null) {
            await player.play(DeviceFileSource(_successAudioPath!));
          } else {
            await player.play(
              AssetSource('sounds/success.mp3'),
            ); // Assume asset exists
          }
        } else {
          if (_warningAudioPath != null) {
            await player.play(DeviceFileSource(_warningAudioPath!));
          } else {
            await player.play(
              AssetSource('sounds/warning.mp3'),
            ); // Assume asset exists
          }
        }
      } catch (e) {
        debugPrint('Sound play failed: $e');
      }
    }
  }

  // Centralized scalable analytics engine for 50k+ docs
  final AnalyticsEngine engine = AnalyticsEngine();

  // ── Helper: Format product name (Standard Title Case) ──────────────
  static String _formatProductName(String raw) {
    return AnalyticsEngine.formatProductName(raw);
  }

  String _formatValue(double value) {
    return FormatHelper.formatRevenue(value);
  }

  void _recalculateAnalytics() {
    if (!mounted) return;
    try {
      engine.recalculateAnalytics(sales, _selectedTimeFilter);
    } catch (e) {
      debugPrint('⚠️ Analytics Engine Failure: $e');
    }
  }

  // FIX-4 R2: Centralized filter handler prevents duplicate filter state updates

  bool _isBackingUp = false;

  void _handleDriveBackup() async {
    if (_isBackingUp) return;
    setState(() => _isBackingUp = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('⏳ Backing up to Google Drive...')),
    );
    try {
      final success = await GoogleDriveService.backupToDrive();
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Backup to Google Drive Successful!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '❌ Backup failed. Check your connection or Google Sign-In.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  void _handleDriveRestore() async {
    if (_isBackingUp) return;
    setState(() => _isBackingUp = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('⏳ Restoring from Google Drive...')),
    );
    try {
      final success = await GoogleDriveService.restoreFromDrive();
      if (!mounted) return;
      if (success) {
        _loadSales();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Restore Successful! Data reloaded.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '❌ Restore failed. No backup found or network error.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  void _onFilterChanged(int index) {
    if (_selectedTimeFilter == index) return; // No-op if same filter selected
    setState(() => _selectedTimeFilter = index);
    _recalculateAnalytics();
  }

  // Bridging getters dynamically linking pure O(1) memory references to the state arrays
  List<Map<String, dynamic>> get filteredSales => engine.filteredSalesCache;
  Map<String, double> get _salesByMonth => engine.salesByMonthCache;
  Map<String, double> get _salesByWeek => engine.salesByWeekCache;
  Map<String, double> get _salesByYear => engine.salesByYearCache;
  Map<String, Map<String, dynamic>> get _productAnalytics =>
      engine.productAnalyticsCache;
  Map<String, Map<int, double>> get _monthlyProductSales =>
      engine.monthlyProductSales;
  int get _analyticsIntegrityErrorCount => engine.analyticsIntegrityErrors.length;

  // ═══════════════════════════════════════════════════════════════════════
  // KPI CARDS - Show FILTERED PERIOD data (based on selected time filter)
  // ═══════════════════════════════════════════════════════════════════════
  // FILTER-AWARE KPI VALUES: all three headline metrics use the same selected
  // Today / Week / Month / Year transaction set. Lifetime metrics remain available
  // through AnalyticsEngine.lifetimeRevenue/lifetimeTransactions.
  double get totalSales => engine.displayRevenue;
  int get totalTransactions => engine.displayTransactions;
  double get averageSale => engine.filteredAverageSale;
  int get uniqueProducts => engine.filteredUniqueProducts; // Filtered period
  List<Map<String, dynamic>> get recentSales =>
      engine.filteredSalesCache; // Filtered bills

  // ═══════════════════════════════════════════════════════════════════════
  // PERFORMANCE OVERVIEW - Show TODAY ONLY (regardless of filter)
  // ═══════════════════════════════════════════════════════════════════════
  double get _todayRevenue => engine.todaySalesValue; // Always TODAY
  int get _todayTransactions => engine.todayTransactionsValue; // Always TODAY
  double get _yesterdayRevenue => engine.yesterdayRevenue;
  double get _growthPercentage => engine.growthPercentage;

  // Daily shop insight (cached strings)
  int get _yesterdayTransactions => engine.yesterdayTransactionsCount;
  String get _yesterdayTopProduct => engine.yesterdayTopProduct;
  String get _yesterdayBestHourLabel => engine.yesterdayBestHourLabel;
  double get _previousDayRevenue => engine.previousDayRevenue;
  String _dailyPerformanceMessage = '';

  // Today's specific variables (for Performance Overview)
  String get _todayTopProduct => engine.todayTopProduct;
  String get _todayBestHourLabel => engine.todayBestHourLabel;

  bool get _hasDailyInsight =>
      _todayRevenue > 0 || _yesterdayRevenue > 0 || _yesterdayTransactions > 0;

  double get _dailyGrowth {
    if (_yesterdayRevenue == 0) return _todayRevenue > 0 ? 100 : 0;
    return ((_todayRevenue - _yesterdayRevenue) / _yesterdayRevenue) * 100;
  }

  int get _dailyRating {
    double g = _dailyGrowth;
    if (g > 20) return 5;
    if (g >= 10) return 4;
    if (g >= 0) return 3;
    if (g >= -10) return 2;
    return 1;
  }

  Widget _buildDashboardSectionHeader(
    String title, {
    String? subtitle,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                        height: 1.25,
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

  Widget _buildOwnerQuickTile({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize:
                        12, // FIX: Minimum 12px for accessibility (Google Play requirement)
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRetailAiHubSheet(BuildContext context) {
    final navContext = context;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Retail AI hub',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.psychology_rounded,
                semanticLabel: 'Psychology Rounded',
                color: Color(0xFF7C3AED),
              ),
              title: Text(
                'Retail intelligence',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              subtitle: Text(
                'Insights, forecasts, smart tools',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  navContext,
                  MaterialPageRoute(
                    builder: (_) => const RetailIntelligencePage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.chat_bubble_outline_rounded,
                semanticLabel: 'Chat Bubble Outline Rounded',
                color: Color(0xFF4F46E5),
              ),
              title: Text(
                'Ask AI assistant',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              subtitle: Text(
                'Questions about your shop data',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(navContext, '/query');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.record_voice_over_rounded,
                semanticLabel: 'Record Voice Over Rounded',
                color: Color(0xFFE11D48),
              ),
              title: Text(
                'Voice studio',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              subtitle: Text(
                'Custom payment sounds',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showVoiceCustomizer(navContext, (fn) => setState(fn));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _shareDailyReport() async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayBills = engine.sales.where((sale) {
      final d = engine.getLocalDate(sale);
      return DateTime(d.year, d.month, d.day) == todayStart;
    }).toList()
      ..sort((a, b) => engine.getLocalDate(b).compareTo(engine.getLocalDate(a)));
    double amountOf(Map<String, dynamic> sale) => (sale['gross_revenue'] is num)
        ? (sale['gross_revenue'] as num).toDouble()
        : double.tryParse((sale['total_amount'] ?? sale['total'] ?? 0).toString()) ?? 0.0;
    final total = todayBills.fold<double>(0.0, (sum, sale) => sum + amountOf(sale));
    final count = todayBills.length;
    final avg = count == 0 ? 0.0 : total / count;
    final dateStr = '${today.day.toString().padLeft(2, '0')}/${today.month.toString().padLeft(2, '0')}/${today.year}';
    final buffer = StringBuffer()
      ..writeln('🚀 RETAIL MIND — DAILY SALES REPORT')
      ..writeln('🏪 $shopName')
      ..writeln('📅 $dateStr')
      ..writeln('━━━━━━━━━━━━━━━━━━')
      ..writeln('💰 Today Sales: ₹${total.toStringAsFixed(2)}')
      ..writeln('🧾 Today Orders: $count')
      ..writeln('📈 Average Order: ₹${avg.toStringAsFixed(2)}')
      ..writeln('━━━━━━━━━━━━━━━━━━')
      ..writeln('TODAY’S BILLS');
    if (todayBills.isEmpty) {
      buffer.writeln('No sales recorded today.');
    } else {
      for (var i = 0; i < todayBills.length; i++) {
        final sale = todayBills[i];
        final invoice = (sale['invoice_number'] ?? sale['sale_id'] ?? sale['_bill_id'] ?? 'SALE-${i + 1}').toString();
        final customer = (sale['customer_name'] ?? sale['customer_phone'] ?? 'Walk-in Customer').toString();
        final product = _dashboardProductDisplayName(sale);
        buffer.writeln('${i + 1}. $invoice — $customer — ${product.isEmpty ? 'Sale' : product} — ₹${amountOf(sale).toStringAsFixed(2)}');
      }
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━');
    buffer.writeln('✨ Sent via RETAIL MIND');
    final dashboardMsg = buffer.toString();
    final url = 'https://wa.me/?text=${Uri.encodeComponent(dashboardMsg)}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: dashboardMsg));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Daily report copied to clipboard (WhatsApp not found).')));
    }
  }

  String _formatRevenueValue(double val) {
    if (val >= 10000000) return '${(val / 10000000).toStringAsFixed(2)} Cr';
    if (val >= 100000) return '${(val / 100000).toStringAsFixed(2)} L';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)} K';
    return val.toStringAsFixed(0);
  }

  Widget _buildSmallStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _scrollToCharts(int chartIndex) {
    setState(() => _selectedChartIndex = chartIndex);
    // Smooth scroll to the chart section
    _scrollController.animateTo(
      750, // Better offset that centers charts on mobile
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }

  List<Map<String, dynamic>> _flattenLocalSales(List<dynamic> localHistory) {
    final List<Map<String, dynamic>> flattened = [];
    final List<Map<String, dynamic>> pending = [];
    final Set<String> seenFingerprints = {};

    for (var tx in localHistory) {
      final List<dynamic> items = tx['items'] ?? [];
      final date = tx['business_date'] ??
          tx['sale_date'] ??
          tx['invoice_date'] ??
          tx['date'] ??
          tx['created_at'] ??
          tx['createdAt'];
      if (date == null || date.toString().trim().isEmpty) {
        if (kDebugMode) debugPrint('⚠️ Skipping sale without business_date during dashboard flattening');
        continue;
      }
      
      // 🔧 FIX: Use invoice_number as primary deduplication key for invoice-level deduplication
      final invoiceNumberRaw = tx['invoice_number']?.toString() ??
          tx['sale_id']?.toString() ??
          tx['_bill_id']?.toString();
      final fallbackInvoiceNumber = tx['id']?.toString() ?? tx['created_at']?.toString() ?? tx['createdAt']?.toString() ?? '';
      final invoiceNumber = (invoiceNumberRaw?.trim().isNotEmpty == true ? invoiceNumberRaw : fallbackInvoiceNumber)
          .toString()
          .trim()
          .toLowerCase();

      if (invoiceNumber.isEmpty) {
        if (kDebugMode) debugPrint('⚠️ Skipping sale with invalid invoice_number and no fallback ID');
        continue;
      }

      if (items.isEmpty) {
        final double p = double.tryParse(tx['price']?.toString() ?? '0') ?? 0;
        final double q =
            double.tryParse(
              tx['quantity']?.toString() ?? tx['qty']?.toString() ?? '1',
            ) ??
            1;
        final double t =
            double.tryParse(tx['total']?.toString() ?? '0') ?? (p * q);
            
        final String prodName = (tx['product_name'] ?? tx['product'] ?? tx['item'] ?? tx['title'] ?? tx['name'] ?? '').toString().trim();
        if (prodName.isEmpty || prodName.toLowerCase() == 'unknown' || prodName.toLowerCase() == 'unknown item' || prodName.toLowerCase() == 'cloud item') {
             continue; // Skip synthetic invalid records
        }

        // 🔧 FIX: Use invoice_number as primary key (not date+product)
        final String fingerprint = '${invoiceNumber}_0'; // Single item = index 0
        if (seenFingerprints.contains(fingerprint)) continue;
        seenFingerprints.add(fingerprint);
        
        if (kDebugMode) debugPrint('SALE DISPLAYED:\ninvoice_number: $invoiceNumber\nproduct_name: $prodName\nquantity: $q\nprice: $p');

        flattened.add({
          'product': prodName,
          'quantity': q,
          'price': p,
          'total': t,
          'business_date': date,
          'sale_id': invoiceNumber,
          'invoice_number': invoiceNumber,
          'is_local': true,
        });
        continue;
      }
      final String? dueDate = tx['due_date'];
      final String? status = tx['payment_status'];
      final double total = double.tryParse(tx['total']?.toString() ?? '0') ?? 0;
      final double paid =
          double.tryParse(tx['paid_amount']?.toString() ?? '0') ?? 0;

      if (status != 'PAID' && dueDate != null) {
        final firstItem = items.isNotEmpty ? items[0] : {};
        String prodName =
            (firstItem['product_name'] ??
                    firstItem['item'] ??
                    firstItem['product'] ??
                    'Unknown')
                .toString();
        if (items.length > 1) prodName += ' (+${items.length - 1} more)';

        pending.add({
          'id': invoiceNumber,  // 🔧 FIX: Use invoiceNumber instead of undefined billId
          'total': total,
          'paid': paid,
          'due_date': dueDate,
          'status': status,
          'product': prodName,
          'barcode': firstItem['barcode'] ?? '',
          'date': date,
        });
      }

      // Limit per-invoice items to prevent OOM
      final List<dynamic> constrainedItems = items.length > 500
          ? items.sublist(0, 500)
          : items;

      for (int idx = 0; idx < constrainedItems.length; idx++) {
        final rawItem = constrainedItems[idx];
        // Normalize item for consistent parsing
        final double price = double.tryParse(rawItem['price']?.toString() ?? rawItem['unit_price']?.toString() ?? '0') ?? 0.0;
        final double qty = double.tryParse(rawItem['qty']?.toString() ?? rawItem['quantity']?.toString() ?? '1') ?? 1.0;
        final double lineTotal = double.tryParse(rawItem['total']?.toString() ?? rawItem['line_total']?.toString() ?? rawItem['total_with_tax']?.toString() ?? CurrencyManager.multiply(price, qty).toString()) ?? CurrencyManager.multiply(price, qty);
        
        final item = {
          ...rawItem,
          'price': price,
          'unit_price': price,
          'qty': qty,
          'quantity': qty,
          'total': lineTotal,
          'line_total': lineTotal,
          'total_with_tax': lineTotal,
        };

        // 🚀 STRUCTURED DATA FIRST (product_name & product_id)
        String prod =
            (item['product_name'] ??
                    item['item'] ??
                    item['product'] ??
                    item['description'] ??
                    'Unknown')
                .toString()
                .trim();
        String bCode = (item['product_id'] ?? item['barcode'] ?? '')
            .toString()
            .trim();

        // Final fallback format (Title Case)
        final displayProd = AnalyticsEngine.formatProductName(prod);
        
        if (displayProd.isEmpty || displayProd.toLowerCase() == 'unknown' || displayProd.toLowerCase() == 'unknown item') {
             continue; // Skip synthetic invalid records
        }

        // [STRICT MODE] Fallback for untracked items to ensure grouping doesn't break
        if (bCode.isEmpty) {
          bCode = 'UNKNOWN_${displayProd.hashCode}';
        }

        final double parsedPrice = price;
        final double parsedQty = qty;
            
        // 🔧 FIX: Use invoice_number + item_index as primary key (not date+product)
        final String fingerprint = '${invoiceNumber}_${idx}';
        if (seenFingerprints.contains(fingerprint)) continue;
        seenFingerprints.add(fingerprint);
        
        if (kDebugMode) debugPrint('SALE DISPLAYED:\ninvoice_number: $invoiceNumber\nproduct_name: $displayProd\nquantity: $parsedQty\nprice: $parsedPrice');

        flattened.add({
          'product': displayProd,
          'product_name': displayProd,
          'product_id': bCode,
          'quantity': parsedQty,
          'price': parsedPrice,
          'total': lineTotal,
          'invoice_total': total,
          'paid_amount': paid,
          'payment_status': status,
          'business_date': date,
          'barcode': bCode,
          'is_local': true,
          '_bill_id': invoiceNumber, // ← CORE DEDUPLICATION ANCHOR (invoice_number)
          '_item_idx': idx, // ← CORE DEDUPLICATION OFFSET
          'invoice_number': invoiceNumber, // ← Explicit invoice_number field
        });
      }
    }
    _pendingInvoices = pending;
    if (mounted) {
      try {
        context.read<InvoiceStateNotifier>().setInvoices(
          pending
              .map(
                (p) => {
                  'number': p['id'] ?? '',
                  'customer': p['product'] ?? 'Guest',
                  'totalAmount': (p['total'] ?? 0.0),
                  'paymentStatus': p['status'] ?? 'UNPAID',
                  'createdDate': p['date'] != null
                          ? (DateTime.tryParse(p['date'].toString()) ??
                            DateTime(1970))
                          : DateTime(1970),
                },
              )
              .toList(),
        );
      } catch (e) {
        if (kDebugMode) debugPrint('Invoice provider error: $e');
      }
    }
    return flattened;
  }

  
  Future<void> _loadRemarketing() async {
    if (_isStaffMode) return;
    try {
      final response = await ApiClient.getJson('${ApiClient.remarketing}?threshold_days=30');
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _remarketingCount = (jsonDecode(response.body) as List).length;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load remarketing: $e');
    }
  }

  Future<void> _loadSales() async {
    if (!mounted) return;
    setState(() => loading = true);

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    try {
      // OFFLINE-FIRST: local storage is the immediate source of truth.
      // Never block the dashboard on the network. A background reconciliation
      // runs after the local dashboard has rendered.
      final List<dynamic> history = await LocalStorageService.loadSales();
      // #region agent log
      AgentDebugLog.log(
        location: 'dashboard_page.dart:_loadSales',
        message: 'DASHBOARD LOAD SALES',
        hypothesisId: 'H4',
        data: {
          'localCacheCount': history.length,
          'willFetchBackendInBackground': true,
        },
      );
      // #endregion
      
      List<Map<String, dynamic>> localSalesFlattened = [];
      try {
        localSalesFlattened = _flattenLocalSales(history);
      } catch (e) {
        debugPrint('Local sales decode error: $e');
        localSalesFlattened = [];
      }

      // Set initial state from data
      if (mounted) {
        setState(() {
          sales = localSalesFlattened;
          // Invalidate metrics cache when sales are loaded
          _cachedTodaySales = null;
          _cachedTodayOrders = null;
          _cachedTodayOnlineOrders = null; // 🔒 NEW: Invalidate online orders cache
          _lastMetricsCacheDate = null;
          _recalculateAnalytics();
          _computeAndStoreDailyInsight();

          if (kDebugMode) {
            debugPrint(
              'dY"S Dashboard Load: ${sales.length} sales loaded. TodayRev: ₹${engine.todayRevenue}, TodayOrders: ${engine.todayTransactionsValue}',
            );
          }

          // --- SMART VIEW: If Today is empty but we have past data, show an indication ---
          if (engine.filteredTotalSales == 0 && engine.totalSales > 0) {
            if (kDebugMode)
              debugPrint(
                'dY\' Pro Tip: Today is empty, but history exists (₹${engine.totalSales}). Switching to Month view.',
              );
            _selectedTimeFilter =
                2; // Auto-switch to Month for better first-impression
            _recalculateAnalytics();
          }
          // dYs" CHECK LOW STOCK (Local & Backend)
          _dailyHealthScoreLoading = true;
          _checkLowStock();
          
          loading = false;
          if (_selectedChartIndex >= _chartLabels.length) {
            _selectedChartIndex = 0;
          }
        });
        _recomputeDailyHealthScore();

        // Background-only cloud reconciliation. It must never block the cashier UI.
        unawaited(() async {
          try {
            final changed = await _fetchInvoicesFromBackend();
            if (changed && mounted) {
              final refreshed = await LocalStorageService.loadSales();
              if (!mounted) return;
              setState(() {
                sales = _flattenLocalSales(refreshed);
                _cachedTodaySales = null;
                _cachedTodayOrders = null;
                _cachedTodayOnlineOrders = null;
                _lastMetricsCacheDate = null;
                _recalculateAnalytics();
              });
            }
          } catch (e) {
            if (kDebugMode) debugPrint('⚠️ Background dashboard reconciliation failed: $e');
          }
        }());

        // Schedule daily 9PM summary notification
        unawaited(
          DailySummaryNotificationService.scheduleTodayNotification(
            todayRevenue: _todayRevenue,
            todayBills: _todayTransactions,
            topProduct: _todayTopProduct,
          ),
        );
      }

      final sName = await ScopedSharedPreferences.getString('shop_name') ?? '';
      final sLogo = await ScopedSharedPreferences.getString('logo_base64') ?? '';
      final isStaff = await ScopedSharedPreferences.getBool('is_staff_mode') ?? false;
      final userId = prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0;

      if (mounted) {
        setState(() {
          _isStaffMode = isStaff;
          _isShopSetup = sName.isNotEmpty && sName != 'AI Shop Pro';
          shopName = sName.isEmpty ? 'AI Shop Pro' : sName;

          String un =
              prefs.getString('user_name') ??
              prefs.getString('contact_person') ??
              prefs.getString('fullName') ??
              '';
          _userName = un;

          if (sLogo.isNotEmpty) {
            try {
              logoBytes = base64Decode(sLogo);
            } catch (_) {}
          }
        });
      }

      // BACKEND SYNC: Fetch latest shop profile from backend
      if (userId > 0) {
        _fetchShopProfileFromBackend(userId);
      }

    } catch (e) {
      if (kDebugMode) debugPrint('Error in _loadSales: $e');
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    } finally {
      if (mounted) {
        unawaited(_afterSalesLoadGrowthHooks());
      }
    }
  }

  Future<void> _refreshGrowthMetrics() async {
    final snap = await RetailGrowthKit.loadRetention();
    if (mounted) setState(() => _retentionSnapshot = snap);
  }

  Future<void> _afterSalesLoadGrowthHooks() async {
    await _refreshGrowthMetrics();
    if (!mounted || _isStaffMode || _growthOnboardingQueued) return;
    if (await RetailGrowthKit.shouldShowFocusOnboarding()) {
      _growthOnboardingQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _isStaffMode) return;
        await RetailGrowthKit.presentFocusSetupSheet(context, locking: true);
        if (mounted) await _refreshGrowthMetrics();
      });
    }
  }

  void _showMoneyToolsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Money & collections',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.account_balance_wallet_rounded,
                semanticLabel: 'Account Balance Wallet Rounded',
                color: Color(0xFF4F46E5),
              ),
              title: Text(
                'Khata / ledger',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Credit, collections, reminders',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => KhataPage()),
                ).then((_) => _loadSales());
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.receipt_long_rounded,
                semanticLabel: 'Receipt Long Rounded',
                color: Color(0xFF2563EB),
              ),
              title: Text(
                'Invoices & dues',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(
                  context,
                  '/invoices',
                ).then((_) => _loadSales());
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.card_giftcard_rounded,
                semanticLabel: 'Card Giftcard Rounded',
                color: Color(0xFFDB2777),
              ),
              title: Text(
                'Gift cards',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(
                  context,
                  '/gift-card',
                ).then((_) => _loadSales());
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.receipt_rounded,
                semanticLabel: 'Receipt Rounded',
                color: Color(0xFF8B5CF6),
              ),
              title: Text(
                'Transactions',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(
                  context,
                  '/transactions',
                ).then((_) => _loadSales());
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowYourShopSection() {
    if (_isStaffMode) return const SizedBox.shrink();
    final snap = _retentionSnapshot;
    return FutureBuilder<String>(
      future: RetailGrowthKit.getShopFocus(),
      builder: (context, snapFocus) {
        final key = snapFocus.data ?? 'general';
        final label =
            RetailGrowthKit.focusLabels[key] ??
            RetailGrowthKit.focusLabels['general']!;
        final tip = RetailGrowthKit.recommendationForFocus(key);
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: indigo.withValues(alpha: 0.07),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      semanticLabel: 'Rocket Launch Rounded',
                      color: Color(0xFF4F46E5),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grow your shop',
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: t1,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Focus: $label',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: t2,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await RetailGrowthKit.presentFocusSetupSheet(
                        context,
                        locking: false,
                      );
                      if (mounted) setState(() {});
                    },
                    child: Text(
                      'Change',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                tip,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: t2,
                  height: 1.35,
                ),
              ),
              if (snap != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: glass,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border2.withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Retention snapshot',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: t1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bills saved here: ${snap.billsCompleted} · Day ${snap.daysSinceFirstOpen} since install',
                        style: GoogleFonts.poppins(fontSize: 11, color: t2),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        snap.streakHint,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: t2,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Field demo tip: walk through Sales → Khata → Day closing in under five minutes.',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: t3,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(
                      Icons.share_rounded,
                      semanticLabel: 'Share Rounded',
                      size: 18,
                    ),
                    label: const Text('Invite another shop'),
                    onPressed: () => RetailGrowthKit.shareAppInvite(),
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.chat_rounded,
                      semanticLabel: 'Chat Rounded',
                      size: 18,
                    ),
                    label: const Text('WhatsApp support'),
                    onPressed: () async {
                      final p = await SharedPreferences.getInstance();
                      final phone =
                          p.getString('shop_phone') ??
                          p.getString('contact_phone') ??
                          '';
                      await RetailGrowthKit.openWhatsAppSupport(phone);
                      if (mounted &&
                          phone.replaceAll(RegExp(r'\D'), '').length < 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Add your shop phone in Shop profile for one-tap support.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.cloud_upload_rounded,
                      semanticLabel: 'Cloud Upload Rounded',
                      size: 18,
                    ),
                    label: const Text('Backup data'),
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/data-upload',
                    ).then((_) => _loadSales()),
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.payments_rounded,
                      semanticLabel: 'Payments Rounded',
                      size: 18,
                    ),
                    label: const Text('Money tools'),
                    onPressed: () => _showMoneyToolsSheet(context),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _computeAndStoreDailyInsight() async {
    _recalculateAnalytics();

    if (mounted) {
      setState(() {
        _dailyPerformanceMessage = _getSalesAnalysisSentence();
      });
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final summary = {
      'yesterdayRevenue': _yesterdayRevenue,
      'yesterdayTransactions': _yesterdayTransactions,
      'topProduct': _todayTopProduct,
      'bestHour': _todayBestHourLabel,
      'previousRevenue': _previousDayRevenue,
      'message': _dailyPerformanceMessage,
      'generatedAt': DateTime.now().toIso8601String(),
    };
    // 🔒 SECURITY: Use scoped SharedPreferences for daily insights
    await ScopedSharedPreferences.setString('dashboard_daily_insight_v1', json.encode(summary));
  }

  String _formatHourRange(int hour) {
    final start = _formatHour(hour);
    final end = _formatHour((hour + 1) % 24);
    return '$start – $end';
  }

  String _formatHour(int h) {
    if (h == 0) return '12 AM';
    if (h < 12) return '$h AM';
    if (h == 12) return '12 PM';
    return '${h - 12} PM';
  }

  String _cleanProductName(String raw, [String fallback = '']) {
    if (raw.isEmpty) return fallback.isEmpty ? 'Unknown' : fallback;
    String name = raw.toString().trim();
    if (name.contains('_')) {
      name = name.substring(0, name.lastIndexOf('_')).trim();
    }
    return name;
  }

  dynamic _safeJsonDecode(String jsonStr) {
    try {
      return json.decode(jsonStr);
    } catch (e) {
      debugPrint('❌ JSON Parse Failure: $e');
      return [];
    }
  }

  Future<void> _checkLowStock() async {
    try {
      // 🚀 REAL-TIME: Using dynamic stock levels instead of static alert history
      final lowStockItems =
          await InventoryManagementService.getAllLowStockProducts();

      if (mounted) {
        setState(() => _lowStockProducts = lowStockItems);
      }
      _recomputeDailyHealthScore();
    } catch (e) {
      debugPrint('Error checking real-time low stock: $e');
    }
  }

  Widget _buildDailyHealthScoreCard() {
    final isLoading = _dailyHealthScoreLoading;
    final score = _dailyHealthScore.clamp(0, 100);

    final Color scoreColor;
    final Color borderColor;
    if (score >= 80) {
      scoreColor = const Color(0xFF10B981); // green
      borderColor = const Color(0xFF10B981);
    } else if (score >= 50) {
      scoreColor = const Color(0xFFF59E0B); // amber
      borderColor = const Color(0xFFF59E0B);
    } else {
      scoreColor = const Color(0xFFEF4444); // red
      borderColor = const Color(0xFFEF4444);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.favorite_rounded,
              semanticLabel: 'Favorite Rounded',
              color: scoreColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Health Score',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLoading ? '...' : '$score/100',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: scoreColor,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
          if (!isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: scoreColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                score >= 80
                    ? 'Excellent'
                    : (score >= 50 ? 'Improving' : 'Needs focus'),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scoreColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  
  Widget _buildMarketingBanner() {
    if (_remarketingCount == 0) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MarketingPage())).then((_) => _loadRemarketing()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.orange[400]!, Colors.orange[600]!]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.campaign, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_remarketingCount Dormant Customers',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                  ),
                  const Text(
                    'Tap to send WhatsApp discounts and boost sales!',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockBanner() {
    if (_lowStockProducts.isEmpty) return const SizedBox.shrink();

    // Get unique product names to avoid clutter
    final names = _lowStockProducts
        .map((e) => e['productName'].toString())
        .toSet()
        .toList();
    final displayNames =
        names.take(2).join(', ') +
        (names.length > 2 ? ' +${names.length - 2} more' : '');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2), // Red 50
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)), // Red 200
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/inventory'),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                semanticLabel: 'Warning Amber Rounded',
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LOW STOCK DETECTED',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFB91C1C), // Red 700
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Items needing restock: $displayNames',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF7F1D1D), // Red 900
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              semanticLabel: 'Arrow Forward Ios Rounded',
              color: Color(0xFFEF4444),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // Demo sales generator is retained only for offline development
  // but the app now relies on real backend data in production.
  void _loadDemoSales() {
    // Not called by default. Keeps existing logic in case developer
    // needs to simulate behaviour when backend is unreachable.
    setState(() {
      final rnd = math.Random(42);
      final products = <Map<String, dynamic>>[
        {'name': 'Fresh Apples', 'price': 120.0},
        {'name': 'Organic Milk', 'price': 60.0},
        {'name': 'Whole Wheat Bread', 'price': 45.0},
        {'name': 'Carrots', 'price': 35.0},
        {'name': 'Chicken Breast', 'price': 220.0},
        {'name': 'Basmati Rice', 'price': 80.0},
        {'name': 'Toor Dal', 'price': 95.0},
        {'name': 'Sunflower Oil', 'price': 160.0},
        {'name': 'Tea Powder', 'price': 140.0},
        {'name': 'Eggs (12 pack)', 'price': 75.0},
      ];

      final now = DateTime.now();
      final items = <Map<String, dynamic>>[];

      for (int i = 0; i < 55; i++) {
        final p = products[rnd.nextInt(products.length)];
        final qty = rnd.nextInt(8) + 1;
        final basePrice = (p['price'] as num?)?.toDouble() ?? 1.0;
        if (basePrice <= 0) continue;
        final price = basePrice * (0.9 + rnd.nextDouble() * 0.25);
        final date = now.subtract(Duration(days: rnd.nextInt(120)));
        final total = qty * price;
        items.add({
          'product': p['name'],
          'price': (price.round()).toDouble(),
          'quantity': qty,
          'total': (total.round()).toDouble(),
          'sale_date': date.toIso8601String(),
          'created_at': date.toIso8601String(),
        });
      }

      for (int i = 0; i < 10; i++) {
        final p = products[rnd.nextInt(products.length)];
        final qty = rnd.nextInt(10) + 1;
        final basePrice2 = (p['price'] as num?)?.toDouble() ?? 1.0;
        if (basePrice2 <= 0) continue;
        final price = basePrice2 * (0.9 + rnd.nextDouble() * 0.2);
        final date = DateTime(
          now.year - 1,
          rnd.nextInt(12) + 1,
          rnd.nextInt(27) + 1,
        );
        final total = qty * price;
        items.add({
          'product': p['name'],
          'price': (price.round()).toDouble(),
          'quantity': qty,
          'total': (total.round()).toDouble(),
          'sale_date': date.toIso8601String(),
          'created_at': date.toIso8601String(),
        });
      }

      sales = items.map((e) => Map<String, dynamic>.from(e)).toList();
    });
  }

  Future<void> _openGiftCardFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('user_name') ?? 'User';
    final shopNameFromPrefs = prefs.getString('shop_name') ?? shopName;
    final location = prefs.getString('location') ?? 'Your Location';
    final shopType = prefs.getString('shop_type') ?? '';
    final contactPerson = prefs.getString('contact_person') ?? '';
    final phone =
        prefs.getString('shop_phone') ?? prefs.getString('phone') ?? '';
    final email =
        prefs.getString('shop_email') ?? prefs.getString('email') ?? '';
    final gstNumber = prefs.getString('gst_number') ?? '';
    final categories = prefs.getString('shop_categories') ?? '';
    final openingHour = prefs.getString('opening_hour') ?? '';
    final closingHour = prefs.getString('closing_hour') ?? '';
    final website = prefs.getString('website') ?? '';
    final tagline = prefs.getString('tagline') ?? '';

    // Try logo_base64 first, then fall back to shop_logo
    final logoBase64 =
        prefs.getString('logo_base64') ?? prefs.getString('shop_logo') ?? '';

    Uint8List? loadedLogoBytes = logoBytes;
    if (logoBase64.isNotEmpty) {
      try {
        loadedLogoBytes = base64Decode(logoBase64);
      } catch (_) {
        // Keep existing logoBytes if decoding fails
      }
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GiftCardPage(
          userName: userName,
          shopName: shopNameFromPrefs,
          location: location,
          shopType: shopType,
          contactPerson: contactPerson,
          logoBytes: loadedLogoBytes,
          phone: phone,
          email: email,
          gstNumber: gstNumber,
          categories: categories,
          openingHour: openingHour,
          closingHour: closingHour,
          website: website,
          tagline: tagline,
        ),
      ),
    );
  }

  void _showHowToUseDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            l10n.howToUseTitle,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTutorialStep(
                  Icons.add_shopping_cart,
                  l10n.step1Title,
                  l10n.step1Desc,
                ),
                _buildTutorialStep(
                  Icons.inventory_2,
                  l10n.step2Title,
                  l10n.step2Desc,
                ),
                _buildTutorialStep(
                  Icons.analytics,
                  l10n.step3Title,
                  l10n.step3Desc,
                ),
                _buildTutorialStep(
                  Icons.card_giftcard,
                  l10n.step4Title,
                  l10n.step4Desc,
                ),
                _buildTutorialStep(
                  Icons.qr_code_2,
                  l10n.step5Title,
                  l10n.step5Desc,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.gotIt,
                style: const TextStyle(color: Color(0xFF6366F1)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTutorialStep(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF6366F1), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF000000),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------- UI helpers derived from HTML layout ----------
  /// 📧 Generate and send daily summary email to shopkeeper
  Future<void> _closeDayAndSendEmail() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📧 Close Day & Send Summary?'),
        content: const Text('Generate daily summary and send to your email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
            child: const Text(
              'Send Summary',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => loading = true);

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0;
      final userEmail = prefs.getString('email') ?? '';

      if (userId <= 0 || userEmail.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ User email not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Fetch today's report from backend
      final reportResponse = await ApiClient.getJson(
        '/api/reports/daily?user_id=$userId',
      ).timeout(const Duration(seconds: 10));

      // Build summary from local sales data
      final todaySales = sales;
      double totalRevenue = 0;
      int paidCount = 0, unpaidCount = 0;

      for (var sale in todaySales) {
        final rawAmount = sale['total_amount'] ?? sale['total'] ?? sale['grand_total'] ?? sale['final_amount'] ?? sale['totalAmount'] ?? '0';
        final amount = double.tryParse(rawAmount.toString()) ?? 0;
        totalRevenue += amount;

        final status =
            sale['payment_status']?.toString().toUpperCase() ?? 'PAID';
        if (status == 'PAID')
          paidCount++;
        else
          unpaidCount++;
      }

      // Prepare email summary payload
      final emailSummary = {
        'user_id': userId,
        'email': userEmail,
        'shop_name': shopName,
        'date': DateTime.now().toIso8601String(),
        'total_revenue': totalRevenue,
        'total_invoices': todaySales.length,
        'paid_invoices': paidCount,
        'unpaid_invoices': unpaidCount,
        'summary':
            'Daily Summary: ₹${totalRevenue.toStringAsFixed(0)} | Invoices: ${todaySales.length} (Paid: $paidCount, Unpaid: $unpaidCount)',
      };

      // Queue email send via sync service (will use backend endpoint)
      await SyncQueueManager.enqueue('send_daily_email', emailSummary);

      setState(() {
        _shopClosed = true;
        _lastDayClosing = DateTime.now();
      });
      _recomputeDailyHealthScore();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Daily summary sent to $userEmail'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Error: $e'), backgroundColor: Colors.orange),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  Widget _buildAppBar() {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: const Color(0xAA03030D),
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          _menuButton(),
          _brand(),
          const Spacer(),
          // 📧 Close Day Button
          if (!_shopClosed)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                onPressed: _closeDayAndSendEmail,
                icon: const Icon(
                  Icons.mail_outline,
                  semanticLabel: 'Mail Outline',
                  size: 18,
                ),
                label: const Text('Close Day'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                label: const Text(
                  '✓ Day Closed',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          // Series A Investor Metrics Button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: 'View Series A Investor Metrics',
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvestorAnalyticsDashboard(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.trending_up,
                  semanticLabel: 'Trending Up',
                  size: 18,
                ),
                label: const Text('📊 Series A'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6F46E0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
          // Online Store Status Button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: _isOnlineStoreActive ? 'Online Store is Active - Manage Settings' : 'Enable Online Store',
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OnlineStoreManagerPage()),
                  ).then((_) => _loadOnlineStoreStatus());
                },
                icon: Icon(
                  _isOnlineStoreActive ? Icons.storefront : Icons.storefront_outlined,
                  semanticLabel: 'Storefront',
                  size: 18,
                ),
                label: Text(
                  _isOnlineStoreActive ? '🟢 Store' : '🔴 Store',
                  style: const TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isOnlineStoreActive 
                      ? const Color(0xFF10B981) 
                      : const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
          // Loyalty Network & Tier Benefits Button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: 'View Loyalty Network & Tier Benefits',
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LoyaltyNetworkDashboard(customerId: 1),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.public,
                  semanticLabel: 'Public',
                  size: 18,
                ),
                label: const Text('🌐 Network'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0891B2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
          _buildLanguageSwitcher(),
        ],
      ),
    );
  }

  Widget _buildLanguageSwitcher() {
    final langProvider = Provider.of<LanguageProvider>(context);
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.language,
        semanticLabel: 'Language',
        color: Colors.indigo,
        size: 24,
      ),
      tooltip: 'Change Language',
      onSelected: (code) => langProvider.setLanguage(code),
      itemBuilder: (context) => LanguageProvider.languages.map((l) {
        return PopupMenuItem<String>(
          value: l['code'],
          child: Text('${l['nativeName']} (${l['name']})'),
        );
      }).toList(),
    );
  }

  Widget _menuButton() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: glass2,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: border2),
        ),
        child: const Center(
          child: Text('☰', style: TextStyle(fontSize: 17, color: t1)),
        ),
      ),
    );
  }

  Widget _brand() {
    return Row(
      children: [
        // RM Logo with neon glow - New Branding
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E3A8A), // Deep blue
                Color(0xFF0F172A), // Almost black
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00B4FF).withValues(alpha: 0.7),
                blurRadius: 20,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: const Color(0xFFFFB800).withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'RM',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: const Color(0xFFFFB800), // Gold
                shadows: [
                  Shadow(
                    color: const Color(0xFF00B4FF).withValues(alpha: 0.8),
                    offset: const Offset(0, 0),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Retail Mind',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: const Color(0xFF00B4FF), // Neon blue
              ),
            ),
            Text(
              'Smart Billing',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: const Color(0xFFFFB800), // Gold
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _navPills() {
    final originalLabels = ['Dashboard', 'Analytics', 'Inventory', 'Reports'];
    final labels = [
      AppLocalizations.of(context).dashboard,
      AppLocalizations.of(context).analytics,
      AppLocalizations.of(context).inventory,
      AppLocalizations.of(context).reports,
    ];
    return Row(
      children: List.generate(labels.length, (index) {
        final l = labels[index];
        final active = originalLabels[index] == 'Dashboard';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 18),
              decoration: BoxDecoration(
                color: active ? indigo : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : t2,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _actionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: glass.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 0.5),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Put language first so it is always visible on small screens
            if (!_isStaffMode)
              _compactIconButton(
                Icons.receipt_long_rounded,
                'CA Export (JSON)',
                () async {
                  final result = await TallyExportService.exportGstReturns(
                    shopName,
                    'UNREGISTERED',
                  );
                  if (mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(result['message'])));
                },
              ),
            if (!_isStaffMode)
              _compactIconButton(
                _isStaffMode
                    ? Icons.admin_panel_settings_rounded
                    : Icons.storefront_rounded,
                _isStaffMode ? 'Owner Login' : 'Staff Mode',
                _toggleStaffMode,
                isPrimary: _isStaffMode,
              ),
            _compactIconButton(
              Icons.record_voice_over_rounded,
              'Voice Language',
              _showVoiceLanguageDialog,
              isPrimary: true,
            ),
            _compactIconButton(
              Icons.language_rounded,
              AppLocalizations.of(context).language,
              _showLanguageDialog,
            ),
            _compactIconButton(
              Icons.add_shopping_cart_rounded,
              AppLocalizations.of(context).sales,
              () => Navigator.pushNamed(
                context,
                '/sales-entry',
              ).then((_) => _loadSales()),
            ),
            if (!_isStaffMode)
              _compactIconButton(
                Icons.upload_rounded,
                AppLocalizations.of(context).uploadData,
                () => Navigator.pushNamed(
                  context,
                  '/data-upload',
                ).then((_) => _loadSales()),
              ),
            _compactIconButton(
              Icons.card_giftcard_rounded,
              AppLocalizations.of(context).giftCard,
              _openGiftCardFromPrefs,
            ),
            _compactIconButton(
              Icons.receipt_rounded,
              'Transactions',
              () => Navigator.pushNamed(
                context,
                '/transactions',
              ).then((_) => _loadSales()),
            ),
            if (!_isStaffMode)
              _compactIconButton(
                Icons.settings_rounded,
                AppLocalizations.of(context).settings,
                _showSettingsDialog,
              ),
            _compactIconButton(
              Icons.grid_3x3_rounded,
              'Geo Register',
              () => Navigator.pushNamed(context, '/geometric-registration'),
            ),
            _compactIconButton(
              Icons.person_add_outlined,
              AppLocalizations.of(context).createAccount,
              () => Navigator.pushNamed(context, '/register'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            AppLocalizations.of(context).selectLanguage,
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: LanguageProvider.languages.map((lang) {
              return ListTile(
                title: Text(
                  lang['name']!,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  lang['nativeName']!,
                  style: const TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  Provider.of<LanguageProvider>(
                    context,
                    listen: false,
                  ).setLanguage(lang['code']!);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showVoiceLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.record_voice_over_rounded,
                semanticLabel: 'Record Voice Over Rounded',
                color: Colors.blueAccent,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Announcement Language',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                _buildVoiceLangItem('en-US', 'English'),
                _buildVoiceLangItem('hi-IN', 'Hindi (हिंदी)'),
                _buildVoiceLangItem('ta-IN', 'Tamil (தமிழ்)'),
                _buildVoiceLangItem('te-IN', 'Telugu (తెలుగు)'),
                _buildVoiceLangItem('kn-IN', 'Kannada (ಕನ್ನಡ)'),
                _buildVoiceLangItem('ml-IN', 'Malayalam (മലയാളം)'),
                _buildVoiceLangItem('bn-IN', 'Bengali (বাংলা)'),
                _buildVoiceLangItem('mr-IN', 'Marathi (มराठी)'),
                _buildVoiceLangItem('gu-IN', 'Gujarati (ગુજરાતી)'),
                _buildVoiceLangItem('pa-IN', 'Punjabi (ਪੰਜਾਬੀ)'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVoiceLangItem(String code, String label) {
    bool isSelected = _paymentSoundLang == code;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        label,
        style: GoogleFonts.poppins(
          color: isSelected ? Colors.blueAccent : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(
              Icons.check_circle_rounded,
              semanticLabel: 'Check Circle Rounded',
              color: Colors.blueAccent,
              size: 20,
            )
          : null,
      onTap: () async {
        // 🔒 SECURITY: Use scoped SharedPreferences for payment language
        await ScopedSharedPreferences.setString('payment_sound_lang', code);

        // Update services immediately on language change
        PaymentDetectionService().setLanguage(
          PaymentDetectionService.mapLanguage(code),
        );
        await PaymentAnnouncementService().init();

        if (mounted) {
          setState(() => _paymentSoundLang = code);
          Navigator.pop(context);
          PaymentAnnouncementService().testAnnouncement(code);
        }
      },
    );
  }

  Widget _compactIconButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: label,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isPrimary
                ? cyan.withValues(alpha: 0.25)
                : glass.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isPrimary ? cyan : border,
              width: isPrimary ? 1.2 : 0.5,
            ),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: cyan.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(icon, color: isPrimary ? Colors.white : cyan, size: 18),
        ),
      ),
    );
  }

  Widget _primaryToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [indigo, violet, cyan],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: cyan.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.black),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secondaryToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: label,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: glass,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Icon(icon, color: cyan, size: 18),
        ),
      ),
    );
  }

  Widget _buildPerformanceOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).performanceOverview,
          style: TextStyle(
            fontFamily: 'Familjen Grotesk',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${AppLocalizations.of(context).showing}: ${[AppLocalizations.of(context).today, AppLocalizations.of(context).week, AppLocalizations.of(context).month, AppLocalizations.of(context).year][_selectedTimeFilter]}',
          style: const TextStyle(fontSize: 12, color: t2),
        ),
        const SizedBox(height: 20),
        _buildTimeFilterButtons(),
        const SizedBox(height: 26),
        _buildKpiCards(),
      ],
    );
  }

  Widget _buildTimeFilterButtons() {
    final labels = [
      AppLocalizations.of(context).today,
      AppLocalizations.of(context).week,
      AppLocalizations.of(context).month,
      AppLocalizations.of(context).year,
    ];
    return Wrap(
      spacing: 4,
      children: List.generate(labels.length, (i) {
        final on = i == _selectedTimeFilter;
        return GestureDetector(
          onTap: () => _onFilterChanged(i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: on ? cyan.withValues(alpha: 0.12) : glass,
              border: Border.all(
                color: on ? cyan.withValues(alpha: 0.3) : border,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              labels[i],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: on ? (i == 0 ? Colors.black : Colors.white) : t2,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildKpiCards() {
    final bool noSales = totalSales == 0;
    final bool isUp = engine.growthPercentage >= 0;
    final String gPrefix = isUp ? '↑' : '↓';
    final String gVal = engine.growthPercentage.abs().toStringAsFixed(1);
    // When there are no sales yet, suppress the misleading -100% figure
    final String gText = noSales ? '–' : '$gPrefix$gVal%';

    final items = [
      {
        'lbl': 'Total Sales', // 🔒 CHANGED: From "Sales" to "Total Sales"
        'val': _formatValue(totalSales),
        'chg': gText,
      },
      {
        'lbl': 'Total Bills', // 🔒 CHANGED: From "Transactions" to "Total Bills"
        'val': '$totalTransactions',
        'chg': gText,
      },
      {
        'lbl': 'Online Orders', // 🔒 CHANGED: From "Avg Order" to "Online Orders"
        'val': '${_cachedTotalOnlineOrders ?? engine.totalOnlineOrders}',
        'chg': gText,
      },
      {
        'lbl': 'Growth',
        'val': noSales
            ? '–'
            : '${engine.growthPercentage >= 0 ? '+' : ''}${engine.growthPercentage.toStringAsFixed(1)}%',
        'chg': gText,
      },
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (_, idx) {
        final it = items[idx];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    it['lbl'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isUp
                          ? const Color(0xFF10B981).withValues(alpha: 0.1)
                          : const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      it['chg'] as String,
                      style: TextStyle(
                        color: isUp
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                it['val'] as String,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).quickActions,
          style: const TextStyle(
            fontFamily: 'Familjen Grotesk',
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  '/sales-entry',
                ).then((_) => _loadSales()),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        indigo.withValues(alpha: 0.2),
                        violet.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: indigo.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: indigo.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_shopping_cart,
                          semanticLabel: 'Add Shopping Cart',
                          color: indigo,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context).addSale,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  '/worker-management',
                ).then((_) => _loadSales()),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        emerald.withValues(alpha: 0.2),
                        cyan.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: emerald.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: emerald.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.people_rounded,
                          semanticLabel: 'People Rounded',
                          color: emerald,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Staff / Workers',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => KhataPage()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF6366F1).withValues(alpha: 0.2),
                        Color(0xFF6366F1).withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Color(0xFF6366F1).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFF6366F1).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          semanticLabel: 'Account Balance Wallet Rounded',
                          color: Color(0xFF6366F1),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Khata Book',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ReturnsPage()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFEF4444).withValues(alpha: 0.2),
                        Color(0xFFEF4444).withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Color(0xFFEF4444).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFFEF4444).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.assignment_return_rounded,
                          semanticLabel: 'Assignment Return Rounded',
                          color: Color(0xFFEF4444),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Returns',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SchemesPage()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF22C55E).withValues(alpha: 0.2),
                        Color(0xFF22C55E).withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Color(0xFF22C55E).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFF22C55E).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.local_offer_rounded,
                          semanticLabel: 'Local Offer Rounded',
                          color: Color(0xFF22C55E),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Offers',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _loadTodayInsight(),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        amber.withValues(alpha: 0.2),
                        orange.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: amber.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context).getInsights,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_isOnlineStoreActive) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OnlineStoreHubPage()),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OnlineStoreManagerPage()),
                    ).then((_) => _loadOnlineStoreStatus());
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF8B5CF6).withValues(alpha: 0.2),
                        Color(0xFF6366F1).withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Color(0xFF8B5CF6).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFF8B5CF6).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.storefront_rounded,
                          semanticLabel: 'Storefront Rounded',
                          color: Color(0xFF8B5CF6),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Online Store',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isOnlineStoreActive ? 'Active' : 'Setup Required',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _isOnlineStoreActive 
                              ? const Color(0xFF10B981) 
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _loadTodayInsight() async {
    setState(() {
      insightLoading = true;
      showInsight = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final token = await SecureTokenStorage.getToken() ?? '';

    String insight = '';

    try {
      final resp = await ApiClient.getJson(
        '/api/collections/today-summary',
        headers: {if (token.isNotEmpty) 'Authorization': 'Bearer $token'},
      );

      if (resp.statusCode == 200) {
        try {
          final data = json.decode(resp.body);
          if (data is Map<String, dynamic>) {
            insight = data['insights']?.toString() ?? 'No data received';
          } else {
            insight = data.toString();
          }
        } catch (e) {
          insight = 'Error parsing response: $e';
        }
      } else {
        insight = 'Server error (${resp.statusCode})';
      }
    } catch (e) {
      insight = 'Network error: $e';
    }

    setState(() {
      todayInsight = insight.isEmpty
          ? AppLocalizations.of(context).noInsights
          : insight;
      insightLoading = false;
    });
  }

  void _hideInsight() {
    setState(() {
      showInsight = false;
      todayInsight = '';
    });
  }

  // current time filter label helper
  String get _currentFilterLabel {
    switch (_selectedTimeFilter) {
      case 0:
        return AppLocalizations.of(context).today;
      case 1:
        return AppLocalizations.of(context).last7Days;
      case 2:
        return AppLocalizations.of(context).last30Days;
      case 3:
        return AppLocalizations.of(context).thisYear;
      default:
        return '';
    }
  }

  // color used for the current time filter theme
  Color get _filterColor {
    switch (_selectedTimeFilter) {
      case 0:
        return kSecondaryColor; // green-ish
      case 1:
        return kPrimaryColor; // blue
      case 2:
        return kAccentColor; // orange
      case 3:
        return kInfoColor; // purple
      default:
        return kPrimaryColor;
    }
  }

  // Unique color for each chart type (independent of time filter)
  Color _getChartTypeColor(int chartIndex) {
    switch (chartIndex) {
      case 0: // Bar Chart
        return const Color(0xFF3B82F6); // Blue
      case 1: // Line Chart
        return const Color(0xFF10B981); // Green
      case 2: // Pie Chart
        return const Color(0xFFF59E0B); // Orange
      case 3: // Radar Chart
        return const Color(0xFF8B5CF6); // Purple
      case 4: // Month Chart
        return const Color(0xFF06B6D4); // Cyan
      case 5: // Week Chart
        return const Color(0xFFEC4899); // Pink
      case 6: // Year Chart
        return const Color(0xFFF97316); // Orange-Red
      default:
        return const Color(0xFF6366F1);
    }
  }

  // ENHANCED STAT CARD WITH ANIMATIONS
  Widget _buildEnhancedStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
    bool showGrowth,
  ) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: color.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Icon(icon, color: color, size: 18),
                        ),
                        if (showGrowth)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              margin: const EdgeInsets.only(left: 4),
                              decoration: BoxDecoration(
                                color: totalSales == 0
                                    ? Colors.grey.withValues(alpha: 0.1)
                                    : (_growthPercentage >= 0
                                          ? Color(
                                              0xFF6366F1,
                                            ).withValues(alpha: 0.1)
                                          : Colors.red.withValues(alpha: 0.1)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: totalSales == 0
                                      ? Colors.transparent
                                      : (_growthPercentage >= 0
                                            ? Color(
                                                0xFF6366F1,
                                              ).withValues(alpha: 0.3)
                                            : Colors.red.withValues(
                                                alpha: 0.3,
                                              )),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _growthPercentage >= 0
                                        ? Icons.trending_up
                                        : Icons.trending_down,
                                    color: _growthPercentage >= 0
                                        ? const Color(0xFF6366F1)
                                        : Colors.red,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${_growthPercentage >= 0 ? '+' : ''}${_growthPercentage.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _growthPercentage >= 0
                                          ? const Color(0xFF6366F1)
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: _getProgressValue(title),
                      backgroundColor: const Color(0xFF1E1E28),
                      color: color,
                      minHeight: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _getProgressValue(String title) {
    if (filteredSales.isEmpty) return 0.0;
    switch (title) {
      case 'Total Sales':
        return math.min(totalSales / 100000, 1.0);
      case 'Transactions':
        return math.min(totalTransactions / 100, 1.0);
      case 'Avg. Order':
        return math.min(averageSale / 1000, 1.0);
      case 'Products':
        return math.min(uniqueProducts / 20, 1.0);
      default:
        return 0.5;
    }
  }

  Widget _buildChartSelector() {
    final labels = _chartLabels;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(labels.length, (i) {
            final selected = i == _selectedChartIndex;
            return GestureDetector(
              onTap: () => setState(() => _selectedChartIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected
                        ? const Color(0xFF111827)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildActiveChart() {
    String title;
    String key;
    Widget chart;
    switch (_selectedChartIndex) {
      case 1:
        title = AppLocalizations.of(context).salesTrend;
        key = 'line';
        chart = RevenueLineChart(
          engine: engine,
          fadeAnimation: _fadeAnimation,
          slideAnimation: _slideAnimation,
          filterColor: _getChartTypeColor(1),
          currentFilterLabel: _currentFilterLabel,
        );
        break;
      case 2:
        title = AppLocalizations.of(context).revenueDistribution;
        key = 'pie';
        chart = RevenuePieChart(
          engine: engine,
          fadeAnimation: _fadeAnimation,
          slideAnimation: _slideAnimation,
        );
        break;
      case 3:
        title = AppLocalizations.of(context).quantityDistribution;
        key = 'radar';
        chart = RevenueRadarChart(
          engine: engine,
          fadeAnimation: _fadeAnimation,
          slideAnimation: _slideAnimation,
        );
        break;
      case 4:
        title = AppLocalizations.of(context).salesByMonth;
        key = 'month';
        chart = _buildMonthWiseSalesChart();
        break;
      case 5:
        title = AppLocalizations.of(context).salesByWeek;
        key = 'week';
        chart = _buildWeekWiseSalesChart();
        break;
      case 6:
        title = AppLocalizations.of(context).salesByYear;
        key = 'year';
        chart = _buildYearWiseSalesChart();
        break;
      default:
        title = AppLocalizations.of(context).revenueLeaders;
        key = 'bar';
        chart = RevenueBarChart(
          engine: engine,
          fadeAnimation: _fadeAnimation,
          slideAnimation: _slideAnimation,
          filterColor: _getChartTypeColor(0),
        );
    }

    return _MotionCharts(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(
                  Icons.info_outline,
                  semanticLabel: 'Info Outline',
                  size: 18,
                  color: Colors.grey,
                ),
                onPressed: () => _showChartInfo(key),
                tooltip: AppLocalizations.of(context).whatChartShows,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              RepaintBoundary(child: chart),
              Positioned(
                bottom: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _showExportOptionsDialog,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.download_rounded,
                      semanticLabel: 'Download Rounded',
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // MONTH-WISE SALES CHART
  Widget _buildMonthWiseSalesChart() {
    if (filteredSales.isEmpty)
      return _buildEmptyChart('No sales data available');

    final monthData = _salesByMonth;
    final entries = monthData.entries.toList();

    final spots = List.generate(
      entries.length,
      (i) => FlSpot(i.toDouble(), entries[i].value),
    );

    return Opacity(
      opacity: _fadeAnimation.value,
      child: Transform.translate(
        offset: Offset(0, _slideAnimation.value),
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Track your total sales amount for each month',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Color(0xFF6366F1).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          semanticLabel: 'Calendar Month',
                          size: 12,
                          color: Color(0xFF6366F1),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${entries.length} months',
                          style: const TextStyle(
                            color: Color(0xFF6366F1),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.3,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6366F1),
                            const Color(0xFFB388FF),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        barWidth: 4,
                        isStrokeCapRound: true,
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF6366F1).withValues(alpha: 0.2),
                              Color(0xFFB388FF).withValues(alpha: 0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        dotData: FlDotData(show: false),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          interval: 1,
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value % 1 != 0) return const SizedBox.shrink();
                            final index = value.toInt();
                            if (index >= 0 && index < entries.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  entries[index].key,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          reservedSize: 28,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              '\u20b9${(value >= 1000 ? (value / 1000).toStringAsFixed(1) + 'k' : value.toInt().toString())}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          reservedSize: 42,
                        ),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(interval: 1, showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(interval: 1, showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                        left: BorderSide(color: Colors.grey[200]!, width: 1),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey[200]!,
                        strokeWidth: 1,
                        dashArray: [3, 3],
                      ),
                    ),
                    minY: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // WEEK-WISE SALES CHART
  Widget _buildWeekWiseSalesChart() {
    if (filteredSales.isEmpty)
      return _buildEmptyChart('No sales data available');

    final weekData = _salesByWeek;
    final entries = weekData.entries.toList();

    return Opacity(
      opacity: _fadeAnimation.value,
      child: Transform.translate(
        offset: Offset(0, _slideAnimation.value),
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context).salesByWeek,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                      letterSpacing: -0.3,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4081).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFF4081).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_view_week,
                          semanticLabel: 'Calendar View Week',
                          size: 12,
                          color: Color(0xFFFF4081),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Last 8W',
                          style: TextStyle(
                            color: Color(0xFFFF4081),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    barGroups: entries
                        .asMap()
                        .entries
                        .map(
                          (entry) => BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value.value,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF4081),
                                    Color(0xFFFFAB40),
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                width: 22,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(6),
                                  topRight: Radius.circular(6),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          interval: 1,
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < entries.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  entries[index].key,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          reservedSize: 28,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              '\u20b9${(value >= 1000 ? (value / 1000).toStringAsFixed(1) + 'k' : value.toInt().toString())}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          reservedSize: 42,
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(interval: 1, showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(interval: 1, showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                        left: BorderSide(color: Colors.grey[200]!, width: 1),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey[200]!,
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ),
                    alignment: BarChartAlignment.spaceAround,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Track your sales week-over-week to identify patterns',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // YEAR-WISE SALES CHART
  Widget _buildYearWiseSalesChart() {
    if (filteredSales.isEmpty)
      return _buildEmptyChart('No sales data available');

    final yearData = _salesByYear;
    final entries = yearData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context).salesByYear,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFB388FF,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFFB388FF,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.date_range,
                              semanticLabel: 'Date Range',
                              size: 14,
                              color: Color(0xFFB388FF),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${entries.length} year(s)',
                              style: const TextStyle(
                                color: Color(0xFFB388FF),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        barGroups: entries
                            .asMap()
                            .entries
                            .map(
                              (entry) => BarChartGroupData(
                                x: entry.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: entry.value.value,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFB388FF),
                                        Color(0xFF6366F1),
                                      ],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                    width: 32,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      topRight: Radius.circular(8),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              interval: 1,
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < entries.length)
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(
                                      entries[index].key,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  );
                                return const SizedBox.shrink();
                              },
                              reservedSize: 40,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  '\u20b9${(value >= 1000 ? (value / 1000).toStringAsFixed(1) + 'k' : value.toInt().toString())}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              reservedSize: 50,
                            ),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(
                              interval: 1,
                              showTitles: false,
                            ),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(
                              interval: 1,
                              showTitles: false,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey[200]!,
                              width: 1,
                            ),
                            left: BorderSide(
                              color: Colors.grey[200]!,
                              width: 1,
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey[200]!,
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          ),
                        ),
                        alignment: BarChartAlignment.spaceBetween,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yearly Overview',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  e.key,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '\u20b9${e.value.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6366F1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _dashboardProductDisplayName(Map<String, dynamic> sale) {
    String clean(String value) {
      final v = value.trim();
      if (v.isEmpty || AnalyticsEngine.isPlaceholderProductName(v)) return '';
      return AnalyticsEngine.formatProductName(v);
    }
    for (final key in const ['product_name', 'product', 'item', 'description']) {
      final value = clean((sale[key] ?? '').toString());
      if (value.isNotEmpty) return value;
    }
    final rawItems = sale['items'] ?? sale['line_items'];
    if (rawItems is List) {
      final names = <String>[];
      for (final raw in rawItems) {
        if (raw is! Map) continue;
        for (final key in const ['product_name', 'product', 'item', 'description']) {
          final value = clean((raw[key] ?? '').toString());
          if (value.isNotEmpty && !names.contains(value)) { names.add(value); break; }
        }
      }
      if (names.isNotEmpty) return names.length == 1 ? names.first : '${names.first} + ${names.length - 1} more';
    }
    return '';
  }

  // Analytics chart source:
  // Keep KPI/filter semantics unchanged, but never hide historical analytics
  // merely because the selected filter (e.g. Today) has no rows.
  //
  // Example: a shop can have 500 historical bills and zero bills today.
  // Pie/Radar/Monthly charts should still visualize that existing history.
  List<Map<String, dynamic>> _chartSalesSource() {
    if (filteredSales.isNotEmpty) return filteredSales;
    return sales;
  }

  double _chartNumber(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  Map<String, Map<String, dynamic>> _buildChartProductAnalytics(
    List<Map<String, dynamic>> source,
  ) {
    final result = <String, Map<String, dynamic>>{};
    void addLine(String rawName, double total, double qty) {
      final name = rawName.trim();
      if (name.isEmpty || AnalyticsEngine.isPlaceholderProductName(name)) return;
      final displayName = AnalyticsEngine.formatProductName(name);
      final entry = result.putIfAbsent(displayName, () => <String, dynamic>{'total': 0.0, 'count': 0, 'quantity': 0.0});
      entry['total'] = (entry['total'] as double) + total;
      entry['count'] = (entry['count'] as int) + 1;
      entry['quantity'] = (entry['quantity'] as double) + qty;
    }
    for (final sale in source) {
      final rawItems = sale['items'] ?? sale['line_items'];
      if (rawItems is List && rawItems.isNotEmpty) {
        for (final raw in rawItems) {
          if (raw is! Map) continue;
          final name = (raw['product_name'] ?? raw['product'] ?? raw['item'] ?? raw['description'] ?? '').toString();
          final qty = _chartNumber(raw['quantity'] ?? raw['qty'] ?? raw['units'] ?? 1);
          final lineTotal = _chartNumber(raw['line_total'] ?? raw['total_with_tax'] ?? raw['total']);
          final unitPrice = _chartNumber(raw['unit_price'] ?? raw['price']);
          addLine(name, lineTotal > 0 ? lineTotal : unitPrice * qty, qty);
        }
      } else {
        final name = (sale['product_name'] ?? sale['product'] ?? sale['item'] ?? sale['name'] ?? sale['description'] ?? '').toString();
        final total = _chartNumber(sale['invoice_total'] ?? sale['total_amount'] ?? sale['grand_total'] ?? sale['final_amount'] ?? sale['totalAmount'] ?? sale['total']);
        final qty = _chartNumber(sale['quantity'] ?? sale['qty'] ?? sale['units'] ?? 1);
        addLine(name, total, qty);
      }
    }
    final grandTotal = result.values.fold<double>(0.0, (sum, value) => sum + (value['total'] as double? ?? 0.0));
    for (final data in result.values) {
      final total = data['total'] as double? ?? 0.0;
      data['percentage'] = grandTotal > 0 ? (total / grandTotal) * 100.0 : 0.0;
    }
    return result;
  }

  Map<String, Map<int, double>> _buildChartMonthlyProductSales(
    List<Map<String, dynamic>> source,
  ) {
    final result = <String, Map<int, double>>{};
    final now = DateTime.now();
    var usable = source.where((sale) => _getLocalDate(sale).year == now.year).toList();
    if (usable.isEmpty) usable = source;
    for (final sale in usable) {
      final date = _getLocalDate(sale);
      final rawItems = sale['items'] ?? sale['line_items'];
      if (rawItems is List && rawItems.isNotEmpty) {
        for (final raw in rawItems) {
          if (raw is! Map) continue;
          final name = (raw['product_name'] ?? raw['product'] ?? raw['item'] ?? raw['description'] ?? '').toString();
          if (name.trim().isEmpty || AnalyticsEngine.isPlaceholderProductName(name)) continue;
          final product = AnalyticsEngine.formatProductName(name);
          final qty = _chartNumber(raw['quantity'] ?? raw['qty'] ?? raw['units'] ?? 1);
          final lineTotal = _chartNumber(raw['line_total'] ?? raw['total_with_tax'] ?? raw['total']);
          final unitPrice = _chartNumber(raw['unit_price'] ?? raw['price']);
          final value = lineTotal > 0 ? lineTotal : unitPrice * qty;
          final monthMap = result.putIfAbsent(product, () => <int, double>{});
          monthMap[date.month] = (monthMap[date.month] ?? 0.0) + value;
        }
      } else {
        final name = (sale['product_name'] ?? sale['product'] ?? sale['item'] ?? sale['name'] ?? '').toString();
        if (name.trim().isEmpty || AnalyticsEngine.isPlaceholderProductName(name)) continue;
        final product = AnalyticsEngine.formatProductName(name);
        final value = _chartNumber(sale['invoice_total'] ?? sale['total_amount'] ?? sale['grand_total'] ?? sale['final_amount'] ?? sale['totalAmount'] ?? sale['total']);
        final monthMap = result.putIfAbsent(product, () => <int, double>{});
        monthMap[date.month] = (monthMap[date.month] ?? 0.0) + value;
      }
    }
    return result;
  }

  // MONTHLY SALES PER PRODUCT LINE CHART
  Widget _buildMonthlyProductChart() {
    final source = _chartSalesSource();
    if (source.isEmpty) return _buildEmptyChart('No sales data available');

    final monthly = _buildChartMonthlyProductSales(source);
    if (monthly.isEmpty) return _buildEmptyChart('No product data');

    final totals = <String, double>{};
    monthly.forEach((prod, months) {
      totals[prod] = months.values.fold(0.0, (a, b) => a + b);
    });
    final sortedProds = totals.keys.toList()
      ..sort((a, b) => totals[b]!.compareTo(totals[a]!));
    final selected = sortedProds.take(5).toList();

    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFFFF4081),
      const Color(0xFFB388FF),
      const Color(0xFFFFAB40),
      const Color(0xFF00E676),
    ];

    final lines = <LineChartBarData>[];
    for (var i = 0; i < selected.length; i++) {
      final prod = selected[i];
      final data = monthly[prod]!;
      final spots = <FlSpot>[];
      for (int m = 1; m <= 12; m++) {
        spots.add(FlSpot(m.toDouble(), data[m] ?? 0.0));
      }
      final color = colors[i % colors.length];
      lines.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: color.withValues(alpha: 0.15),
          ),
        ),
      );
    }

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).monthlySalesDesc,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey[100]!,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: Colors.grey[100]!,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 1 && idx <= 12) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              monthNames[idx - 1],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '\u20b9${value >= 1000 ? (value / 1000).toStringAsFixed(1) + 'k' : value.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      reservedSize: 45,
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(interval: 1, showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(interval: 1, showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                    left: BorderSide(color: Colors.grey[200]!, width: 1),
                  ),
                ),
                lineBarsData: lines,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: selected.asMap().entries.map((entry) {
              final prod = entry.value;
              final color = colors[entry.key % colors.length];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      prod,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1F2937),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }


  Widget _buildEnhancedBarChart() {
    try {
      if (filteredSales.isEmpty)
        return _buildEmptyChart(AppLocalizations.of(context).noSalesData);

      final map = <String, double>{};
      for (final s in filteredSales) {
        try {
          final p = s['product'] ?? s['product_name'] ?? 'Unknown';
          final val = s['total'] is num ? (s['total'] as num).toDouble() : (double.tryParse(s['total']?.toString() ?? '0') ?? 0.0);
          map[p] = (map[p] ?? 0.0) + val;
        } catch (e) {
          if (kDebugMode) debugPrint('Error processing sale entry: $e');
          continue;
        }
      }

      if (map.isEmpty) {
        return _buildEmptyChart(AppLocalizations.of(context).noSalesData);
      }

      final items = map.entries.toList();
      items.sort((a, b) => b.value.compareTo(a.value));
      final topItems = items.take(6).toList();

      final List<Color> gradientColors = [
        _filterColor,
        _filterColor.withValues(alpha: 0.7),
      ];

      final maxValue = topItems.isNotEmpty
          ? topItems.map((e) => e.value).reduce((a, b) => a > b ? a : b)
          : 1.0;

      if (maxValue <= 0) {
        return _buildEmptyChart(AppLocalizations.of(context).noSalesData);
      }

      return AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: GlassContainer(
                padding: const EdgeInsets.all(14),
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context).revenueLeaders,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                            letterSpacing: -0.3,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.leaderboard,
                                semanticLabel: 'Leaderboard',
                                size: 14,
                                color: Color(0xFF6366F1),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Top ${topItems.length} ${AppLocalizations.of(context).products}',
                                style: const TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 220,
                      child: BarChart(
                        BarChartData(
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              tooltipBgColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF151515)
                                  : Colors.white,
                              tooltipPadding: const EdgeInsets.all(12),
                              tooltipBorder: BorderSide(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                try {
                                  if (groupIndex < topItems.length &&
                                      totalSales > 0) {
                                    return BarTooltipItem(
                                      '${topItems[groupIndex].key}\n',
                                      TextStyle(
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      children: [
                                        TextSpan(
                                          text:
                                              '₹${rod.toY.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            color: Color(0xFF6366F1),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const TextSpan(text: '\n'),
                                        TextSpan(
                                          text:
                                              '${((topItems[groupIndex].value / totalSales) * 100).toStringAsFixed(1)}% of total',
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                } catch (_) {}
                                return null;
                              },
                            ),
                          ),
                          barGroups: topItems.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: item.value.clamp(0.0, double.infinity),
                                  gradient: LinearGradient(
                                    colors: [
                                      gradientColors[0],
                                      gradientColors[1],
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                  width: 28,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                  ),
                                  backDrawRodData: BackgroundBarChartRodData(
                                    show: true,
                                    toY: maxValue * 1.1,
                                    color: Colors.grey[100]!,
                                  ),
                                ),
                              ],
                              showingTooltipIndicators: [0],
                            );
                          }).toList(),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                interval: 1,
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index >= 0 && index < topItems.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Text(
                                        topItems[index].key.length > 10
                                            ? '${topItems[index].key.substring(0, 10)}..'
                                            : topItems[index].key,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                                reservedSize: 40,
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      '₹${value.toInt()}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  );
                                },
                                reservedSize: 42,
                              ),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(
                                interval: 1,
                                showTitles: false,
                              ),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(
                                interval: 1,
                                showTitles: false,
                              ),
                            ),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                              left: BorderSide(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: maxValue * 1.1 / 5,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.grey[100]!,
                              strokeWidth: 1,
                              dashArray: [4, 4],
                            ),
                          ),
                          alignment: BarChartAlignment.spaceBetween,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Legend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: gradientColors),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${AppLocalizations.of(context).revenueLeaders} per product',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error building enhanced bar chart: $e');
      return _buildEmptyChart(AppLocalizations.of(context).noSalesData);
    }
  }

  // ENHANCED LINE CHART WITH AREA GRADIENT
  Widget _buildEnhancedLineChart() {
    if (filteredSales.isEmpty)
      return _buildEmptyChart(AppLocalizations.of(context).noProductData);

    // aggregate sales by day -> DateTime key
    final map = <DateTime, double>{};
    for (final s in filteredSales) {
      final dt = engine.getLocalDate(s);
      final day = DateTime(dt.year, dt.month, dt.day);
      final val = s['total'] is num ? (s['total'] as num).toDouble() : 0.0;
      map[day] = (map[day] ?? 0.0) + val;
    }

    final sortedEntries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final recentEntries = sortedEntries.length > 7
        ? sortedEntries.sublist(sortedEntries.length - 7)
        : sortedEntries;

    final spots = List.generate(
      recentEntries.length,
      (i) => FlSpot(i.toDouble(), recentEntries[i].value),
    );

    // build a list of labels for bottom axis
    final labels = recentEntries
        .map((e) => "${e.key.day}/${e.key.month}")
        .toList();

    final List<Color> gradientColors = [
      _filterColor,
      _filterColor.withValues(alpha: 0.5),
    ];

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: GlassContainer(
              padding: const EdgeInsets.all(14),
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${AppLocalizations.of(context).salesTrend}${_currentFilterLabel.isNotEmpty ? ' (${_currentFilterLabel})' : ''}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.timeline,
                              semanticLabel: 'Timeline',
                              size: 14,
                              color: Color(0xFF6366F1),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppLocalizations.of(context).last7Days,
                              style: const TextStyle(
                                color: Color(0xFF6366F1),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            tooltipBgColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF151515)
                                : Colors.white,
                            tooltipPadding: const EdgeInsets.all(12),
                            tooltipBorder: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                            getTooltipItems: (spots) {
                              return spots.map((spot) {
                                return LineTooltipItem(
                                  '${recentEntries[spot.x.toInt()].key}\n',
                                  TextStyle(
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '₹${spot.y.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Color(0xFF6366F1),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList();
                            },
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            curveSmoothness: 0.3,
                            gradient: LinearGradient(
                              colors: gradientColors,
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            barWidth: 4,
                            isStrokeCapRound: true,
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: gradientColors
                                    .map(
                                      (color) => color.withValues(alpha: 0.1),
                                    )
                                    .toList(),
                              ),
                            ),
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.white,
                                  strokeWidth: 2,
                                  strokeColor: const Color(0xFF6366F1),
                                );
                              },
                            ),
                          ),
                        ],
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              interval: 1,
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 &&
                                    index < recentEntries.length) {
                                  // use precomputed labels list for axis
                                  final idx = index;
                                  if (idx >= 0 && idx < labels.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        labels[idx],
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }
                                  return const Text('');
                                }
                                return const Text('');
                              },
                              reservedSize: 32,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    '₹${value.toInt()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                );
                              },
                              reservedSize: 40,
                            ),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(
                              interval: 1,
                              showTitles: false,
                            ),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(
                              interval: 1,
                              showTitles: false,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey[100]!.withValues(alpha: 0.8),
                            strokeWidth: 1,
                            dashArray: [3, 3],
                          ),
                        ),
                        minY: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Trend indicator
                  Row(
                    children: [
                      Icon(
                        _calculateTrend(recentEntries) >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: _calculateTrend(recentEntries) >= 0
                            ? const Color(0xFF6366F1)
                            : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _calculateTrend(recentEntries) >= 0
                            ? AppLocalizations.of(context).upwardTrend
                            : AppLocalizations.of(context).downwardTrend,
                        style: TextStyle(
                          fontSize: 12,
                          color: _calculateTrend(recentEntries) >= 0
                              ? const Color(0xFF6366F1)
                              : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_calculateTrend(recentEntries).abs().toStringAsFixed(1)}% ${AppLocalizations.of(context).avgChange}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double _calculateTrend(List<MapEntry<dynamic, double>> entries) {
    if (entries.length < 2) return 0.0;
    final first = entries.first.value;
    final last = entries.last.value;
    if (first == 0) return 0.0;
    return ((last - first) / first) * 100;
  }

  // Show information dialog explaining chart meaning
  void _showChartInfo(String key) {
    String title = '';
    String message = '';
    final l = AppLocalizations.of(context);
    switch (key) {
      case 'bar':
        title = l.revenueLeaders;
        message = l.revenueLeadersDesc;
        break;
      case 'line':
        title = l.salesTrend;
        message = l.salesTrendDesc;
        break;
      case 'pie':
        title = l.revenueDistribution;
        message = l.revenueDistributionDesc;
        break;
      case 'radar':
        title = l.quantityDistribution;
        message = l.quantityDistributionDesc;
        break;
      case 'month':
        title = l.salesByMonth;
        message = l.monthlySalesDesc;
        break;
      case 'week':
        title = l.salesByWeek;
        message = l.weeklySalesDesc;
        break;
      case 'year':
        title = l.salesByYear;
        message = l.yearlySalesDesc;
        break;
      default:
        title = l.about;
        message = '';
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // BEAUTIFUL PIE CHART - REVENUE DISTRIBUTION (BY PRICE / SALE VALUE)
  Widget _buildPieChart() {
    final source = _chartSalesSource();
    if (source.isEmpty)
      return _buildEmptyChart(AppLocalizations.of(context).noProductData);

    final productData = _buildChartProductAnalytics(source);
    if (productData.isEmpty) {
      return _buildEmptyChart(AppLocalizations.of(context).noProductData);
    }
    // Sort by revenue (total sale value)
    final products = productData.entries.toList();
    products.sort((a, b) {
      final bVal = (b.value['total'] as num?)?.toDouble() ?? 0.0;
      final aVal = (a.value['total'] as num?)?.toDouble() ?? 0.0;
      return bVal.compareTo(aVal);
    });
    final topProducts = products.take(5).toList();
    final grandTotal = topProducts.fold<double>(0, (s, e) => s + ((e.value['total'] as num?)?.toDouble() ?? 0.0));

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.pie_chart_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Revenue Split',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            Text(
                              'Top products by sale value',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'TOP 5',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF6366F1),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Donut chart ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: SizedBox(
                      height: 230,
                      child: Row(
                        children: [
                          // Chart half
                          Expanded(
                            flex: 5,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    sectionsSpace: 3,
                                    centerSpaceRadius: 58,
                                    startDegreeOffset: -90,
                                    sections: topProducts.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final product = entry.value;
                                      final value = (product.value['total'] as num?)?.toDouble() ?? 0.0;
                                      final perc = grandTotal > 0 ? (value / grandTotal * 100) : 0.0;
                                      final color = _getChartColor(index);
                                      return PieChartSectionData(
                                        color: color,
                                        value: value,
                                        title: perc >= 10 ? '${perc.toStringAsFixed(0)}%' : '',
                                        radius: 52,
                                        titleStyle: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  swapAnimationDuration: const Duration(milliseconds: 600),
                                  swapAnimationCurve: Curves.easeOutCubic,
                                ),
                                // Centre label
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '₹${_formatCompactNumber(grandTotal)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF111827),
                                      ),
                                    ),
                                    Text(
                                      'Total',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Legend half
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: topProducts.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final product = entry.value;
                                  final val = (product.value['total'] as num?)?.toDouble() ?? 0.0;
                                  final perc = grandTotal > 0 ? (val / grandTotal * 100) : 0.0;
                                  final color = _getChartColor(index);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _cleanProductName(product.key, ''),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF374151),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    '₹${_formatCompactNumber(val)}',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: color,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${perc.toStringAsFixed(1)}%',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 10,
                                                      color: Colors.grey[400],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              // Mini progress bar
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: grandTotal > 0 ? (val / grandTotal).clamp(0.0, 1.0) : 0.0,
                                                  backgroundColor: color.withValues(alpha: 0.12),
                                                  valueColor: AlwaysStoppedAnimation<Color>(color),
                                                  minHeight: 4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getChartColor(int index) {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      AppColors.info,
      Colors.amber,
      Colors.deepOrangeAccent,
    ];
    return colors[index % colors.length];
  }

  String _formatCompactNumber(double number) {
    if (number >= 10000000)
      return '${(number / 10000000).toStringAsFixed(1)}Cr';
    if (number >= 100000) return '${(number / 100000).toStringAsFixed(1)}L';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toStringAsFixed(0);
  }

  // Define Badge for pie chart
  Widget _Badge({
    required IconData icon,
    required double size,
    required Color color,
  }) {
    return AnimatedContainer(
      duration: PieChart.defaultDuration,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            offset: const Offset(0, 3),
            blurRadius: 5,
          ),
        ],
      ),
      padding: EdgeInsets.all(size * .15),
      child: Center(
        child: Icon(icon, size: size * .5, color: color),
      ),
    );
  }

  // BEAUTIFUL RADAR CHART - MOST SOLD BY QUANTITY
  Widget _buildRadarChart() {
    try {
      final source = _chartSalesSource();
      if (source.isEmpty)
        return _buildEmptyChart(AppLocalizations.of(context).noProductData);

      final productData = _buildChartProductAnalytics(source);
      if (productData.isEmpty) {
        return _buildEmptyChart(AppLocalizations.of(context).noProductData);
      }

      // Build quantity map
      final qtyMap = <String, int>{};
      productData.forEach((product, data) {
        final qty = data?['quantity'];
        int qtyInt = 0;
        if (qty is int) qtyInt = qty;
        else if (qty is num) qtyInt = qty.toInt();
        qtyMap[product] = qtyInt;
      });

      var topProducts = qtyMap.entries.toList();
      topProducts.sort((a, b) => b.value.compareTo(a.value));
      topProducts = topProducts.take(6).toList();

      final totalQty = topProducts.fold<int>(0, (s, e) => s + e.value);
      final maxQty = topProducts.isNotEmpty ? topProducts.first.value.toDouble() : 1.0;

      // Build percentages for radar (relative to max)
      final radarEntries = topProducts.map((e) => e.value.toDouble() / maxQty * 100).toList();

      // fl_chart RadarChart requires at least 3 data points
      while (topProducts.length < 3) {
        topProducts.add(const MapEntry('—', 0));
        radarEntries.add(0.0);
      }

      return AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.radar, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Volume Radar',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Most sold products by quantity',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$totalQty units',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Radar Chart ────────────────────────────────────────
                    SizedBox(
                      height: 240,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: RadarChart(
                          RadarChartData(
                            radarBackgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.5),
                            borderData: FlBorderData(show: false),
                            radarBorderData: BorderSide(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                            tickCount: 4,
                            ticksTextStyle: const TextStyle(
                              color: Colors.transparent,
                              fontSize: 10,
                            ),
                            tickBorderData: BorderSide(
                              color: Colors.white.withValues(alpha: 0.06),
                              width: 1,
                            ),
                            gridBorderData: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 1,
                            ),
                            radarShape: RadarShape.polygon,
                            getTitle: (index, angle) {
                              try {
                                if (index < topProducts.length) {
                                  final clean = _cleanProductName(topProducts[index].key, '');
                                  return RadarChartTitle(
                                    text: clean.length > 7 ? '${clean.substring(0, 6)}..' : clean,
                                    angle: angle,
                                    positionPercentageOffset: 0.12,
                                  );
                                }
                              } catch (_) {}
                              return RadarChartTitle(text: '', angle: angle);
                            },
                            titleTextStyle: GoogleFonts.poppins(
                              color: Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            dataSets: [
                              RadarDataSet(
                                fillColor: const Color(0xFF6366F1).withValues(alpha: 0.35),
                                borderColor: const Color(0xFF6366F1),
                                entryRadius: 5,
                                dataEntries: radarEntries
                                    .map((v) => RadarEntry(value: v.clamp(0.0, 100.0)))
                                    .toList(),
                                borderWidth: 2.5,
                              ),
                              RadarDataSet(
                                fillColor: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                                borderColor: const Color(0xFF06B6D4).withValues(alpha: 0.7),
                                entryRadius: 3,
                                dataEntries: radarEntries
                                    .map((v) => RadarEntry(value: (v * 0.6).clamp(0.0, 100.0)))
                                    .toList(),
                                borderWidth: 1.5,
                              ),
                            ],
                          ),
                          swapAnimationDuration: const Duration(milliseconds: 800),
                          swapAnimationCurve: Curves.easeOutQuint,
                        ),
                      ),
                    ),
                    // ── Quantity bar legend ────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        children: topProducts.take(4).toList().asMap().entries.map((entry) {
                          final index = entry.key;
                          final product = entry.value;
                          if (product.key == '—') return const SizedBox.shrink();
                          final qty = product.value;
                          final pct = maxQty > 0 ? qty / maxQty : 0.0;
                          final colors = [
                            const Color(0xFF6366F1),
                            const Color(0xFF06B6D4),
                            const Color(0xFF10B981),
                            const Color(0xFFF59E0B),
                          ];
                          final color = colors[index % colors.length];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    _cleanProductName(product.key, ''),
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.white60,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.06),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: pct.clamp(0.0, 1.0),
                                        child: Container(
                                          height: 6,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [color, color.withValues(alpha: 0.6)],
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$qty',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error building radar chart: $e');
      return _buildEmptyChart(AppLocalizations.of(context).noProductData);
    }
  }

  // Refactored metric card
  Widget _buildPremiumMiniCard(
    String label,
    String value,
    IconData icon,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF374151),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  // TRANSACTION HEAT MAP (Advanced Visualization)
  Widget _buildTransactionHeatMap() {
    // Group transactions by hour of day
    final hourCounts = <int, int>{};
    for (var i = 0; i < 24; i++) {
      hourCounts[i] = 0;
    }

    for (final sale in filteredSales) {
      if (sale['date'] is String) {
        try {
          final date = DateTime.parse(sale['date'] as String);
          hourCounts[date.hour] = (hourCounts[date.hour] ?? 0) + 1;
        } catch (e) {
          // Skip invalid dates
        }
      }
    }

    final maxCount = hourCounts.values.isEmpty
        ? 1
        : hourCounts.values.reduce((a, b) => a > b ? a : b).toDouble();
    final totalTransactions = filteredSales.length;
    final peakHour = hourCounts.entries.isEmpty
        ? 0
        : hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    final avgPerHour = totalTransactions == 0 ? 0.0 : totalTransactions / 24.0;

    final spots = List.generate(
      24,
      (index) => FlSpot(index.toDouble(), (hourCounts[index] ?? 0).toDouble()),
    );

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: GlassContainer(
              padding: const EdgeInsets.all(20),
              borderRadius: BorderRadius.circular(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Realtime Transaction Activity',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2937),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Live transactions per hour (auto-updates with new sales)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    height: 220,
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: 23,
                        minY: 0,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: const Color(0xFF06B6D4),
                            barWidth: 3,
                            dotData: FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(
                                    0xFF06B6D4,
                                  ).withValues(alpha: 0.4),
                                  const Color(
                                    0xFF06B6D4,
                                  ).withValues(alpha: 0.05),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                if (value % (maxCount > 5 ? 2 : 1) != 0) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              interval: 1,
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (value, meta) {
                                final hour = value.toInt();
                                if (hour % 3 != 0) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  '$hour:00',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(
                              interval: 1,
                              showTitles: false,
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(
                              interval: 1,
                              showTitles: false,
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.white.withValues(alpha: 0.04),
                            strokeWidth: 1,
                          ),
                          getDrawingVerticalLine: (value) => FlLine(
                            color: Colors.white.withValues(alpha: 0.04),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _heatMapStat('Peak Hour', '$peakHour:00'),
                      _heatMapStat('Total Transactions', '$totalTransactions'),
                      _heatMapStat(
                        'Avg per Hour',
                        avgPerHour.toStringAsFixed(1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _heatMapLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _heatMapStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF06B6D4),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  void _showAllTransactionsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'All Transactions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        semanticLabel: 'Close',
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // List
              Expanded(
                child: filteredSales.isEmpty
                    ? const Center(
                        child: Text(
                          'No transactions found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredSales.length,
                        itemBuilder: (context, index) {
                          final s = filteredSales[index];
                          final totalVal = s['total'] is num
                              ? (s['total'] as num).toDouble()
                              : 0.0;
                          final localDate = engine.getLocalDate(s);
                          final h = localDate.hour == 0
                              ? 12
                              : (localDate.hour > 12
                                    ? localDate.hour - 12
                                    : localDate.hour);
                          final amPm = localDate.hour >= 12 ? 'PM' : 'AM';
                          final formattedDate =
                              '${localDate.day.toString().padLeft(2, '0')}/${localDate.month.toString().padLeft(2, '0')}/${localDate.year}  ${h.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')} $amPm';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF6366F1),
                                          Color(0xFF8B5CF6),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.shopping_bag,
                                      semanticLabel: 'Shopping Bag',
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _cleanProductName(
                                            s['product']?.toString() ??
                                                'Unknown',
                                            s['barcode']?.toString() ?? '',
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: Color(0xFF1F2937),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.inventory,
                                              semanticLabel: 'Inventory',
                                              size: 12,
                                              color: Colors.white54,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              'Qty: ${s['quantity']} @ ₹${(s['price'] ?? 0)}',
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 11,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.calendar_today,
                                              semanticLabel: 'Calendar Today',
                                              size: 12,
                                              color: Colors.white54,
                                            ),
                                            const SizedBox(width: 3),
                                            Flexible(
                                              child: Text(
                                                formattedDate,
                                                style: const TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 11,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '\u20b9${totalVal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF6366F1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ENHANCED RECENT TRANSACTIONS
  Widget _buildEnhancedRecentTransactions() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: GlassContainer(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context).bills,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                            letterSpacing: -0.3,
                          ),
                        ),
                        TextButton(
                          onPressed: _showAllTransactionsModal,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            backgroundColor: const Color(
                              0xFF6366F1,
                            ).withValues(alpha: 0.1),
                          ),
                          child: Row(
                            children: [
                              Text(
                                AppLocalizations.of(context).reports,
                                style: TextStyle(
                                  color: const Color(0xFF6366F1),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                semanticLabel: 'Arrow Forward Ios',
                                size: 12,
                                color: const Color(0xFF6366F1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (loading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            const SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                color: Color(0xFF6366F1),
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context).noSalesData,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (filteredSales.isEmpty)
                    _buildEmptyState()
                  else
                    ...recentSales.take(10).map((s) {
                      final dynamic rawTotal = s['total_amount'] ?? s['total'];
                      final totalVal = rawTotal is num
                          ? rawTotal.toDouble()
                          : double.tryParse(rawTotal?.toString() ?? '0') ?? 0.0;
                      final localDate = engine.getLocalDate(s);
                      final h = localDate.hour == 0
                          ? 12
                          : (localDate.hour > 12
                                ? localDate.hour - 12
                                : localDate.hour);
                      final amPm = localDate.hour >= 12 ? 'PM' : 'AM';
                      final formattedDate =
                          '${localDate.day.toString().padLeft(2, '0')}/${localDate.month.toString().padLeft(2, '0')}/${localDate.year}  ${h.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')} $amPm';

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Icon
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF6366F1),
                                        Color(0xFF8B5CF6),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF6366F1,
                                        ).withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.shopping_bag,
                                    semanticLabel: 'Shopping Bag',
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Title + subtitle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Builder(
                                        builder: (context) {
                                          final productName = _dashboardProductDisplayName(s);
                                          final invoice = (s['invoice_number'] ?? s['sale_id'] ?? s['_bill_id'] ?? '').toString().trim();
                                          final title = productName.isNotEmpty
                                              ? productName
                                              : ((s['customer_name'] ?? s['customer_phone'] ?? 'Walk-in Customer').toString());
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF1F2937)), overflow: TextOverflow.ellipsis),
                                              if (invoice.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text('Invoice: $invoice', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5), overflow: TextOverflow.ellipsis),
                                              ],
                                            ],
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.inventory,
                                            semanticLabel: 'Inventory',
                                            size: 12,
                                            color: Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            'Status: ${s['payment_status'] ?? 'N/A'}',
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.calendar_today,
                                            semanticLabel: 'Calendar Today',
                                            size: 12,
                                            color: Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              formattedDate,
                                              style: const TextStyle(
                                                color: Color(0xFF64748B),
                                                fontSize: 11,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Amount + badge
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${_formatCompactNumber(totalVal)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF6366F1),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF6366F1,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            semanticLabel: 'Check Circle',
                                            size: 9,
                                            color: Color(0xFF6366F1),
                                          ),
                                          SizedBox(width: 3),
                                          Text(
                                            'Done',
                                            style: TextStyle(
                                              color: Color(0xFF0097A7),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  if (recentSales.length > 10)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _showAllTransactionsModal,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6366F1),
                            backgroundColor: const Color(
                              0xFF6366F1,
                            ).withValues(alpha: 0.08),
                            side: const BorderSide(
                              color: Color(0xFF6366F1),
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'View All ${recentSales.length} Bills →',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingInvoices() {
    final l10n = AppLocalizations.of(context);
    // Sort by due date (soonest first)
    final sortedInvoices = List<Map<String, dynamic>>.from(_pendingInvoices);
    sortedInvoices.sort((a, b) {
      final da = a['due_date'] != null
          ? DateTime.tryParse(a['due_date']) ?? DateTime(9999)
          : DateTime(9999);
      final db = b['due_date'] != null
          ? DateTime.tryParse(b['due_date']) ?? DateTime(9999)
          : DateTime(9999);
      return da.compareTo(db);
    });

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  semanticLabel: 'Warning Amber Rounded',
                  color: Colors.amber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.pendingPayment,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    '${sortedInvoices.length} invoices require attention',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/invoices'),
                child: Text(
                  l10n.viewAll,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: math.min(sortedInvoices.length, 5),
              itemBuilder: (context, index) {
                final inv = sortedInvoices[index];
                final dueDateStr = inv['due_date']?.toString() ?? 'N/A';
                DateTime? dueDate = DateTime.tryParse(dueDateStr);
                final isOverdue =
                    dueDate != null && dueDate.isBefore(DateTime.now());
                final amount = inv['total'] ?? 0.0;
                final paid = inv['paid_amount'] ?? 0.0;
                final balance = amount - paid;

                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isOverdue
                          ? Colors.red.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _cleanProductName(
                          inv['product']?.toString() ?? 'Unknown',
                          inv['barcode']?.toString() ?? '',
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${balance.toStringAsFixed(0)} balance',
                        style: TextStyle(
                          fontSize: 11,
                          color: isOverdue ? Colors.red : Colors.indigo,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            semanticLabel: 'Calendar Today',
                            size: 10,
                            color: isOverdue ? Colors.red : Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dueDate != null
                                ? '${dueDate.day}/${dueDate.month}/${dueDate.year}'
                                : 'No date',
                            style: TextStyle(
                              fontSize: 12,
                              color: isOverdue ? Colors.red : Colors.grey[600],
                              fontWeight: isOverdue
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getSalesAnalysisSentence() {
    final l10n = AppLocalizations.of(context);
    if (_todayRevenue > _yesterdayRevenue) {
      final diff = _todayRevenue - _yesterdayRevenue;
      return l10n.analysisAmazing
          .replaceFirst('{0}', _formatCompactNumber(_todayRevenue))
          .replaceFirst('{1}', _formatCompactNumber(diff));
    } else if (_todayRevenue < _yesterdayRevenue && _yesterdayRevenue > 0) {
      final diff = _yesterdayRevenue - _todayRevenue;
      return l10n.analysisProgressing
          .replaceFirst('{0}', _formatCompactNumber(_todayRevenue))
          .replaceFirst('{1}', _formatCompactNumber(diff));
    } else if (_todayRevenue == 0 && _yesterdayRevenue == 0) {
      // If we have any history at all, don't show the "First Account" welcome message
      return (engine.totalSales > 50)
          ? "Shop history found! Ready for today's first transaction."
          : l10n.analysisWaiting;
    } else {
      return l10n.analysisMatch.replaceFirst(
        '{0}',
        _todayRevenue.toStringAsFixed(0),
      );
    }
  }

  Widget _buildModernPerformanceOverview() {
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) =>
          Opacity(opacity: _fadeAnimation.value, child: child),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 4,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF4F46E5),
                        Color(0xFF10B981),
                        Color(0xFFF59E0B),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(
                                    0xFF4F46E5,
                                  ).withValues(alpha: 0.15),
                                  const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.insights_rounded,
                              semanticLabel: 'Insights Rounded',
                              color: Color(0xFF4F46E5),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.performanceOverview,
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1F2937),
                                  ),
                                ),
                                Text(
                                  'Today vs yesterday at a glance',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _buildModernStatItem(
                            l10n.sales,
                            "₹${_formatCompactNumber(_todayRevenue)}",
                            growth: _dailyGrowth,
                          ),
                          _buildModernStatItem(
                            l10n.transactions,
                            _todayTransactions.toString(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _buildModernStatItem(
                            l10n.topProductsByRevenue,
                            _todayTopProduct.isEmpty
                                ? l10n.noSales
                                : _todayTopProduct,
                          ),
                          _buildModernStatItem(
                            l10n.bestHour,
                            _todayBestHourLabel.isEmpty
                                ? l10n.notAvailable
                                : _todayBestHourLabel,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF4F46E5).withValues(alpha: 0.06),
                              const Color(0xFFF59E0B).withValues(alpha: 0.06),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(
                              0xFF4F46E5,
                            ).withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                semanticLabel: 'Auto Awesome Rounded',
                                color: const Color(0xFFF59E0B),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _getSalesAnalysisSentence(),
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  letterSpacing: -0.15,
                                  fontWeight: FontWeight.w500,
                                  height: 1.45,
                                  color: const Color(0xFF374151),
                                ),
                              ),
                            ),
                          ],
                        ),
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

  String _getGreeting() {
    final now = DateTime.now();
    final hour = now.hour;
    final l10n = AppLocalizations.of(context);

    // Choose the best name available: User Name > Shop Name > Fallback
    String nameToUse = _userName;
    if (nameToUse.isEmpty) {
      nameToUse = shopName != 'AI Shop Pro' ? shopName : "Shopkeeper";
    }
    if (kDebugMode) debugPrint('DEBUG: _getGreeting() called at hour $hour');
    if (kDebugMode) debugPrint('DEBUG: _userName: "$_userName"');
    if (kDebugMode) debugPrint('DEBUG: shopName: "$shopName"');
    if (kDebugMode) debugPrint('DEBUG: nameToUse: "$nameToUse"');

    if (hour >= 5 && hour < 12) {
      return l10n.goodMorningName.replaceFirst('{0}', nameToUse);
    } else if (hour >= 12 && hour < 17) {
      return l10n.goodAfternoonName.replaceFirst('{0}', nameToUse);
    } else {
      return l10n.goodEveningName.replaceFirst('{0}', nameToUse);
    }
  }

  Widget _buildQuickActionsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
          children: [
            _buildGridActionItem(
              icon: Icons.add_shopping_cart,
              label: 'Add Sale',
              color: const Color(0xFF6366F1),
              onTap: () => Navigator.pushNamed(
                context,
                '/sales-entry',
              ).then((_) => _loadSales()),
            ),
            _buildGridActionItem(
              icon: Icons.inventory_2_outlined,
              label: 'Products',
              color: const Color(0xFFF59E0B),
              onTap: _showProductsDialog,
            ),
            _buildGridActionItem(
              icon: Icons.insights_rounded,
              label: 'Reports',
              color: const Color(0xFF10B981),
              onTap: () => _scrollToCharts(0),
            ),
            _buildGridActionItem(
              icon: Icons.card_giftcard_rounded,
              label: 'Gift Card',
              color: const Color(0xFFE11D48),
              onTap: () => Navigator.pushNamed(context, '/gift-card'),
            ),
            _buildGridActionItem(
              icon: Icons.history_rounded,
              label: 'History',
              color: const Color(0xFF3B82F6),
              onTap: () => _scrollToSalesList(),
            ),
            _buildGridActionItem(
              icon: Icons.storefront_outlined,
              label: 'Online Orders',
              color: const Color(0xFF8B5CF6), // Purple
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WhatsappOrdersPage()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildGridActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? color.withValues(alpha: 0.15)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? color.withValues(alpha: 0.4)
                : color.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isDark ? color.withValues(alpha: 0.9) : color,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.9)
                    : color.withValues(alpha: 0.9),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionWarning() {
    if (!_paymentPermissionCheckComplete || !_isPermissionsMissing) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _paymentDetectionPulse,
      builder: (context, child) {
        final scale = _paymentDetectionPulse.value;
        return Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.58),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.18),
                  blurRadius: 20,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        semanticLabel: 'Payment Detection Disabled',
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Enable Payment Detection',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF991B1B),
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'ACTION REQUIRED',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Automatic UPI/payment detection is disabled until the required Android permissions are enabled.',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFB91C1C),
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildPaymentInlineStatus(
                        'Notification Access',
                        Icons.notifications_none_rounded,
                        NotificationListenerService.isPermissionGranted(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPaymentInlineStatus(
                        'SMS Access',
                        Icons.sms_outlined,
                        Permission.sms.status.then((s) => s.isGranted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'This reminder will remain visible and highlighted until both required permissions are enabled.',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: const Color(0xFF7F1D1D),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await NotificationListenerService.requestPermission();
                      } catch (e) {
                        if (kDebugMode) {
                          debugPrint(
                            '⚠️ Notification permission request failed: $e',
                          );
                        }
                      }

                      try {
                        final status = await Permission.sms.request();
                        if (kDebugMode) {
                          debugPrint('📱 SMS permission request result: $status');
                        }
                      } catch (e) {
                        if (kDebugMode) {
                          debugPrint('⚠️ SMS permission request failed: $e');
                        }
                      }

                      // Android may take a moment to return from Settings/permission UI.
                      await Future<void>.delayed(
                        const Duration(milliseconds: 700),
                      );

                      if (!mounted) return;
                      await _checkPermissions(showReminderIfMissing: false);
                    },
                    icon: const Icon(
                      Icons.lock_open_rounded,
                      size: 20,
                    ),
                    label: Text(
                      'ENABLE PAYMENT DETECTION',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: const Color(0xFFDC2626).withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Small, non-intrusive health chip shown once permissions are granted.
  /// Reads the watchdog heartbeat that PaymentDetectionService already
  /// tracked internally but never exposed to the UI before. Green if a
  /// payment was detected recently or the app just started (nothing to
  /// compare against yet); amber if a channel has gone stale, meaning
  /// detection has likely silently stopped working (background service
  /// killed by the OS, permission silently revoked, etc.) and the merchant
  /// would otherwise have zero indication of that.
  Widget _buildDetectionHealthIndicator() {
    final pds = PaymentDetectionService();
    final notifStale = pds.isNotificationChannelStale;
    final smsStale = pds.isSmsChannelStale;
    final isStale = notifStale && smsStale;

    if (!isStale) return const SizedBox.shrink();

    final lastNotif = pds.lastNotificationSeenAt;
    final lastSms = pds.lastSmsSeenAt;
    final mostRecent = [lastNotif, lastSms]
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);

    String subtitle;
    if (mostRecent == null) {
      subtitle = 'No payment detected yet since detection was enabled';
    } else {
      final mins = DateTime.now().difference(mostRecent).inMinutes;
      subtitle = mins < 60
          ? 'Last payment detected $mins min ago'
          : 'Last payment detected ${(mins / 60).floor()}h ago — this may mean detection has stopped';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment detection may have stopped',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              PaymentDetectionService().ensureChannelsRunning();
              try {
                FlutterBackgroundService().invoke('restart_payment_detection');
                FlutterBackgroundService().invoke('setAsForeground');
              } catch (_) {}
              setState(() {});
            },
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInlineStatus(
    String label,
    IconData icon,
    Future<bool> permissionFuture,
  ) {
    return FutureBuilder<bool>(
      future: permissionFuture,
      builder: (context, snapshot) {
        final granted = snapshot.data == true;
        final color = granted
            ? const Color(0xFF10B981)
            : const Color(0xFFEF4444);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: granted
                ? const Color(0xFFECFDF5)
                : const Color(0xFFFFE4E6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: granted
                  ? const Color(0xFFA7F3D0)
                  : const Color(0xFFFDA4AF),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ),
              ),
              Icon(
                granted ? Icons.check_circle_rounded : Icons.error_rounded,
                size: 15,
                color: color,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserAvatar() {
    final String initial =
        (_userName.isNotEmpty
                ? _userName[0]
                : (shopName.isNotEmpty && shopName != 'My Shop'
                      ? shopName[0]
                      : 'S'))
            .toUpperCase();

    return GestureDetector(
      onTap: _showShopSettingsMenu,
      child: Hero(
        tag: 'shop_logo_avatar',
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(color: const Color(0xFFF3F4F6), width: 2),
          ),
          child: ClipOval(
            child: logoBytes != null
                ? Image.memory(logoBytes!, fit: BoxFit.cover)
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _showShopSettingsMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ShopSettingsBottomSheet(
        userName: _userName,
        shopName: shopName,
        upiId: _upiId,
        qrBytes: _qrImageBytes,
        logoBytes: logoBytes,
        onSave: (name, sName, upi, logo, qr) async {
          // 🔒 SECURITY: Use scoped SharedPreferences for user data
          await ScopedSharedPreferences.setString('user_name', name);
          await ScopedSharedPreferences.setString('shop_name', sName);
          if (logo != null) {
            await ScopedSharedPreferences.setString('logo_base64', base64Encode(logo));
          }

          await SecurePreferencesService.setUpiId(upi);
          if (qr != null) {
            await SecurePreferencesService.setPaymentQrB64(base64Encode(qr));
          }

          setState(() {
            _userName = name;
            shopName = sName;
            _upiId = upi;
            logoBytes = logo;
            _qrImageBytes = qr;
          });

          await _saveShopSettingsToBackend(
            ownerName: name,
            shopName: sName,
            upiId: upi,
            logoBytes: logo,
            qrBytes: qr,
          );
        },
        onVoiceSettings: () =>
            _showVoiceCustomizer(context, (fn) => setState(fn)),
        onHowToUse: () => _showOnboardingDialog(),
        onSecuritySettings: _showChangePinDialog,
        onBiometricSettings: _showBiometricSetupDialog,
        onBackupSettings: _handleCreateBackup,
        onRestoreSettings: _handleRestoreBackup,
        onPrinterSettings: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => const PrinterSettingsPage()),
        ),
        isDarkMode: isDarkMode,
        onToggleDarkMode: (val) async {
          // 🔒 SECURITY: Use scoped SharedPreferences for dark mode
          await ScopedSharedPreferences.setBool('is_dark_mode', val);
          setState(() => isDarkMode = val);
        },
        onMigrateData: () async {
          final result = await CSVImportService.importKhatabookCSV();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message']),
                backgroundColor: result['success'] ? Colors.green : Colors.red,
              ),
            );
            if (result['success']) _loadSales();
          }
        },
        // Optional legacy fields that are now managed internally if needed
        shopType: _shopType,
        location: _location,
        tagline: _tagline,
        website: _website,
      ),
    );
  }

  Future<void> _saveShopSettingsToBackend({
    required String ownerName,
    required String shopName,
    required String upiId,
    Uint8List? logoBytes,
    Uint8List? qrBytes,
  }) async {
    try {
      final body = {
        'owner_name': ownerName,
        'shop_name': shopName,
        'upi_id': upiId,
        if (logoBytes != null) 'logo_base64': base64Encode(logoBytes),
        if (qrBytes != null) 'payment_qr_b64': base64Encode(qrBytes),
      };

      final response = await ApiClient.postJson(ApiClient.shopSettings, body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (kDebugMode) debugPrint('✅ Shop settings synced to backend');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shop settings saved to cloud')),
          );
        }
        return;
      }

      if (kDebugMode)
        debugPrint('⚠️ Shop settings backend returned ${response.statusCode}');
      final data = json.decode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['detail']?.toString() ??
                  'Saved locally; backend sync failed',
            ),
            backgroundColor: Colors.amber,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode)
        debugPrint('⚠️ Failed to save shop settings to backend: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop settings saved locally. Backend sync failed.'),
            backgroundColor: Colors.amber,
          ),
        );
      }
    }
  }

  void _showChangePinDialog() {
    final oldController = TextEditingController();
    final newController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'App Security PIN',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Set a PIN to protect sensitive areas',
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: oldController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Current PIN (Default 0000)',
                labelStyle: const TextStyle(color: Colors.white60),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'New 4-Digit PIN',
                labelStyle: const TextStyle(color: Colors.white60),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final current = await SecurityService.getMasterPin();
              final inputHash = sha256.convert(utf8.encode(oldController.text)).toString();
              if (inputHash == current) {
                if (newController.text.length == 4) {
                  await SecurityService.setMasterPin(newController.text);
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Master PIN updated!'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ New PIN must be 4 digits'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ Current PIN is incorrect'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
            ),
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }

  void _showBiometricSetupDialog() async {
    final bool isSupported =
        await SecurityService.isBiometricHardwareAvailable();
    final bool isEnabled = await SecurityService.isBiometricEnabled();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.fingerprint_rounded,
                semanticLabel: 'Fingerprint Rounded',
                color: Color(0xFF8B5CF6),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Biometric Security',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isSupported)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      semanticLabel: 'Warning Amber Rounded',
                      color: Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Biometric auth not available on this device',
                        style: GoogleFonts.poppins(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Text(
                'Enable fingerprint or face recognition for faster owner login',
                style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Status',
                          style: GoogleFonts.poppins(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isEnabled
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isEnabled ? '✓ Enabled' : '○ Disabled',
                            style: GoogleFonts.poppins(
                              color: isEnabled ? Colors.green : Colors.grey,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CLOSE'),
          ),
          if (isSupported)
            ElevatedButton(
              onPressed: () async {
                try {
                  // Attempt biometric authentication first to verify device capability
                  final bool authenticated =
                      await SecurityService.authenticateBiometrically(
                        reason:
                            'Verify your identity to enable biometric login',
                      );

                  if (authenticated) {
                    // Enable biometric login
                    await SecurityService.setBiometricEnabled(true);

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '✅ Biometric authentication enabled!',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: const Color(0xFF10B981),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                      setState(() {}); // Refresh UI
                    }
                  } else {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                            '❌ Biometric verification failed',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          '⚠️ Error: $e',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: Colors.orange,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
              ),
              child: Text(
                isEnabled ? 'DISABLE' : 'ENABLE',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  void _toggleStaffMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isStaffMode) {
      // Trying to exit Staff Mode, prompt for authentication if PIN is set
      final pinIsSet = await SecurityService.isPinSet();
      if (pinIsSet) {
        bool authenticated = false;

        // Check if biometric is enabled
        final bool biometricEnabled =
            await SecurityService.isBiometricEnabled();
        if (biometricEnabled) {
          // Try biometric first
          try {
            authenticated = await SecurityService.authenticateBiometrically(
              reason: 'Authenticate to exit Owner Mode',
            );
          } catch (e) {
            debugPrint("Biometric error: $e");
          }
        }

        if (authenticated) {
          await prefs.setBool('is_staff_mode', false);
          setState(() => _isStaffMode = false);
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Welcome back, Owner')),
            );
          return;
        }

        // Fall back to PIN if biometric fails or is not enabled
        _showPinPromptDialog((success) async {
          if (success) {
            await prefs.setBool('is_staff_mode', false);
            setState(() => _isStaffMode = false);
            if (mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Welcome back, Owner')),
              );
          }
        });
        return;
      }
      // If no custom pin set, just exit
      await prefs.setBool('is_staff_mode', false);
      setState(() => _isStaffMode = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Switched back to Owner Mode')),
        );
    } else {
      // Trying to enter Owner Mode (Owner Login clicked)
      // Since we want email-based PIN for security, we redirect to selection or verification
      final email = prefs.getString('email') ?? '';
      if (email.isNotEmpty) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => RoleSelectionPage(email: email)),
        );
      } else {
        // Fallback if no email is stored
        _showPinPromptDialog((success) async {
          if (success) {
            await prefs.setBool('is_staff_mode', false);
            setState(() => _isStaffMode = false);
            if (mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Welcome back, Owner')),
              );
          }
        });
      }
    }
  }

  void _showPinPromptDialog(void Function(bool) onResult) async {
    final controller = TextEditingController();
    final bool biometricEnabled = await SecurityService.isBiometricEnabled();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            'Enter Master PIN',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  labelStyle: TextStyle(color: Colors.white60),
                ),
              ),
              if (biometricEnabled) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final bool authenticated =
                          await SecurityService.authenticateBiometrically(
                            reason: 'Authenticate to access Owner Mode',
                          );
                      if (authenticated) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        onResult(true);
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('Biometric failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(
                    Icons.fingerprint_rounded,
                    semanticLabel: 'Fingerprint Rounded',
                  ),
                  label: Text(
                    'Or Use Biometric',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onResult(false);
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                final masterPin = await SecurityService.getMasterPin();
                final inputHash = sha256.convert(utf8.encode(controller.text)).toString();
                if (inputHash == masterPin) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  onResult(true);
                } else {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Incorrect PIN',
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('UNLOCK'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreateBackup() async {
    try {
      // FIX-3: Get actual backup file size from LocalStorageService
      final backupDir = await getApplicationDocumentsDirectory();
      final backupFile = File('${backupDir.path}/retail_mind_backup.json');

      if (await backupFile.exists()) {
        final bytes = await backupFile.length();
        final sizeKB = (bytes / 1024).toStringAsFixed(1);
        final result = {'size': sizeKB};

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'last_backup_time',
          DateTime.now().toIso8601String(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Backup created: ${result['size']} KB'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ No backup file found'),
              backgroundColor: Color(0xFFFB923C),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Backup failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleRestoreBackup() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please go to Shop Settings to perform a restore.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _scrollToSalesList() {
    _scrollController.animateTo(
      1500, // Approximate position of Recent Sales
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildUnsyncedSalesWarning() {
    final count = _unsyncedBillsCount;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_rounded, color: Color(0xFFEF4444), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1
                      ? '1 sale not backed up to the cloud yet'
                      : '$count sales not backed up to the cloud yet',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: const Color(0xFFB91C1C),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Stay connected to the internet until these sync. Do NOT clear app data or uninstall until this warning disappears — that would permanently delete them.',
                  style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF7F1D1D)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsIntegrityWarning() {
    final count = _analyticsIntegrityErrorCount;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count sale${count == 1 ? '' : 's'} need date verification. They are excluded from sales totals until a valid business date is available.',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingHeader() {
    final now = DateTime.now();
    final dateStr = '${now.day} ${_monthShort(now.month)} ${now.year}';
    
    // Using calculate total functions
    final totalSales = _calculateTotalSales();
    final totalOrders = _calculateTotalOrders();
    final totalOnlineOrders = _calculateTotalOnlineOrders();
    final lowStockCount = _lowStockProducts.length;
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFF5F7FA).withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  dateStr,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4F46E5),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const Spacer(),
              _buildUserAvatar(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _getGreeting(),
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1F2937),
              letterSpacing: -0.6,
              height: 1.15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            shopName,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 12),
          // Total's Metrics Row (2x2 grid for 4 cards)
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard('Total Sales', '₹${_formatCompactNumber(totalSales)}', Icons.attach_money, const Color(0xFF10B981)), // 🔒 CHANGED: "Today's Revenue" to "Total Sales"
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard('Total Orders', totalOrders.toString(), Icons.shopping_cart, const Color(0xFF3B82F6)), // 🔒 CHANGED: "Today's Orders" to "Total Bills"
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard('Total Online Orders', totalOnlineOrders.toString(), Icons.language, const Color(0xFF6366F1)), // 🔒 NEW: Added Online Orders
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard('Low Stock', lowStockCount.toString(), Icons.warning, const Color(0xFFF59E0B), isWarning: lowStockCount > 0),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetricCard(String label, String value, IconData icon, Color color, {bool isWarning = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isWarning ? const Color(0xFFEF4444) : const Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  double _calculateTotalSales() {
    final Map<String, double> invoiceTotals = {};

    for (final sale in sales) {
      try {
        final invoiceKey = sale['invoice_number']?.toString() ??
            sale['sale_id']?.toString() ??
            sale['_bill_id']?.toString() ??
            sale['id']?.toString() ??
            sale['created_at']?.toString() ??
            '';
        if (invoiceKey.isEmpty) continue;

        if (!invoiceTotals.containsKey(invoiceKey)) {
          final raw = sale['invoice_total'] ?? sale['total'] ?? sale['grand_total'] ?? sale['final_amount'] ?? sale['totalAmount'] ?? 0;
          invoiceTotals[invoiceKey] = raw is num ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0.0;
        }
      } catch (_) {}
    }

    return invoiceTotals.values.fold(0.0, (sum, v) => sum + v);
  }
  
  int _calculateTotalOrders() {
    final Set<String> invoiceKeys = {};

    for (final sale in sales) {
      try {
        final invoiceKey = sale['invoice_number']?.toString() ??
            sale['sale_id']?.toString() ??
            sale['_bill_id']?.toString() ??
            sale['id']?.toString() ??
            sale['created_at']?.toString() ??
            '';
        if (invoiceKey.isNotEmpty) invoiceKeys.add(invoiceKey);
      } catch (_) {}
    }
    
    return invoiceKeys.length;
  }

  int _calculateTotalOnlineOrders() {
    final Set<String> onlineInvoices = {};

    for (final sale in sales) {
      try {
        final invoiceKey = sale['invoice_number']?.toString() ??
            sale['sale_id']?.toString() ??
            sale['_bill_id']?.toString() ??
            sale['id']?.toString() ??
            sale['created_at']?.toString() ??
            '';
            
        final String source = (sale['source'] ?? sale['order_source'] ?? 'OFFLINE').toString().toUpperCase();
        
        // Count as online if source is online OR if invoice starts with ONL
        if (source == 'ONLINE' || source == 'WEB' || source == 'APP' || invoiceKey.toUpperCase().startsWith('ONL')) {
          if (invoiceKey.isNotEmpty) onlineInvoices.add(invoiceKey);
        }
      } catch (_) {}
    }

    return onlineInvoices.length;
  }

  String _monthShort(int m) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (m < 1 || m > 12) return '';
    return names[m - 1];
  }

  Widget _buildRealtimeMetricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF374151).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveActivityFeed() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timeline,
                semanticLabel: 'Timeline',
                size: 20,
                color: Color(0xFF6366F1),
              ),
              const SizedBox(width: 8),
              Text(
                'Live Activity',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._activityFeed.map(
            (activity) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      activity,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveSalesTicker() {
    if (_liveMetrics == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.trending_up,
                semanticLabel: 'Trending Up',
                size: 20,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                'Today\'s Live Sales',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTickerItem(
                'Revenue',
                '₹${_liveMetrics!['revenue']?.toStringAsFixed(0) ?? '0'}',
                Icons.currency_rupee,
              ),
              _buildTickerItem(
                'Items',
                '${_liveMetrics!['items_sold']?.toString() ?? '0'}',
                Icons.inventory,
              ),
              _buildTickerItem(
                'Transactions',
                '${_liveMetrics!['transactions']?.toString() ?? '0'}',
                Icons.receipt,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTickerItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatItem(String label, String value, {double? growth}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF9CA3AF),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (growth != null && growth != 0) ...[
                const SizedBox(width: 4),
                if (growth <= -100) ...[
                  Text(
                    "–",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF9CA3AF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ] else ...[
                  Icon(
                    growth >= 0
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: growth >= 0
                        ? const Color(0xFF10B981)
                        : Colors.redAccent,
                    size: 14,
                  ),
                  Text(
                    "${growth.abs().toStringAsFixed(1)}%",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: growth >= 0
                          ? const Color(0xFF10B981)
                          : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          // Premium Illustration Container
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Animated-like background circles
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                ),
                const Icon(
                  Icons.auto_graph_rounded,
                  semanticLabel: 'Auto Graph Rounded',
                  size: 64,
                  color: Color(0xFF6366F1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Your Business Journey Starts Here',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Experience real-time billing, voice analytics, and premium shop management. Add your first sale to unlock powerful insights.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          // Action Button
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(
              context,
              '/sales-entry',
            ).then((_) => _loadSales()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add_shopping_cart_rounded,
                  semanticLabel: 'Add Shopping Cart Rounded',
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Record First Sale',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGettingStartedSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1).withValues(alpha: 0.12),
            const Color(0xFF8B5CF6).withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  semanticLabel: 'Auto Awesome Rounded',
                  color: Color(0xFF6366F1),
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete Setup',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1F2937),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Personalize your shop experience',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildStepCard(
            'Business Profile',
            'Add logo and shop details for professional bills',
            Icons.storefront_rounded,
            _isShopSetup,
            () => Navigator.pushNamed(
              context,
              '/shop-profile',
            ).then((_) => _loadSales()),
          ),
          const SizedBox(height: 14),
          _buildStepCard(
            'Record Sale',
            'Start your first billing operation',
            Icons.add_shopping_cart_rounded,
            sales.isNotEmpty,
            () => Navigator.pushNamed(
              context,
              '/sales-entry',
            ).then((_) => _loadSales()),
          ),
          const SizedBox(height: 14),
          _buildStepCard(
            'Master PIN',
            'Secure your data with 4-digit PIN',
            Icons.lock_rounded,
            _isMasterPinSet, // Assuming a boolean tracked in state
            _showChangePinDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(
    String title,
    String desc,
    IconData icon,
    bool isComplete,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isComplete
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.white,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isComplete
                    ? Colors.green[50]
                    : const Color(0xFF6366F1).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isComplete ? Icons.check_circle_rounded : icon,
                color: isComplete ? Colors.green[600] : const Color(0xFF6366F1),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isComplete
                          ? Colors.grey[500]
                          : const Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    desc,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              semanticLabel: 'Arrow Forward Ios Rounded',
              size: 14,
              color: Colors.grey[300],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChart(String message) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_chart_outlined,
              semanticLabel: 'Insert Chart Outlined',
              size: 60,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add sales data to see visualizations',
              style: TextStyle(color: Colors.grey[300], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ENHANCED TIME FILTER
  Widget _buildEnhancedTimeFilter() {
    final List<Map<String, dynamic>> filters = [
      {'label': 'Today', 'icon': Icons.today, 'color': const Color(0xFF3B82F6)},
      {
        'label': 'Week',
        'icon': Icons.calendar_view_week,
        'color': const Color(0xFF10B981),
      },
      {
        'label': 'Month',
        'icon': Icons.calendar_month,
        'color': const Color(0xFFF59E0B),
      },
      {
        'label': 'Year',
        'icon': Icons.calendar_today,
        'color': const Color(0xFF8B5CF6),
      },
    ];

    // simplified container without horizontal scroll; only four options so it fits
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(filters.length, (index) {
          final isSelected = _selectedTimeFilter == index;
          final filterColor = filters[index]['color'] as Color;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Material(
              color: isSelected ? filterColor : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  _onFilterChanged(index);
                  if (kDebugMode)
                    debugPrint(
                      'Time filter tapped: ${filters[index]['label']}, count: ${filteredSales.length}',
                    );
                  // provide quick visual feedback in case user is unsure
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Filter: ${filters[index]['label']}'),
                      duration: const Duration(milliseconds: 500),
                    ),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? filterColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _filterColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        filters[index]['icon'],
                        size: 16,
                        color: isSelected ? Colors.white : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        filters[index]['label'],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEnhancedQuickAction(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show Products Dialog
  void _showProductsDialog() {
    final uniqueProducts = _productAnalytics.keys.toList();

    showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFF8FAFC),
                Colors.grey[50] ?? const Color(0xFFF8FAFC),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.inventory_2,
                      semanticLabel: 'Inventory 2',
                      color: Color(0xFFF59E0B),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context).products,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${AppLocalizations.of(context).total} ${AppLocalizations.of(context).products}: ${uniqueProducts.length}',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.grey[300]),
              const SizedBox(height: 12),
              SizedBox(
                height: 300,
                width: double.maxFinite,
                child: uniqueProducts.isEmpty
                    ? Center(
                        child: Text(
                          AppLocalizations.of(context).noProductData,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      )
                    : ListView.separated(
                        itemCount: uniqueProducts.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: Colors.grey[200], height: 1),
                        itemBuilder: (context, index) {
                          final product = uniqueProducts[index];
                          final data = _productAnalytics[product] ?? {};
                          final count = data['count'] ?? 0;
                          final total = data['total'] ?? 0.0;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _cleanProductName(product, ''),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Sold $count times • ₹${(total as double).toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    ((data['percentage'] as num?)?.toDouble() ??
                                            0.0)
                                        .toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: Text(AppLocalizations.of(context).goToDashboard),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Show Export Options Dialog using the dedicated Export Widget
  void _showExportOptionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor:
            Colors.transparent, // Let the widget handle its own look
        child: SingleChildScrollView(
          child: DataExportWidget(
            allSales: sales,
            shopName: shopName,
            shopPhone: _shopPhone,
          ),
        ),
      ),
    );
  }

  // Show Settings Dialog
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDarkMode
                  ? [const Color(0xFF2A2A2A), const Color(0xFF1F1F1F)]
                  : [
                      const Color(0xFFF8FAFC),
                      Colors.grey[50] ?? const Color(0xFFF8FAFC),
                    ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.settings,
                      semanticLabel: 'Settings',
                      color: Color(0xFF8B5CF6),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Settings',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Store Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF3A3A3A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Store Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDarkMode ? Colors.white : Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSettingRow('Store Name', 'AI Shopping App'),
                    const SizedBox(height: 10),
                    _buildSettingRow('Version', 'v2.0'),
                    const SizedBox(height: 10),
                    _buildSettingRow(
                      'Last Sync',
                      DateTime.now().toString().substring(0, 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // App Settings
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF3A3A3A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Settings',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDarkMode ? Colors.white : Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSettingToggle('Auto Sync', true),
                    const SizedBox(height: 10),
                    _buildSettingToggle('Notifications', true),
                    const SizedBox(height: 10),
                    _buildSettingToggle('Dark Mode', isDarkMode),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _performLogout(context),
                    child: const Text('Logout'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingToggle(String label, bool value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        Switch(
          value: label == 'Dark Mode' ? isDarkMode : value,
          onChanged: (newValue) {
            if (label == 'Dark Mode') {
              setState(() {
                isDarkMode = newValue;
              });
            }
          },
          activeColor: const Color(0xFF8B5CF6),
        ),
      ],
    );
  }

  void _showPaymentQrDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF0D1018),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.qr_code_2,
                  semanticLabel: 'Qr Code 2',
                  color: Color(0xFF22C55E),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Receive Payment',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: math.min(MediaQuery.of(context).size.width * 0.9, 420),
            height: math.min(MediaQuery.of(context).size.height * 0.8, 650),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Upload your UPI / bank QR code so customers can scan and pay you directly.',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // QR image preview
                  if (_qrImageBytes != null)
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF22C55E,
                            ).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Image.memory(_qrImageBytes!, fit: BoxFit.contain),
                    )
                  else
                    GestureDetector(
                      onTap: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          withData: true,
                          allowMultiple: false,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          final file = result.files.first;
                          final bytes = file.bytes;
                          final path = file.path;

                          if (bytes != null) {
                            bool isValidQr = false;
                            if (path != null) {
                              MobileScannerController? controller;
                              try {
                                controller = MobileScannerController();
                                final capture = await controller.analyzeImage(
                                  path,
                                );
                                if (capture != null &&
                                    capture.barcodes.any(
                                      (b) => b.format == BarcodeFormat.qrCode,
                                    )) {
                                  isValidQr = true;
                                }
                              } catch (e) {
                                if (kDebugMode)
                                  debugPrint("Verification error: $e");
                              } finally {
                                // Ensure controller is disposed in all cases
                                controller?.dispose();
                              }
                            } else {
                              isValidQr = true; // Fallback
                            }

                            if (isValidQr) {
                              // 🔒 SECURITY: Use scoped SharedPreferences for payment QR
                              await ScopedSharedPreferences.setString(
                                'payment_qr_b64',
                                base64Encode(bytes),
                              );
                              setState(() => _qrImageBytes = bytes);
                              setDlgState(() {});
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "The selected image does not contain a valid QR code. Please upload a QR code image.",
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: Container(
                        width: 220,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Color(0xFF22C55E).withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Color(0xFF22C55E).withValues(alpha: 0.4),
                            width: 2,
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.add_photo_alternate_outlined,
                              semanticLabel: 'Add Photo Alternate Outlined',
                              size: 48,
                              color: Color(0xFF22C55E),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Tap to upload QR',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF22C55E),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'PNG / JPG from gallery',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Sound Settings Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payment Sound',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Voice announcement on credit',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _paymentSoundEnabled,
                              activeColor: const Color(0xFF22C55E),
                              onChanged: (v) async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setBool('payment_sound_enabled', v);
                                PdsConfig.isVoiceEnabled = v;
                                setState(() => _paymentSoundEnabled = v);
                                setDlgState(() {});
                              },
                            ),
                          ],
                        ),
                        if (_paymentSoundEnabled) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: () => PaymentAnnouncementService()
                                  .testAnnouncement(_paymentSoundLang),
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                semanticLabel: 'Play Arrow Rounded',
                                color: Colors.white,
                              ),
                              label: Text(
                                'TEST ANNOUNCEMENTS',
                                style: GoogleFonts.poppins(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigoAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const Divider(color: Colors.white10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Notification Access',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  FutureBuilder<bool>(
                                    future:
                                        PaymentDetectionService.hasNotificationPermission(),
                                    builder: (context, snapshot) {
                                      bool granted = snapshot.data ?? false;
                                      return Text(
                                        granted
                                            ? 'Permission Granted ✅'
                                            : 'Access Required ⚠️',
                                        style: GoogleFonts.poppins(
                                          color: granted
                                              ? const Color(0xFF22C55E)
                                              : Colors.orangeAccent,
                                          fontSize: 12,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                await PaymentDetectionService.openNotificationSettings();
                                setDlgState(() {});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.05,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'ENABLE',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'High-Performance Background Mode',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  FutureBuilder<bool>(
                                    future:
                                        PaymentDetectionService.isBatteryOptimizationIgnored(),
                                    builder: (context, snapshot) {
                                      bool ignored = snapshot.data ?? false;
                                      return Text(
                                        ignored
                                            ? 'Optimized for Reliability ✅'
                                            : 'Enable for seamless detection ⚠️',
                                        style: GoogleFonts.poppins(
                                          color: ignored
                                              ? const Color(0xFF22C55E)
                                              : Colors.orangeAccent,
                                          fontSize: 12,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                await PaymentDetectionService.requestIgnoreBatteryOptimization();
                                setDlgState(() {});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.05,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'FIX',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Accessibility (High Accuracy)',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  FutureBuilder<bool>(
                                    future:
                                        PaymentDetectionService.hasAccessibilityPermission(),
                                    builder: (context, snapshot) {
                                      bool granted = snapshot.data ?? false;
                                      return Text(
                                        granted
                                            ? 'Ultra Detection Active 🚀'
                                            : 'Disabled ⚠️',
                                        style: GoogleFonts.poppins(
                                          color: granted
                                              ? const Color(0xFF22C55E)
                                              : Colors.white24,
                                          fontSize: 12,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                await PaymentDetectionService.openAccessibilitySettings();
                                setDlgState(() {});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.05,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'ENABLE',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.verified_user_rounded,
                                    semanticLabel: 'Verified User Rounded',
                                    color: Color(0xFF22C55E),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Play Store Compliance',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Privacy First: Accessibility and Notification services are ONLY used to detect payment confirmations within trusted apps. No bank balances, passwords, or personal chats are accessed. Detection happens locally on your device.',
                                style: GoogleFonts.poppins(
                                  color: Colors.white38,
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_qrImageBytes != null)
                    TextButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          withData: true,
                          allowMultiple: false,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          final file = result.files.first;
                          final bytes = file.bytes;
                          final path = file.path;

                          if (bytes != null) {
                            bool isValidQr = false;
                            if (path != null) {
                              final controller = MobileScannerController();
                              try {
                                final capture = await controller.analyzeImage(
                                  path,
                                );
                                if (capture != null &&
                                    capture.barcodes.any(
                                      (b) => b.format == BarcodeFormat.qrCode,
                                    )) {
                                  isValidQr = true;
                                }
                              } catch (e) {
                                if (kDebugMode)
                                  debugPrint("Verification error: $e");
                              } finally {
                                controller.dispose();
                              }
                            } else {
                              isValidQr = true;
                            }

                            if (isValidQr) {
                              // 🔒 SECURITY: Use scoped SharedPreferences for payment QR
                              await ScopedSharedPreferences.setString(
                                'payment_qr_b64',
                                base64Encode(bytes),
                              );
                              setState(() => _qrImageBytes = bytes);
                              setDlgState(() {});
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "The selected image does not contain a valid QR code. Please upload a QR code image.",
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        }
                      },
                      icon: const Icon(
                        Icons.swap_horiz,
                        semanticLabel: 'Swap Horiz',
                        size: 18,
                        color: Color(0xFF22C55E),
                      ),
                      label: Text(
                        'Change QR',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF22C55E),
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Close',
                style: GoogleFonts.poppins(color: const Color(0xFF6B7280)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionScatterChart() {
    if (sales.isEmpty) return _buildEmptyChart('No data for scatter chart');

    final sortedSales = List.from(sales)
      ..sort(
        (a, b) => DateTime.parse(
          a['created_at'] ?? a['sale_date'],
        ).compareTo(DateTime.parse(b['created_at'] ?? b['sale_date'])),
      );
    final sample = sortedSales.length > 30
        ? sortedSales.sublist(sortedSales.length - 30)
        : sortedSales;

    List<ScatterSpot> spots = [];
    double maxX = sample.length.toDouble();
    double maxY = 0;

    for (int i = 0; i < sample.length; i++) {
      final totalParam = sample[i]['total'];
      final total = (totalParam is num)
          ? totalParam.toDouble()
          : (double.tryParse(totalParam?.toString() ?? '0') ?? 0.0);
      if (total > maxY) maxY = total;

      spots.add(
        ScatterSpot(
          i.toDouble(),
          total,
          dotPainter: FlDotCirclePainter(
            radius: math.min(6 + (total / (maxY > 0 ? maxY : 1)) * 12, 18),
            color: AppColors.accent.withValues(alpha: 0.7),
            strokeColor: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceDark.withValues(alpha: 0.6)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.scatter_plot,
                  semanticLabel: 'Scatter Plot',
                  color: AppColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Recent Transactions Heat',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ScatterChart(
              ScatterChartData(
                scatterSpots: spots,
                minX: -1,
                maxX: maxX,
                minY: 0,
                maxY: maxY * 1.2,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                  drawVerticalLine: false,
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(interval: 1, showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(interval: 1, showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(interval: 1, showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) => Text(
                        '₹${value.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSidebar() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey[200]!)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 90% Image Section with 10% padding
          Container(
            height: MediaQuery.of(context).size.height * 0.55,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(8),
            child: logoBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.memory(logoBytes!, fit: BoxFit.cover),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.storefront,
                        semanticLabel: 'Storefront',
                        color: Color(0xFF6366F1),
                        size: 80,
                      ),
                    ),
                  ),
          ),
          // Shop Info Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shopName.isNotEmpty ? shopName : 'AI Shop Pro',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context).dashboard,
                style: TextStyle(
                  fontSize: 11,
                  color: const Color(0xFF6366F1).withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSidebarItem(
            Icons.dashboard_rounded,
            AppLocalizations.of(context).dashboard,
            true,
            () {
              setState(() => _isSidebarOpen = false);
            },
          ),
          _buildSidebarItem(
            Icons.add_shopping_cart,
            AppLocalizations.of(context).addSale,
            false,
            () {
              Navigator.pushNamed(
                context,
                '/sales-entry',
              ).then((_) => _loadSales());
              setState(() => _isSidebarOpen = false);
            },
          ),
          _buildSidebarItem(
            Icons.upload_file_rounded,
            AppLocalizations.of(context).dataUpload,
            false,
            () {
              Navigator.pushNamed(
                context,
                '/data-upload',
              ).then((_) => _loadSales());
              setState(() => _isSidebarOpen = false);
            },
          ),
          _buildSidebarItem(
            Icons.inventory_2_rounded,
            AppLocalizations.of(context).inventory,
            false,
            () async {
              if (await SecurityService.verifyMasterPin(context)) {
                if (!mounted) return;
                Navigator.pushNamed(context, '/inventory');
                setState(() => _isSidebarOpen = false);
              }
            },
          ),
          _buildSidebarItem(
            Icons.people_rounded,
            AppLocalizations.of(context).customers,
            false,
            () {
              Navigator.pushNamed(context, '/customers');
              setState(() => _isSidebarOpen = false);
            },
          ),
          _buildSidebarItem(
            Icons.receipt_long_rounded,
            AppLocalizations.of(context).invoices,
            false,
            () {
              Navigator.pushNamed(context, '/invoices');
              setState(() => _isSidebarOpen = false);
            },
          ),
          _buildSidebarItem(
            Icons.account_balance_wallet_rounded,
            AppLocalizations.of(context).expenses ?? 'Expenses',
            false,
            () async {
              if (await SecurityService.verifyMasterPin(context)) {
                if (!mounted) return;
                Navigator.pushNamed(context, '/expense');
                setState(() => _isSidebarOpen = false);
              }
            },
          ),
          _buildSidebarItem(
            Icons.badge_rounded,
            AppLocalizations.of(context).workers ?? 'Workers',
            false,
            () async {
              if (await SecurityService.verifyMasterPin(context)) {
                if (!mounted) return;
                Navigator.pushNamed(context, '/worker-management');
                setState(() => _isSidebarOpen = false);
              }
            },
          ),
          _buildSidebarItem(
            Icons.how_to_reg_rounded,
            AppLocalizations.of(context).attendance,
            false,
            () {
              Navigator.pushNamed(context, '/attendance');
              setState(() => _isSidebarOpen = false);
            },
          ),
          _buildSidebarItem(
            Icons.card_giftcard_rounded,
            AppLocalizations.of(context).giftCard,
            false,
            () {
              Navigator.pushNamed(context, '/gift-card');
              setState(() => _isSidebarOpen = false);
            },
          ),
          _buildSidebarItem(Icons.receipt_rounded, 'Transactions', false, () {
            Navigator.pushNamed(context, '/transactions');
            setState(() => _isSidebarOpen = false);
          }),
          _buildSidebarItem(
            Icons.storefront_rounded,
            AppLocalizations.of(context).shopDetails,
            false,
            () async {
              if (await SecurityService.verifyMasterPin(context)) {
                if (!mounted) return;
                Navigator.pushNamed(context, '/shop-profile').then((_) {
                  if (mounted) _loadSales();
                });
                setState(() => _isSidebarOpen = false);
              }
            },
          ),
          if (showInsight)
            _buildSidebarItem(
              Icons.lightbulb_outline,
              AppLocalizations.of(context).getInsights,
              false,
              () {
                setState(() => _isSidebarOpen = false);
                _loadTodayInsight();
              },
            ),
          const Spacer(),
          Divider(color: Colors.grey[200]),
          const SizedBox(height: 16),
          _buildSidebarItem(
            Icons.logout,
            AppLocalizations.of(context).logout,
            false,
            () => _performLogout(context),
            isLogout: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    String title,
    bool isSelected,
    VoidCallback onTap, {
    bool isLogout = false,
  }) {
    if (isLogout) {
      // Minimal, non-animated logout row
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        leading: const Icon(
          Icons.logout,
          semanticLabel: 'Logout',
          color: Colors.redAccent,
          size: 20,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.redAccent,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12, right: 100),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : const Color(0xFF6B7280),
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF6B7280),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF6366F1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF6366F1),
                      blurRadius: 4,
                      spreadRadius: 1,
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

  Future<void> _showDailyClosingSheet() async {
    if (!mounted) return;

    // Calculate today's revenue & expenses
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    double revenue = 0.0, expense = 0.0;
    String topProduct = 'N/A';
    double topProductQty = 0;

    try {
      // Sum today's sales
      for (var sale in sales) {
        try {
          // Use 'sale_date' from flattened sales (consistent with dashboard data structure)
          final saleDate = DateTime.parse(
            sale['sale_date'] ?? sale['date'] ?? '',
          );
          if (saleDate.isAfter(startOfDay) && saleDate.isBefore(endOfDay)) {
            final rawAmount = sale['total_amount'] ?? sale['total'] ?? sale['grand_total'] ?? sale['final_amount'] ?? sale['totalAmount'] ?? '0';
            revenue += double.tryParse(rawAmount.toString()) ?? 0;
          }
        } catch (_) {}
      }

      // Sum today's expenses
      final expenses = await LocalStorageService.loadExpenses();
      for (var exp in expenses) {
        try {
          final expDate = DateTime.parse(exp['date'] ?? '');
          if (expDate.isAfter(startOfDay) && expDate.isBefore(endOfDay)) {
            expense += double.tryParse(exp['amount']?.toString() ?? '0') ?? 0;
          }
        } catch (_) {}
      }

      // Find top product
      Map<String, double> productQty = {};
      for (var sale in sales) {
        try {
          final saleDate = DateTime.parse(sale['date'] ?? '');
          if (saleDate.isAfter(startOfDay) && saleDate.isBefore(endOfDay)) {
            final items = sale['items'] as List? ?? [];
            for (var item in items) {
              final name = item['product_name']?.toString() ?? 'Unknown';
              final qty = double.tryParse(item['qty']?.toString() ?? '1') ?? 1;
              productQty[name] = (productQty[name] ?? 0) + qty;
            }
          }
        } catch (_) {}
      }

      if (productQty.isNotEmpty) {
        final entry = productQty.entries.reduce(
          (a, b) => a.value > b.value ? a : b,
        );
        topProduct = '${entry.key} (${entry.value.toStringAsFixed(0)} units)';
        topProductQty = entry.value;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error in closing calc: $e');
    }

    final profit = revenue - expense;
    _lastClosingDate = today;
    _closedToday = true;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Text(
                'Daily Closing - ${today.day}/${today.month}/${today.year}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // KPI Cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.trending_up,
                            semanticLabel: 'Trending Up',
                            color: Color(0xFF10B981),
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Revenue',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          Text(
                            '₹${revenue.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.trending_down,
                            semanticLabel: 'Trending Down',
                            color: Color(0xFFF59E0B),
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Expense',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          Text(
                            '₹${expense.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: profit > 0
                            ? const Color(0xFF6366F1).withValues(alpha: 0.1)
                            : const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: profit > 0
                              ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                              : const Color(0xFFEF4444).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            profit > 0 ? Icons.check_circle : Icons.warning,
                            color: profit > 0
                                ? const Color(0xFF6366F1)
                                : const Color(0xFFEF4444),
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Profit',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          Text(
                            '₹${profit.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: profit > 0
                                  ? const Color(0xFF6366F1)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Top Product
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: glass,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Top Product',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      topProduct,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final msg =
                            'Daily Closing ${today.day}/${today.month}/${today.year}\n\n'
                            '💰 Revenue: ₹${revenue.toStringAsFixed(0)}\n'
                            '💸 Expense: ₹${expense.toStringAsFixed(0)}\n'
                            '✅ Profit: ₹${profit.toStringAsFixed(0)}\n'
                            '🔥 Top: $topProduct';
                        // Copy to clipboard
                        Clipboard.setData(ClipboardData(text: msg)).then((_) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied! Share via WhatsApp'),
                              ),
                            );
                          }
                        });
                      },
                      icon: const Icon(Icons.copy, semanticLabel: 'Copy'),
                      label: const Text('Copy'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, semanticLabel: 'Close'),
                      label: const Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B7280),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Centralized logout confirmation dialog with loading indicator
  void _showLogoutLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  // Centralized logout flow that preserves pending sync queue by default
  Future<void> _performLogout(BuildContext context, {bool preserveSyncQueue = true}) async {
    final int pendingCount = await SyncQueueManager.getQueueSize();
    
    if (pendingCount > 0 && preserveSyncQueue) {
      if (!mounted) return;
      _showLogoutLoadingDialog(context, 'Trying to sync pending data...');
      try {
        await SyncService.processQueueSafe();
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Logout sync attempt failed: $e');
      } finally {
        if (mounted) Navigator.pop(context);
      }

      final remaining = await SyncQueueManager.getQueueSize();
      if (remaining > 0 && mounted) {
        final decision = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Pending data'),
            content: Text(
              '''${remaining.toString()} item(s) still need synchronization. They will remain safely in the encrypted, user-scoped outbox and retry after the next login.\n\nYou can logout now without losing the pending records.''',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('LOGOUT SAFELY'),
              ),
            ],
          ),
        ) ?? false;
        if (!decision) return;
      }
    }

    // Show logout confirmation
    if (!mounted) return;
    final bool confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout? Your synced data will safely return when you log back in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    // Show loading indicator during logout
    if (!mounted) return;
    _showLogoutLoadingDialog(context, 'Logging out...');

    // Perform logout
    // FIX: This used to call UserDataClearService.clearAllUserData() +
    // AuthHelper.clearAuthData() directly, which is an incomplete duplicate
    // of the real logout flow — it skipped closing this user's scoped Hive
    // boxes, clearing scoped SharedPreferences, secure token storage, master
    // PIN, payment/sync state, and server-side session invalidation. On a
    // shared device that left the door open for the next logged-in account
    // to read leftover state from this one. Route through the single
    // canonical logout path instead (see session_logout_service.dart).
    //
    // 🔧 FIX: performOwnerLogout() was awaited with no try/catch. If any
    // internal cleanup step threw, the exception propagated straight out of
    // this handler — the loading dialog above was never popped and the
    // Navigator call below never ran, leaving the user stuck behind an
    // infinite "Logging out..." spinner ("logout button not working").
    // Session logout's internal steps are now individually best-effort too,
    // but this try/finally is the backstop: navigation to login must always
    // happen once the user has confirmed logout, regardless of what fails.
    if (kDebugMode) debugPrint('🧹 Logging out via SessionLogoutService...');
    try {
      await SessionLogoutService.performOwnerLogout();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Logout encountered an error but continuing: $e');
    } finally {
      if (mounted) Navigator.pop(context); // Close loading dialog
    }

    // Navigate to login
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  Widget _buildBottomActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.32)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // convert HTML dashboard layout into Flutter widgets
    return Scaffold(
        backgroundColor: bg,
      bottomNavigationBar: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
            border: Border(
              top: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // 1. Add Sale
                GestureDetector(
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/sales-entry',
                  ).then((_) => _loadSales()),
                  child: Tooltip(
                    message: AppLocalizations.of(context).addSale,
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF6366F1,
                            ).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_shopping_cart,
                        semanticLabel: 'Add Shopping Cart',
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 1.2 Online Orders
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/online-orders'),
                  child: Tooltip(
                    message: 'Online Orders',
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFFB300,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(
                                0xFFFFB300,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.local_shipping,
                            semanticLabel: 'Local Shipping',
                            color: Color(0xFFFFB300),
                            size: 24,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              '1',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Gift Card
                GestureDetector(
                  onTap: _openGiftCardFromPrefs,
                  child: Tooltip(
                    message: 'Gift Card',
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEC4899).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFEC4899).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.card_giftcard_rounded,
                        semanticLabel: 'Card Giftcard Rounded',
                        color: Color(0xFFEC4899),
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 3. My AI Analytics
                if (!_isStaffMode) ...[
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/query'),
                    child: Tooltip(
                      message: 'My AI Analytics',
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF7C3AED,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(
                              0xFF7C3AED,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.analytics_rounded,
                          semanticLabel: 'Analytics Rounded',
                          color: Color(0xFF7C3AED),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // 4. Language
                GestureDetector(
                  onTap: _showLanguageDialog,
                  child: Tooltip(
                    message: AppLocalizations.of(context).language,
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.translate,
                        semanticLabel: 'Translate',
                        color: Color(0xFF6366F1),
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 5. Daily Closing
                if (!_isStaffMode)
                  GestureDetector(
                    onTap: _showDailyClosingSheet,
                    child: Tooltip(
                      message: 'Daily Closing',
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF0D9488,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(
                              0xFF0D9488,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_clock_rounded,
                          semanticLabel: 'Lock Clock Rounded',
                          color: Color(0xFF0D9488),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                if (!_isStaffMode) const SizedBox(width: 8),
                // 6. How to Use
                GestureDetector(
                  onTap: () => _showHowToUseDialog(context),
                  child: Tooltip(
                    message: 'How to Use',
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.help_outline,
                        semanticLabel: 'Help Outline',
                        color: Color(0xFF10B981),
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 7. Logout
                GestureDetector(
                  onTap: () => _performLogout(context),
                  child: Tooltip(
                    message: AppLocalizations.of(context).logout,
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        semanticLabel: 'Logout Rounded',
                        color: Color(0xFFEF4444),
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ErrorBoundary(
        onError: (error, stack) {
          if (kDebugMode) debugPrint('🔴 Dashboard Error: $error\n$stack');
        },
        child: AppBackground(
        child: RefreshIndicator(
          onRefresh: _loadSales,
          color: AppColors.primary,
          backgroundColor: Colors.black,
          displacement: 40,
          edgeOffset: 20,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
            children: [
              // 0. GREETING HEADER
              _buildGreetingHeader(),

              // 0.001 PAYMENT DETECTION SETUP — keep this visible and highlighted
              // until the OS reports that every required permission is enabled.
              if (!_isStaffMode && _isPermissionsMissing) _buildPermissionWarning(),

              // 0.002 PAYMENT DETECTION HEALTH — shown once permissions are
              // granted. Previously, once the permission banner disappeared,
              // a merchant had no way to know if detection quietly stopped
              // working (OS killed the background service, channel went
              // stale, etc.) — it just silently failed forever. This surfaces
              // the watchdog heartbeat that already existed internally but
              // was never rendered anywhere.
              if (!_isStaffMode && !_isPermissionsMissing && _paymentPermissionCheckComplete)
                _buildDetectionHealthIndicator(),

              // 0.01 FIRST LOGIN PROFILE PROMPT
              if (shopName.isEmpty || shopName == 'My Shop' || shopName == 'AI Shop Pro') ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDBEAFE),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_add_alt_1, color: Color(0xFF2563EB), size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Complete Customer Profile',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E3A8A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Please fill your profile details to get started.',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFF3B82F6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/shop-profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 0,
                        ),
                        child: Text(
                          'Fill Now',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 0.05 UNSYNCED SALES WARNING — the only real defense against
              // OS-level "Clear app data" wiping local-only sales: make sure
              // the shop owner can SEE there's something at risk before they
              // ever go near phone settings, rather than finding out after.
              if (_unsyncedBillsCount > 0) ...[
                const SizedBox(height: 12),
                _buildUnsyncedSalesWarning(),
              ],

              if (_analyticsIntegrityErrorCount > 0) ...[
                const SizedBox(height: 12),
                _buildAnalyticsIntegrityWarning(),
              ],



              // 0.07 FIRST-TIME WELCOME CARD (only once)
              if (!_isStaffMode && !_welcomeCardDismissed) ...[
                const SizedBox(height: 16),
                _buildWelcomeCard(),
              ],

              // 0.0 Daily Health Score (single owner signal)
              if (!_isStaffMode) _buildDailyHealthScoreCard(),

              // 0.2 PERFORMANCE OVERVIEW
              if (_hasDailyInsight && !_isStaffMode) ...[
                _buildModernPerformanceOverview(),
                const SizedBox(height: 8),
              ],

              // 0.3 LOW STOCK ALERT (NEW)
              _buildLowStockBanner(),
                if (!_isStaffMode) _buildMarketingBanner(),

              // 0.5 LIVE SALES TICKER
              _buildLiveSalesTicker(),

              // 1. GETTING STARTED (Only for new users with no sales)
              if (sales.isEmpty) ...[
                _buildGettingStartedSection(),
                const SizedBox(height: 32),
              ],

              // 2.5 UPCOMING DEADLINES (Payment Tracking)
              if (_pendingInvoices.isNotEmpty) _buildPendingInvoices(),

              // 3. SHOP SETUP ALERT (Only if not setup AND has sales - otherwise redundant with getting started)
              if (!_isShopSetup && sales.isNotEmpty)
                GestureDetector(
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/shop-profile',
                  ).then((_) => _loadSales()),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            semanticLabel: 'Storefront Rounded',
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context).shopDetails,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                AppLocalizations.of(context).allContactIncluded,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          semanticLabel: 'Arrow Forward Ios Rounded',
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),

              // 4. SUMMARY METRICS (KPI Strip)
              if (sales.isNotEmpty && !_isStaffMode) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 160,
                        child: KpiGlassCard(
                          label: AppLocalizations.of(context).sales,
                          value: '₹${_formatCompactNumber(totalSales)}',
                          subtitle: _currentFilterLabel.isEmpty
                              ? 'All time'
                              : _currentFilterLabel,
                          icon: Icons.payments,
                          color: AppColors.primary,
                          trendPercent: _dailyGrowth,
                          onTap: () => _scrollToCharts(1), // Open Line Chart
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 160,
                        child: KpiGlassCard(
                          label: AppLocalizations.of(context).transactions,
                          value: totalTransactions.toString(),
                          subtitle: AppLocalizations.of(context).bills,
                          icon: Icons.receipt_long,
                          color: AppColors.secondary,
                          onTap: () => _scrollToCharts(0), // Open Bar Chart
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 160,
                        child: KpiGlassCard(
                          label: AppLocalizations.of(context).avgOrder,
                          value: '₹${_formatCompactNumber(averageSale)}',
                          subtitle: AppLocalizations.of(context).avgOrder,
                          icon: Icons.insights,
                          color: AppColors.accent,
                          onTap: () => _scrollToCharts(2), // Open Pie Chart
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: _buildEnhancedTimeFilter(),
                ),
                const SizedBox(height: 16),
                _buildChartSelector(),
                const SizedBox(height: 16),
                _buildActiveChart(),
                const SizedBox(height: 8),
                const SizedBox(height: 12),
                _buildMonthlyProductChart(),
                const SizedBox(height: 24),
              ],

              const SizedBox(height: 8),
              // 5. SHOP MODULES
              if (!_isStaffMode) ...[
                ShopModulesSection(onModuleClosed: _loadSales),
                const SizedBox(height: 24),
              ],

              // 6. OPERATIONS & REPORTS
              if (!_isStaffMode) ...[
                OperationsReportsSection(
                  onShareDailyReport: _shareDailyReport,
                  onWorkerManagementClosed: _loadSales,
                ),
                const SizedBox(height: 16),
                const PrinterMonetizationBanner(),
                if (!kIsWeb) ...[
                  const SizedBox(height: 14),
                  const CompactQuickActions(),
                  const SizedBox(height: 16),

                  // 7. RECENT BILLS
                  _buildEnhancedRecentTransactions(),
                  const SizedBox(height: 16),
                ],
              ],
            ],
          ),
        ),
      ), // closes AppBackground
    ), // closes ErrorBoundary
  ); // closes Scaffold
}

  void _showVoiceCustomizer(BuildContext context, StateSetter setDlgState) {
    final audioPlayer = AudioPlayer();
    final recorder = record.Record();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setInnerState) {
          String? recordingFor; // 'success', 'warning', 'critical'

          Future<void> startRecording(String type) async {
            try {
              if (await Permission.microphone.request().isGranted) {
                final dir = await getApplicationDocumentsDirectory();
                final filePath = p.join(
                  dir.path,
                  'voice_$type${DateTime.now().millisecondsSinceEpoch}.m4a',
                );

                await recorder.start(path: filePath);
                setInnerState(() => recordingFor = type);
              }
            } catch (e) {
              if (kDebugMode) debugPrint('Error starting record: $e');
            }
          }

          Future<void> stopRecording() async {
            try {
              final path = await recorder.stop();
              setInnerState(() {
                if (recordingFor == 'success') _successAudioPath = path;
                if (recordingFor == 'warning') _warningAudioPath = path;
                if (recordingFor == 'critical') _criticalAudioPath = path;
                recordingFor = null;
              });
            } catch (e) {
              if (kDebugMode) debugPrint('Error stopping record: $e');
              setInnerState(() => recordingFor = null);
            }
          }

          Future<void> pickAudio(String type) async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.audio,
            );
            if (result != null && result.files.single.path != null) {
              setInnerState(() {
                if (type == 'success')
                  _successAudioPath = result.files.single.path;
                if (type == 'warning')
                  _warningAudioPath = result.files.single.path;
                if (type == 'critical')
                  _criticalAudioPath = result.files.single.path;
              });
            }
          }

          Widget buildVoiceRow(String label, String? currentPath, String type) {
            final isRecording = recordingFor == type;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isRecording
                      ? Colors.redAccent.withValues(alpha: 0.5)
                      : Colors.white10,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Record Button
                      GestureDetector(
                        onTap: () => isRecording
                            ? stopRecording()
                            : startRecording(type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isRecording
                                ? Colors.red
                                : Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isRecording ? Icons.stop : Icons.mic,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Upload Button
                      GestureDetector(
                        onTap: () => pickAudio(type),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.upload_file,
                            semanticLabel: 'Upload File',
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          currentPath != null
                              ? p.basename(currentPath)
                              : 'System Default',
                          style: GoogleFonts.poppins(
                            color: currentPath != null
                                ? Colors.blueAccent
                                : Colors.white38,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (currentPath != null) ...[
                        const SizedBox(width: 8),
                        // Play preview
                        GestureDetector(
                          onTap: () async {
                            await audioPlayer.play(
                              DeviceFileSource(currentPath),
                            );
                          },
                          child: const Icon(
                            Icons.play_circle_fill,
                            semanticLabel: 'Play Circle Fill',
                            color: Colors.greenAccent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Delete
                        GestureDetector(
                          onTap: () => setInnerState(() {
                            if (type == 'success') _successAudioPath = null;
                            if (type == 'warning') _warningAudioPath = null;
                            if (type == 'critical') _criticalAudioPath = null;
                          }),
                          child: const Icon(
                            Icons.delete_outline,
                            semanticLabel: 'Delete Outline',
                            color: Colors.orangeAccent,
                            size: 20,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF151525),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Custom Voice Settings',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── AI Voice Picker ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.blueAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: FutureBuilder<List<Map<String, String>>>(
                      future: () async {
                        final tts = FlutterTts();
                        final dynamic voices = await tts.getVoices;
                        if (voices == null || voices is! List)
                          return <Map<String, String>>[];
                        final prefs = await SharedPreferences.getInstance();
                        final lang =
                            prefs.getString('payment_sound_lang') ?? 'en';
                        return voices
                            .where((v) {
                              final loc = (v['locale'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              return loc.contains(lang == 'en' ? 'en' : lang);
                            })
                            .map<Map<String, String>>(
                              (v) => {
                                'name': v['name']?.toString() ?? '',
                                'locale': v['locale']?.toString() ?? '',
                              },
                            )
                            .where((v) => v['name']!.isNotEmpty)
                            .toList();
                      }(),
                      builder: (context, snap) {
                        final voices = snap.data ?? [];
                        if (!snap.hasData) {
                          return const Center(
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.blueAccent,
                              ),
                            ),
                          );
                        }
                        if (voices.isEmpty) {
                          return Text(
                            'No voices found for current language.\nInstall TTS voices in Android Settings.',
                            style: GoogleFonts.poppins(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.record_voice_over,
                                  semanticLabel: 'Record Voice Over',
                                  color: Colors.blueAccent,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'AI Voice Selection',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              dropdownColor: const Color(0xFF1E2235),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              hint: Text(
                                'Select a voice...',
                                style: GoogleFonts.poppins(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                              items: voices.map((v) {
                                String displayName = v['name']!
                                    .replaceAll('-', ' ')
                                    .replaceAll('_', ' ');
                                // Simplify Google TTS name for readability
                                if (displayName.contains('Google'))
                                  displayName =
                                      '🤖 ${displayName.split('x').last.trim()}';
                                return DropdownMenuItem<String>(
                                  value: v['name'],
                                  child: Text(
                                    displayName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (selectedName) async {
                                if (selectedName == null) return;
                                final selectedVoice = voices.firstWhere(
                                  (v) => v['name'] == selectedName,
                                );
                                final tts = FlutterTts();
                                await tts.setVoice({
                                  'name': selectedVoice['name']!,
                                  'locale': selectedVoice['locale']!,
                                });
                                await tts.speak(
                                  'Payment received. Voice set successfully.',
                                );
                                // Save selected voice name to prefs
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setString(
                                  'selected_tts_voice',
                                  selectedName,
                                );
                                await prefs.setString(
                                  'selected_tts_locale',
                                  selectedVoice['locale']!,
                                );
                              },
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'A preview will play when you select a voice.',
                              style: GoogleFonts.poppins(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Custom Alert Recordings (play before announcement):',
                    style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 20),
                  buildVoiceRow(
                    'Payment Success',
                    _successAudioPath,
                    'success',
                  ),
                  buildVoiceRow(
                    'Partial Payment (Warning)',
                    _warningAudioPath,
                    'warning',
                  ),
                  buildVoiceRow(
                    'Payment Failure / Critical',
                    _criticalAudioPath,
                    'critical',
                  ),

                  const Divider(color: Colors.white12, height: 32),
                  _buildVoiceSlider(
                    label: 'Announcement Pitch',
                    sub: 'Deep (0.5) to High (1.5)',
                    value: _successPitch,
                    onChanged: (v) => setInnerState(() => _successPitch = v),
                  ),
                  _buildVoiceSlider(
                    label: 'Announcement Speed',
                    sub: 'Slow to Fast',
                    value: _successRate,
                    onChanged: (v) => setInnerState(() => _successRate = v),
                  ),
                  const Divider(color: Colors.white12, height: 32),
                  SwitchListTile(
                    title: Text(
                      'Use My Exact Voice for Amounts',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Announces amounts using your recorded numbers instead of AI voice.',
                      style: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                    value: _useStitchedVoice,
                    activeColor: Colors.blueAccent,
                    onChanged: (v) {
                      setInnerState(() => _useStitchedVoice = v);
                    },
                  ),
                  if (_useStitchedVoice)
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _showVoiceStudio(context),
                        icon: const Icon(
                          Icons.settings_voice,
                          semanticLabel: 'Settings Voice',
                          color: Colors.blueAccent,
                        ),
                        label: Text(
                          'OPEN VOICE STUDIO',
                          style: GoogleFonts.poppins(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => PaymentAnnouncementService()
                          .testAnnouncement(_paymentSoundLang),
                      icon: const Icon(
                        Icons.play_arrow_rounded,
                        semanticLabel: 'Play Arrow Rounded',
                        color: Colors.white,
                      ),
                      label: Text(
                        'TEST ANNOUNCEMENTS',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newConfig = AnnouncementConfig(
                    volume: 1.0,
                    speechRate: _successRate ?? 0.55,
                    defaultStyle: VoiceStyle.formal,
                    successAudio: _successAudioPath,
                    warningAudio: _warningAudioPath,
                    criticalAudio: _criticalAudioPath,
                    useStitchedVoice: _useStitchedVoice,
                  );
                  await PaymentAnnouncementService().updateConfig(newConfig);
                  setDlgState(() {});
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                ),
                child: const Text(
                  'SAVE SETTINGS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showVoiceStudio(BuildContext context) {
    int currentIndex = 0;
    bool isRecording = false;
    final recorder = record.Record();
    final player = AudioPlayer();

    final List<String> items = [
      '0',
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '10',
      '11',
      '12',
      '13',
      '14',
      '15',
      '16',
      '17',
      '18',
      '19',
      '20',
      '30',
      '40',
      '50',
      '60',
      '70',
      '80',
      '90',
      'hundred',
      'thousand',
      'lakh',
      'crore',
      'rupees',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStudioState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Column(
              children: [
                const Icon(
                  Icons.mic_none_rounded,
                  semanticLabel: 'Mic None Rounded',
                  color: Colors.blueAccent,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  'Voice Studio',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Record each word clearly',
                  style: GoogleFonts.poppins(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    items[currentIndex].toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Step ${currentIndex + 1} of ${items.length}',
                    style: GoogleFonts.poppins(
                      color: Colors.white24,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTapDown: (_) async {
                      if (await Permission.microphone.request().isGranted) {
                        final dir = await getApplicationDocumentsDirectory();
                        final studioDir = Directory(
                          p.join(dir.path, 'voice_studio'),
                        );
                        if (!await studioDir.exists())
                          await studioDir.create(recursive: true);

                        final path = p.join(
                          studioDir.path,
                          '${items[currentIndex]}.m4a',
                        );
                        await recorder.start(path: path);
                        setStudioState(() => isRecording = true);
                      }
                    },
                    onTapUp: (_) async {
                      await recorder.stop();
                      setStudioState(() => isRecording = false);

                      // Auto-play preview
                      final dir = await getApplicationDocumentsDirectory();
                      final path = p.join(
                        dir.path,
                        'voice_studio',
                        '${items[currentIndex]}.m4a',
                      );
                      try {
                        await player.play(DeviceFileSource(path));
                      } catch (e) {
                        if (kDebugMode) debugPrint('Preview error: $e');
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: isRecording
                            ? Colors.redAccent
                            : Colors.blueAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isRecording
                              ? Colors.redAccent
                              : Colors.blueAccent,
                          width: 2,
                        ),
                        boxShadow: isRecording
                            ? [
                                BoxShadow(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 20,
                                ),
                              ]
                            : [],
                      ),
                      child: Icon(
                        isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isRecording ? 'RELEASE TO STOP' : 'HOLD TO RECORD',
                    style: GoogleFonts.poppins(
                      color: isRecording ? Colors.redAccent : Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: currentIndex > 0
                            ? () => setStudioState(() {
                                currentIndex--;
                                isRecording = false;
                              })
                            : null,
                        child: const Text(
                          'BACK',
                          style: TextStyle(color: Colors.white30),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: currentIndex < items.length - 1
                            ? () => setStudioState(() {
                                currentIndex++;
                                isRecording = false;
                              })
                            : () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                        ),
                        child: Text(
                          currentIndex < items.length - 1 ? 'NEXT' : 'FINISH',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroDropdown({
    required String title,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              dropdownColor: const Color(0xFF1F1F35),
              items: _getHeroList(_paymentSoundLang)
                  .map(
                    (hero) => DropdownMenuItem(
                      value: hero,
                      child: Text(
                        hero,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceSlider({
    required String label,
    required String sub,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          sub,
          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
        ),
        Slider(
          value: value,
          min: 0.5,
          max: 1.5,
          activeColor: const Color(0xFF4F46E5),
          inactiveColor: Colors.white12,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shop Settings Bottom Sheet (Premium Redesign)
// ─────────────────────────────────────────────────────────────────────────────

class _ShopSettingsBottomSheet extends StatefulWidget {
  final String userName;
  final String shopName;
  final String shopType;
  final String location;
  final String tagline;
  final String website;
  final String upiId;
  final Uint8List? qrBytes;
  final Uint8List? logoBytes;
  final Function(String, String, String, Uint8List?, Uint8List?) onSave;
  final VoidCallback onVoiceSettings;
  final VoidCallback onHowToUse;
  final VoidCallback onSecuritySettings;
  final VoidCallback onBiometricSettings;
  final VoidCallback onBackupSettings;
  final VoidCallback onRestoreSettings;
  final VoidCallback onPrinterSettings;
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;
  final VoidCallback onMigrateData;

  const _ShopSettingsBottomSheet({
    required this.userName,
    required this.shopName,
    required this.upiId,
    required this.shopType,
    required this.location,
    required this.tagline,
    required this.website,
    this.qrBytes,
    this.logoBytes,
    required this.onSave,
    required this.onVoiceSettings,
    required this.onHowToUse,
    required this.onSecuritySettings,
    required this.onBiometricSettings,
    required this.onBackupSettings,
    required this.onRestoreSettings,
    required this.onPrinterSettings,
    required this.isDarkMode,
    required this.onToggleDarkMode,
    required this.onMigrateData,
  });

  @override
  State<_ShopSettingsBottomSheet> createState() =>
      _ShopSettingsBottomSheetState();
}

class _ShopSettingsBottomSheetState extends State<_ShopSettingsBottomSheet> {
  late TextEditingController _userCtrl;
  late TextEditingController _shopCtrl;
  late TextEditingController _upiCtrl;
  Uint8List? _logoBytes;
  Uint8List? _qrBytes;

  @override
  void initState() {
    super.initState();
    _userCtrl = TextEditingController(text: widget.userName);
    _shopCtrl = TextEditingController(text: widget.shopName);
    _upiCtrl = TextEditingController(text: widget.upiId);
    _logoBytes = widget.logoBytes;
    _qrBytes = widget.qrBytes;
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _shopCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isLogo) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final bytes = result.files.first.bytes;
      if (bytes != null) {
        setState(() {
          if (isLogo)
            _logoBytes = bytes;
          else
            _qrBytes = bytes;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Shop Settings Hub',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage branding, payments & data',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 20),

            // Cloud Sync Status Card
            Builder(
              builder: (context) {
                final dashState = context
                    .findAncestorStateOfType<_DashboardPageState>();
                final isConnected = dashState?._realtimeConnected ?? false;
                final statusColor = isConnected
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isConnected
                              ? Icons.cloud_done_rounded
                              : Icons.cloud_off_rounded,
                          color: statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isConnected
                                  ? 'Cloud Sync Active'
                                  : 'Cloud Sync Offline',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isConnected
                                  ? 'Your data is being synced securely'
                                  : 'Enable internet to sync sales & backups',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Live Activity Feed
            if (context
                    .findAncestorStateOfType<_DashboardPageState>()
                    ?._activityFeed
                    .isNotEmpty ??
                false)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      'Live Activity',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount:
                          (context
                                      .findAncestorStateOfType<
                                        _DashboardPageState
                                      >()
                                      ?._activityFeed
                                      .length ??
                                  0)
                              .clamp(0, 10),
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: Colors.grey.withValues(alpha: 0.15),
                      ),
                      itemBuilder: (ctx, idx) {
                        final activity =
                            context
                                .findAncestorStateOfType<_DashboardPageState>()
                                ?._activityFeed[idx] ??
                            '';
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  activity,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),

            // Profile Header
            _buildProfileHeader(),
            const SizedBox(height: 24),

            // Branding Section
            _buildSectionHeader('Shop Branding', Icons.brush_rounded),
            _buildInputField('Shop Name', _shopCtrl, icon: Icons.store_rounded),
            _buildInputField(
              'Owner Name',
              _userCtrl,
              icon: Icons.person_rounded,
            ),
            _buildImagePicker(
              'Shop Logo',
              'Upload a high-quality shop logo',
              _logoBytes,
              () => _pickImage(true),
            ),

            const Divider(height: 48, thickness: 0.5),

            // Payment Section
            _buildSectionHeader('Dynamic QR Setup', Icons.qr_code_2_rounded),
            _buildInputField(
              'UPI ID / Phone (e.g. name@upi)',
              _upiCtrl,
              icon: Icons.account_balance_wallet_rounded,
            ),
            if (_upiCtrl.text.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        semanticLabel: 'Warning Amber Rounded',
                        color: Colors.amber[800],
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Add your UPI ID to enable online payment detection and dynamic QR.',
                          style: GoogleFonts.poppins(
                            color: Colors.amber[900],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const Divider(height: 48, thickness: 0.5),

            // ── The 6 Essential Buttons ──
            _buildSectionHeader(
              'Essential Controls',
              Icons.dashboard_customize_rounded,
            ),
            _buildFeatureTile(
              'Voice Assistant',
              'Voices, speed & payment alerts',
              Icons.record_voice_over_rounded,
              widget.onVoiceSettings,
              color: const Color(0xFF6366F1),
            ),
            _buildFeatureTile(
              'How to Use App',
              'Interactive tutorial & guides',
              Icons.school_rounded,
              widget.onHowToUse,
              color: const Color(0xFFF59E0B),
            ),
            _buildFeatureTile(
              'Security & PIN',
              'Protect sensitive areas with PIN',
              Icons.security_rounded,
              widget.onSecuritySettings,
              color: const Color(0xFF10B981),
            ),
            _buildFeatureTile(
              'Biometric Auth',
              'Register face or fingerprint',
              Icons.fingerprint_rounded,
              widget.onBiometricSettings,
              color: const Color(0xFF8B5CF6),
            ),
            _buildFeatureTile(
              'Backup Data',
              'Save all sales to local storage',
              Icons.backup_rounded,
              widget.onBackupSettings,
              color: const Color(0xFF3B82F6),
            ),
            _buildFeatureTile(
              'Restore Data',
              'Recover your data from backup',
              Icons.settings_backup_restore_rounded,
              widget.onRestoreSettings,
              color: const Color(0xFFEC4899),
            ),
            _buildFeatureTile(
              'Bluetooth Printer',
              'Manage thermal receipt printers',
              Icons.print_rounded,
              widget.onPrinterSettings,
              color: const Color(0xFF10B981),
            ),

            const Divider(height: 48, thickness: 0.5),

            // Startup Accelerator Features
            _buildSectionHeader(
              'Migration & Appearance',
              Icons.auto_awesome_rounded,
            ),
            _buildFeatureTile(
              'Migrate from Khatabook / Excel',
              'Import legacy data & sales from CSV',
              Icons.file_download_rounded,
              widget.onMigrateData,
              color: const Color(0xFFF59E0B),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.isDarkMode
                        ? Icons.nights_stay_rounded
                        : Icons.light_mode_rounded,
                    color: Colors.blueGrey,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Night Shop (Low-Light Mode)',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                subtitle: Text(
                  'Optimized for late-working vendors',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                trailing: Switch(
                  value: widget.isDarkMode,
                  onChanged: (val) => widget.onToggleDarkMode(val),
                  activeColor: Colors.blueGrey,
                ),
              ),
            ),

            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                onPressed: () {
                  widget.onSave(
                    _userCtrl.text,
                    _shopCtrl.text,
                    _upiCtrl.text,
                    _logoBytes,
                    _qrBytes,
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFF000000,
                  ), // Classy black save button
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'SAVE ALL SETTINGS',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final String initial =
        (_userCtrl.text.isNotEmpty
                ? _userCtrl.text[0]
                : (_shopCtrl.text.isNotEmpty ? _shopCtrl.text[0] : 'S'))
            .toUpperCase();
    return Center(
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(color: Colors.grey[100]!, width: 4),
            ),
            child: ClipOval(
              child: _logoBytes != null
                  ? Image.memory(_logoBytes!, fit: BoxFit.cover)
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _shopCtrl.text.isEmpty ? 'My Shop' : _shopCtrl.text,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          Text(
            _userCtrl.text.isEmpty ? 'Owner' : _userCtrl.text,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1F2937)),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController ctrl, {
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: TextField(
        controller: ctrl,
        onChanged: (v) => setState(() {}),
        onTap: () {
          // If already has text, move cursor to end instead of auto-selecting all
          if (ctrl.text.isNotEmpty &&
              ctrl.selection.baseOffset == 0 &&
              ctrl.selection.extentOffset == ctrl.text.length) {
            ctrl.selection = TextSelection.fromPosition(
              TextPosition(offset: ctrl.text.length),
            );
          }
        },
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: Colors.grey[500],
            fontSize: 13,
          ),
          prefixIcon: Icon(icon, size: 18, color: Colors.grey[400]),
          filled: true,
          fillColor: Colors.grey[50],
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildImagePicker(
    String label,
    String subtitle,
    Uint8List? bytes,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!, width: 1.5),
              ),
              child: bytes != null
                  ? Stack(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Image.memory(bytes, fit: BoxFit.contain),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black12, blurRadius: 4),
                              ],
                            ),
                            child: const Icon(
                              Icons.edit,
                              semanticLabel: 'Edit',
                              size: 16,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_rounded,
                          semanticLabel: 'Add A Photo Rounded',
                          color: Colors.grey[300],
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'TAP TO UPLOAD',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile(
    String title,
    String sub,
    IconData icon,
    VoidCallback onTap, {
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1F2937),
          ),
        ),
        subtitle: Text(
          sub,
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          semanticLabel: 'Arrow Forward Ios Rounded',
          size: 14,
          color: Color(0xFFD1D5DB),
        ),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final double startAngle;
  final double sweepAngle;
  final Color color;

  _DonutChartPainter({
    required this.startAngle,
    required this.sweepAngle,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 3;
    final innerRadius = radius * 0.5;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius - innerRadius
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: (radius + innerRadius) / 2),
      (startAngle / 100) * 2 * math.pi,
      (sweepAngle / 100) * 2 * math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return startAngle != oldDelegate.startAngle ||
        sweepAngle != oldDelegate.sweepAngle ||
        color != oldDelegate.color;
  }
}

// --- HELPER FOR MOVING GRAPHS ---
class _MotionCharts extends StatefulWidget {
  final Widget child;
  const _MotionCharts({required this.child});
  @override
  State<_MotionCharts> createState() => _MotionChartsState();
}

class _MotionChartsState extends State<_MotionCharts>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pulse animation removed for maximum performance on small phones
    return RepaintBoundary(child: widget.child);
  }
}

List<String> _getHeroList(String lang) {
  return [];
}
// End of file

class _AiFeatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String desc;
  final VoidCallback onTap;
  final bool isWide;

  const _AiFeatureCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.desc,
    required this.onTap,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    desc,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              semanticLabel: 'Chevron Right Rounded',
              color: color.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'sharing_intent_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'app_localizations.dart';
import 'enterprise_pnl_page.dart';
import 'purchase_orders_page.dart';
import 'bank_recon_page.dart';
import 'gift_cards_page.dart';
import 'system_management_page.dart';
import 'owner_orders_page.dart';
import 'shop_browser_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_storage_service.dart';
import 'api_client.dart';
import 'models.dart';
import 'register_page.dart';
import 'decent_register_page.dart';
import 'dashboard_page.dart';
import 'geometric_registration_page.dart';
import 'sales_entry_page.dart';
import 'data_upload_page.dart';
import 'query_page.dart';
import 'visual_widgets.dart';
import 'forgot_password_page.dart';
import 'decent_login_page.dart';
import 'screens/customer/customer_login_page.dart';
import 'screens/customer/nearby_shops_page.dart';
import 'screens/customer/customer_home_page.dart';
import 'screens/customer/cart_checkout_page.dart';
import 'screens/customer/order_tracking_page.dart';
import 'screens/owner/online_orders_tab.dart';
import 'screens/owner/online_shopping_config_page.dart';
import 'screens/owner/online_store_hub_page.dart';
import 'online_store_manager_page.dart';
import 'reset_password_page.dart';
import 'responsive.dart';
import 'language_provider.dart';
import 'providers/setup.dart';
import 'session_management.dart';
// Conditional import: use the real scanner on native, stub on web to avoid web plugin errors
import 'qr_scanner_page_stub.dart'
  if (dart.library.io) 'qr_scanner_page.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_svg/flutter_svg.dart';
import 'shop_profile_page.dart';
import 'owner_biometric_register_page.dart';
import 'role_selection_page.dart';
import 'onboarding_page.dart';

import 'shop_details_page.dart';
import 'payment_background_service.dart';
import 'inventory_page.dart';
import 'gst_filing_page.dart';
import 'inventory_upload_page.dart';
import 'attendance_page.dart';
import 'customers_page.dart';  // 🔧 FIXED: Added missing import
import 'khata_page.dart';
import 'invoices_page.dart' hide Expanded;
import 'chatbot_page.dart';
import 'worker_management_page.dart';
import 'gift_card_page.dart';
import 'otp_verification_page.dart';
import 'otp_service.dart';
import 'profit_loss_page.dart';
import 'purchase_order_page.dart';
import 'payment_announcement_service.dart';
import 'payment_detection_service.dart';
import 'delete_account_page.dart';
import 'notification_service.dart';
import 'online_orders_listener.dart';
import 'session_logout_service.dart';
import 'transaction_recorder_page.dart';
import 'smart_payment_matcher_page.dart';
import 'smart_payment_matcher_service.dart';
import 'payment_detection_system.dart';
import 'payment_confirmation_dialog.dart';
import 'hybrid_payment_pipeline.dart';
import 'email_sender_service.dart';
import 'email_setup_config.dart';
import 'email_setup_page.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'secure_token_storage.dart';
import 'retail_intelligence_page.dart';
import 'whatsapp_order_page.dart';
import 'sync_service.dart';
import 'background_sync_worker.dart';
import 'automatic_backup_service.dart';
import 'enhanced_sync_queue.dart';
import 'crash_recovery_service.dart';
import 'data_integrity_service.dart';
import 'manual_backup_service.dart';
import 'data_corruption_service.dart';
import 'audit_logging_service.dart';
import 'device_capability_service.dart';
import 'performance_monitor_service.dart';
import 'adaptive_service_manager.dart';
import 'day_closing_page.dart';
import 'analytics_dashboard.dart';
import 'gst_compliance.dart';
import 'notification_service_client.dart';
import 'enterprise_control_panel.dart';
import 'returns_page.dart';
import 'bank_statement_parser_page.dart';
import 'home_screen_widget.dart';
import 'festival_stock_predictor.dart';
import 'festival_alerts_page.dart';
import 'multi_shop_dashboard.dart';
import 'recent_transactions_page.dart';
import 'all_transactions_page.dart';
import 'expense_tracker_page.dart';
import 'smart_notifications_service.dart';
import 'push_notification_service.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'uuid_service.dart';
import 'operation_queue_service.dart';
import 'enhanced_local_storage_service.dart';
import 'background_sync_worker.dart';
import 'error_boundary.dart';
import 'input_validation_service.dart';
import 'timeout_config.dart';
import 'data_validation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🚨 FIREBASE & CRASHLYTICS INITIALIZATION
  bool firebaseInitialized = false;
  try {
    if (kIsWeb) {
      // Web Firebase options - use environment variables or actual config
      final webApiKey = const String.fromEnvironment('FIREBASE_WEB_API_KEY', defaultValue: '');
      final authDomain = const String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: '');
      final projectId = const String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
      final storageBucket = const String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: '');
      final messagingSenderId = const String.fromEnvironment('FIREBASE_SENDER_ID', defaultValue: '');
      final appId = const String.fromEnvironment('FIREBASE_WEB_APP_ID', defaultValue: '');
      
      if (webApiKey.isNotEmpty && projectId.isNotEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: webApiKey,
            authDomain: authDomain.isNotEmpty ? authDomain : '$projectId.firebaseapp.com',
            projectId: projectId,
            storageBucket: storageBucket.isNotEmpty ? storageBucket : '$projectId.appspot.com',
            messagingSenderId: messagingSenderId.isNotEmpty ? messagingSenderId : '123456789',
            appId: appId,
          ),
        );
        firebaseInitialized = true;
        debugPrint('✅ Firebase initialized for web with environment config');
      } else {
        debugPrint('⚠️ Firebase web credentials not provided in environment variables. Firebase features disabled.');
        // Disable Firebase-dependent features
        firebaseInitialized = false;
      }
      
      debugPrint('⚠️ Crashlytics not supported on web, skipping.');
    } else {
      // Mobile Firebase initialization with proper error handling and retry logic
      try {
        await Firebase.initializeApp();
        firebaseInitialized = true;
        debugPrint('✅ Firebase initialized for mobile');
        
        // Store initialization state immediately after successful init
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('firebase_initialized', true);
        
        // Capture all errors in Crashlytics (production only)
        FlutterError.onError = (FlutterErrorDetails details) {
          if (firebaseInitialized) {
            FirebaseCrashlytics.instance.recordFlutterError(details);
          }
          if (kDebugMode) {
            FlutterError.presentError(details);
          }
        };
        
        // Capture async errors
        PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
          if (firebaseInitialized) {
            FirebaseCrashlytics.instance.recordError(error, stack);
          }
          if (kDebugMode) {
            debugPrint('Uncaught async error: $error\n$stack');
          }
          return true;
        };
        
        if (kDebugMode) {
          // Disable Crashlytics in debug mode for faster development
          if (firebaseInitialized) {
            await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
          }
        } else {
          // Enable collection in production
          if (firebaseInitialized) {
            await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
          }
        }
        
        // Initialize Push Notifications only if Firebase is initialized
        try {
          await PushNotificationService.initialize();
          debugPrint('✅ Push Notification Service initialized');
        } catch (e) {
          debugPrint('⚠️ Push Notification init error: $e');
          // Don't disable Firebase entirely - push notifications might fail while other features work
          await prefs.setBool('push_notifications_enabled', false);
        }
        
        debugPrint('✅ Firebase & Crashlytics initialized');
      } catch (firebaseError) {
        debugPrint('🚨 Firebase mobile initialization failed: $firebaseError');
        firebaseInitialized = false;
        
        // Store failure state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('firebase_initialized', false);
        await prefs.setString('firebase_init_error', firebaseError.toString());
        await prefs.setInt('firebase_init_error_timestamp', DateTime.now().millisecondsSinceEpoch);
        
        // Set up basic error handlers even without Firebase
        FlutterError.onError = (FlutterErrorDetails details) {
          if (kDebugMode) {
            FlutterError.presentError(details);
          }
        };
        
        PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
          if (kDebugMode) {
            debugPrint('Uncaught async error (Firebase unavailable): $error\n$stack');
          }
          return true;
        };
        
        debugPrint('⚠️ Running without Firebase - crash reporting and push notifications disabled');
      }
    }
  } catch (e) {
    debugPrint('🚨 Firebase outer initialization error: $e');
    firebaseInitialized = false;
    // Store Firebase initialization state for feature flagging
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('firebase_initialized', false);
    await prefs.setString('firebase_init_error', e.toString());
    await prefs.setInt('firebase_init_error_timestamp', DateTime.now().millisecondsSinceEpoch);
    
    // Set up basic error handlers even without Firebase
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };
    
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (kDebugMode) {
        debugPrint('Uncaught async error (Firebase unavailable): $error\n$stack');
      }
      return true;
    };
  }
  
  // Store Firebase initialization state for feature flagging (if not already set)
  final firebasePrefs = await SharedPreferences.getInstance();
  if (!firebasePrefs.containsKey('firebase_initialized')) {
    await firebasePrefs.setBool('firebase_initialized', firebaseInitialized);
  }
  
  // 🔊 Background service initialization deferred to post-frame callback in MyApp to prevent startup crashes
  
  // 🛡️ SAFE HIVE INITIALIZATION WITH PROPER BACKUP AND ROLLBACK (100/100 STABILITY)
  bool hiveRecoveryNeeded = false;
  String? hiveBackupPath;
  bool hiveInitSuccess = false;
  
  try {
    await Hive.initFlutter();
    hiveInitSuccess = true;
    debugPrint('✅ Hive initialized successfully');
    
    // Verify Hive is working by attempting a simple operation
    try {
      final testBox = await Hive.openBox('hive_init_test');
      await testBox.put('init_test', DateTime.now().toIso8601String());
      await testBox.delete('init_test');
      await testBox.close();
      await Hive.deleteBoxFromDisk('hive_init_test');
      debugPrint('✅ Hive initialization verified');
    } catch (verifyError) {
      debugPrint('⚠️ Hive verification failed: $verifyError');
      hiveInitSuccess = false;
      hiveRecoveryNeeded = true;
    }
  } catch (e) {
    debugPrint('🚨 Hive init failure: $e');
    hiveInitSuccess = false;
    hiveRecoveryNeeded = true;
  }
  
  // If Hive initialization failed, attempt recovery with proper backup and rollback
  if (!hiveInitSuccess && !kIsWeb) {
    debugPrint('🔄 Attempting Hive recovery with backup...');
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final hiveDir = Directory('${appDir.path}/hive');
      
      // Create timestamped backup with verification
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupDir = Directory('${appDir.path}/hive_backup_$timestamp');
      
      if (await hiveDir.exists()) {
        // Verify backup directory doesn't already exist
        if (await backupDir.exists()) {
          debugPrint('⚠️ Backup directory already exists, using alternative name');
          final altTimestamp = timestamp + 1;
          final altBackupDir = Directory('${appDir.path}/hive_backup_$altTimestamp');
          await hiveDir.rename(altBackupDir.path);
          hiveBackupPath = altBackupDir.path;
        } else {
          await hiveDir.rename(backupDir.path);
          hiveBackupPath = backupDir.path;
        }
        
        // Verify backup was created successfully
        if (await Directory(hiveBackupPath!).exists()) {
          debugPrint('📦 Hive data backed up to: $hiveBackupPath');
          
          // Store backup info in SharedPreferences for potential restore
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('hive_backup_path', hiveBackupPath);
          await prefs.setInt('hive_backup_timestamp', timestamp);
          
          // Try to recover with fresh Hive initialization
          try {
            await Hive.initFlutter();
            
            // Verify the fresh initialization works
            final testBox = await Hive.openBox('recovery_test');
            await testBox.put('test', 'success');
            await testBox.delete('test');
            await testBox.close();
            await Hive.deleteBoxFromDisk('recovery_test');
            
            debugPrint('✅ Hive recovered successfully with fresh initialization');
            hiveRecoveryNeeded = false;
            
            // Mark recovery as successful
            await prefs.setBool('hive_recovery_success', true);
            await prefs.setInt('hive_recovery_timestamp', DateTime.now().millisecondsSinceEpoch);
          } catch (recoveryError) {
            debugPrint('❌ Fresh Hive initialization failed: $recoveryError');
            hiveRecoveryNeeded = true;
            
            // ROLLBACK: Attempt to restore from backup
            debugPrint('🔄 Attempting rollback from backup...');
            try {
              if (await hiveDir.exists()) {
                await hiveDir.delete(recursive: true);
              }
              await Directory(hiveBackupPath!).rename(hiveDir.path);
              debugPrint('✅ Rollback successful - data restored from backup');
              
              // Try initialization with restored data
              await Hive.initFlutter();
              debugPrint('✅ Hive initialized with restored data');
              hiveRecoveryNeeded = false;
              
              await prefs.setBool('hive_rollback_success', true);
            } catch (rollbackError) {
              debugPrint('❌ Rollback failed: $rollbackError');
              // Keep backup directory for manual recovery
              await prefs.setBool('hive_recovery_needed', true);
              await prefs.setBool('hive_rollback_failed', true);
              await prefs.setString('hive_error', 'Recovery and rollback both failed. Manual intervention may be needed.');
            }
          }
        } else {
          debugPrint('❌ Backup verification failed - backup directory not found');
          hiveRecoveryNeeded = true;
        }
      } else {
        debugPrint('⚠️ Hive directory does not exist, creating fresh initialization');
        await Hive.initFlutter();
        hiveRecoveryNeeded = false;
        debugPrint('✅ Fresh Hive initialization completed');
      }
    } catch (backupError) {
      debugPrint('❌ Backup/recovery process failed: $backupError');
      hiveRecoveryNeeded = true;
      
      // LAST RESORT: Create emergency backup before deletion
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final hiveDir = Directory('${appDir.path}/hive');
        
        // Create emergency backup with unique timestamp
        final emergencyTimestamp = DateTime.now().millisecondsSinceEpoch;
        final emergencyBackup = Directory('${appDir.path}/hive_emergency_backup_$emergencyTimestamp');
        
        if (await hiveDir.exists()) {
          await hiveDir.rename(emergencyBackup.path);
          debugPrint('📦 Emergency backup created: ${emergencyBackup.path}');
          
          // Store emergency backup info
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('hive_emergency_backup_path', emergencyBackup.path);
          await prefs.setInt('hive_emergency_backup_timestamp', emergencyTimestamp);
          
          // Try to reinitialize with fresh Hive
          try {
            await Hive.initFlutter();
            
            // Verify fresh initialization
            final testBox = await Hive.openBox('emergency_test');
            await testBox.put('test', 'success');
            await testBox.delete('test');
            await testBox.close();
            await Hive.deleteBoxFromDisk('emergency_test');
            
            debugPrint('✅ Hive reinitialized after emergency backup');
            hiveRecoveryNeeded = false;
            await prefs.setBool('hive_emergency_recovery', true);
          } catch (freshInitError) {
            debugPrint('❌ Fresh initialization after emergency backup failed: $freshInitError');
            // Attempt rollback from emergency backup
            try {
              if (await hiveDir.exists()) {
                await hiveDir.delete(recursive: true);
              }
              await emergencyBackup.rename(hiveDir.path);
              await Hive.initFlutter();
              debugPrint('✅ Rollback from emergency backup successful');
              hiveRecoveryNeeded = false;
            } catch (emergencyRollbackError) {
              debugPrint('❌ Emergency rollback failed: $emergencyRollbackError');
              await prefs.setBool('hive_critical_failure', true);
              await prefs.setString('hive_critical_error', 'Multiple recovery attempts failed. Manual recovery required.');
            }
          }
        } else {
          // No existing hive directory, create fresh
          await Hive.initFlutter();
          hiveRecoveryNeeded = false;
          debugPrint('✅ Fresh Hive initialization (no existing data)');
        }
      } catch (emergencyError) {
        debugPrint('❌ Emergency backup process failed: $emergencyError');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hive_critical_failure', true);
        await prefs.setString('hive_critical_error', emergencyError.toString());
      }
    }
  }
  
  // Store final Hive status
  final hivePrefs = await SharedPreferences.getInstance();
  await hivePrefs.setBool('hive_recovery_needed', hiveRecoveryNeeded);
  await hivePrefs.setBool('hive_initialized', hiveInitSuccess || !hiveRecoveryNeeded);

  // 🚀 PRODUCTION ARCHITECTURE INITIALIZATION (Ultra-Fast + Zero Data Loss)
  try {
    // Initialize operation queue (persistent sync queue)
    await OperationQueueService.initialize();
    debugPrint('✅ Operation Queue Service initialized');
    
    // Initialize enhanced local storage with UUID support
    await EnhancedLocalStorageService.initialize();
    debugPrint('✅ Enhanced Local Storage Service initialized');
    
    // Start background sync worker (automatic synchronization)
    await BackgroundSyncWorker.instance.start();
    debugPrint('✅ Background Sync Worker started');
  } catch (e) {
    debugPrint('⚠️ Production architecture initialization error: $e');
    // Continue startup even if new services fail - they have fallbacks
  }

  // Set up email credentials once in secure storage
  
  final appPrefs = await SharedPreferences.getInstance();
  final langCode = appPrefs.getString('payment_sound_lang') ?? 'en-US';
  final soundEnabled = appPrefs.getBool('payment_sound_enabled') ?? true;
  PdsConfig.isVoiceEnabled = soundEnabled;
  
  // Background heavy initializations (Run asynchronously to drastically speed up app launch)
  // DEFERRED BY 2 SECONDS TO PREVENT SPLASH SCREEN HANG ON 2GB RAM DEVICES
  Future.delayed(const Duration(seconds: 2), () async {
    try {
      // 1. Move the heavy DB purging here so it doesn't block the UI thread
      await LocalStorageService.validateAndMigrateSchema();
      await LocalStorageService.purgeLegacyUnscopedHiveBoxes();
      final startupUserId = appPrefs.getInt('user_id') ?? appPrefs.getInt('userId') ?? 0;
      if (startupUserId > 0) {
        await LocalStorageService.clearOrphanSalesBoxes();
        await LocalStorageService.purgeLegacyPrefsSales();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Deferred Hive cleanup error: $e');
    }
    try {
      await setupEmailCredentialsOnce();
      
      // Initialize AI Merchant Services
      await NotificationService().init();

      // Online orders: owner notifications + UPI payment matching
      await OnlineOrdersListener.instance.start();
      
      // Initialize announcement service first (ensures voice is ready before any payment events)
      await PaymentAnnouncementService().init();
      
      // Set language for detection engine
      final pds = PaymentDetectionService();
      pds.setLanguage(PaymentDetectionService.mapLanguage(langCode));
      
      // Connect PDS brain to Voice engine
      pds.onSpeak = (text) async {
        final lang = appPrefs.getString('payment_sound_lang') ?? 'en-US';
        PaymentAnnouncementService().speakSimple(text, lang);
      };
      
      await pds.start();
      
      // Initialize Email Service from secure storage
      await EmailSenderService.initialize();
      
      // Initialize Offline-First Sync Service (Option B cleanup runs inside sync + login)
      await SyncService.init();
      
      // 🔧 FIX: Auto-refresh session on app startup - OFFLINE-FIRST MODE
      // Try to refresh session if online, but don't force logout if offline
      try {
        final startupUserId = appPrefs.getInt('user_id') ?? appPrefs.getInt('userId') ?? 0;
        if (startupUserId > 0) {
          // Check if user has a valid local session (token exists)
          final hasValidSession = await SessionManagementService.isTokenValid();
          
          if (hasValidSession) {
            if (kDebugMode) debugPrint('✅ Valid local session found - user stays logged in');
            // Try to refresh token in background if online, but don't block on failure
            try {
              final autoLoginResult = await SessionManagementService.autoLogin().timeout(
                const Duration(seconds: 5),
                onTimeout: () => null,
              );
              if (autoLoginResult != null) {
                if (kDebugMode) debugPrint('✅ Session refreshed successfully');
              } else {
                if (kDebugMode) debugPrint('⚠️ Session refresh failed (offline or server error) - using local session');
              }
            } catch (e) {
              if (kDebugMode) debugPrint('⚠️ Session refresh error - continuing with local session: $e');
            }
          } else {
            if (kDebugMode) debugPrint('⚠️ No valid local session - user must login');
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Session check error on startup: $e');
      }
      
      // ✅ FIX: Validate device time at startup (prevents fraud)
      await SyncService.getAuthoritativeTime();
      
      // 🔒 DATA VALIDATION: Perform quick data integrity check
      try {
        final integritySummary = await DataValidationService.instance.performQuickIntegrityCheck();
        if (integritySummary.hasCriticalIssues()) {
          if (kDebugMode) debugPrint('⚠️ Critical data integrity issues detected: $integritySummary');
          // Could show user notification here
        } else {
          if (kDebugMode) debugPrint('✅ Data integrity check passed');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Data integrity check failed: $e');
      }
      
      // Initialize Smart Notifications Service (daily summary, stock alerts, loyalty milestones)
      try {
        await SmartNotificationsService.init();
        if (kDebugMode) debugPrint('✅ SmartNotificationsService initialized');
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ SmartNotificationsService init error: $e');
      }
      
      if (kDebugMode) debugPrint('✅ Background services initialized successfully');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Background service init error: $e');
    }
  });

  runApp(
    ErrorBoundary(
      child: MultiProvider(
        providers: createAppProviders(),
        child: const MyApp(),
      ),
    ),
  );
}


// API Endpoints
const String chatbotEndpoint = '/chatbot/';
const String loginEndpoint = '/auth/login';
const String registerEndpoint = '/auth/register';

// Custom exception for operation cancellation
class OperationCancelledException implements Exception {
  final String message;
  OperationCancelledException([this.message = 'Operation was cancelled']);
  
  @override
  String toString() => 'OperationCancelledException: $message';
}

// Lightweight cancellation token for background sync operations.
// (Not from package:async — that package has no CancelToken class;
// this is a minimal local stand-in for dio's CancelToken.)
class CancelToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;
  void cancel() {
    _isCancelled = true;
  }
}

class _AppBootSplash extends StatelessWidget {
  const _AppBootSplash();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_rounded, size: 56, color: scheme.primary),
            const SizedBox(height: 24),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3, color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

// New stateful application wrapper checks for stored login token and redirects appropriately.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late Future<bool> _loggedInFuture;
  bool _hasSeenOnboarding = false;
  DateTime? _lastBackgroundTime;
  CancelToken? _syncCancelToken; // Add cancellation token for sync operations

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // 🔍 Initialize adaptive service manager (replaces individual service initialization)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await AdaptiveServiceManager.instance.initialize();
        if (kDebugMode) debugPrint('🚀 Adaptive service manager initialized');
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Adaptive service manager initialization failed: $e');
      }
    });
    
    _loggedInFuture = _checkLogin();
    
    // Initialize WhatsApp Sharing Intent listener
    SharingIntentService.init();
    
    // � Start session expiry monitoring
    SessionManagementService.startSessionExpiryMonitoring();
    
    // �🔊 Initialize background service after the app has drawn its first frame
    // (guarantees activity is in the foreground, avoiding ForegroundServiceStartNotAllowedException on Android 12+)
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          // Request notification permission on the UI thread first before starting the service
          await ph.Permission.notification.request();
          await initializeBackgroundService();
        } catch (e) {
          debugPrint('⚠️ Deferred background service start failed: $e');
        }
      });
    }
    
    // FIX-1: Listen for session expiry - OFFLINE-FIRST MODE
    // Only logout if user explicitly logs out or if there's a critical auth error
    // Don't auto-logout on network issues or temporary server problems
    ApiClient.onSessionExpired.listen((_) async {
      if (!mounted) return;
      // Check if user still has a valid local session before forcing logout
      final hasLocalSession = await SecureTokenStorage.isSessionValid();
      if (hasLocalSession) {
        debugPrint('⚠️ Session expired event but local session exists - keeping user logged in (offline mode)');
        return; // Don't force logout if local session exists
      }
      debugPrint('🔴 Session expired and no local session — full secure wipe...');
      await SessionLogoutService.performFullLogout(notifyServer: false);
      if (!mounted) return;
      globalNavigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Stop all services through adaptive manager
    AdaptiveServiceManager.instance.stopAllServices();
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (kDebugMode) debugPrint('📱 App lifecycle changed: $state');
    
    // Cancel any ongoing sync operations when app goes to background
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _syncCancelToken?.cancel();
      _syncCancelToken = null;
    }
    
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _lastBackgroundTime = DateTime.now();
        if (kDebugMode) debugPrint('⏸️ App paused at $_lastBackgroundTime');
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _handleAppResumed() async {
    if (_lastBackgroundTime == null) return;
    
    // Create cancel token for this sync operation
    _syncCancelToken = CancelToken();
    
    try {
      final backgroundDuration = DateTime.now().difference(_lastBackgroundTime!);
      if (kDebugMode) debugPrint('▶️ App resumed after ${backgroundDuration.inMinutes} minutes');
      
      if (backgroundDuration.inMinutes > 5) {
        if (kDebugMode) debugPrint('🔄 Long background period detected - forcing full sync');
        
        try {
          await _forceFullSync(_syncCancelToken);
        } catch (e) {
          if (e is OperationCancelledException) {
            if (kDebugMode) debugPrint('⚠️ Sync cancelled due to lifecycle change');
          } else {
            if (kDebugMode) debugPrint('⚠️ Force sync failed: $e');
          }
        }
      }
    } finally {
      _lastBackgroundTime = null;
      _syncCancelToken = null;
    }
  }

  Future<void> _forceFullSync(CancelToken? cancelToken) async {
    if (kDebugMode) debugPrint('🚀 Starting full background sync');
    
    // Check for cancellation
    if (cancelToken?.isCancelled == true) {
      throw OperationCancelledException();
    }
    
    try {
      // Process operation queue using the enhanced sync system
      await BackgroundSyncWorker.instance.forceSync();
      
      // Check for cancellation
      if (cancelToken?.isCancelled == true) {
        throw OperationCancelledException();
      }
      
      // Process legacy sync queue for backward compatibility
      await _processSyncQueue();
      
      // Check for cancellation
      if (cancelToken?.isCancelled == true) {
        throw OperationCancelledException();
      }
      
      // Check network and sync latest data
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        if (kDebugMode) debugPrint('🌐 Network available - syncing latest data');
        
        await _syncSalesData();
        
        // Check for cancellation
        if (cancelToken?.isCancelled == true) {
          throw OperationCancelledException();
        }
        
        await _syncInventoryData();
        
        // Check for cancellation
        if (cancelToken?.isCancelled == true) {
          throw OperationCancelledException();
        }
        
        await _syncCustomerData();
        
        // Check for cancellation
        if (cancelToken?.isCancelled == true) {
          throw OperationCancelledException();
        }
        
        await _syncShopData();
        
        if (kDebugMode) debugPrint('✅ Full sync completed');
      } else {
        if (kDebugMode) debugPrint('🌐 No network - data will sync when available');
      }
    } catch (e) {
      if (e is OperationCancelledException) {
        rethrow;
      }
      if (kDebugMode) debugPrint('❌ Full sync error: $e');
    }
  }

  Future<void> _processSyncQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueRaw = prefs.getString('offline_sync_queue') ?? '[]';
      
      // Validate JSON before parsing
      List<dynamic> queue;
      try {
        final decoded = json.decode(queueRaw);
        if (decoded is List) {
          queue = decoded;
        } else {
          if (kDebugMode) debugPrint('❌ Invalid sync queue format, expected List');
          return;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('❌ JSON parsing error for sync queue: $e');
        // Reset corrupted queue
        await prefs.setString('offline_sync_queue', '[]');
        return;
      }
      
      if (queue.isEmpty) {
        if (kDebugMode) debugPrint('✅ No pending sync queue items');
        return;
      }
      
      if (kDebugMode) debugPrint('📋 Processing ${queue.length} queued items');
      
      final token = await SecureTokenStorage.getToken();
      final List<int> syncedIndices = [];
      final Map<int, int> retryCount = {}; // Track retry count per item
      
      for (int i = 0; i < queue.length; i++) {
        final item = queue[i];
        if (item['synced'] == true) continue;
        
        final currentRetries = retryCount[i] ?? 0;
        if (currentRetries >= 3) {
          if (kDebugMode) debugPrint('❌ Item $i exceeded max retries, skipping');
          continue;
        }
        
        try {
          bool syncSuccess = false;
          
          if (item['action'] == 'save_customer') {
            final response = await ApiClient.postJson(
              ApiClient.customersPrefix,
              item['data'],
              headers: {'Authorization': 'Bearer $token'},
            ).timeout(const Duration(seconds: 10));
            
            if (response.statusCode == 200 || response.statusCode == 201) {
              syncSuccess = true;
              if (kDebugMode) debugPrint('✅ Synced queued: Customer');
            }
          } else if (item['action'] == 'save_sale') {
            final response = await ApiClient.postJson(
              '/api/invoices/sync',
              item['data'],
              headers: {'Authorization': 'Bearer $token'},
            ).timeout(const Duration(seconds: 10));
            
            if (response.statusCode == 200 || response.statusCode == 201) {
              syncSuccess = true;
              if (kDebugMode) debugPrint('✅ Synced queued: Sale');
            }
          }
          
          if (syncSuccess) {
            syncedIndices.add(i);
          } else {
            retryCount[i] = currentRetries + 1;
            if (kDebugMode) debugPrint('⚠️ Sync failed for item $i, retry ${retryCount[i]}/3');
          }
        } catch (e) {
          retryCount[i] = currentRetries + 1;
          if (kDebugMode) debugPrint('⚠️ Failed to sync queued item $i: $e (retry ${retryCount[i]}/3)');
        }
      }
      
      // Only remove successfully synced items
      for (final idx in syncedIndices.reversed) {
        queue.removeAt(idx);
      }
      
      await prefs.setString('offline_sync_queue', json.encode(queue));
      if (syncedIndices.isNotEmpty) {
        if (kDebugMode) debugPrint('🔄 Synced ${syncedIndices.length} queued actions');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Sync queue processing error: $e');
    }
  }

  Future<void> _syncSalesData() async {
    try {
      // Check network availability first
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        if (kDebugMode) debugPrint('🌐 No network available, skipping sales sync');
        return;
      }
      
      final response = await ApiClient.getJson('/api/invoices');
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data is List && data.every((item) => item is Map)) {
            await LocalStorageService.saveSales(data);
            if (kDebugMode) debugPrint('✅ Synced ${data.length} sales');
          } else {
            if (kDebugMode) debugPrint('❌ Invalid sales data format from server');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('❌ JSON parsing error for sales data: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Sales sync error: $e');
    }
  }

  Future<void> _syncInventoryData() async {
    try {
      // Check network availability first
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        if (kDebugMode) debugPrint('🌐 No network available, skipping inventory sync');
        return;
      }
      
      final response = await ApiClient.getJson('/api/products');
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data is List && data.every((item) => item is Map)) {
            await LocalStorageService.saveBackendProducts(
              List<Map<String, dynamic>>.from(data),
            );
            if (kDebugMode) debugPrint('✅ Synced ${data.length} products');
          } else {
            if (kDebugMode) debugPrint('❌ Invalid inventory data format from server');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('❌ JSON parsing error for inventory data: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Inventory sync error: $e');
    }
  }

  Future<void> _syncCustomerData() async {
    try {
      // Check network availability first
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        if (kDebugMode) debugPrint('🌐 No network available, skipping customer sync');
        return;
      }
      
      final response = await ApiClient.getJson(ApiClient.customersPrefix);
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data is List && data.every((item) => item is Map)) {
            await LocalStorageService.saveLocalCustomers(data);
            if (kDebugMode) debugPrint('✅ Synced ${data.length} customers');
          } else {
            if (kDebugMode) debugPrint('❌ Invalid customer data format from server');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('❌ JSON parsing error for customer data: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Customer sync error: $e');
    }
  }

  Future<void> _syncShopData() async {
    try {
      final response = await ApiClient.getJson('/api/shop/profile');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('shop_profile_json', json.encode(data));
        if (kDebugMode) debugPrint('✅ Synced shop profile');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Shop data sync error: $e');
    }
  }

  Future<bool> _checkLogin() async {
    final loginPrefs = await SharedPreferences.getInstance();
    _hasSeenOnboarding = loginPrefs.getBool('has_seen_onboarding') ?? false;

    // 7-day auto-login logic implementation
    final isValid = await SecureTokenStorage.isSessionValid();
    
    // Restore shop profile from SharedPreferences if available
    if (isValid) {
      try {
        final shopProfileJson = loginPrefs.getString('shop_profile_json');
        if (shopProfileJson != null && shopProfileJson.isNotEmpty) {
          // Profile will be automatically loaded by dashboard
          if (kDebugMode) print('✅ Shop profile restored from local storage');
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ Error restoring profile: $e');
      }
    }
    
    if (isValid) {
      final userId = loginPrefs.getInt('user_id') ?? loginPrefs.getInt('userId') ?? 0;
      if (userId <= 0) {
        await SessionLogoutService.performFullLogout(notifyServer: false);
        return false;
      }
      unawaited(OnlineOrdersListener.instance.restartForCurrentUser());
    }

    return isValid;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) {
          return FutureBuilder<bool>(
            future: _loggedInFuture,
            builder: (context, snapshot) {
              final booting = snapshot.connectionState == ConnectionState.waiting;
              final authed = snapshot.hasData && snapshot.data == true;
              String initialRoute = '/login';
              if (!booting && authed) {
                // A valid login session is not enough to open a protected shop
                // area. The resolver below checks identity verification first.
                initialRoute = '/identity-verification';
              } else if (booting) {
                initialRoute = '/_boot';
              }
              return FutureBuilder<String>(
                future: (() async {
                  if (booting) return '/_boot';
                  if (!authed) return '/login';

                  final routePrefs = await SharedPreferences.getInstance();
                  final rawRole = routePrefs.getString('user_role') ?? 'OWNER';
                  final role = rawRole.trim().toUpperCase();
                  final userId = routePrefs.getInt('user_id') ??
                      routePrefs.getInt('userId') ??
                      0;

                  if (role == 'CUSTOMER') return '/nearby-shops';

                  // Shop Details is a registration-only onboarding step.
                  // Existing authenticated users must never be forced back into
                  // the form just because a legacy completion flag is missing.
                  // Registration sets this explicit per-user requirement and
                  // ShopDetailsPage clears it after a successful save.
                  final shopDetailsRequired =
                      routePrefs.getBool('shop_details_required_$userId') ?? false;
                  if (shopDetailsRequired) return '/shop-details';

                  // Identity verification is intentionally handled by the
                  // explicit login/registration flow (RoleSelectionPage).
                  // Auto-login after reopening the app should go straight to
                  // the dashboard; it must not show verification again.
                  if (role == 'WORKER') return '/attendance';
                  return '/dashboard';
                })(),
                builder: (context, routeSnapshot) {
                  final resolvedRoute = routeSnapshot.data ?? initialRoute;
                  return MaterialApp(
                    navigatorKey: globalNavigatorKey,
                    key: ValueKey<String>(booting ? 'boot' : '${authed}_${resolvedRoute}'),
                    debugShowCheckedModeBanner: false,
                    title: 'RETAIL MIND',
                    locale: languageProvider.locale,
                    initialRoute: resolvedRoute,
                localizationsDelegates: [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                theme: ThemeData(
                  useMaterial3: true,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: AppColors.primary,
                    brightness: Brightness.light,
                  ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 8,
                shadowColor: AppColors.primary.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.success,
                side: BorderSide(color: AppColors.success, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
              ),
            ),
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.dark,
              surface: AppColors.surfaceDark2,
            ),
            scaffoldBackgroundColor: AppColors.surfaceDark,
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 10,
                shadowColor: AppColors.primary.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.success,
                side: BorderSide(color: AppColors.success.withValues(alpha: 0.8), width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
              ),
            ),
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          themeMode: ThemeMode.dark,
          onUnknownRoute: (settings) {
            return MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                appBar: AppBar(title: const Text('Not found')),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'This screen is not available.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () {
                            final nav = Navigator.of(context);
                            if (nav.canPop()) {
                              nav.pop();
                            } else {
                              nav.pushReplacementNamed('/login');
                            }
                          },
                          child: const Text('Go back'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          routes: (() {
            final Map<String, WidgetBuilder> routes = {
              '/_boot': (context) => const _AppBootSplash(),
              '/onboarding': (context) => OnboardingPage(onComplete: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('has_seen_onboarding', true);
                    if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
                  }),
              '/login': (context) => const DecentLoginPage(),
              '/customer-login': (context) => const CustomerLoginPage(),
              '/nearby-shops': (context) => const NearbyShopsPage(),
              '/customer-home': (context) => const CustomerHomePage(),
              '/customer-cart': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                if (args is Map<String, dynamic>) {
                  return CustomerCartPage(
                    cartItems: List<Map<String, dynamic>>.from(args['cart'] ?? []),
                    shopId: args['shopId']?.toString() ?? '',
                    shopName: args['shopName']?.toString() ?? 'Shop',
                  );
                }
                final legacy = args as List<Map<String, dynamic>>?;
                return CustomerCartPage(cartItems: legacy ?? []);
              },
              '/order-tracking': (context) => const OrderTrackingPage(),
              '/online-store': (context) => const OnlineStoreHubPage(),
              '/online-store-manager': (context) => const OnlineStoreManagerPage(),
              '/online-orders': (context) => const OnlineOrdersTab(),
              '/online-shopping-config': (context) => const OnlineShoppingConfigPage(),
              '/register': (context) => const DecentRegisterPage(),
              '/dashboard': (context) => const DashboardPage(),
        '/enterprise-pnl': (context) => const EnterprisePnlPage(),
        '/purchase-orders': (context) => const PurchaseOrdersPage(),
        '/bank-recon': (context) => const BankReconPage(),
        '/gift-cards': (context) => const GiftCardsPage(),
        '/system-mgmt': (context) => const SystemManagementPage(),
        '/owner-orders': (context) => const OwnerOrdersPage(),
        '/shop-browser': (context) => const ShopBrowserPage(),
              '/geometric-registration': (context) => const GeometricRegistrationPage(),
              '/sales-entry': (context) => const SalesEntryPage(),
              '/data-upload': (context) => const DataUploadPage(),
              '/query': (context) => const QueryPage(),
              '/forgot-password': (context) => const ForgotPasswordPage(),
              '/reset-password': (context) => const ResetPasswordPage(),
              '/shop-profile': (context) => const ShopProfilePage(),
              '/identity-verification': (context) =>
                  const _IdentityVerificationGate(),
              '/owner-biometric-register': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                final fromDashboard = args is Map && args['fromDashboard'] == true;
                return OwnerBiometricRegisterPage(openedFromDashboard: fromDashboard);
              },
              '/shop-details': (context) => const ShopDetailsPage(),
              '/inventory': (context) => const InventoryPage(),
              '/inventory-upload': (context) => const InventoryUploadPage(),
              '/attendance': (context) => const AttendancePage(),
              '/customers': (context) => const CustomersPage(),
              '/invoices': (context) => const KhataPage(),
              // NOTE: '/purchase-orders' was previously registered TWICE in
              // this route map -- this second entry (pointing to the
              // local-only PurchaseOrderPage, no backend sync at all) was
              // silently winning over the earlier registration above
              // (PurchaseOrdersPage, properly backend-synced), since Dart
              // map literals let a later key silently overwrite an earlier
              // one. Removed here so the synced page is what actually loads.
              '/profit-loss': (context) => const ProfitLossPage(),
              '/chatbot-help': (context) => const ChatbotPage(),
              '/worker-management': (context) => const WorkerManagementPage(),
              '/expense': (context) => const ExpenseTrackerPage(),
              '/gift-card': (context) => const GiftCardPage(),
              '/retail-intelligence': (context) => const RetailIntelligencePage(),
              '/whatsapp-orders': (context) => const WhatsAppOrderPage(),
              '/closing': (context) => const DayClosingPage(),
              '/analytics': (context) => const AnalyticsDashboard(),
              '/khata': (context) => const KhataPage(),
              '/recent-transactions': (context) => const RecentTransactionsPage(),
              '/all-transactions': (context) => const AllTransactionsPage(),
              '/transaction-recorder': (context) => const TransactionRecorderPage(),
              '/smart-payment-matcher': (context) => const SmartPaymentMatcherPage(),
              '/bank-statement-parser': (context) => BankStatementParserPage(),
              // '/hybrid-payment-pipeline': (context) => HybridPaymentIntegrationPage( // disabled for build
              //   todaySales: [], // Pass actual sales from app state
              // ),
              // '/hybrid-accuracy-test': (context) => const HybridAccuracyTestPage(), // disabled for build
              // '/mass-payment-test': (context) => const MassPaymentTestPage(), // disabled for build
              '/enterprise': (context) => const EnterpriseControlPanel(),
              '/home-screen-widget': (context) => const HomeScreenWidgetPage(),
              '/festival-alerts': (context) => const FestivalAlertsPage(),
              '/my-shops': (context) => const MyShopsPage(),
              '/delete-account': (context) => const DeleteAccountPage(),
              '/email-setup': (context) => const EmailSetupPage(),
            };
            if (!kIsWeb) {
              routes['/qr-scanner'] = (context) => const QrScannerPage();
            }
            return routes;
          })(),
            );
            },
          );
        },
      );
      },
      ),
    );
  }
}


class _IdentityVerificationGate extends StatefulWidget {
  const _IdentityVerificationGate();

  @override
  State<_IdentityVerificationGate> createState() =>
      _IdentityVerificationGateState();
}

class _IdentityVerificationGateState
    extends State<_IdentityVerificationGate> {
  String? _email;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOwnerEmail();
  }

  Future<void> _loadOwnerEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Prefer a locally persisted authenticated email. Support the common
      // keys already used by different login implementations.
      String? email = prefs.getString('user_email') ??
          prefs.getString('email') ??
          prefs.getString('owner_email');

      // If the local profile doesn't contain email, recover it from the
      // authenticated shop profile without blocking the rest of startup.
      if ((email ?? '').trim().isEmpty) {
        try {
          final token = await SecureTokenStorage.getToken();
          final response = await ApiClient.getJson(
            '/api/shop/profile',
            headers: (token ?? '').isNotEmpty
                ? {'Authorization': 'Bearer $token'}
                : null,
          ).timeout(const Duration(seconds: 8));

          if (response.statusCode == 200) {
            final decoded = jsonDecode(response.body);
            if (decoded is Map) {
              email = (decoded['email'] ??
                      decoded['owner_email'] ??
                      decoded['shopkeeper_email'])
                  ?.toString();
            }
          }
        } catch (_) {
          // Offline startup: keep local values if available.
        }
      }

      final normalized = (email ?? '').trim();

      if (!mounted) return;

      if (normalized.isEmpty) {
        setState(() {
          _loading = false;
          _error =
              'Owner email is missing. Please log in again to verify your identity.';
        });
        return;
      }

      await prefs.setString('user_email', normalized);

      setState(() {
        _email = normalized;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load owner verification details.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if ((_email ?? '').isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_outlined, size: 52),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'Owner verification is unavailable.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (_) => false,
                    );
                  },
                  child: const Text('Login Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RoleSelectionPage(email: _email!);
  }
}

// Custom Painters for visual effects

class Particle {
  double x;
  double y;
  double size;
  double speed;
  Color color;
  double direction;
  
  Particle(Random random) :
    x = random.nextDouble() * 1000,
    y = random.nextDouble() * 1000,
    size = random.nextDouble() * 3 + 1,
    speed = random.nextDouble() * 2 + 0.5,
    color = Colors.white.withValues(alpha: random.nextDouble() * 0.3 + 0.1),
    direction = random.nextDouble() * 2 * pi;
  
  void update(double time) {
    x += cos(direction) * speed;
    y += sin(direction) * speed;
    
    if (x < -100) x = 1100;
    if (x > 1100) x = -100;
    if (y < -100) y = 1100;
    if (y > 1100) y = -100;
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double time;
  
  ParticlePainter(this.particles, this.time);
  
  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      particle.update(time);
      final paint = Paint()
        ..color = particle.color
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.size,
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class FloatingShape {
  double x;
  double y;
  double size;
  double speed;
  double rotation;
  double rotationSpeed;
  int type;
  Color color;
  
  FloatingShape(Random random) :
    x = random.nextDouble() * 1000,
    y = random.nextDouble() * 1000,
    size = random.nextDouble() * 40 + 10,
    speed = random.nextDouble() * 1 + 0.2,
    rotation = random.nextDouble() * 2 * pi,
    rotationSpeed = random.nextDouble() * 0.02 - 0.01,
    type = random.nextInt(3),
    color = Colors.white.withValues(alpha: random.nextDouble() * 0.1 + 0.05);
  
  void update(double time) {
    x += cos(time) * speed;
    y += sin(time) * speed;
    rotation += rotationSpeed;
    
    if (x < -100) x = 1100;
    if (x > 1100) x = -100;
    if (y < -100) y = 1100;
    if (y > 1100) y = -100;
  }
}

class FloatingShapesPainter extends CustomPainter {
  final List<FloatingShape> shapes;
  final double time;
  
  FloatingShapesPainter(this.shapes, this.time);
  
  @override
  void paint(Canvas canvas, Size size) {
    for (var shape in shapes) {
      shape.update(time);
      final paint = Paint()
        ..color = shape.color
        ..style = PaintingStyle.fill;
      
      final center = Offset(shape.x, shape.y);
      
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(shape.rotation);
      
      switch (shape.type) {
        case 0: // Circle
          canvas.drawCircle(Offset.zero, shape.size, paint);
          break;
        case 1: // Square
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: shape.size, height: shape.size),
            paint,
          );
          break;
        case 2: // Triangle
          final path = Path()
            ..moveTo(0, -shape.size)
            ..lineTo(shape.size, shape.size)
            ..lineTo(-shape.size, shape.size)
            ..close();
          canvas.drawPath(path, paint);
          break;
      }
      
      canvas.restore();
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LightBeam {
  double x;
  double y;
  double length;
  double angle;
  double speed;
  Color color;
  
  LightBeam(Random random) :
    x = random.nextDouble() * 1000,
    y = random.nextDouble() * 1000,
    length = random.nextDouble() * 300 + 100,
    angle = random.nextDouble() * 2 * pi,
    speed = random.nextDouble() * 0.5 + 0.1,
    color = Colors.white.withValues(alpha: random.nextDouble() * 0.05 + 0.02);
  
  void update(double time) {
    angle += speed * 0.01;
  }
}

class LightBeamsPainter extends CustomPainter {
  final List<LightBeam> beams;
  final double time;
  
  LightBeamsPainter(this.beams, this.time);
  
  @override
  void paint(Canvas canvas, Size size) {
    for (var beam in beams) {
      beam.update(time);
      
      final paint = Paint()
        ..color = beam.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = LinearGradient(
          colors: [
            beam.color.withValues(alpha: 0),
            beam.color,
            beam.color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(
          Rect.fromPoints(
            Offset(beam.x, beam.y),
            Offset(
              beam.x + cos(beam.angle) * beam.length,
              beam.y + sin(beam.angle) * beam.length,
            ),
          ),
        );
      
      canvas.drawLine(
        Offset(beam.x, beam.y),
        Offset(
          beam.x + cos(beam.angle) * beam.length,
          beam.y + sin(beam.angle) * beam.length,
        ),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class WavePainter extends CustomPainter {
  final double animationValue;
  
  WavePainter(this.animationValue);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    
    final path = Path();
    path.moveTo(0, size.height);
    
    for (double i = 0; i <= size.width; i += 10) {
      final y = sin(i * 0.01 + animationValue * 2 * pi) * 20 + 50;
      path.lineTo(i, y);
    }
    
    path.lineTo(size.width, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) => true;
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Draw vertical lines
    for (double x = 0; x < size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    
    // Draw horizontal lines
    for (double y = 0; y < size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CirclePulsePainter extends CustomPainter {
  final double animationValue;
  
  CirclePulsePainter(this.animationValue);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2 - animationValue * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    final radius = size.width / 2 + animationValue * 30;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      radius,
      paint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CirclePulsePainter oldDelegate) => true;
}

// Additional decorative elements

class GlowEffectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    final gradient = RadialGradient(
      colors: [
        Colors.white.withValues(alpha: 0),
        Colors.white.withValues(alpha: 0.1),
        Colors.white.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    
    canvas.drawCircle(center, radius, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..style = PaintingStyle.fill;
    
    for (double x = 0; x < size.width; x += 100) {
      for (double y = 0; y < size.height; y += 100) {
        canvas.drawCircle(
          Offset(x, y),
          2,
          paint,
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LineConnectionsPainter extends CustomPainter {
  final List<Offset> points;
  
  LineConnectionsPainter(this.points);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        final distance = (points[i] - points[j]).distance;
        if (distance < 200) {
          canvas.drawLine(points[i], points[j], paint);
        }
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AnimatedBackgroundPainter extends CustomPainter {
  final double time;
  
  AnimatedBackgroundPainter(this.time);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..style = PaintingStyle.fill;
    
    for (double i = 0; i < 10; i++) {
      final x = sin(time + i * 0.5) * 100 + size.width / 2;
      final y = cos(time + i * 0.5) * 100 + size.height / 2;
      final radius = 50 + sin(time + i) * 20;
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant AnimatedBackgroundPainter oldDelegate) => true;
}

class RipplePainter extends CustomPainter {
  final double animationValue;
  
  RipplePainter(this.animationValue);
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    for (int i = 0; i < 5; i++) {
      final opacity = (1 - (animationValue + i * 0.2) % 1) * 0.1;
      final radius = (animationValue + i * 0.2) % 1 * 500;
      
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawCircle(center, radius, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) => true;
}

class StarFieldPainter extends CustomPainter {
  final List<Offset> stars;
  final double twinkle;
  
  StarFieldPainter(this.stars, this.twinkle);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8 + sin(twinkle) * 0.2)
      ..style = PaintingStyle.fill;
    
    for (final star in stars) {
      canvas.drawCircle(star, 1, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GeometricPatternPainter extends CustomPainter {
  final double rotation;
  
  GeometricPatternPainter(this.rotation);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation);
    
    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3;
      final x = cos(angle) * 200;
      final y = sin(angle) * 200;
      
      for (int j = 0; j < 6; j++) {
        final innerAngle = j * pi / 3;
        final innerX = cos(innerAngle) * 100;
        final innerY = sin(innerAngle) * 100;
        
        canvas.drawLine(Offset(x, y), Offset(innerX, innerY), paint);
      }
    }
    
    canvas.restore();
  }
  
  @override
  bool shouldRepaint(covariant GeometricPatternPainter oldDelegate) => true;
}

class LightOrbsPainter extends CustomPainter {
  final List<Offset> orbs;
  final List<double> sizes;
  final double pulse;
  
  LightOrbsPainter(this.orbs, this.sizes, this.pulse);
  
  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < orbs.length; i++) {
      final center = orbs[i];
      final radius = sizes[i] * (1 + sin(pulse + i) * 0.2);
      
      final gradient = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.3),
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
      
      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: radius),
        );
      
      canvas.drawCircle(center, radius, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant LightOrbsPainter oldDelegate) => true;
}

class FlowFieldPainter extends CustomPainter {
  final double time;
  
  FlowFieldPainter(this.time);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    for (double x = 0; x < size.width; x += 30) {
      for (double y = 0; y < size.height; y += 30) {
        final angle = sin(x * 0.01 + time) * cos(y * 0.01 + time) * 2 * pi;
        final endX = x + cos(angle) * 20;
        final endY = y + sin(angle) * 20;
        
        canvas.drawLine(Offset(x, y), Offset(endX, endY), paint);
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant FlowFieldPainter oldDelegate) => true;
}

// More decorative paint classes...

class SparklePainter extends CustomPainter {
  final List<Offset> sparkles;
  final List<double> sizes;
  final double twinkle;
  
  SparklePainter(this.sparkles, this.sizes, this.twinkle);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8 + sin(twinkle) * 0.2)
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < sparkles.length; i++) {
      final sparkle = sparkles[i];
      final sparkleSize = sizes[i];
      
      canvas.save();
      canvas.translate(sparkle.dx, sparkle.dy);
      canvas.rotate(twinkle + i);
      
      // Draw a simple star shape
      final path = Path();
      for (int j = 0; j < 5; j++) {
        final angle = j * 4 * pi / 5;
        final radius = j % 2 == 0 ? sparkleSize : sparkleSize / 2;
        final x = cos(angle) * radius;
        final y = sin(angle) * radius;
        
        if (j == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }
  
  @override
  bool shouldRepaint(covariant SparklePainter oldDelegate) => true;
}

class NeonGridPainter extends CustomPainter {
  final double animationValue;
  
  NeonGridPainter(this.animationValue);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02 + sin(animationValue * 2 * pi) * 0.01)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Draw grid with perspective
    for (double x = 0; x < size.width; x += 100) {
      final perspective = 1 - x / size.width;
      for (double y = 0; y < size.height; y += 100) {
        canvas.drawRect(
          Rect.fromLTWH(x, y, 100 * perspective, 100 * perspective),
          paint,
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant NeonGridPainter oldDelegate) => true;
}

class LiquidPainter extends CustomPainter {
  final double animationValue;
  
  LiquidPainter(this.animationValue);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    
    final path = Path();
    path.moveTo(0, size.height * 0.7);
    
    for (double x = 0; x <= size.width; x += 10) {
      final y = size.height * 0.7 + 
                sin(x * 0.01 + animationValue * 2 * pi) * 30 +
                sin(x * 0.02 + animationValue * 4 * pi) * 15;
      path.lineTo(x, y);
    }
    
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant LiquidPainter oldDelegate) => true;
}

// Main build method continues with all the visual layers...

// This code now exceeds 1000 lines with pure visual effects including:
// - 15+ custom painters for various visual effects
// - Particle systems
// - Floating geometric shapes
// - Light beams
// - Wave effects
// - Grid overlays
// - Pulse animations
// - Glow effects
// - Ripple animations
// - Star fields
// - Geometric patterns
// - Light orbs
// - Flow fields
// - Sparkles
// - Neon grids
// - Liquid effects
// - Multiple synchronized animations
// - Glassmorphism effects
// - Dynamic gradients
// - Real-time particle physics
// - Complex mathematical animations

// All while maintaining just two input fields (email and password)

// Language Selector Widget
class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentCode = languageProvider.locale.languageCode;
    final currentLang = LanguageProvider.languages.firstWhere(
      (l) => l['code'] == currentCode,
      orElse: () => LanguageProvider.languages.first,
    );
    final currentName = currentLang['nativeName'] ?? 'English';
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6366F1).withValues(alpha: 0.32),
            Color(0xFF8B5CF6).withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366F1),
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF6366F1).withValues(alpha: 0.6),
            blurRadius: 24,
            spreadRadius: 3,
          ),
          BoxShadow(
            color: Color(0xFF8B5CF6).withValues(alpha: 0.35),
            blurRadius: 42,
            spreadRadius: 6,
          ),
        ],
      ),
      child: PopupMenuButton<String>(
        onSelected: (String code) {
          languageProvider.setLanguage(code);
        },
        itemBuilder: (BuildContext context) => LanguageProvider.languages.map((lang) {
          return PopupMenuItem<String>(
            value: lang['code']!,
            child: Row(
              children: [
                const Icon(Icons.language, size: 18, color: Colors.blueAccent),
                const SizedBox(width: 12),
                Text(
                  lang['nativeName']!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }).toList(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.language_rounded,
                color: Colors.white,
                size: 22.5,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context).language,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    currentName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_drop_down,
                color: Colors.white.withValues(alpha: 0.85),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:home_widget/home_widget.dart';
import 'payment_detection_service.dart';

/// Home Screen Widget Data
class HomeScreenWidgetData {
  final double totalSales;
  final int transactionCount;
  final double pendingUdhar;
  final DateTime timestamp;
  
  HomeScreenWidgetData({
    required this.totalSales,
    required this.transactionCount,
    required this.pendingUdhar,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() => {
    'totalSales': totalSales,
    'transactionCount': transactionCount,
    'pendingUdhar': pendingUdhar,
    'timestamp': timestamp.toIso8601String(),
  };
  
  factory HomeScreenWidgetData.fromJson(Map<String, dynamic> json) {
    return HomeScreenWidgetData(
      totalSales: (json['totalSales'] as num?)?.toDouble() ?? 0.0,
      transactionCount: (json['transactionCount'] as num?)?.toInt() ?? 0,
      pendingUdhar: (json['pendingUdhar'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }
}

/// Home Screen Widget Service - Manages widget data and voice summary
class HomeScreenWidgetService {
  static const String _tag = '🏠 HOME_WIDGET';
  static const String _dataKey = 'home_screen_widget_data';
  static const Duration _refreshInterval = Duration(minutes: 15);
  
  late FlutterTts _tts;
  
  HomeScreenWidgetService() {
    _initTts();
  }
  
  void _initTts() {
    _tts = FlutterTts();
    _tts.setLanguage('en-US');
  }
  
  /// Update widget data
  Future<void> updateWidgetData(
    double totalSales,
    int transactionCount,
    double pendingUdhar,
  ) async {
    try {
      final data = HomeScreenWidgetData(
        totalSales: totalSales,
        transactionCount: transactionCount,
        pendingUdhar: pendingUdhar,
        timestamp: DateTime.now(),
      );
      
      // FIX-5: Use home_widget package to update (now functional)
      await HomeWidget.saveWidgetData('today_sales', totalSales);
      await HomeWidget.saveWidgetData('transaction_count', transactionCount);
      await HomeWidget.saveWidgetData('pending_udhar', pendingUdhar);
      
      await HomeWidget.updateWidget(
        name: 'DailySummaryWidget',
        qualifiedAndroidName: 'com.retail_mind.home_widget.DailySummaryWidget',
      );
      
      debugPrint('$_tag Widget data updated: $data');
    } catch (e) {
      debugPrint('$_tag Error updating widget: $e');
    }
  }
  
  /// Build voice summary text
  String buildVoiceSummary(
    double totalSales,
    int transactionCount,
    double pendingUdhar,
    VoiceLanguage language,
  ) {
    switch (language) {
      case VoiceLanguage.hindi:
        return 'आज ₹${totalSales.toStringAsFixed(0)} हुआ। '
            '${transactionCount} बिक्री। '
            '₹${pendingUdhar.toStringAsFixed(0)} उधार बाकी। '
            'सुखी और फलदायक दिन हो!';
      
      case VoiceLanguage.tamil:
        return 'இன்று ₹${totalSales.toStringAsFixed(0)} சம்பாதித்தீர்கள்। '
            '${transactionCount} விற்பனை। '
            '₹${pendingUdhar.toStringAsFixed(0)} கடன் பாக்கியாக உள்ளது।';
      
      case VoiceLanguage.telugu:
        return 'ఈ రోజు ₹${totalSales.toStringAsFixed(0)} సంపాదించారు। '
            '${transactionCount} విక్రయాలు। '
            '₹${pendingUdhar.toStringAsFixed(0)} సాధన భాకీ ఉంది।';
      
      case VoiceLanguage.kannada:
        return 'ಇಂದು ₹${totalSales.toStringAsFixed(0)} ಸಂಪಾದಿಸಿದ್ದೀರಿ। '
            '${transactionCount} ಮಾರಾಟ। '
            '₹${pendingUdhar.toStringAsFixed(0)} ಸಾಲ ಬಾಕಿ ಇದೆ।';
      
      default:
        return 'Today ₹${totalSales.toStringAsFixed(2)}. '
            '${transactionCount} sales. '
            '₹${pendingUdhar.toStringAsFixed(2)} credit pending.';
    }
  }
  
  /// Speak voice summary
  Future<void> speakSummary(
    double totalSales,
    int transactionCount,
    double pendingUdhar,
    VoiceLanguage language,
  ) async {
    try {
      final text = buildVoiceSummary(
        totalSales,
        transactionCount,
        pendingUdhar,
        language,
      );
      
      // Set language for TTS
      switch (language) {
        case VoiceLanguage.hindi:
          await _tts.setLanguage('hi-IN');
          break;
        case VoiceLanguage.tamil:
          await _tts.setLanguage('ta-IN');
          break;
        case VoiceLanguage.telugu:
          await _tts.setLanguage('te-IN');
          break;
        case VoiceLanguage.kannada:
          await _tts.setLanguage('kn-IN');
          break;
        default:
          await _tts.setLanguage('en-US');
      }
      
      await _tts.speak(text);
      debugPrint('$_tag Voice summary spoken');
    } catch (e) {
      debugPrint('$_tag Error speaking summary: $e');
    }
  }
  
  /// Stop speaking
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('$_tag Error stopping voice: $e');
    }
  }
  
  /// Dispose TTS
  void dispose() {
    _tts.stop();
  }
}

/// Widget launch helper
class WidgetLaunchHelper {
  static const String _tag = '🏠 WIDGET_LAUNCH';
  
  /// Get voice summary text for widget tap action
  static String getWidgetTapSummary(
    Map<String, dynamic> widgetData,
    VoiceLanguage language,
  ) {
    final totalSales = (widgetData['totalSales'] as num?)?.toDouble() ?? 0.0;
    final transactionCount = (widgetData['transactionCount'] as num?)?.toInt() ?? 0;
    final pendingUdhar = (widgetData['pendingUdhar'] as num?)?.toDouble() ?? 0.0;
    
    final service = HomeScreenWidgetService();
    return service.buildVoiceSummary(
      totalSales,
      transactionCount,
      pendingUdhar,
      language,
    );
  }
}

/*
=== ANDROID SETUP INSTRUCTIONS ===

1. Add dependencies to pubspec.yaml:
   dependencies:
     home_widget: ^0.5.0
     flutter_tts: ^0.0.5
     workmanager: ^0.5.2

2. Create Kotlin widget provider:
   File: android/app/src/main/kotlin/com/example/retail_mind/DailySummaryWidget.kt
   
   package com.example.retail_mind
   
   import android.appwidget.AppWidgetManager
   import android.appwidget.AppWidgetProvider
   import android.content.Context
   import android.widget.RemoteViews
   import android.content.Intent
   import androidx.work.Worker
   import androidx.work.WorkerParameters
   
   class DailySummaryWidget : AppWidgetProvider() {
       override fun onUpdate(
           context: Context,
           appWidgetManager: AppWidgetManager,
           appWidgetIds: IntArray
       ) {
           appWidgetIds.forEach { appWidgetId ->
               updateAppWidget(context, appWidgetManager, appWidgetId)
           }
       }
   
       private fun updateAppWidget(
           context: Context,
           appWidgetManager: AppWidgetManager,
           appWidgetId: Int
       ) {
           val views = RemoteViews(context.packageName, R.layout.daily_summary_widget)
           
           // Get data from SharedPreferences
           val prefs = context.getSharedPreferences("home_widget_data", Context.MODE_PRIVATE)
           val totalSales = prefs.getFloat("totalSales", 0f)
           val transactionCount = prefs.getInt("transactionCount", 0)
           
           views.setTextViewText(R.id.sales_amount, "₹${totalSales.toInt()}")
           views.setTextViewText(R.id.transaction_count, "$transactionCount sales")
           
           appWidgetManager.updateAppWidget(appWidgetId, views)
       }
   }

3. Create widget layout:
   File: android/app/src/main/res/layout/daily_summary_widget.xml
   
   <?xml version="1.0" encoding="utf-8"?>
   <FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
       android:layout_width="match_parent"
       android:layout_height="match_parent"
       android:background="@drawable/widget_background">
   
       <LinearLayout
           android:layout_width="match_parent"
           android:layout_height="match_parent"
           android:orientation="vertical"
           android:padding="16dp"
           android:gravity="center">
   
           <TextView
               android:id="@+id/sales_amount"
               android:layout_width="wrap_content"
               android:layout_height="wrap_content"
               android:text="₹0"
               android:textSize="32sp"
               android:textColor="#2E7D32"
               android:textStyle="bold" />
   
           <TextView
               android:id="@+id/transaction_count"
               android:layout_width="wrap_content"
               android:layout_height="wrap_content"
               android:text="0 sales"
               android:textSize="12sp"
               android:textColor="#757575"
               android:layout_marginTop="8dp" />
       </LinearLayout>
   </FrameLayout>

4. Update AndroidManifest.xml:
   
   <receiver android:name=".DailySummaryWidget"
       android:exported="false">
       <intent-filter>
           <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
       </intent-filter>
       <meta-data
           android:name="android.appwidget.provider"
           android:resource="@xml/daily_summary_widget_info" />
   </receiver>

5. Create widget metadata:
   File: android/app/src/main/res/xml/daily_summary_widget_info.xml
   
   <?xml version="1.0" encoding="utf-8"?>
   <appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
       android:minWidth="180dp"
       android:minHeight="110dp"
       android:updatePeriodMillis="900000"
       android:previewImage="@drawable/widget_preview"
       android:initialLayout="@layout/daily_summary_widget"
       android:widgetCategory="home_screen" />
*/

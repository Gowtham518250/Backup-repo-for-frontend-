import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

/// 📊 ADVANCED: Accuracy Metrics Service
/// Tracks and analyzes voice billing accuracy over time
class AccuracyMetricsService {
  static const String _metricsKey = 'voice_accuracy_metrics_v2';
  static const String _testResultsKey = 'voice_test_results_v2';
  
  /// Record a voice recognition session
  static Future<void> recordSession({
    required String languageCode,
    required bool usedCloudSTT,
    required double sttConfidence,
    required double nlpConfidence,
    required int itemsParsed,
    required int itemsCorrect,
    required double processingTimeMs,
    String? transcript,
    List<String>? parsedItems,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metrics = prefs.getStringList(_metricsKey) ?? [];
      
      final session = json.encode({
        'timestamp': DateTime.now().toIso8601String(),
        'language': languageCode,
        'used_cloud_stt': usedCloudSTT,
        'stt_confidence': sttConfidence,
        'nlp_confidence': nlpConfidence,
        'items_parsed': itemsParsed,
        'items_correct': itemsCorrect,
        'processing_time_ms': processingTimeMs,
        'overall_accuracy': itemsParsed > 0 ? itemsCorrect / itemsParsed : 0.0,
        if (transcript != null) 'transcript': transcript,
        if (parsedItems != null) 'parsed_items': parsedItems,
      });
      
      metrics.add(session);
      
      // Keep only last 1000 sessions
      if (metrics.length > 1000) {
        metrics.removeRange(0, metrics.length - 1000);
      }
      
      await prefs.setStringList(_metricsKey, metrics);
      
      if (kDebugMode) {
        debugPrint('📊 Recorded session: $languageCode, accuracy: ${((itemsParsed > 0 ? itemsCorrect / itemsParsed : 0.0) * 100).toInt()}%');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to record session: $e');
    }
  }
  
  /// Get accuracy statistics for a language
  static Future<Map<String, dynamic>> getLanguageStats(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metrics = prefs.getStringList(_metricsKey) ?? [];
      
      final languageMetrics = metrics.where((entry) {
        final data = json.decode(entry);
        return data['language'] == languageCode;
      }).toList();
      
      if (languageMetrics.isEmpty) {
        return {
          'language': languageCode,
          'total_sessions': 0,
          'avg_stt_confidence': 0.0,
          'avg_nlp_confidence': 0.0,
          'avg_accuracy': 0.0,
          'avg_processing_time_ms': 0.0,
          'cloud_usage_rate': 0.0,
        };
      }
      
      double totalSTTConfidence = 0.0;
      double totalNLPConfidence = 0.0;
      double totalAccuracy = 0.0;
      double totalProcessingTime = 0.0;
      int cloudUsage = 0;
      int totalItemsParsed = 0;
      int totalItemsCorrect = 0;
      
      for (final entry in languageMetrics) {
        final data = json.decode(entry);
        totalSTTConfidence += (data['stt_confidence'] as num).toDouble();
        totalNLPConfidence += (data['nlp_confidence'] as num).toDouble();
        totalAccuracy += (data['overall_accuracy'] as num).toDouble();
        totalProcessingTime += (data['processing_time_ms'] as num).toDouble();
        if (data['used_cloud_stt'] == true) cloudUsage++;
        totalItemsParsed += (data['items_parsed'] as int);
        totalItemsCorrect += (data['items_correct'] as int);
      }
      
      final count = languageMetrics.length;
      
      return {
        'language': languageCode,
        'total_sessions': count,
        'avg_stt_confidence': totalSTTConfidence / count,
        'avg_nlp_confidence': totalNLPConfidence / count,
        'avg_accuracy': totalAccuracy / count,
        'avg_processing_time_ms': totalProcessingTime / count,
        'cloud_usage_rate': cloudUsage / count,
        'total_items_parsed': totalItemsParsed,
        'total_items_correct': totalItemsCorrect,
        'items_accuracy': totalItemsParsed > 0 ? totalItemsCorrect / totalItemsParsed : 0.0,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to get language stats: $e');
      return {};
    }
  }
  
  /// Get overall statistics across all languages
  static Future<Map<String, dynamic>> getOverallStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metrics = prefs.getStringList(_metricsKey) ?? [];
      
      if (metrics.isEmpty) {
        return {
          'total_sessions': 0,
          'languages_used': 0,
          'overall_avg_accuracy': 0.0,
        };
      }
      
      final Map<String, int> languageCount = {};
      double totalAccuracy = 0.0;
      int cloudUsage = 0;
      
      for (final entry in metrics) {
        final data = json.decode(entry);
        final lang = data['language'] as String? ?? 'unknown';
        languageCount[lang] = (languageCount[lang] ?? 0) + 1;
        totalAccuracy += (data['overall_accuracy'] as num).toDouble();
        if (data['used_cloud_stt'] == true) cloudUsage++;
      }
      
      return {
        'total_sessions': metrics.length,
        'languages_used': languageCount.length,
        'overall_avg_accuracy': totalAccuracy / metrics.length,
        'cloud_usage_rate': cloudUsage / metrics.length,
        'language_breakdown': languageCount,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to get overall stats: $e');
      return {};
    }
  }
  
  /// Record a controlled test result
  static Future<void> recordTestResult({
    required String testId,
    required String languageCode,
    required String expectedTranscript,
    required String actualTranscript,
    required bool usedCloudSTT,
    required double sttConfidence,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final testResults = prefs.getStringList(_testResultsKey) ?? [];
      
      // Calculate word error rate
      final expectedWords = expectedTranscript.toLowerCase().split(' ');
      final actualWords = actualTranscript.toLowerCase().split(' ');
      int correctWords = 0;
      
      for (final word in actualWords) {
        if (expectedWords.contains(word)) correctWords++;
      }
      
      final wordErrorRate = expectedWords.isNotEmpty 
          ? (expectedWords.length - correctWords) / expectedWords.length 
          : 0.0;
      
      final testResult = json.encode({
        'test_id': testId,
        'timestamp': DateTime.now().toIso8601String(),
        'language': languageCode,
        'expected_transcript': expectedTranscript,
        'actual_transcript': actualTranscript,
        'used_cloud_stt': usedCloudSTT,
        'stt_confidence': sttConfidence,
        'word_error_rate': wordErrorRate,
        'accuracy': 1.0 - wordErrorRate,
      });
      
      testResults.add(testResult);
      
      // Keep only last 500 test results
      if (testResults.length > 500) {
        testResults.removeRange(0, testResults.length - 500);
      }
      
      await prefs.setStringList(_testResultsKey, testResults);
      
      if (kDebugMode) {
        debugPrint('🧪 Recorded test: $testId, accuracy: ${((1.0 - wordErrorRate) * 100).toInt()}%');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to record test result: $e');
    }
  }
  
  /// Get test results for a language
  static Future<Map<String, dynamic>> getTestResults(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final testResults = prefs.getStringList(_testResultsKey) ?? [];
      
      final languageTests = testResults.where((entry) {
        final data = json.decode(entry);
        return data['language'] == languageCode;
      }).toList();
      
      if (languageTests.isEmpty) {
        return {
          'language': languageCode,
          'total_tests': 0,
          'avg_accuracy': 0.0,
          'avg_word_error_rate': 0.0,
        };
      }
      
      double totalAccuracy = 0.0;
      double totalWER = 0.0;
      int cloudTests = 0;
      
      for (final entry in languageTests) {
        final data = json.decode(entry);
        totalAccuracy += (data['accuracy'] as num).toDouble();
        totalWER += (data['word_error_rate'] as num).toDouble();
        if (data['used_cloud_stt'] == true) cloudTests++;
      }
      
      final count = languageTests.length;
      
      return {
        'language': languageCode,
        'total_tests': count,
        'avg_accuracy': totalAccuracy / count,
        'avg_word_error_rate': totalWER / count,
        'cloud_usage_rate': cloudTests / count,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to get test results: $e');
      return {};
    }
  }
  
  /// Generate accuracy report
  static Future<Map<String, dynamic>> generateAccuracyReport() async {
    try {
      final overallStats = await getOverallStats();
      
      final languageReports = <String, dynamic>{};
      
      for (final lang in ['en-IN', 'hi-IN', 'ta-IN', 'te-IN', 'kn-IN', 'ml-IN', 'mr-IN', 'bn-IN', 'gu-IN', 'pa-IN']) {
        final langStats = await getLanguageStats(lang);
        final testResults = await getTestResults(lang);
        
        if (langStats['total_sessions'] > 0 || testResults['total_tests'] > 0) {
          languageReports[lang] = {
            'session_stats': langStats,
            'test_results': testResults,
          };
        }
      }
      
      return {
        'generated_at': DateTime.now().toIso8601String(),
        'overall_stats': overallStats,
        'language_reports': languageReports,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to generate accuracy report: $e');
      return {};
    }
  }
  
  /// Clear all metrics (for testing)
  static Future<void> clearMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_metricsKey);
    await prefs.remove(_testResultsKey);
    
    if (kDebugMode) debugPrint('🗑️ Cleared accuracy metrics');
  }
  
  /// Export metrics as JSON string
  static Future<String> exportMetrics() async {
    final report = await generateAccuracyReport();
    return json.encode(report);
  }
}

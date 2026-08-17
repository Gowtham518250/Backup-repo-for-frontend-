import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

/// 🧠 ADVANCED: Voice Feedback Learning Service
/// Learns from user corrections to improve voice recognition accuracy over time
class VoiceFeedbackLearningService {
  static const String _feedbackKey = 'voice_billing_feedback';
  static const String _userCorrectionsKey = 'voice_user_corrections';
  static const String _accuracyMetricsKey = 'voice_accuracy_metrics';
  
  /// Record user correction for misinterpreted voice
  static Future<void> recordCorrection({
    required String originalTranscript,
    required String correctedItemName,
    required String languageCode,
    required double originalConfidence,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final corrections = prefs.getStringList(_userCorrectionsKey) ?? [];
      
      final correctionEntry = json.encode({
        'timestamp': DateTime.now().toIso8601String(),
        'original_transcript': originalTranscript,
        'corrected_name': correctedItemName,
        'language': languageCode,
        'original_confidence': originalConfidence,
      });
      
      corrections.add(correctionEntry);
      
      // Keep only last 1000 corrections to prevent unbounded growth
      if (corrections.length > 1000) {
        corrections.removeRange(0, corrections.length - 1000);
      }
      
      await prefs.setStringList(_userCorrectionsKey, corrections);
      
      if (kDebugMode) {
        debugPrint('📚 Recorded correction: "$originalTranscript" → "$correctedItemName"');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to record correction: $e');
    }
  }
  
  /// Get common misinterpretations for a language
  /// Returns Map<mispronouncedWord, correctWord>
  static Future<Map<String, String>> getCommonCorrections(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final corrections = prefs.getStringList(_userCorrectionsKey) ?? [];
      
      final Map<String, int> mispronunciationCount = {};
      final Map<String, String> correctionMap = {};
      
      for (final entry in corrections) {
        final data = json.decode(entry);
        if (data['language'] == languageCode) {
          final original = data['original_transcript'].toString().toLowerCase().trim();
          final corrected = data['corrected_name'].toString().toLowerCase().trim();
          
          // Count occurrences
          mispronunciationCount[original] = (mispronunciationCount[original] ?? 0) + 1;
          
          // If this mispronunciation appears 3+ times, save the most common correction
          final count = mispronunciationCount[original] ?? 0;
          if (count >= 3) {
            correctionMap[original] = corrected;
          }
        }
      }
      
      return correctionMap;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to get common corrections: $e');
      return {};
    }
  }
  
  /// Record accuracy metrics
  static Future<void> recordAccuracyMetrics({
    required String languageCode,
    required bool usedCloudSTT,
    required double sttConfidence,
    required double nlpConfidence,
    required int itemsCorrect,
    required int itemsTotal,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metrics = prefs.getStringList(_accuracyMetricsKey) ?? [];
      
      final metricEntry = json.encode({
        'timestamp': DateTime.now().toIso8601String(),
        'language': languageCode,
        'used_cloud_stt': usedCloudSTT,
        'stt_confidence': sttConfidence,
        'nlp_confidence': nlpConfidence,
        'items_correct': itemsCorrect,
        'items_total': itemsTotal,
        'accuracy': itemsTotal > 0 ? itemsCorrect / itemsTotal : 0.0,
      });
      
      metrics.add(metricEntry);
      
      // Keep only last 500 metrics
      if (metrics.length > 500) {
        metrics.removeRange(0, metrics.length - 500);
      }
      
      await prefs.setStringList(_accuracyMetricsKey, metrics);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to record metrics: $e');
    }
  }
  
  /// Get accuracy metrics for a language
  static Future<Map<String, dynamic>> getAccuracyMetrics(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metrics = prefs.getStringList(_accuracyMetricsKey) ?? [];
      
      final languageMetrics = metrics.where((entry) {
        final data = json.decode(entry);
        return data['language'] == languageCode;
      }).toList();
      
      if (languageMetrics.isEmpty) {
        return {
          'total_records': 0,
          'avg_stt_confidence': 0.0,
          'avg_nlp_confidence': 0.0,
          'avg_accuracy': 0.0,
          'cloud_usage': 0.0,
        };
      }
      
      double totalSTTConfidence = 0.0;
      double totalNLPConfidence = 0.0;
      double totalAccuracy = 0.0;
      int cloudUsage = 0;
      
      for (final entry in languageMetrics) {
        final data = json.decode(entry);
        totalSTTConfidence += (data['stt_confidence'] as num).toDouble();
        totalNLPConfidence += (data['nlp_confidence'] as num).toDouble();
        totalAccuracy += (data['accuracy'] as num).toDouble();
        if (data['used_cloud_stt'] == true) cloudUsage++;
      }
      
      final count = languageMetrics.length;
      
      return {
        'total_records': count,
        'avg_stt_confidence': totalSTTConfidence / count,
        'avg_nlp_confidence': totalNLPConfidence / count,
        'avg_accuracy': totalAccuracy / count,
        'cloud_usage': cloudUsage / count,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to get accuracy metrics: $e');
      return {};
    }
  }
  
  /// Clear all learning data (for testing/reset)
  static Future<void> clearLearningData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userCorrectionsKey);
    await prefs.remove(_accuracyMetricsKey);
    
    if (kDebugMode) debugPrint('🗑️ Cleared voice learning data');
  }
  
  /// Apply learned corrections to transcript
  static Future<String> applyLearnedCorrections({
    required String transcript,
    required String languageCode,
  }) async {
    try {
      final corrections = await getCommonCorrections(languageCode);
      if (corrections.isEmpty) return transcript;
      
      String corrected = transcript.toLowerCase();
      corrections.forEach((mispronounced, correct) {
        corrected = corrected.replaceAll(RegExp(r'\b' + mispronounced + r'\b'), correct);
      });
      
      return corrected;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to apply corrections: $e');
      return transcript;
    }
  }
  
  /// Get learning statistics
  static Future<Map<String, dynamic>> getLearningStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final corrections = prefs.getStringList(_userCorrectionsKey) ?? [];
      final metrics = prefs.getStringList(_accuracyMetricsKey) ?? [];
      
      // Count corrections by language
      final Map<String, int> correctionsByLang = {};
      for (final entry in corrections) {
        final data = json.decode(entry);
        final lang = data['language'] as String? ?? 'unknown';
        correctionsByLang[lang] = (correctionsByLang[lang] ?? 0) + 1;
      }
      
      // Count metrics by language
      final Map<String, int> metricsByLang = {};
      for (final entry in metrics) {
        final data = json.decode(entry);
        final lang = data['language'] as String? ?? 'unknown';
        metricsByLang[lang] = (metricsByLang[lang] ?? 0) + 1;
      }
      
      return {
        'total_corrections': corrections.length,
        'total_metrics': metrics.length,
        'corrections_by_language': correctionsByLang,
        'metrics_by_language': metricsByLang,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to get learning statistics: $e');
      return {};
    }
  }
}

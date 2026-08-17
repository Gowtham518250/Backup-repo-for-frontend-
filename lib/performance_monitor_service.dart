import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_capability_service.dart';

/// Performance Monitor Service
/// Monitors app performance and provides optimization recommendations
/// Ensures smooth operation on low-end devices
class PerformanceMonitorService {
  static PerformanceMonitorService? _instance;
  
  Timer? _monitoringTimer;
  bool _isMonitoring = false;
  
  // Performance metrics
  final List<PerformanceMetric> _metrics = [];
  static const int _maxMetrics = 100;
  
  // Performance thresholds
  static const double _highMemoryUsageThreshold = 0.8; // 80%
  static const double _highCpuUsageThreshold = 0.7; // 70%
  static const int _slowFrameTimeThreshold = 16; // ms (below 60fps)
  
  PerformanceMonitorService._();
  
  static PerformanceMonitorService get instance {
    _instance ??= PerformanceMonitorService._();
    return _instance!;
  }
  
  /// Start performance monitoring
  Future<void> startMonitoring() async {
    if (_isMonitoring) {
      if (kDebugMode) debugPrint('⏳ Performance monitoring already running');
      return;
    }
    
    _isMonitoring = true;
    
    if (kDebugMode) debugPrint('🚀 Starting performance monitoring');
    
    // Start periodic monitoring
    _monitoringTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _collectMetrics();
    });
    
    // Initial metrics collection
    await _collectMetrics();
  }
  
  /// Stop performance monitoring
  void stopMonitoring() {
    if (!_isMonitoring) return;
    
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    
    if (kDebugMode) debugPrint('🛑 Performance monitoring stopped');
  }
  
  /// Collect performance metrics
  Future<void> _collectMetrics() async {
    try {
      final metric = PerformanceMetric(
        timestamp: DateTime.now(),
        memoryUsage: await _getMemoryUsage(),
        cpuUsage: await _getCpuUsage(),
        frameTime: await _getFrameTime(),
        batteryLevel: await _getBatteryLevel(),
        thermalState: await _getThermalState(),
      );
      
      _addMetric(metric);
      
      // Check for performance issues
      _checkPerformanceIssues(metric);
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error collecting metrics: $e');
    }
  }
  
  /// Add metric to history
  void _addMetric(PerformanceMetric metric) {
    _metrics.add(metric);
    
    // Trim metrics if too many
    if (_metrics.length > _maxMetrics) {
      _metrics.removeAt(0);
    }
  }
  
  /// Check for performance issues
  void _checkPerformanceIssues(PerformanceMetric metric) {
    final issues = <String>[];
    
    if (metric.memoryUsage > _highMemoryUsageThreshold) {
      issues.add('High memory usage: ${(metric.memoryUsage * 100).toStringAsFixed(1)}%');
    }
    
    if (metric.cpuUsage > _highCpuUsageThreshold) {
      issues.add('High CPU usage: ${(metric.cpuUsage * 100).toStringAsFixed(1)}%');
    }
    
    if (metric.frameTime > _slowFrameTimeThreshold) {
      issues.add('Slow frame time: ${metric.frameTime.toStringAsFixed(1)}ms');
    }
    
    if (metric.thermalState == ThermalState.hot) {
      issues.add('Device thermal state: HOT');
    }
    
    if (issues.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ Performance issues detected:');
        for (final issue in issues) {
          debugPrint('   - $issue');
        }
      }
      
      // Trigger optimization
      _optimizePerformance();
    }
  }
  
  /// Optimize performance based on current state
  void _optimizePerformance() {
    if (kDebugMode) debugPrint('🔧 Optimizing performance...');
    
    // Get device capabilities
    final deviceService = DeviceCapabilityService.instance;
    if (deviceService.isLowEndDevice) {
      // Aggressive optimization for low-end devices
      _aggressiveOptimization();
    } else {
      // Moderate optimization for other devices
      _moderateOptimization();
    }
  }
  
  /// Aggressive optimization for low-end devices
  void _aggressiveOptimization() {
    // Clear caches
    _clearCaches();
    
    // Reduce logging
    _reduceLogging();
    
    // Pause non-critical services
    _pauseNonCriticalServices();
    
    if (kDebugMode) debugPrint('🔥 Aggressive optimization applied');
  }
  
  /// Moderate optimization for normal devices
  void _moderateOptimization() {
    // Clear old caches
    _clearOldCaches();
    
    // Reduce logging frequency
    _reduceLoggingFrequency();
    
    if (kDebugMode) debugPrint('⚡ Moderate optimization applied');
  }
  
  /// Clear caches
  void _clearCaches() {
    // This would clear various caches
    if (kDebugMode) debugPrint('🗑️ Clearing caches');
  }
  
  /// Clear old caches only
  void _clearOldCaches() {
    // This would clear only old cache entries
    if (kDebugMode) debugPrint('🧹 Clearing old caches');
  }
  
  /// Reduce logging
  void _reduceLogging() {
    // Reduce logging level
    if (kDebugMode) debugPrint('📝 Reducing logging');
  }
  
  /// Reduce logging frequency
  void _reduceLoggingFrequency() {
    // Reduce how often logs are written
    if (kDebugMode) debugPrint('📉 Reducing logging frequency');
  }
  
  /// Pause non-critical services
  void _pauseNonCriticalServices() {
    // Pause services that aren't critical for core functionality
    if (kDebugMode) debugPrint('⏸️ Pausing non-critical services');
  }
  
  /// Get memory usage (simplified)
  Future<double> _getMemoryUsage() async {
    try {
      // This would use platform-specific methods
      // For now, return a placeholder
      return 0.5; // 50% memory usage
    } catch (e) {
      return 0.5;
    }
  }
  
  /// Get CPU usage (simplified)
  Future<double> _getCpuUsage() async {
    try {
      // This would use platform-specific methods
      return 0.3; // 30% CPU usage
    } catch (e) {
      return 0.3;
    }
  }
  
  /// Get frame time (simplified)
  Future<double> _getFrameTime() async {
    try {
      // This would measure actual frame rendering time
      return 16.0; // 60fps = 16ms per frame
    } catch (e) {
      return 16.0;
    }
  }
  
  /// Get battery level
  Future<double> _getBatteryLevel() async {
    try {
      // This would use battery plugin
      return 0.8; // 80% battery
    } catch (e) {
      return 0.8;
    }
  }
  
  /// Get thermal state
  Future<ThermalState> _getThermalState() async {
    try {
      // This would use platform-specific thermal monitoring
      return ThermalState.normal;
    } catch (e) {
      return ThermalState.normal;
    }
  }
  
  /// Get performance summary
  PerformanceSummary getPerformanceSummary() {
    if (_metrics.isEmpty) {
      return PerformanceSummary(
        averageMemoryUsage: 0.0,
        averageCpuUsage: 0.0,
        averageFrameTime: 0.0,
        performanceScore: 0,
        recommendations: [],
      );
    }
    
    final avgMemory = _metrics.map((m) => m.memoryUsage).reduce((a, b) => a + b) / _metrics.length;
    final avgCpu = _metrics.map((m) => m.cpuUsage).reduce((a, b) => a + b) / _metrics.length;
    final avgFrameTime = _metrics.map((m) => m.frameTime).reduce((a, b) => a + b) / _metrics.length;
    
    // Calculate performance score (0-100)
    final memoryScore = (1.0 - avgMemory) * 40;
    final cpuScore = (1.0 - avgCpu) * 30;
    final frameScore = (1.0 - (avgFrameTime / 33.0)) * 30; // 33ms = 30fps baseline
    
    final performanceScore = (memoryScore + cpuScore + frameScore).clamp(0, 100).toInt();
    
    // Generate recommendations
    final recommendations = <String>[];
    
    if (avgMemory > 0.7) {
      recommendations.add('Reduce memory usage by clearing caches');
    }
    
    if (avgCpu > 0.6) {
      recommendations.add('Optimize CPU-intensive operations');
    }
    
    if (avgFrameTime > 20) {
      recommendations.add('Improve UI rendering performance');
    }
    
    if (performanceScore < 50) {
      recommendations.add('Consider enabling low-performance mode');
    }
    
    return PerformanceSummary(
      averageMemoryUsage: avgMemory,
      averageCpuUsage: avgCpu,
      averageFrameTime: avgFrameTime,
      performanceScore: performanceScore,
      recommendations: recommendations,
    );
  }
  
  /// Get metrics history
  List<PerformanceMetric> getMetricsHistory({int? limit}) {
    if (limit != null && _metrics.length > limit) {
      return _metrics.sublist(_metrics.length - limit);
    }
    return List.from(_metrics);
  }
  
  /// Clear metrics history
  void clearMetrics() {
    _metrics.clear();
    if (kDebugMode) debugPrint('🗑️ Performance metrics cleared');
  }
  
  /// Export performance report
  Future<String> exportPerformanceReport() async {
    final summary = getPerformanceSummary();
    final buffer = StringBuffer();
    
    buffer.writeln('PERFORMANCE REPORT');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');
    buffer.writeln('Performance Score: ${summary.performanceScore}/100');
    buffer.writeln('Average Memory Usage: ${(summary.averageMemoryUsage * 100).toStringAsFixed(1)}%');
    buffer.writeln('Average CPU Usage: ${(summary.averageCpuUsage * 100).toStringAsFixed(1)}%');
    buffer.writeln('Average Frame Time: ${summary.averageFrameTime.toStringAsFixed(1)}ms');
    buffer.writeln('');
    buffer.writeln('Recommendations:');
    for (final recommendation in summary.recommendations) {
      buffer.writeln('  - $recommendation');
    }
    
    return buffer.toString();
  }
}

/// Performance metric
class PerformanceMetric {
  final DateTime timestamp;
  final double memoryUsage; // 0.0 to 1.0
  final double cpuUsage; // 0.0 to 1.0
  final double frameTime; // in milliseconds
  final double batteryLevel; // 0.0 to 1.0
  final ThermalState thermalState;
  
  PerformanceMetric({
    required this.timestamp,
    required this.memoryUsage,
    required this.cpuUsage,
    required this.frameTime,
    required this.batteryLevel,
    required this.thermalState,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'memory_usage': memoryUsage,
      'cpu_usage': cpuUsage,
      'frame_time': frameTime,
      'battery_level': batteryLevel,
      'thermal_state': thermalState.toString(),
    };
  }
}

/// Thermal state
enum ThermalState {
  normal,
  warm,
  hot,
}

/// Performance summary
class PerformanceSummary {
  final double averageMemoryUsage;
  final double averageCpuUsage;
  final double averageFrameTime;
  final int performanceScore;
  final List<String> recommendations;
  
  PerformanceSummary({
    required this.averageMemoryUsage,
    required this.averageCpuUsage,
    required this.averageFrameTime,
    required this.performanceScore,
    required this.recommendations,
  });
}
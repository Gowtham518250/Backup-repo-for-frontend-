import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Device Capability Service
/// Detects device capabilities and optimizes app performance accordingly
/// Ensures smooth operation on low-end devices (2GB RAM)
class DeviceCapabilityService {
  static DeviceCapabilityService? _instance;
  
  DeviceCapabilities? _capabilities;
  bool _isLowEndDevice = false;
  bool _isHighEndDevice = false;
  
  DeviceCapabilityService._();
  
  static DeviceCapabilityService get instance {
    _instance ??= DeviceCapabilityService._();
    return _instance!;
  }
  
  /// Initialize device capability detection
  Future<void> initialize() async {
    try {
      if (kDebugMode) debugPrint('🔍 Detecting device capabilities...');
      
      _capabilities = await _detectCapabilities();
      _isLowEndDevice = _determineLowEndDevice();
      _isHighEndDevice = _determineHighEndDevice();
      
      if (kDebugMode) {
        debugPrint('📱 Device capabilities detected:');
        debugPrint('   Total RAM: ${_capabilities?.totalRAM} GB');
        debugPrint('   Available RAM: ${_capabilities?.availableRAM} GB');
        debugPrint('   CPU Cores: ${_capabilities?.cpuCores}');
        debugPrint('   Low-end device: $_isLowEndDevice');
        debugPrint('   High-end device: $_isHighEndDevice');
        debugPrint('   Performance mode: ${_getPerformanceMode()}');
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error detecting device capabilities: $e');
      // Default to conservative settings if detection fails
      _isLowEndDevice = true;
    }
  }
  
  /// Detect device capabilities
  Future<DeviceCapabilities> _detectCapabilities() async {
    final capabilities = DeviceCapabilities();
    
    try {
      // Get device info
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        capabilities.totalRAM = await _getAndroidTotalRAM();
        capabilities.cpuCores = androidInfo.supportedAbis.length;
        capabilities.androidSdkVersion = androidInfo.version.sdkInt;
        capabilities.deviceModel = '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        final machine = iosInfo.utsname.machine;
        capabilities.totalRAM = _estimateIOSRAM(machine);
        capabilities.cpuCores = _estimateIOSCores(machine);
        capabilities.deviceModel = iosInfo.model;
      }
      
      // Get available memory
      capabilities.availableRAM = await _getAvailableMemory();
      
      // Get performance metrics
      capabilities.cpuUsage = await _getCpuUsage();
      
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error getting device info: $e');
      // Set conservative defaults
      capabilities.totalRAM = 2.0; // Assume 2GB if unknown
      capabilities.availableRAM = 1.0;
      capabilities.cpuCores = 2;
    }
    
    return capabilities;
  }
  
  /// Determine if this is a low-end device
  bool _determineLowEndDevice() {
    if (_capabilities == null) return true; // Conservative default
    
    // Low-end criteria:
    // - Less than 3GB RAM
    // - Less than 4 CPU cores
    // - Android version less than 8 (API 26)
    return (_capabilities!.totalRAM < 3.0) ||
           (_capabilities!.cpuCores < 4) ||
           (_capabilities!.androidSdkVersion != null && _capabilities!.androidSdkVersion! < 26);
  }
  
  /// Determine if this is a high-end device
  bool _determineHighEndDevice() {
    if (_capabilities == null) return false;
    
    // High-end criteria:
    // - 6GB+ RAM
    // - 8+ CPU cores
    return (_capabilities!.totalRAM >= 6.0) && (_capabilities!.cpuCores >= 8);
  }
  
  /// Get current performance mode
  PerformanceMode _getPerformanceMode() {
    if (_isHighEndDevice) return PerformanceMode.high;
    if (_isLowEndDevice) return PerformanceMode.low;
    return PerformanceMode.balanced;
  }
  
  /// Get total RAM on Android by reading /proc/meminfo
  /// (device_info_plus does not expose total device memory directly)
  Future<double> _getAndroidTotalRAM() async {
    try {
      final file = File('/proc/meminfo');
      if (!await file.exists()) return 2.0; // Conservative default

      final lines = await file.readAsLines();
      for (final line in lines) {
        if (line.startsWith('MemTotal:')) {
          final match = RegExp(r'(\d+)').firstMatch(line);
          if (match != null) {
            final kb = int.parse(match.group(1)!);
            return kb / (1024 * 1024); // Convert KB to GB
          }
        }
      }
      return 2.0; // Conservative default if MemTotal not found
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error reading /proc/meminfo: $e');
      return 2.0; // Conservative default
    }
  }

  /// Get available memory
  Future<double> _getAvailableMemory() async {
    try {
      // This is a simplified estimation
      // In production, you'd use platform-specific methods
      if (_capabilities != null) {
        return _capabilities!.totalRAM * 0.6; // Assume 60% available
      }
      return 1.0;
    } catch (e) {
      return 1.0;
    }
  }
  
  /// Estimate iOS RAM based on device model
  double _estimateIOSRAM(String machine) {
    // Simplified estimation based on common iOS devices
    if (machine.contains('iPhone8') || machine.contains('iPhone9')) return 2.0;
    if (machine.contains('iPhone10') || machine.contains('iPhone11')) return 3.0;
    if (machine.contains('iPhone12') || machine.contains('iPhone13')) return 4.0;
    if (machine.contains('iPhone14') || machine.contains('iPhone15')) return 6.0;
    return 3.0; // Default
  }
  
  /// Estimate iOS CPU cores
  int _estimateIOSCores(String machine) {
    if (machine.contains('iPhone8') || machine.contains('iPhone9')) return 2;
    if (machine.contains('iPhone10') || machine.contains('iPhone11')) return 4;
    if (machine.contains('iPhone12') || machine.contains('iPhone13')) return 6;
    if (machine.contains('iPhone14') || machine.contains('iPhone15')) return 8;
    return 4; // Default
  }
  
  /// Get CPU usage (simplified)
  Future<double> _getCpuUsage() async {
    try {
      // This would require platform-specific implementation
      return 0.5; // Placeholder
    } catch (e) {
      return 0.5;
    }
  }
  
  /// Get device capabilities
  DeviceCapabilities? get capabilities => _capabilities;
  
  /// Check if device is low-end
  bool get isLowEndDevice => _isLowEndDevice;
  
  /// Check if device is high-end
  bool get isHighEndDevice => _isHighEndDevice;
  
  /// Get current performance mode
  PerformanceMode get performanceMode => _getPerformanceMode();
  
  /// Check if feature should be enabled based on device capabilities
  bool shouldEnableFeature(FeatureRequirement requirement) {
    if (_capabilities == null) return false; // Conservative
    
    switch (requirement) {
      case FeatureRequirement.highPerformance:
        return !_isLowEndDevice;
      case FeatureRequirement.mediumPerformance:
        return _capabilities!.totalRAM >= 2.0;
      case FeatureRequirement.lowPerformance:
        return true; // All devices can handle low-performance features
      case FeatureRequirement.biometric:
        return _capabilities!.totalRAM >= 2.0;
      case FeatureRequirement.voiceRecognition:
        return _capabilities!.totalRAM >= 3.0;
      case FeatureRequirement.advancedAnalytics:
        return !_isLowEndDevice;
      case FeatureRequirement.backgroundSync:
        return _capabilities!.totalRAM >= 2.0;
    }
  }
  
  /// Get recommended service configuration for this device
  ServiceConfiguration getRecommendedServiceConfig() {
    if (_isLowEndDevice) {
      return ServiceConfiguration(
        enableBackgroundSync: true,
        syncInterval: 15, // minutes - less frequent
        enableAutoBackup: true,
        backupInterval: 48, // hours - less frequent
        enableIntegrityChecks: true,
        integrityCheckInterval: 24, // hours - less frequent
        enableCorruptionDetection: true,
        corruptionCheckInterval: 48, // hours - less frequent
        enableAuditLogging: true,
        maxLogEntries: 100, // Reduced log size
        enableEnhancedQueue: false, // Disable heavy queue
        enableCrashRecovery: true,
        maxCacheSize: 50, // MB - reduced cache
      );
    } else if (_isHighEndDevice) {
      return ServiceConfiguration(
        enableBackgroundSync: true,
        syncInterval: 5, // minutes - frequent
        enableAutoBackup: true,
        backupInterval: 24, // hours - daily
        enableIntegrityChecks: true,
        integrityCheckInterval: 6, // hours - frequent
        enableCorruptionDetection: true,
        corruptionCheckInterval: 12, // hours - frequent
        enableAuditLogging: true,
        maxLogEntries: 500, // Full log size
        enableEnhancedQueue: true,
        enableCrashRecovery: true,
        maxCacheSize: 200, // MB - larger cache
      );
    } else {
      // Balanced mode
      return ServiceConfiguration(
        enableBackgroundSync: true,
        syncInterval: 10, // minutes
        enableAutoBackup: true,
        backupInterval: 36, // hours
        enableIntegrityChecks: true,
        integrityCheckInterval: 12, // hours
        enableCorruptionDetection: true,
        corruptionCheckInterval: 24, // hours
        enableAuditLogging: true,
        maxLogEntries: 300, // Medium log size
        enableEnhancedQueue: true,
        enableCrashRecovery: true,
        maxCacheSize: 100, // MB - medium cache
      );
    }
  }
}

/// Device capabilities
class DeviceCapabilities {
  double totalRAM = 0.0; // in GB
  double availableRAM = 0.0; // in GB
  int cpuCores = 0;
  int? androidSdkVersion;
  String? deviceModel;
  double cpuUsage = 0.0;
}

/// Performance mode
enum PerformanceMode {
  low,      // 2GB RAM devices
  balanced, // 3-4GB RAM devices
  high,     // 6GB+ RAM devices
}

/// Feature requirements
enum FeatureRequirement {
  highPerformance,    // Requires 4GB+ RAM
  mediumPerformance,  // Requires 2GB+ RAM
  lowPerformance,     // Works on all devices
  biometric,         // Requires 2GB+ RAM
  voiceRecognition,  // Requires 3GB+ RAM
  advancedAnalytics, // Requires 4GB+ RAM
  backgroundSync,    // Requires 2GB+ RAM
}

/// Service configuration
class ServiceConfiguration {
  bool enableBackgroundSync;
  int syncInterval; // minutes
  bool enableAutoBackup;
  int backupInterval; // hours
  bool enableIntegrityChecks;
  int integrityCheckInterval; // hours
  bool enableCorruptionDetection;
  int corruptionCheckInterval; // hours
  bool enableAuditLogging;
  int maxLogEntries;
  bool enableEnhancedQueue;
  bool enableCrashRecovery;
  int maxCacheSize; // MB
  
  ServiceConfiguration({
    required this.enableBackgroundSync,
    required this.syncInterval,
    required this.enableAutoBackup,
    required this.backupInterval,
    required this.enableIntegrityChecks,
    required this.integrityCheckInterval,
    required this.enableCorruptionDetection,
    required this.corruptionCheckInterval,
    required this.enableAuditLogging,
    required this.maxLogEntries,
    required this.enableEnhancedQueue,
    required this.enableCrashRecovery,
    required this.maxCacheSize,
  });
}
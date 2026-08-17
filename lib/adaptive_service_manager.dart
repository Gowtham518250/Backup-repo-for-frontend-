import 'package:flutter/foundation.dart';
import 'sync_service.dart';

/// 🔧 RECONSTRUCTED FILE: this file was found completely empty (0 bytes) in
/// the repository — `AdaptiveServiceManager` was referenced in main.dart but
/// never defined anywhere, causing `flutter analyze` to report it as an
/// undefined identifier at both call sites. I don't have the original,
/// possibly more elaborate version of this class (the comment above its
/// call site suggests it once "replaced individual service initialization"
/// for multiple background services), so this is a safe, minimal
/// reconstruction that does exactly what its two call sites need:
///   - `initialize()` — called once after the first frame in MyApp.initState
///   - `stopAllServices()` — called from MyApp.dispose()
/// If you have an older copy of this file with more responsibilities
/// (e.g. battery/network-aware polling), restore that instead of this stub.
class AdaptiveServiceManager {
  AdaptiveServiceManager._();
  static final AdaptiveServiceManager instance = AdaptiveServiceManager._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await SyncService.init();
      _initialized = true;
      if (kDebugMode) debugPrint('✅ AdaptiveServiceManager: services started');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ AdaptiveServiceManager.initialize failed: $e');
    }
  }

  void stopAllServices() {
    if (!_initialized) return;
    try {
      SyncService.dispose();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ AdaptiveServiceManager.stopAllServices failed: $e');
    } finally {
      _initialized = false;
    }
  }
}
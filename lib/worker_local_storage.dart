import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// Durable local worker roster cache.
/// Backend remains authoritative when reachable; local storage is the
/// offline fallback and survives page recreation/app restarts.
class WorkerLocalStorage {
  static String getWorkerPreferenceKey(int shopkeeperId) => 'workers_$shopkeeperId';
  static String getLegacyWorkerKey(int shopkeeperId) => 'workers_json_$shopkeeperId';

  static Future<List<Worker>> fetchWorkers(int shopkeeperId) async {
    if (shopkeeperId <= 0) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString(getWorkerPreferenceKey(shopkeeperId));
      raw ??= prefs.getString(getLegacyWorkerKey(shopkeeperId));
      raw ??= prefs.getString('workers_json');
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final workers = decoded
          .whereType<Map>()
          .map((w) => Worker.fromJson(Map<String, dynamic>.from(w)))
          .toList();
      if (workers.isNotEmpty) await saveWorkers(shopkeeperId, workers);
      return workers;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveWorkers(int shopkeeperId, List<Worker> workers) async {
    if (shopkeeperId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(workers.map((w) => w.toJson()).toList());
    await prefs.setString(getWorkerPreferenceKey(shopkeeperId), encoded);
    await prefs.setString(getLegacyWorkerKey(shopkeeperId), encoded);
    await prefs.setString('workers_json', encoded);
  }

  static Future<void> saveWorkersJson(int shopkeeperId, List<dynamic> workers) async {
    final models = workers
        .whereType<Map>()
        .map((w) => Worker.fromJson(Map<String, dynamic>.from(w)))
        .toList();
    await saveWorkers(shopkeeperId, models);
  }

  static Future<Worker?> getWorkerByName(int shopkeeperId, String name) async {
    final workers = await fetchWorkers(shopkeeperId);
    try {
      return workers.firstWhere((w) => w.name.toLowerCase() == name.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  static Future<bool> workerExists(int shopkeeperId, String name) async =>
      (await getWorkerByName(shopkeeperId, name)) != null;

  static Future<List<String>> getWorkerNames(int shopkeeperId) async =>
      (await fetchWorkers(shopkeeperId)).map((w) => w.name).toList();

  static Future<int> getWorkerCount(int shopkeeperId) async =>
      (await fetchWorkers(shopkeeperId)).length;

  static Future<void> clearWorkers(int shopkeeperId) async {
    if (shopkeeperId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(getWorkerPreferenceKey(shopkeeperId));
    await prefs.remove(getLegacyWorkerKey(shopkeeperId));
  }
}

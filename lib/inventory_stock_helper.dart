/// Unified stock field handling — API uses stock/quantity, UI uses current_stock.
class InventoryStockHelper {
  static double readStock(Map<String, dynamic> p) {
    for (final key in ['current_stock', 'stock', 'quantity', 'qty', 'available_stock']) {
      final v = p[key];
      if (v == null) continue;
      final n = double.tryParse(v.toString());
      if (n != null) return n;
    }
    return 0;
  }

  static void writeStock(Map<String, dynamic> p, double value) {
    p['current_stock'] = value;
    p['stock'] = value;
    p['quantity'] = value;
  }

  static Map<String, dynamic> normalizeProduct(Map<String, dynamic> raw) {
    final p = Map<String, dynamic>.from(raw);
    final name = (p['product_name'] ?? p['name'] ?? p['product'] ?? '').toString();
    if (name.isNotEmpty) p['product_name'] = name;
    writeStock(p, readStock(p));
    p['min_stock'] = double.tryParse(p['min_stock']?.toString() ?? '10') ?? 10;
    return p;
  }

  static List<Map<String, dynamic>> normalizeProducts(List<dynamic> list) {
    return list
        .whereType<Map>()
        .map((e) => normalizeProduct(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// After a sale, local cache has the truth — never let stale API overwrite it.
  static List<Map<String, dynamic>> mergeApiWithLocalCache(
    List<Map<String, dynamic>> apiList,
    List<Map<String, dynamic>> localList,
  ) {
    final localById = <String, Map<String, dynamic>>{};
    for (final p in normalizeProducts(localList)) {
      final id = (p['id'] ?? p['product_id'] ?? '').toString();
      if (id.isNotEmpty) localById[id] = p;
    }

    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final raw in apiList) {
      final apiP = normalizeProduct(Map<String, dynamic>.from(raw));
      final id = (apiP['id'] ?? apiP['product_id'] ?? '').toString();
      if (id.isNotEmpty && localById.containsKey(id)) {
        writeStock(apiP, readStock(localById[id]!));
      }
      merged.add(apiP);
      if (id.isNotEmpty) seen.add(id);
    }

    for (final entry in localById.entries) {
      if (!seen.contains(entry.key)) merged.add(entry.value);
    }
    return merged;
  }
}

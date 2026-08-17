import 'local_storage_service.dart';
import 'stored_sale.dart';

class SalesStorageRepository {
  static Future<List<StoredSale>> loadStoredSales() async {
    final rawSales = await LocalStorageService.loadSales();
    return rawSales.map((sale) {
      if (sale is StoredSale) {
        return sale;
      }
      if (sale is Map) {
        return StoredSale.fromJson(Map<String, dynamic>.from(sale));
      }
      return StoredSale(
        saleId: sale.toString(),
        status: 'PENDING',
        createdAt: DateTime.now(),
        rawData: {'value': sale},
      );
    }).toList();
  }

  static Future<void> saveStoredSales(List<StoredSale> sales) async {
    await LocalStorageService.saveSales(sales.map((sale) => sale.toJson()).toList());
  }
}

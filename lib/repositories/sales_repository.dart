import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_client.dart';

/// Repository Pattern: Abstracts external data source interactions
class SalesRepository {
  /// Fetches sales data from the remote backend
  static Future<List<Map<String, dynamic>>> fetchRemoteSales({required String token}) async {
    final response = await ApiClient.getJson('/auth/sales', headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } else {
      throw Exception('Failed to load remote sales');
    }
  }

  /// Pushes a single sale to the remote backend
  static Future<bool> pushSale({
    required Map<String, String> saleData,
    required String token,
  }) async {
    final response = await ApiClient.postForm('/auth/sales', saleData, headers: {
      'Authorization': 'Bearer $token',
    }).timeout(const Duration(seconds: 15));

    return response.statusCode == 200 || response.statusCode == 201;
  }
}

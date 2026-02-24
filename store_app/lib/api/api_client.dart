import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/city.dart';
import '../models/product.dart';

class ApiClient {
  static String get _base => Config.baseUrl.replaceAll(RegExp(r'/$'), '');

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Consumer-Key': Config.consumerKey,
        'X-Consumer-Secret': Config.consumerSecret,
      };

  /// GET /api/products
  static Future<List<Product>> getProducts() async {
    final r = await http.get(
      Uri.parse('$_base/api/products'),
      headers: _headers,
    );
    if (r.statusCode != 200) throw Exception('فشل تحميل المنتجات: ${r.statusCode}');
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (data?['ok'] != true) throw Exception(data?['message'] ?? 'فشل تحميل المنتجات');
    final list = data!['products'] as List<dynamic>? ?? [];
    return list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/cities
  static Future<List<City>> getCities() async {
    final r = await http.get(
      Uri.parse('$_base/api/cities'),
      headers: _headers,
    );
    if (r.statusCode != 200) throw Exception('فشل تحميل المدن: ${r.statusCode}');
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (data?['ok'] != true) throw Exception(data?['message'] ?? 'فشل تحميل المدن');
    final list = data!['cities'] as List<dynamic>? ?? [];
    return list.map((e) => City.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/orders
  static Future<Map<String, dynamic>> postOrder({
    required int cityId,
    required String customerName,
    required String customerPhone,
    String customerAddress = '',
    required List<Map<String, dynamic>> items,
  }) async {
    final body = {
      'city_id': cityId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'items': items,
    };
    final r = await http.post(
      Uri.parse('$_base/api/orders'),
      headers: _headers,
      body: jsonEncode(body),
    );
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (r.statusCode >= 200 && r.statusCode < 300 && data?['ok'] == true) {
      return data!;
    }
    throw Exception(data?['message'] ?? data?['error'] ?? 'فشل إرسال الطلب: ${r.statusCode}');
  }
}

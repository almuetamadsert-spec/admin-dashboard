import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../core/auth/auth_service.dart';

class MerchantApi {
  static String get _base => Config.baseUrl.replaceAll(RegExp(r'/$'), '');

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) throw Exception('مطلوب تسجيل الدخول');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// GET /api/merchant/orders
  static Future<List<MerchantOrder>> getOrders() async {
    final r = await http.get(
      Uri.parse('$_base/api/merchant/orders'),
      headers: await _headers(),
    );
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (r.statusCode != 200) throw Exception(data?['message'] ?? 'فشل تحميل الطلبات: ${r.statusCode}');
    if (data?['ok'] != true) throw Exception(data?['message'] ?? 'فشل تحميل الطلبات');
    final list = data!['orders'] as List<dynamic>? ?? [];
    return list.map((e) => MerchantOrder.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/merchant/orders/:id
  static Future<MerchantOrderDetail> getOrderDetail(int orderId) async {
    final r = await http.get(
      Uri.parse('$_base/api/merchant/orders/$orderId'),
      headers: await _headers(),
    );
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (r.statusCode != 200) throw Exception(data?['message'] ?? 'فشل تحميل الطلب: ${r.statusCode}');
    if (data?['ok'] != true) throw Exception(data?['message'] ?? 'فشل تحميل الطلب');
    return MerchantOrderDetail.fromJson(data!);
  }

  /// POST /api/merchant/orders/:id/transfer
  static Future<void> transferOrder(int orderId, int targetMerchantId) async {
    final r = await http.post(
      Uri.parse('$_base/api/merchant/orders/$orderId/transfer'),
      headers: await _headers(),
      body: jsonEncode({'target_merchant_id': targetMerchantId}),
    );
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (r.statusCode != 200) throw Exception(data?['message'] ?? 'فشل تحويل الطلب: ${r.statusCode}');
    if (data?['ok'] != true) throw Exception(data?['message'] ?? 'فشل تحويل الطلب');
  }

  /// POST /api/merchant/orders/:id/claim — استحواذ (قيد التنفيذ)
  static Future<void> claimOrder(int orderId) async {
    final r = await http.post(
      Uri.parse('$_base/api/merchant/orders/$orderId/claim'),
      headers: await _headers(),
    );
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (r.statusCode != 200) throw Exception(data?['message'] ?? 'فشل استلام الطلب: ${r.statusCode}');
    if (data?['ok'] != true) throw Exception(data?['message'] ?? 'فشل استلام الطلب');
  }

  /// POST /api/merchant/orders/:id/contacted — تسجيل أن التاجر اتصل بالعميل
  static Future<void> setContacted(int orderId) async {
    final r = await http.post(
      Uri.parse('$_base/api/merchant/orders/$orderId/contacted'),
      headers: await _headers(),
    );
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (r.statusCode != 200) throw Exception(data?['message'] ?? 'فشل: ${r.statusCode}');
    if (data?['ok'] != true) throw Exception(data?['message'] ?? 'فشل');
  }

  /// POST /api/merchant/orders/:id/delivered
  static Future<void> setDelivered(int orderId) async {
    final r = await http.post(
      Uri.parse('$_base/api/merchant/orders/$orderId/delivered'),
      headers: await _headers(),
    );
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (r.statusCode != 200) throw Exception(data?['message'] ?? 'فشل: ${r.statusCode}');
    if (data?['ok'] != true) throw Exception(data?['message'] ?? 'فشل');
  }

  /// POST /api/merchant/orders/:id/unavailable
  static Future<void> setUnavailable(int orderId, {String? reason}) async {
    final r = await http.post(
      Uri.parse('$_base/api/merchant/orders/$orderId/unavailable'),
      headers: await _headers(),
      body: jsonEncode({'reason': reason ?? 'نفاد الكمية'}),
    );
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (r.statusCode != 200) throw Exception(data?['message'] ?? 'فشل: ${r.statusCode}');
    if (data?['ok'] != true) throw Exception(data?['message'] ?? 'فشل');
  }

  /// POST /api/merchant/orders/:id/refused
  static Future<void> setRefused(int orderId) async {
    final r = await http.post(
      Uri.parse('$_base/api/merchant/orders/$orderId/refused'),
      headers: await _headers(),
    );
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (r.statusCode != 200) throw Exception(data?['message'] ?? 'فشل: ${r.statusCode}');
    if (data?['ok'] != true) throw Exception(data?['message'] ?? 'فشل');
  }

  /// GET /api/merchant/merchants — قائمة التجار (لاختيار التحويل)
  static Future<List<MerchantItem>> getMerchants() async {
    final r = await http.get(
      Uri.parse('$_base/api/merchant/merchants'),
      headers: await _headers(),
    );
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (r.statusCode != 200) throw Exception(data?['message'] ?? 'فشل تحميل التجار: ${r.statusCode}');
    if (data?['ok'] != true) throw Exception(data?['message'] ?? 'فشل تحميل التجار');
    final list = data!['merchants'] as List<dynamic>? ?? [];
    return list.map((e) => MerchantItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/merchant/categories
  static Future<List<MerchantCategory>> getCategories() async {
    final r = await http.get(Uri.parse('$_base/api/merchant/categories'), headers: await _headers());
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (r.statusCode != 200) throw Exception(data?['message'] ?? 'فشل: ${r.statusCode}');
    final list = data!['categories'] as List<dynamic>? ?? [];
    return list.map((e) => MerchantCategory.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/merchant/brand-categories
  static Future<List<MerchantBrandCategory>> getBrandCategories() async {
    final r = await http.get(Uri.parse('$_base/api/merchant/brand-categories'), headers: await _headers());
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (r.statusCode != 200) throw Exception(data?['message'] ?? 'فشل: ${r.statusCode}');
    final list = data!['brand_categories'] as List<dynamic>? ?? [];
    return list.map((e) => MerchantBrandCategory.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/merchant/products — للمخزون (تصنيف، براند، بحث)
  static Future<List<MerchantProduct>> getProductsForInventory({int? categoryId, String? company, String? q}) async {
    var uri = Uri.parse('$_base/api/merchant/products');
    final query = <String, String>{};
    if (categoryId != null) query['category_id'] = categoryId.toString();
    if (company != null && company.isNotEmpty) query['company'] = company;
    if (q != null && q.isNotEmpty) query['q'] = q;
    if (query.isNotEmpty) uri = uri.replace(queryParameters: query);
    final r = await http.get(uri, headers: await _headers());
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (r.statusCode != 200) throw Exception(data?['message'] ?? 'فشل: ${r.statusCode}');
    if (data?['ok'] != true) throw Exception(data?['message'] ?? 'فشل');
    final list = data!['products'] as List<dynamic>? ?? [];
    return list.map((e) => MerchantProduct.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/merchant/inventory
  static Future<List<MerchantInventoryItem>> getInventory() async {
    final r = await http.get(Uri.parse('$_base/api/merchant/inventory'), headers: await _headers());
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (r.statusCode != 200) throw Exception(data?['message'] ?? 'فشل: ${r.statusCode}');
    if (data?['ok'] != true) throw Exception(data?['message'] ?? 'فشل');
    final list = data!['items'] as List<dynamic>? ?? [];
    return list.map((e) => MerchantInventoryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/merchant/inventory
  static Future<void> saveInventory(List<Map<String, dynamic>> items) async {
    final r = await http.post(
      Uri.parse('$_base/api/merchant/inventory'),
      headers: await _headers(),
      body: jsonEncode({'items': items}),
    );
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (r.statusCode != 200) throw Exception(data?['message'] ?? 'فشل: ${r.statusCode}');
    if (data?['ok'] != true) throw Exception(data?['message'] ?? 'فشل');
  }

  /// DELETE /api/merchant/inventory/:productId
  static Future<void> deleteInventoryProduct(int productId) async {
    final r = await http.delete(
      Uri.parse('$_base/api/merchant/inventory/$productId'),
      headers: await _headers(),
    );
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (r.statusCode != 200) throw Exception(data?['message'] ?? 'فشل: ${r.statusCode}');
    if (data?['ok'] != true) throw Exception(data?['message'] ?? 'فشل');
  }

  /// GET /api/merchant/stats
  static Future<MerchantStats> getStats() async {
    final r = await http.get(
      Uri.parse('$_base/api/merchant/stats'),
      headers: await _headers(),
    );
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (r.statusCode != 200) throw Exception(data?['message'] ?? 'فشل تحميل الإحصائيات: ${r.statusCode}');
    if (data?['ok'] != true) throw Exception(data?['message'] ?? 'فشل تحميل الإحصائيات');
    return MerchantStats.fromJson(data!['stats'] as Map<String, dynamic>);
  }
}

class MerchantOrder {
  final int id;
  final String orderNumber;
  final int? merchantId;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final int? cityId;
  final String? cityName;
  final String status;
  final double totalAmount;
  final String? createdAt;

  MerchantOrder({
    required this.id,
    required this.orderNumber,
    this.merchantId,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.cityId,
    this.cityName,
    required this.status,
    required this.totalAmount,
    this.createdAt,
  });

  bool get isClaimed => merchantId != null;

  static MerchantOrder fromJson(Map<String, dynamic> j) {
    return MerchantOrder(
      id: (j['id'] as num).toInt(),
      orderNumber: j['order_number'] as String? ?? '',
      merchantId: (j['merchant_id'] as num?)?.toInt(),
      customerName: j['customer_name'] as String?,
      customerPhone: j['customer_phone'] as String?,
      customerAddress: j['customer_address'] as String?,
      cityId: (j['city_id'] as num?)?.toInt(),
      cityName: j['city_name'] as String?,
      status: j['status'] as String? ?? 'pending',
      totalAmount: (j['total_amount'] as num?)?.toDouble() ?? 0,
      createdAt: j['created_at'] as String?,
    );
  }
}

class MerchantOrderDetail {
  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> items;

  MerchantOrderDetail({required this.order, required this.items});

  static MerchantOrderDetail fromJson(Map<String, dynamic> data) {
    final order = data['order'] as Map<String, dynamic>? ?? {};
    final list = data['items'] as List<dynamic>? ?? [];
    return MerchantOrderDetail(
      order: order,
      items: list.map((e) => e as Map<String, dynamic>).toList(),
    );
  }
}

class MerchantStats {
  final int orderCount;
  final double totalSales;
  final double? pendingCommission;
  final int? dailyCapacityUsed;
  final int? dailyCapacityMax;

  MerchantStats({
    required this.orderCount,
    required this.totalSales,
    this.pendingCommission,
    this.dailyCapacityUsed,
    this.dailyCapacityMax,
  });

  static MerchantStats fromJson(Map<String, dynamic> j) {
    return MerchantStats(
      orderCount: (j['orderCount'] as num?)?.toInt() ?? (j['order_count'] as num?)?.toInt() ?? 0,
      totalSales: (j['totalSales'] as num?)?.toDouble() ?? (j['total_sales'] as num?)?.toDouble() ?? 0,
      pendingCommission: (j['pendingCommission'] as num?)?.toDouble(),
      dailyCapacityUsed: (j['dailyCapacityUsed'] as num?)?.toInt(),
      dailyCapacityMax: (j['dailyCapacityMax'] as num?)?.toInt(),
    );
  }
}

class MerchantItem {
  final int id;
  final String name;
  final String? storeName;
  final int? cityId;

  MerchantItem({required this.id, required this.name, this.storeName, this.cityId});

  static MerchantItem fromJson(Map<String, dynamic> j) {
    return MerchantItem(
      id: (j['id'] as num).toInt(),
      name: j['name'] as String? ?? '',
      storeName: j['store_name'] as String?,
      cityId: (j['city_id'] as num?)?.toInt(),
    );
  }
}

class MerchantCategory {
  final int id;
  final String nameAr;
  MerchantCategory({required this.id, required this.nameAr});
  static MerchantCategory fromJson(Map<String, dynamic> j) {
    return MerchantCategory(
      id: (j['id'] as num).toInt(),
      nameAr: j['name_ar'] as String? ?? '',
    );
  }
}

class MerchantBrandCategory {
  final int id;
  final String nameAr;
  MerchantBrandCategory({required this.id, required this.nameAr});
  static MerchantBrandCategory fromJson(Map<String, dynamic> j) {
    return MerchantBrandCategory(
      id: (j['id'] as num).toInt(),
      nameAr: j['name_ar'] as String? ?? '',
    );
  }
}

class MerchantProduct {
  final int id;
  final String nameAr;
  final String? nameEn;
  final double price;
  final double finalPrice;
  final String? imagePath;
  final String? company;
  final int? categoryId;
  final String? shortDescription;
  final String? longDescription;

  MerchantProduct({
    required this.id,
    required this.nameAr,
    this.nameEn,
    required this.price,
    required this.finalPrice,
    this.imagePath,
    this.company,
    this.categoryId,
    this.shortDescription,
    this.longDescription,
  });

  String get displayName => nameAr;

  static MerchantProduct fromJson(Map<String, dynamic> j) {
    final price = (j['price'] as num?)?.toDouble() ?? 0;
    final discount = (j['discount_percent'] as num?)?.toDouble() ?? 0;
    return MerchantProduct(
      id: (j['id'] as num).toInt(),
      nameAr: j['name_ar'] as String? ?? '',
      nameEn: j['name_en'] as String?,
      price: price,
      finalPrice: (j['final_price'] as num?)?.toDouble() ?? price * (1 - discount / 100),
      imagePath: j['image_path'] as String?,
      company: j['company'] as String?,
      categoryId: (j['category_id'] as num?)?.toInt(),
      shortDescription: j['short_description'] as String?,
      longDescription: j['long_description'] as String?,
    );
  }
}

class MerchantInventoryItem {
  final int productId;
  final int quantity;
  final String nameAr;
  final String? imagePath;
  final String? shortDescription;
  final String? longDescription;

  MerchantInventoryItem({
    required this.productId,
    required this.quantity,
    required this.nameAr,
    this.imagePath,
    this.shortDescription,
    this.longDescription,
  });

  static MerchantInventoryItem fromJson(Map<String, dynamic> j) {
    return MerchantInventoryItem(
      productId: (j['product_id'] as num).toInt(),
      quantity: (j['quantity'] as num?)?.toInt() ?? 0,
      nameAr: j['name_ar'] as String? ?? '',
      imagePath: j['image_path'] as String?,
      shortDescription: j['short_description'] as String?,
      longDescription: j['long_description'] as String?,
    );
  }
}

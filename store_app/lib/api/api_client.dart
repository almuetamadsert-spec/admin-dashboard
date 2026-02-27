import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/brand_category.dart';
import '../models/category.dart';
import '../models/city.dart';
import '../models/my_order.dart';
import '../models/product.dart';

class ApiClient {
  static String get _base => Config.baseUrl.replaceAll(RegExp(r'/$'), '');

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Consumer-Key': Config.consumerKey,
        'X-Consumer-Secret': Config.consumerSecret,
      };

  /// GET /api/categories (مع كسر الكاش لرؤية آخر تعديلات اللوحة)
  static Future<List<Category>> getCategories() async {
    final r = await http.get(
      Uri.parse('$_base/api/categories?_=${DateTime.now().millisecondsSinceEpoch}'),
      headers: _headers,
    );
    if (r.statusCode != 200) throw Exception('فشل تحميل التصنيفات: ${r.statusCode}');
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (data?['ok'] != true) throw Exception(data?['message'] ?? 'فشل تحميل التصنيفات');
    final list = data!['categories'] as List<dynamic>? ?? [];
    return list.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/brand-categories
  static Future<List<BrandCategory>> getBrandCategories() async {
    final r = await http.get(
      Uri.parse('$_base/api/brand-categories?_=${DateTime.now().millisecondsSinceEpoch}'),
      headers: _headers,
    );
    if (r.statusCode != 200) return [];
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    final list = data?['brand_categories'] as List<dynamic>? ?? [];
    return list.map((e) => BrandCategory.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/products — اختياري: category_id, company (براند), q (بحث), sort (price_asc|price_desc|date_asc|date_desc)
  static Future<List<Product>> getProducts({int? categoryId, String? company, String? q, String? sort}) async {
    var uri = Uri.parse('$_base/api/products');
    final query = <String, String>{};
    if (categoryId != null) query['category_id'] = categoryId.toString();
    if (company != null && company.isNotEmpty) query['company'] = company;
    if (q != null && q.isNotEmpty) query['q'] = q;
    if (sort != null && sort.isNotEmpty) query['sort'] = sort;
    if (query.isNotEmpty) uri = uri.replace(queryParameters: query);
    final r = await http.get(uri, headers: _headers);
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

  /// GET /api/store-ui/slider — شرائح الإعلانات
  static Future<SliderData> getSlider() async {
    final r = await http.get(
      Uri.parse('$_base/api/store-ui/slider'),
      headers: _headers,
    );
    if (r.statusCode != 200) return SliderData(intervalSeconds: 5, slides: [], productLayout: 'grid_2');
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (data?['ok'] != true) return SliderData(intervalSeconds: 5, slides: [], productLayout: 'grid_2');
    final list = data!['slides'] as List<dynamic>? ?? [];
    final interval = (data['interval_seconds'] as num?)?.toInt() ?? 5;
    final layout = data['product_layout'] as String? ?? 'grid_2';
    final cardJson = data['product_card'] as Map<String, dynamic>?;
    return SliderData(
      intervalSeconds: interval.clamp(2, 60),
      slides: list.map((e) => SliderSlide.fromJson(e as Map<String, dynamic>)).toList(),
      productLayout: ['grid_2', 'grid_3', 'slider'].contains(layout) ? layout : 'grid_2',
      cardLayout: ProductCardLayout.fromJson(cardJson),
    );
  }

  /// GET /api/cms/:slug — صفحة من نحن / خصوصية / شروط
  static Future<Map<String, dynamic>?> getCmsPage(String slug) async {
    final r = await http.get(Uri.parse('$_base/api/cms/$slug'), headers: _headers);
    if (r.statusCode != 200) return null;
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (data?['ok'] != true) return null;
    return data!['page'] as Map<String, dynamic>?;
  }

  /// GET /api/social-links — روابط السوشيال ميديا
  static Future<Map<String, dynamic>> getSocialLinks() async {
    final r = await http.get(Uri.parse('$_base/api/social-links'), headers: _headers);
    if (r.statusCode != 200) return {'ok': false, 'links': <Map<String, dynamic>>[], 'icon_shape': 'circle', 'icon_bg_color': '#06A3E7', 'icon_symbol_color': '#ffffff'};
    final data = jsonDecode(r.body) as Map<String, dynamic>? ?? {};
    final list = data['links'] as List<dynamic>? ?? [];
    return {
      'ok': data['ok'] == true,
      'links': list.map((e) => e as Map<String, dynamic>).toList(),
      'icon_shape': data['icon_shape'] as String? ?? 'circle',
      'icon_bg_color': data['icon_bg_color'] as String? ?? '#06A3E7',
      'icon_symbol_color': data['icon_symbol_color'] as String? ?? '#ffffff',
    };
  }

  /// GET /api/orders?phone=xxx — طلباتي
  static Future<List<MyOrder>> getMyOrders(String phone) async {
    final normalized = phone.trim().replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) return [];
    final uri = Uri.parse('$_base/api/orders').replace(queryParameters: {'phone': normalized});
    final r = await http.get(uri, headers: _headers);
    if (r.statusCode != 200) throw Exception('فشل تحميل الطلبات: ${r.statusCode}');
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (data?['ok'] != true) return [];
    final list = data!['orders'] as List<dynamic>? ?? [];
    return list.map((e) => MyOrder.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/orders
  static Future<Map<String, dynamic>> postOrder({
    required int cityId,
    required String customerName,
    required String customerPhone,
    String customerPhoneAlt = '',
    String customerAddress = '',
    required List<Map<String, dynamic>> items,
  }) async {
    final body = {
      'city_id': cityId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_phone_alt': customerPhoneAlt,
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

class SliderData {
  final int intervalSeconds;
  final List<SliderSlide> slides;
  final String productLayout; // grid_2 | grid_3 | slider
  final ProductCardLayout cardLayout;
  SliderData({
    required this.intervalSeconds,
    required this.slides,
    this.productLayout = 'grid_2',
    ProductCardLayout? cardLayout,
  }) : cardLayout = cardLayout ?? const ProductCardLayout();
}

class ProductCardLayout {
  final String bgColor;
  final String radius; // sharp | rounded | medium
  final bool showAddToCart;
  final bool showBuyNow;
  final String brandPosition; // left | right | top | bottom
  final String nameAlign; // left | center | right
  final String priceAlign; // left | center | right
  final String addBtnStyle; // small_rounded | full_rounded | sharp
  final String addBtnPosition; // left | right
  final String addBtnColor; // hex

  const ProductCardLayout({
    this.bgColor = '#ffffff',
    this.radius = 'rounded',
    this.showAddToCart = false,
    this.showBuyNow = false,
    this.brandPosition = 'left',
    this.nameAlign = 'right',
    this.priceAlign = 'right',
    this.addBtnStyle = 'small_rounded',
    this.addBtnPosition = 'right',
    this.addBtnColor = '#06A3E7',
  });

  factory ProductCardLayout.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const ProductCardLayout();
    return ProductCardLayout(
      bgColor: (j['bg_color'] as String?) ?? '#ffffff',
      radius: (j['radius'] as String?) ?? 'rounded',
      showAddToCart: j['show_add_to_cart'] == true,
      showBuyNow: j['show_buy_now'] == true,
      brandPosition: (j['brand_position'] as String?) ?? 'left',
      nameAlign: (j['name_align'] as String?) ?? 'right',
      priceAlign: (j['price_align'] as String?) ?? 'right',
      addBtnStyle: (j['add_btn_style'] as String?) ?? 'small_rounded',
      addBtnPosition: (j['add_btn_position'] as String?) ?? 'right',
      addBtnColor: (j['add_btn_color'] as String?) ?? '#06A3E7',
    );
  }

  double get borderRadius {
    switch (radius) {
      case 'sharp':
        return 0;
      case 'medium':
        return 12;
      case 'rounded':
      default:
        return 12;
    }
  }
}

class SliderSlide {
  final int id;
  final String imageUrl;
  final String imagePath;
  final String cornerStyle; // sharp | rounded | medium
  SliderSlide({required this.id, required this.imageUrl, this.imagePath = '', required this.cornerStyle});
  static SliderSlide fromJson(Map<String, dynamic> j) {
    return SliderSlide(
      id: (j['id'] as num?)?.toInt() ?? 0,
      imageUrl: j['image_url'] as String? ?? '',
      imagePath: j['image_path'] as String? ?? '',
      cornerStyle: j['corner_style'] as String? ?? 'rounded',
    );
  }
  double get borderRadius {
    switch (cornerStyle) {
      case 'sharp': return 0;
      case 'medium': return 12;
      case 'rounded':
      default: return 20;
    }
  }
}

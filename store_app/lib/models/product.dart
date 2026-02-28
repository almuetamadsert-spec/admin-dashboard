class Product {
  final int id;
  final String? nameAr;
  final String? nameEn;
  final double price;
  final double finalPrice;
  final String? imagePath;
  final List<String> secondaryImages;
  final int stock;
  final String? company;
  final String? description;
  final String? shortDescription;

  // الخيارات الجديدة
  final List<String> colors;
  final List<String> sizes;
  final List<String> storageCapacities;
  final List<String> batteryCapacities;

  Product({
    required this.id,
    this.nameAr,
    this.nameEn,
    required this.price,
    required this.finalPrice,
    this.imagePath,
    this.secondaryImages = const [],
    this.stock = 0,
    this.company,
    this.description,
    this.shortDescription,
    this.colors = const [],
    this.sizes = const [],
    this.storageCapacities = const [],
    this.batteryCapacities = const [],
  });

  String get displayName => (nameAr?.isNotEmpty == true ? nameAr : nameEn) ?? 'منتج';
  
  List<String> get allImages => [
    if (imagePath != null && imagePath!.isNotEmpty) imagePath!,
    ...secondaryImages,
  ];

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      nameAr: json['name_ar']?.toString(),
      nameEn: json['name_en']?.toString(),
      price: (double.tryParse(json['price']?.toString() ?? '0') ?? 0),
      finalPrice: (double.tryParse(json['final_price']?.toString() ?? '0') ?? 0),
      imagePath: json['image_path']?.toString(),
      secondaryImages: _parseImagePaths(json['image_paths']),
      stock: int.tryParse(json['stock']?.toString() ?? '0') ?? 0,
      company: json['company']?.toString(),
      description: json['description']?.toString(),
      shortDescription: json['short_description']?.toString(),
      colors: _parseList(json['colors']),
      sizes: _parseList(json['sizes']),
      storageCapacities: _parseList(json['storage_capacities']),
      batteryCapacities: _parseList(json['battery_capacities']),
    );
  }

  static List<String> _parseImagePaths(dynamic value) {
    if (value == null) return [];
    final str = value.toString().trim();
    if (str.isEmpty) return [];
    return str.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  static List<String> _parseList(dynamic value) {
    if (value == null) return [];
    final str = value.toString().trim();
    if (str.isEmpty) return [];
    return str.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
}

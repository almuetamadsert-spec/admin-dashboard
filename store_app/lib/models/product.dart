class Product {
  final int id;
  final String? nameAr;
  final String? nameEn;
  final double price;
  final double finalPrice;
  final String? imagePath;
  final int stock;

  Product({
    required this.id,
    this.nameAr,
    this.nameEn,
    required this.price,
    required this.finalPrice,
    this.imagePath,
    this.stock = 0,
  });

  String get displayName => (nameAr?.isNotEmpty == true ? nameAr : nameEn) ?? 'منتج';

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      nameAr: json['name_ar']?.toString(),
      nameEn: json['name_en']?.toString(),
      price: (double.tryParse(json['price']?.toString() ?? '0') ?? 0),
      finalPrice: (double.tryParse(json['final_price']?.toString() ?? '0') ?? 0),
      imagePath: json['image_path']?.toString(),
      stock: int.tryParse(json['stock']?.toString() ?? '0') ?? 0,
    );
  }
}

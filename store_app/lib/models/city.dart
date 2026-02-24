class City {
  final int id;
  final String name;
  final double deliveryFee;

  City({
    required this.id,
    required this.name,
    this.deliveryFee = 0,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      deliveryFee: double.tryParse(json['delivery_fee']?.toString() ?? '0') ?? 0,
    );
  }
}

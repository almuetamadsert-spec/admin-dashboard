import 'product.dart';

class CartItem {
  final Product product;
  int quantity;
  
  // الخيارات المختارة
  final String? selectedColor;
  final String? selectedSize;
  final String? selectedStorage;
  final String? selectedBattery;

  CartItem({
    required this.product, 
    this.quantity = 1,
    this.selectedColor,
    this.selectedSize,
    this.selectedStorage,
    this.selectedBattery,
  });

  double get subtotal => product.finalPrice * quantity;

  // نص مجمع للخيارات لسهولة العرض
  String get optionsString {
    final opts = <String>[];
    if (selectedColor?.isNotEmpty == true) opts.add('اللون: $selectedColor');
    if (selectedSize?.isNotEmpty == true) opts.add('المقاس: $selectedSize');
    if (selectedStorage?.isNotEmpty == true) opts.add('السعة: $selectedStorage');
    if (selectedBattery?.isNotEmpty == true) opts.add('البطارية: $selectedBattery');
    return opts.join(' | ');
  }
}

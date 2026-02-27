import 'package:flutter/material.dart';

import '../../config.dart';
import '../../models/cart_item.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';

/// صفحة تفاصيل المنتج: معرض صور، براند، اسم، سعر، ألوان، سعة، كمية، وصف، زرّان ثابتان.
class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final List<CartItem> cart;
  final void Function(
    Product product, {
    int quantity,
    String? selectedColor,
    String? selectedSize,
    String? selectedStorage,
    String? selectedBattery,
  }) onAddToCart;
  final VoidCallback? onBuyNow;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.cart,
    required this.onAddToCart,
    this.onBuyNow,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  int _selectedColorIndex = -1;
  int _selectedSizeIndex = -1;
  int _selectedStorageIndex = -1;
  int _selectedBatteryIndex = -1;

  static final Map<String, Color> _colorMap = {
    // English
    'black': Colors.black, 'white': Colors.white, 'red': Colors.red,
    'blue': Colors.blue, 'green': Colors.green, 'yellow': Colors.yellow,
    'orange': Colors.orange, 'purple': Colors.purple, 'pink': Colors.pink,
    'grey': Colors.grey, 'gray': Colors.grey, 'brown': Colors.brown,
    'cyan': Colors.cyan, 'gold': const Color(0xFFFFD700),
    'silver': const Color(0xFFC0C0C0), 'navy': const Color(0xFF000080),
    // Arabic
    'اسود': Colors.black, 'أسود': Colors.black,
    'ابيض': Colors.white, 'أبيض': Colors.white,
    'احمر': Colors.red, 'أحمر': Colors.red,
    'ازرق': Colors.blue, 'أزرق': Colors.blue,
    'اخضر': Colors.green, 'أخضر': Colors.green,
    'اصفر': Colors.yellow, 'أصفر': Colors.yellow,
    'برتقالي': Colors.orange,
    'بنفسجي': Colors.purple, 'موف': Colors.purple,
    'وردي': Colors.pink, 'بمبي': Colors.pink, 'زهري': Colors.pink,
    'رصاصي': Colors.grey, 'رمادي': Colors.grey,
    'بني': Colors.brown,
    'سماوي': Colors.lightBlue,
    'ذهبي': const Color(0xFFFFD700),
    'فضي': const Color(0xFFC0C0C0),
    'كحلي': const Color(0xFF000080),
    'بيج': const Color(0xFFF5F5DC),
    'عنابي': const Color(0xFF800000), 'مارون': const Color(0xFF800000),
  };

  Color _parseColor(String name) {
    final cleanName = name.trim().toLowerCase();
    if (_colorMap.containsKey(cleanName)) return _colorMap[cleanName]!;
    if (cleanName.startsWith('#')) {
      try {
        final hex = cleanName.replaceFirst('#', '');
        return Color(int.parse(hex, radix: 16) + (hex.length == 6 ? 0xFF000000 : 0x00000000));
      } catch (_) {}
    }
    return Colors.grey.shade300; // Default fallback for unknown colors
  }

  @override
  void initState() {
    super.initState();
    if (widget.product.colors.isNotEmpty) _selectedColorIndex = 0;
    if (widget.product.sizes.isNotEmpty) _selectedSizeIndex = 0;
    if (widget.product.storageCapacities.isNotEmpty) _selectedStorageIndex = 0;
    if (widget.product.batteryCapacities.isNotEmpty) _selectedBatteryIndex = 0;
  }

  String _imageUrl() {
    if (widget.product.imagePath == null || widget.product.imagePath!.isEmpty) return '';
    final base = Config.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/uploads/${widget.product.imagePath!.replaceFirst(RegExp(r'^\/+'), '')}';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl();
    final hasDiscount = widget.product.finalPrice < widget.product.price;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart_outlined),
                      onPressed: () {
                        if (widget.onBuyNow != null) widget.onBuyNow!();
                      },
                    ),
                    if (widget.cart.isNotEmpty)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${widget.cart.fold(0, (s, e) => s + e.quantity)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              title: const Text('تفاصيل المنتج', style: TextStyle(fontSize: 18)),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              foregroundColor: Colors.black87,
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 280,
                child: PageView(
                  children: [
                    if (imageUrl.isEmpty)
                      Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported, size: 80),
                      )
                    else
                      Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, size: 80),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.company ?? 'منتج',
                      style: TextStyle(fontSize: 12, color: kPrimaryBlue),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.product.displayName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (widget.product.shortDescription?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.product.shortDescription!,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${widget.product.finalPrice.toStringAsFixed(0)} د.ل',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: kPrimaryBlue,
                          ),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${widget.product.price.toStringAsFixed(0)} د.ل',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star, size: 18, color: Colors.amber.shade700),
                        const SizedBox(width: 4),
                        const Text('4.8', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        Text('124 تقييم', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(width: 16),
                        Text(
                          widget.product.stock > 0 ? 'متوفر في المخزون' : 'غير متوفر',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.product.stock > 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    if (widget.product.colors.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('اختر اللون', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: List.generate(
                          widget.product.colors.length,
                          (i) {
                            final colorName = widget.product.colors[i];
                            final colorVal = _parseColor(colorName);
                            final isSelected = _selectedColorIndex == i;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedColorIndex = i),
                              child: Tooltip(
                                message: colorName,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: colorVal,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? kPrimaryBlue : Colors.grey.shade300,
                                      width: isSelected ? 3 : 1,
                                    ),
                                    boxShadow: [
                                      if (isSelected) 
                                        BoxShadow(color: kPrimaryBlue.withOpacity(0.3), blurRadius: 4, spreadRadius: 1)
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    if (widget.product.sizes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('المقاس / الحجم', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(
                          widget.product.sizes.length,
                          (i) => ChoiceChip(
                            label: Text(widget.product.sizes[i]),
                            selected: _selectedSizeIndex == i,
                            onSelected: (val) {
                              if (val) setState(() => _selectedSizeIndex = i);
                            },
                            selectedColor: kPrimaryBlue.withOpacity(0.2),
                          ),
                        ),
                      ),
                    ],

                    if (widget.product.storageCapacities.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('سعة التخزين', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(
                          widget.product.storageCapacities.length,
                          (i) => ChoiceChip(
                            label: Text(widget.product.storageCapacities[i]),
                            selected: _selectedStorageIndex == i,
                            onSelected: (val) {
                              if (val) setState(() => _selectedStorageIndex = i);
                            },
                            selectedColor: kPrimaryBlue.withOpacity(0.2),
                          ),
                        ),
                      ),
                    ],

                    if (widget.product.batteryCapacities.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('سعة البطارية', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(
                          widget.product.batteryCapacities.length,
                          (i) => ChoiceChip(
                            label: Text(widget.product.batteryCapacities[i]),
                            selected: _selectedBatteryIndex == i,
                            onSelected: (val) {
                              if (val) setState(() => _selectedBatteryIndex = i);
                            },
                            selectedColor: kPrimaryBlue.withOpacity(0.2),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text('الكمية', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton.filled(
                          onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                          icon: const Icon(Icons.remove),
                          style: IconButton.styleFrom(backgroundColor: kPrimaryBlue, foregroundColor: Colors.white),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        IconButton.filled(
                          onPressed: () => setState(() => _quantity++),
                          icon: const Icon(Icons.add),
                          style: IconButton.styleFrom(backgroundColor: kPrimaryBlue, foregroundColor: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'تبقى ${widget.product.stock} قطع فقط!',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                        ),
                      ],
                    ),
                    if (widget.product.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 20),
                      const Text('الوصف', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        widget.product.description!,
                        style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey.shade700),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text('التقييمات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('4.8', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Icon(Icons.star, color: Colors.amber.shade700, size: 20),
                        const SizedBox(width: 4),
                        Text('124 تقييم', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('اكتب تقييماً'),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.product.stock > 0
                        ? () {
                            if (widget.product.colors.isNotEmpty && _selectedColorIndex == -1) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار اللون')));
                              return;
                            }
                            if (widget.product.sizes.isNotEmpty && _selectedSizeIndex == -1) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار المقاس')));
                              return;
                            }
                            if (widget.product.storageCapacities.isNotEmpty && _selectedStorageIndex == -1) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار سعة التخزين')));
                              return;
                            }
                            if (widget.product.batteryCapacities.isNotEmpty && _selectedBatteryIndex == -1) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار سعة البطارية')));
                              return;
                            }

                            widget.onAddToCart(
                              widget.product,
                              quantity: _quantity,
                              selectedColor: _selectedColorIndex >= 0 ? widget.product.colors[_selectedColorIndex] : null,
                              selectedSize: _selectedSizeIndex >= 0 ? widget.product.sizes[_selectedSizeIndex] : null,
                              selectedStorage: _selectedStorageIndex >= 0 ? widget.product.storageCapacities[_selectedStorageIndex] : null,
                              selectedBattery: _selectedBatteryIndex >= 0 ? widget.product.batteryCapacities[_selectedBatteryIndex] : null,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('تمت إضافة ${widget.product.displayName}')),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('أضف إلى السلة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimaryBlue,
                      side: const BorderSide(color: kPrimaryBlue),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.product.stock > 0
                        ? () {
                            if (widget.product.colors.isNotEmpty && _selectedColorIndex == -1) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار اللون')));
                              return;
                            }
                            if (widget.product.sizes.isNotEmpty && _selectedSizeIndex == -1) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار المقاس')));
                              return;
                            }
                            if (widget.product.storageCapacities.isNotEmpty && _selectedStorageIndex == -1) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار سعة التخزين')));
                              return;
                            }
                            if (widget.product.batteryCapacities.isNotEmpty && _selectedBatteryIndex == -1) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار سعة البطارية')));
                              return;
                            }

                            widget.onAddToCart(
                              widget.product,
                              quantity: _quantity,
                              selectedColor: _selectedColorIndex >= 0 ? widget.product.colors[_selectedColorIndex] : null,
                              selectedSize: _selectedSizeIndex >= 0 ? widget.product.sizes[_selectedSizeIndex] : null,
                              selectedStorage: _selectedStorageIndex >= 0 ? widget.product.storageCapacities[_selectedStorageIndex] : null,
                              selectedBattery: _selectedBatteryIndex >= 0 ? widget.product.batteryCapacities[_selectedBatteryIndex] : null,
                            );
                            widget.onBuyNow?.call();
                          }
                        : null,
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('اشترِ الآن'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrimaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

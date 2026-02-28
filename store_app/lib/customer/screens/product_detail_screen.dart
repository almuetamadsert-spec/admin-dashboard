import 'package:flutter/material.dart';

import '../../config.dart';
import '../../models/cart_item.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';
// import 'package:flutter_html/flutter_html.dart';

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

  String _formatImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    final base = Config.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/uploads/${path.replaceFirst(RegExp(r'^\/+'), '')}';
  }

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final allImages = widget.product.allImages;
    final hasDiscount = widget.product.finalPrice < widget.product.price;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              centerTitle: true,
              elevation: 0,
              backgroundColor: context.theme.scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: context.colors.onSurface),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                'تفاصيل المنتج',
                style: context.textTheme.titleLarge?.copyWith(fontSize: 18),
              ),
              actions: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.shopping_cart_outlined, color: context.colors.onSurface),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onBuyNow?.call();
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
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '${widget.cart.fold(0, (s, e) => s + e.quantity)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Container(
                      height: 320,
                      decoration: BoxDecoration(
                        color: context.isDark ? kDarkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          if (!context.isDark)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          if (allImages.isEmpty)
                            Center(
                              child: Icon(Icons.image_not_supported, size: 80, color: Colors.grey.shade300),
                            )
                          else
                            PageView.builder(
                              controller: _pageController,
                              onPageChanged: (v) => setState(() => _currentPage = v),
                              itemCount: allImages.length,
                              itemBuilder: (ctx, i) {
                                return Image.network(
                                  _formatImageUrl(allImages[i]),
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey.shade100,
                                    child: const Icon(Icons.broken_image, size: 80),
                                  ),
                                );
                              },
                            ),
                          if (allImages.length > 1)
                            Positioned(
                              bottom: 12,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  allImages.length,
                                  (index) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: _currentPage == index ? 20 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _currentPage == index ? kPrimaryBlue : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            widget.product.displayName,
                            style: context.textTheme.titleLarge?.copyWith(fontSize: 22, height: 1.2),
                          ),
                        ),
                        if (widget.product.company?.isNotEmpty == true)
                          Text(
                            widget.product.company!,
                            style: TextStyle(
                              fontSize: 16,
                              color: context.colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // السعر وحالة التوفر
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.product.finalPrice.toStringAsFixed(0)} د.ل',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: context.colors.primary,
                              ),
                            ),
                            if (hasDiscount)
                              Text(
                                '${widget.product.price.toStringAsFixed(0)} د.ل',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: (widget.product.stock > 0 ? Colors.green : Colors.red).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.product.stock > 0 ? Icons.check_circle : Icons.error,
                                    size: 14,
                                    color: widget.product.stock > 0 ? Colors.green : Colors.red,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.product.stock > 0 ? 'متوفر' : 'نفذ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: widget.product.stock > 0 ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (widget.product.shortDescription?.isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      Text(
                        widget.product.shortDescription!,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.isDark ? kDarkTextSecondary : kTextSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
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
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: colorVal,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? context.colors.primary : Colors.grey.shade300,
                                    width: isSelected ? 3 : 1,
                                  ),
                                  boxShadow: [
                                    if (isSelected) 
                                      BoxShadow(color: context.colors.primary.withOpacity(0.3), blurRadius: 4, spreadRadius: 1)
                                  ],
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
                          style: IconButton.styleFrom(
                            backgroundColor: context.colors.primary,
                            foregroundColor: context.colors.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'تبقى ${widget.product.stock} قطع فقط!',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                        ),
                      ],
                    ),
                    if (widget.product.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 24),
                      Text('كامل التفاصيل', style: context.textTheme.titleLarge?.copyWith(fontSize: 18)),
                      const SizedBox(height: 12),
                      Text(
                        widget.product.description!.replaceAll(r'\n', '\n').replaceAll('<strong>', '').replaceAll('</strong>', '').replaceAll('<br>', '\n').replaceAll('&bull;', '•'),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.isDark ? kDarkTextSecondary : kTextSecondary,
                          height: 1.7,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const SizedBox(height: 120),
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

                            setState(() {
                              widget.onAddToCart(
                                widget.product,
                                quantity: _quantity,
                                selectedColor: _selectedColorIndex >= 0 ? widget.product.colors[_selectedColorIndex] : null,
                                selectedSize: _selectedSizeIndex >= 0 ? widget.product.sizes[_selectedSizeIndex] : null,
                                selectedStorage: _selectedStorageIndex >= 0 ? widget.product.storageCapacities[_selectedStorageIndex] : null,
                                selectedBattery: _selectedBatteryIndex >= 0 ? widget.product.batteryCapacities[_selectedBatteryIndex] : null,
                              );
                            });
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

                            setState(() {
                              widget.onAddToCart(
                                widget.product,
                                quantity: _quantity,
                                selectedColor: _selectedColorIndex >= 0 ? widget.product.colors[_selectedColorIndex] : null,
                                selectedSize: _selectedSizeIndex >= 0 ? widget.product.sizes[_selectedSizeIndex] : null,
                                selectedStorage: _selectedStorageIndex >= 0 ? widget.product.storageCapacities[_selectedStorageIndex] : null,
                                selectedBattery: _selectedBatteryIndex >= 0 ? widget.product.batteryCapacities[_selectedBatteryIndex] : null,
                              );
                            });
                            Navigator.pop(context); // إغلاق صفحة التفاصيل
                            widget.onBuyNow?.call(); // الانتقال للسلة
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

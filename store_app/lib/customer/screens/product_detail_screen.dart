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
              expandedHeight: 0,
              centerTitle: true,
              elevation: 0,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [kPrimaryBlue, Color(0xFF42C2F7)],
                  ),
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'تفاصيل المنتج',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              actions: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(left: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onBuyNow?.call();
                        },
                      ),
                    ),
                    if (widget.cart.isNotEmpty)
                      Positioned(
                        left: 8,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: kDanger, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '${widget.cart.fold(0, (s, e) => s + e.quantity)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(
              child: Container(
                color: kPrimaryBlue.withOpacity(0.02),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Container(
                        height: 340,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: kPrimaryBlue.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            if (allImages.isEmpty)
                              Center(child: Icon(Icons.image_not_supported_outlined, size: 80, color: Colors.grey.shade200))
                            else
                              PageView.builder(
                                controller: _pageController,
                                onPageChanged: (v) => setState(() => _currentPage = v),
                                itemCount: allImages.length,
                                itemBuilder: (ctx, i) => InteractiveViewer(
                                  child: Image.network(
                                    _formatImageUrl(allImages[i]),
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 80),
                                  ),
                                ),
                              ),
                            if (allImages.length > 1)
                              Positioned(
                                bottom: 16,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    allImages.length,
                                    (index) => AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      width: _currentPage == index ? 24 : 8,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: _currentPage == index ? kPrimaryBlue : Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(3),
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
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.product.company?.isNotEmpty == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: kPrimaryBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    widget.product.company!,
                                    style: const TextStyle(fontSize: 12, color: kPrimaryBlue, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              Text(
                                widget.product.displayName,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.2, letterSpacing: -0.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade100),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('السعر الحالي', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${widget.product.finalPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: kPrimaryBlue),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 6, right: 4),
                                    child: Text('د.ل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
                                  ),
                                ],
                              ),
                              if (hasDiscount)
                                Text(
                                  '${widget.product.price.toStringAsFixed(0)} د.ل',
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade400, decoration: TextDecoration.lineThrough),
                                ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: (widget.product.stock > 0 ? kSuccess : kDanger).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  widget.product.stock > 0 ? Icons.inventory_2_rounded : Icons.block_flipped,
                                  size: 16,
                                  color: widget.product.stock > 0 ? kSuccess : kDanger,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.product.stock > 0 ? 'متوفر بالمخزن' : 'نفذت الكمية',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: widget.product.stock > 0 ? kSuccess : kDanger),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.product.shortDescription?.isNotEmpty == true) ...[
                      const SizedBox(height: 24),
                      const Text('وصف سريع', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(
                        widget.product.shortDescription!,
                        style: const TextStyle(color: kTextSecondary, height: 1.6, fontSize: 14),
                      ),
                    ],

                    // Options sections (Colors, Sizes, etc.) with improved styling
                    if (widget.product.colors.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text('الألوان المتوفرة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: List.generate(
                          widget.product.colors.length,
                          (i) {
                            final colorVal = _parseColor(widget.product.colors[i]);
                            final isSelected = _selectedColorIndex == i;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedColorIndex = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: colorVal,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isSelected ? kPrimaryBlue : Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(color: (isSelected ? kPrimaryBlue : Colors.black).withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))
                                  ],
                                ),
                                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    // Standard choice chips for sizes/storage
                    _buildSelectionSection('المقاس والحجم', widget.product.sizes, _selectedSizeIndex, (i) => setState(() => _selectedSizeIndex = i)),
                    _buildSelectionSection('سعة التخزين', widget.product.storageCapacities, _selectedStorageIndex, (i) => setState(() => _selectedStorageIndex = i)),
                    _buildSelectionSection('سعة البطارية', widget.product.batteryCapacities, _selectedBatteryIndex, (i) => setState(() => _selectedBatteryIndex = i)),

                    const SizedBox(height: 32),
                    const Text('الكمية المطلوبة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _quantityBtn(Icons.remove_rounded, _quantity > 1 ? () => setState(() => _quantity--) : null),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text('$_quantity', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          ),
                          _quantityBtn(Icons.add_rounded, () => setState(() => _quantity++)),
                        ],
                      ),
                    ),

                    if (widget.product.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 40),
                      const Text('تفاصيل إضافية', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      const SizedBox(height: 12),
                      Text(
                        widget.product.description!.replaceAll(r'\n', '\n').replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&bull;', '•'),
                        style: const TextStyle(color: kTextSecondary, height: 1.8, fontSize: 15),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (widget.product.stock <= 0) return;
                    _handleAddToCart();
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: kPrimaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kPrimaryBlue.withOpacity(0.2)),
                    ),
                    child: const Center(
                      child: Text('أضف للسلة', style: TextStyle(color: kPrimaryBlue, fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () {
                    if (widget.product.stock <= 0) return;
                    _handleAddToCart();
                    Navigator.pop(context);
                    widget.onBuyNow?.call();
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [kPrimaryBlue, Color(0xFF42C2F7)]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: kPrimaryBlue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
                    ),
                    child: const Center(
                      child: Text('اشتري الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAddToCart() {
    // التحقق من الاختيارات
    if (widget.product.colors.isNotEmpty && _selectedColorIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار اللون')));
      return;
    }
    // ... بقية التحقق وإضافة المنتجات
    widget.onAddToCart(
      widget.product,
      quantity: _quantity,
      selectedColor: _selectedColorIndex >= 0 ? widget.product.colors[_selectedColorIndex] : null,
      selectedSize: _selectedSizeIndex >= 0 ? widget.product.sizes[_selectedSizeIndex] : null,
      selectedStorage: _selectedStorageIndex >= 0 ? widget.product.storageCapacities[_selectedStorageIndex] : null,
      selectedBattery: _selectedBatteryIndex >= 0 ? widget.product.batteryCapacities[_selectedBatteryIndex] : null,
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت إضافة ${widget.product.displayName} بنجاح')));
  }

  Widget _buildSelectionSection(String title, List<String> items, int selectedIdx, Function(int) onSelect) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(
            items.length,
            (i) => ChoiceChip(
              label: Text(items[i]),
              selected: selectedIdx == i,
              onSelected: (val) => onSelect(i),
              selectedColor: kPrimaryBlue,
              labelStyle: TextStyle(color: selectedIdx == i ? Colors.white : kTextSecondary, fontWeight: FontWeight.bold),
              backgroundColor: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _quantityBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: onTap == null ? Colors.grey.shade200 : Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: onTap == null ? Colors.grey : kPrimaryBlue, size: 24),
      ),
    );
  }
}

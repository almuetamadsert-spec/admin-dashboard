import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../config.dart';
import '../../models/brand_category.dart';
import '../../models/cart_item.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';
import '../../utils/category_icons.dart';
import 'brand_products_screen.dart';
import 'category_products_screen.dart';
import 'product_detail_screen.dart';

/// صفحة "عرض الكل" — تصنيفات المنتجات + تصنيفات البراندات.
class AllCategoriesScreen extends StatefulWidget {
  final List<CartItem> cart;
  final void Function(
    Product product, {
    int quantity,
    String? selectedColor,
    String? selectedSize,
    String? selectedStorage,
    String? selectedBattery,
  }) onAddToCart;
  final VoidCallback onOpenCart;
  final void Function(Category category)? onCategoryTap;
  final void Function(BrandCategory brand)? onBrandTap;

  const AllCategoriesScreen({
    super.key,
    required this.cart,
    required this.onAddToCart,
    required this.onOpenCart,
    this.onCategoryTap,
    this.onBrandTap,
  });

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  List<Category>? _categories;
  List<BrandCategory>? _brandCategories;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.getCategories(),
        ApiClient.getBrandCategories(),
      ]);
      if (mounted) {
        setState(() {
          _categories = results[0] as List<Category>;
          _brandCategories = results[1] as List<BrandCategory>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  String _categoryIconUrl(Category c) {
    if (c.iconPath == null || c.iconPath!.isEmpty) return '';
    final base = Config.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/uploads/${c.iconPath!.replaceFirst(RegExp(r'^\/+'), '')}';
  }

  void _onCategoryTap(Category cat) {
    if (widget.onCategoryTap != null) {
      widget.onCategoryTap!(cat);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CategoryProductsScreen(
          category: cat,
          cart: widget.cart,
          onAddToCart: widget.onAddToCart,
          onOpenCart: widget.onOpenCart,
          onProductTap: (p) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ProductDetailScreen(
                  product: p,
                  cart: widget.cart,
                  onAddToCart: widget.onAddToCart,
                  onBuyNow: widget.onOpenCart,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _onBrandTap(BrandCategory brand) {
    if (widget.onBrandTap != null) {
      widget.onBrandTap!(brand);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BrandProductsScreen(
          brand: brand,
          cart: widget.cart,
          onAddToCart: widget.onAddToCart,
          onOpenCart: widget.onOpenCart,
          onProductTap: (p) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ProductDetailScreen(
                  product: p,
                  cart: widget.cart,
                  onAddToCart: widget.onAddToCart,
                  onBuyNow: widget.onOpenCart,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// حجم أيقونة البراند حسب الإعداد
  double _brandIconSize(BrandCategory b) {
    switch (b.iconSize) {
      case 'small': return 40;
      case 'large': return 64;
      case 'medium':
      default: return 52;
    }
  }

  /// نصف قطر زوايا أيقونة البراند
  double _brandIconRadius(BrandCategory b) {
    switch (b.iconCorner) {
      case 'sharp': return 0;
      case 'medium': return 8;
      case 'rounded':
      default: return 16;
    }
  }

  /// عرض/ارتفاع حاوية أيقونة البراند (مربع أو مستطيل)
  (double, double) _brandIconBox(BrandCategory b) {
    final size = _brandIconSize(b);
    if (b.iconShape == 'rectangle') return (size * 1.25, size);
    return (size, size);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
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
          leading: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                  onPressed: widget.onOpenCart,
                ),
              ),
              if (widget.cart.isNotEmpty)
                Positioned(
                  right: 8,
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
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
          ],
          title: const Text(
            'التصنيفات',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      children: [
                        // تصنيفات المنتجات
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'تصنيفات المنتجات',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        _buildProductCategoriesGrid(),
                        const SizedBox(height: 24),
                        // تصنيفات البراندات
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'تصنيفات البراندات',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        _buildBrandCategoriesGrid(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildProductCategoriesGrid() {
    final list = _categories ?? [];
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('لا توجد تصنيفات', style: TextStyle(color: Colors.grey)),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 12,
      ),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final c = list[i];
        final isBgTransparent = c.iconColor == 'transparent' || c.iconColor.isEmpty;
        final bgColor = isBgTransparent
            ? Colors.transparent
            : colorFromHex(c.iconColor, opacity: (c.iconOpacity.clamp(0, 100)) / 100);
        final symbolColor = (c.iconSymbolColor != null && c.iconSymbolColor!.isNotEmpty)
            ? colorFromHex(c.iconSymbolColor!)
            : Colors.white;
        final iconUrl = _categoryIconUrl(c);
        final isCircle = isCircleShape(c.iconType);
        final radius = borderRadiusForType(c.iconType);
        return InkWell(
          onTap: () => _onCategoryTap(c),
          borderRadius: BorderRadius.circular(isCircle ? 26 : radius),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: bgColor.withOpacity(isBgTransparent ? 0 : 0.1),
                        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
                        borderRadius: isCircle ? null : BorderRadius.circular(radius.clamp(0.0, 16)),
                        border: isBgTransparent ? Border.all(color: Colors.grey.shade100, width: 1.5) : null,
                        boxShadow: [
                          if (!isBgTransparent)
                            BoxShadow(color: bgColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Center(
                        child: iconUrl.isEmpty
                            ? Icon(categoryIcon(c), color: isBgTransparent ? kPrimaryBlue : bgColor.withOpacity(1), size: 28)
                            : ClipRRect(
                                borderRadius: isCircle ? BorderRadius.circular(29) : BorderRadius.circular(radius.clamp(0.0, 16)),
                                child: Image.network(
                                  iconUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (_, __, ___) => Icon(categoryIcon(c), color: isBgTransparent ? kPrimaryBlue : bgColor.withOpacity(1), size: 28),
                                ),
                              ),
                      ),
                    ),
                    Text(
                      c.displayName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildBrandCategoriesGrid() {
    final list = _brandCategories ?? [];
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('لا توجد تصنيفات براندات', style: TextStyle(color: Colors.grey)),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 12,
      ),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final b = list[i];
        final (w, h) = _brandIconBox(b);
        final radius = _brandIconRadius(b);
        final bgColor = colorFromHex(b.iconColor);
        final iconUrl = b.iconUrl ?? (b.iconPath != null && b.iconPath!.isNotEmpty
            ? '${Config.baseUrl.replaceAll(RegExp(r'/$'), '')}/uploads/${b.iconPath!.replaceFirst(RegExp(r'^\/+'), '')}'
            : '');
        return InkWell(
          onTap: () => _onBrandTap(b),
          borderRadius: BorderRadius.circular(radius),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: w,
                height: h,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: iconUrl.isEmpty
                    ? Icon(Icons.business, color: Colors.white, size: w * 0.5)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(radius),
                        child: Image.network(
                          iconUrl,
                          fit: BoxFit.cover,
                          width: w,
                          height: h,
                          errorBuilder: (_, __, ___) => Icon(Icons.business, color: Colors.white, size: w * 0.5),
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                b.displayName,
                style: const TextStyle(fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

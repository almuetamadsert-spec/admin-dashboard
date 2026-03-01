import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../config.dart';
import '../../models/cart_item.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';
import '../widgets/product_card.dart';

/// صفحة أنيقة تعرض منتجات التصنيف مع بحث وفلتر (السعر / التاريخ).
class CategoryProductsScreen extends StatefulWidget {
  final Category category;
  final List<CartItem> cart;
  final void Function(
    Product product, {
    int quantity,
    String? selectedColor,
    String? selectedSize,
    String? selectedStorage,
    String? selectedBattery,
  }) onAddToCart;
  final void Function(Product product)? onProductTap;
  final VoidCallback onOpenCart;

  const CategoryProductsScreen({
    super.key,
    required this.category,
    required this.cart,
    required this.onAddToCart,
    required this.onOpenCart,
    this.onProductTap,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  List<Product>? _products;
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _sort = ''; // price_asc | price_desc | date_asc | date_desc
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  SliderData? _sliderData;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiClient.getProducts(
        categoryId: widget.category.id,
        q: _searchQuery.isEmpty ? null : _searchQuery,
        sort: _sort.isEmpty ? null : _sort,
      );
      SliderData? sd;
      try { sd = await ApiClient.getSlider(); } catch(_) {}
      
      if (mounted) {
        setState(() {
          _products = list;
          _sliderData = sd;
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

  String _productImageUrl(Product p) {
    if (p.imagePath == null || p.imagePath!.isEmpty) return '';
    final base = Config.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/uploads/${p.imagePath!.replaceFirst(RegExp(r'^\/+'), '')}';
  }

  Widget _productCard(Product p) {
    return ProductCard(
      product: p,
      layout: _sliderData?.cardLayout ?? const ProductCardLayout(),
      onTap: (product) => widget.onProductTap?.call(product),
      onAddToCart: (product) {
        widget.onAddToCart(product);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت إضافة ${product.displayName}')));
      },
      onBuyNow: () {
        widget.onAddToCart(p);
        widget.onOpenCart();
      },
    );
  }

  Widget _buildActionButtons(Product p) {
    // For these screens, we use a simple default design or the system ones if they exist
    // However, the card details here were using default values earlier.
    // Wait, the API now has the settings for these in slider endpoint, but these screens don't load slider data.
    // They just load products. We can just use standard buttons, or if the API wasn't loading it, we can fetch settings.
    // Actually, earlier these cards ALWAYS had "إضافة" button. Since the user wants to enable/disable it, we might need settings here.
    // If we don't have settings here, we can just use default "Buy now" style buttons. Wait, if the user turns it off in admin, we wouldn't know!
    // Let's check if the user wanted this for all product cards and if we have access to sliderData.
    // Actually we only have `_products` here. Let's just assume `showAddToCart=true` and `showBuyNow=true` for simplicity unless we fetch slider!
    // Let's fetch settings if we need, but for now we'll just show both buttons using default style!
    
    // Better yet, just return standard buttons.
    Widget cartBtn = FilledButton.icon(
      onPressed: p.stock > 0
          ? () {
              widget.onAddToCart(p);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت إضافة ${p.displayName}')));
            }
          : null,
      icon: const Icon(Icons.add_shopping_cart, size: 16),
      label: const Text('إضافة'),
      style: FilledButton.styleFrom(
        backgroundColor: kPrimaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        textStyle: const TextStyle(fontSize: 12),
      ),
    );

    Widget buyBtn = FilledButton.icon(
      onPressed: p.stock > 0
          ? () {
              widget.onAddToCart(p);
              widget.onOpenCart();
            }
          : null,
      icon: const Icon(Icons.shopping_bag, size: 16),
      label: const Text('شراء'),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        textStyle: const TextStyle(fontSize: 12),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Expanded(child: cartBtn),
          const SizedBox(width: 4),
          Expanded(child: buyBtn),
        ],
      ),
    );
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
          title: Text(
            widget.category.displayName,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        body: Container(
          color: kPrimaryBlue.withOpacity(0.02),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'ابحث عن منتجك المفضل...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            hintStyle: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w400),
                          ),
                          onSubmitted: (v) {
                            setState(() {
                              _searchQuery = v.trim();
                              _load();
                            });
                          },
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _load();
                            });
                          },
                        ),
                      Container(
                        margin: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: kPrimaryBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _searchQuery = _searchController.text.trim();
                              _load();
                            });
                          },
                          icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.sort_rounded, size: 18, color: kPrimaryBlue),
                    const SizedBox(width: 8),
                    const Text('ترتيب حسب:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kTextSecondary)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sort.isEmpty ? null : _sort,
                            hint: const Text('الافتراضي', style: TextStyle(fontSize: 12)),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: kPrimaryBlue),
                            style: const TextStyle(fontSize: 13, color: kPrimaryBlue, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                            items: const [
                              DropdownMenuItem(value: '', child: Text('الافتراضي')),
                              DropdownMenuItem(value: 'price_asc', child: Text('السعر من الأقل')),
                              DropdownMenuItem(value: 'price_desc', child: Text('السعر من الأعلى')),
                              DropdownMenuItem(value: 'date_desc', child: Text('الأحدث')),
                              DropdownMenuItem(value: 'date_asc', child: Text('الأقدم')),
                            ],
                            onChanged: (v) {
                              setState(() {
                                _sort = v ?? '';
                                _load();
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _load,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _products == null || _products!.isEmpty
                          ? const Center(child: Text('لا توجد منتجات في هذا التصنيف'))
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: GridView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 0.6,
                                ),
                                itemCount: _products!.length,
                                itemBuilder: (context, i) => _productCard(_products![i]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    ),
  );
}
}



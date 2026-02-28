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
          leading: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: widget.onOpenCart,
              ),
              if (widget.cart.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text(
                      '${widget.cart.fold(0, (s, e) => s + e.quantity)}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          title: Text(widget.category.displayName, style: const TextStyle(fontSize: 18)),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'بحث بالاسم أو الكود...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (v) {
                        setState(() {
                          _searchQuery = v.trim();
                          _load();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () {
                      setState(() {
                        _searchQuery = _searchController.text.trim();
                        _load();
                      });
                    },
                    icon: const Icon(Icons.search),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('ترتيب:', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _sort.isEmpty ? null : _sort,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
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
    );
  }
}

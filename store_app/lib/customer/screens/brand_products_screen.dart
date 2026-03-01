import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../models/brand_category.dart';
import '../../models/cart_item.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';
import '../widgets/product_card.dart';

/// صفحة منتجات براند واحد (حسب حقل الشركة).
class BrandProductsScreen extends StatefulWidget {
  final BrandCategory brand;
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

  const BrandProductsScreen({
    super.key,
    required this.brand,
    required this.cart,
    required this.onAddToCart,
    required this.onOpenCart,
    this.onProductTap,
  });

  @override
  State<BrandProductsScreen> createState() => _BrandProductsScreenState();
}

class _BrandProductsScreenState extends State<BrandProductsScreen> {
  List<Product>? _products;
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _sort = '';
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
        company: widget.brand.nameAr,
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
            widget.brand.displayName,
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
                            hintText: 'البحث في منتجات البراند...',
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
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.6,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _products!.length,
                  itemBuilder: (context, i) => _productCard(_products![i]),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
}




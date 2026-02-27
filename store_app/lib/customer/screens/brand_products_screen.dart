import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../config.dart';
import '../../models/brand_category.dart';
import '../../models/cart_item.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';

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
      if (mounted) {
        setState(() {
          _products = list;
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
    final imageUrl = _productImageUrl(p);
    final hasDiscount = p.finalPrice < p.price;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(6),
      child: InkWell(
        onTap: () => widget.onProductTap?.call(p),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isEmpty
                      ? Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported, size: 40),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, size: 40),
                          ),
                        ),
                  if (hasDiscount)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('عرض', style: TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.company != null && p.company!.isNotEmpty)
                    Text(
                      p.company!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0, bottom: 4.0),
                    child: Text(
                      p.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${p.finalPrice.toStringAsFixed(0)} د.ل',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryBlue, fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      if (hasDiscount)
                        Text(
                          '${p.price.toStringAsFixed(0)} د.ل',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500, decoration: TextDecoration.lineThrough),
                        ),
                    ],
                  ),
                  _buildActionButtons(p),
                ],
              ),
            ),
          ],
        ),
      ),
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(widget.brand.displayName, style: const TextStyle(fontSize: 18)),
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
                        hintText: 'بحث...',
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
    );
  }
}

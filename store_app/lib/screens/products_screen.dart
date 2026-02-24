import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class ProductsScreen extends StatefulWidget {
  final List<CartItem> cart;
  final void Function(Product product, {int quantity}) onAddToCart;
  final VoidCallback onOpenCart;

  const ProductsScreen({
    super.key,
    required this.cart,
    required this.onAddToCart,
    required this.onOpenCart,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product>? _products;
  String? _error;
  bool _loading = true;

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
      final list = await ApiClient.getProducts();
      if (mounted) setState(() => _products = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _cartCount => widget.cart.fold(0, (s, e) => s + e.quantity);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المنتجات'),
          actions: [
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: widget.cart.isEmpty ? null : widget.onOpenCart,
                ),
                if (_cartCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: CircleAvatar(
                      radius: 10,
                      child: Text('$_cartCount', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: _loading
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
                    ? const Center(child: Text('لا توجد منتجات'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _products!.length,
                          itemBuilder: (context, i) {
                            final p = _products![i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(p.displayName),
                                subtitle: Text(
                                  '${p.finalPrice.toStringAsFixed(2)} د.ل',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                trailing: FilledButton.icon(
                                  onPressed: p.stock > 0
                                      ? () {
                                          widget.onAddToCart(p);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('تمت إضافة ${p.displayName}')),
                                          );
                                        }
                                      : null,
                                  icon: const Icon(Icons.add_shopping_cart, size: 20),
                                  label: const Text('إضافة'),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}

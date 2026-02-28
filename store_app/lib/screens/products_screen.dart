import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../customer/widgets/product_card.dart';

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
  SliderData? _sliderData;
  String? _error;
  bool _loading = true;
  late PageController _bannerPageController;
  int _bannerIndex = 0;

  @override
  void initState() {
    super.initState();
    _bannerPageController = PageController();
    _bannerPageController.addListener(() {
      if (!mounted) return;
      final page = _bannerPageController.page?.round() ?? 0;
      if (page != _bannerIndex) setState(() => _bannerIndex = page);
    });
    _load();
  }

  @override
  void dispose() {
    _bannerPageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiClient.getProducts();
      SliderData? sliderData;
      try {
        sliderData = await ApiClient.getSlider();
      } catch (_) {
        sliderData = SliderData(intervalSeconds: 5, slides: [], productLayout: 'grid_2');
      }
      if (mounted) {
        setState(() {
          _products = list;
          _sliderData = sliderData;
        });
        _startBannerTimer();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startBannerTimer() {
    Future.delayed(Duration(seconds: _sliderData?.intervalSeconds ?? 5), () {
      if (!mounted || _sliderData == null || _sliderData!.slides.length <= 1) return;
      final current = _bannerPageController.page?.round() ?? 0;
      final next = (current + 1) % _sliderData!.slides.length;
      _bannerPageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startBannerTimer();
    });
  }

  int get _cartCount => widget.cart.fold(0, (s, e) => s + e.quantity);

  String _productImageUrl(Product p) {
    if (p.imagePath == null || p.imagePath!.isEmpty) return '';
    final base = Config.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/uploads/${p.imagePath!.replaceFirst(RegExp(r'^\/+'), '')}';
  }

  String _sliderImageUrl(SliderSlide s) {
    if (s.imagePath.isNotEmpty) {
      final base = Config.baseUrl.replaceAll(RegExp(r'/$'), '');
      return '$base/uploads/${s.imagePath.replaceFirst(RegExp(r'^\/+'), '')}';
    }
    return s.imageUrl;
  }

  Widget _productCard(Product p) {
    return ProductCard(
      product: p,
      layout: _sliderData?.cardLayout ?? const ProductCardLayout(),
      onTap: (product) {
        // Handle tap if needed
      },
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

  // Remove unused helpers like _textAlignFrom, _cardColorFromHex, _buildActionButtons


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
                        child: CustomScrollView(
                          slivers: [
                            if (_sliderData != null && _sliderData!.slides.isNotEmpty)
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 160,
                                  child: Stack(
                                    children: [
                                      PageView.builder(
                                        controller: _bannerPageController,
                                        itemCount: _sliderData!.slides.length,
                                        onPageChanged: (i) => setState(() => _bannerIndex = i),
                                        itemBuilder: (context, i) {
                                          final s = _sliderData!.slides[i];
                                          final url = _sliderImageUrl(s);
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(s.borderRadius),
                                              child: url.isEmpty
                                                  ? Container(
                                                      color: Colors.grey.shade200,
                                                      child: const Icon(Icons.image_not_supported, size: 48),
                                                    )
                                                  : Image.network(
                                                      url,
                                                      fit: BoxFit.cover,
                                                      width: double.infinity,
                                                      errorBuilder: (_, __, ___) => Container(
                                                        color: Colors.grey.shade200,
                                                        child: const Icon(Icons.image_not_supported, size: 48),
                                                      ),
                                                    ),
                                            ),
                                          );
                                        },
                                      ),
                                      if (_sliderData!.slides.length > 1)
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom: 4,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: List.generate(
                                              _sliderData!.slides.length,
                                              (i) => Container(
                                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                                width: _bannerIndex == i ? 10 : 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: _bannerIndex == i
                                                      ? Theme.of(context).colorScheme.primary
                                                      : Colors.grey.shade400,
                                                  borderRadius: BorderRadius.circular(3),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            if (_sliderData != null && _sliderData!.slides.isNotEmpty)
                              const SliverToBoxAdapter(child: SizedBox(height: 12)),
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              sliver: _sliderData?.productLayout == 'slider'
                                  ? SliverToBoxAdapter(
                                      child: SizedBox(
                                        height: 280,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: _products!.length,
                                          itemBuilder: (context, i) => SizedBox(
                                            width: MediaQuery.of(context).size.width * 0.45,
                                            child: _productCard(_products![i]),
                                          ),
                                        ),
                                      ),
                                    )
                                  : SliverGrid.count(
                                      crossAxisCount: _sliderData?.productLayout == 'grid_3' ? 3 : 2,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 8,
                                      childAspectRatio: 0.6,
                                      children: _products!.map((p) => _productCard(p)).toList(),
                                    ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 24)),
                          ],
                        ),
                      ),
      ),
    );
  }
}

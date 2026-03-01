import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_client.dart';
import '../../config.dart';
import '../../models/cart_item.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';
import '../../utils/category_icons.dart';
import '../widgets/product_card.dart';

/// الواجهة الرئيسية للعميل حسب التصميم: هيدر (قائمة، شعار المعتمد، إشعارات)، موقع، بحث، سلايدر، تصنيفات، شبكة منتجات.
class HomeScreen extends StatefulWidget {
  final List<CartItem> cart;
  final void Function(Product product, {int quantity}) onAddToCart;
  final VoidCallback onOpenCart;
  final VoidCallback? onOpenMenu;
  final int notificationCount;
  final void Function(Product product)? onProductTap;
  final void Function(Category category)? onCategoryTap;
  final VoidCallback? onShowAllCategories;

  const HomeScreen({
    super.key,
    required this.cart,
    required this.onAddToCart,
    required this.onOpenCart,
    this.onOpenMenu,
    this.notificationCount = 0,
    this.onProductTap,
    this.onCategoryTap,
    this.onShowAllCategories,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Product>? _products;
  List<Category>? _categories;
  List<HomeSection>? _homeSections; // NEW
  SliderData? _sliderData;
  String? _error;
  bool _loading = true;
  late PageController _bannerPageController;
  int _bannerIndex = 0;
  String _deliveryCity = '—';
  String? _customerName;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bannerPageController = PageController();
    _loadSavedPrefs();
    _bannerPageController.addListener(() {
      if (!mounted) return;
      final page = _bannerPageController.page?.round() ?? 0;
      if (page != _bannerIndex) setState(() => _bannerIndex = page);
    });
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshSilent());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _bannerPageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshSilent();
  }

  Future<void> _loadSavedPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final city = prefs.getString('delivery_city_name');
      final name = prefs.getString('customer_name');
      if (mounted) {
        setState(() {
          _deliveryCity = city?.trim().isNotEmpty == true ? city! : '—';
          _customerName = name?.trim().isNotEmpty == true ? name : null;
        });
      }
    } catch (_) {}
  }

  /// ترحيب حسب الوقت واسم العميل
  String get _greeting {
    final hour = DateTime.now().hour;
    final name = _customerName?.trim().isNotEmpty == true ? _customerName! : null;
    final prefix = hour < 12 ? 'صباح الخير' : 'مرحباً';
    return name != null ? '$prefix $name' : prefix;
  }

  /// تحديث صامت كل 15 ثانية وعند العودة للتطبيق — لتطبيق تعديلات اللوحة فوراً
  Future<void> _refreshSilent() async {
    if (!mounted) return;
    await _loadSavedPrefs();
    if (!mounted) return;
    try {
      final list = await ApiClient.getProducts();
      List<Category> categories = [];
      try {
        categories = await ApiClient.getCategories();
      } catch (_) {}
      SliderData? sliderData;
      try {
        sliderData = await ApiClient.getSlider();
      } catch (_) {
        sliderData = _sliderData ?? SliderData(intervalSeconds: 5, slides: [], productLayout: 'grid_2');
      }
      List<HomeSection>? homeSections;
      try {
        homeSections = await ApiClient.getHomeData();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _products = list;
          _categories = categories;
          _sliderData = sliderData;
          _homeSections = homeSections;
        });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiClient.getProducts();
      List<Category> categories = [];
      try {
        categories = await ApiClient.getCategories();
      } catch (_) {}
      SliderData? sliderData;
      try {
        sliderData = await ApiClient.getSlider();
      } catch (_) {
        sliderData = SliderData(intervalSeconds: 5, slides: [], productLayout: 'grid_2');
      }
      List<HomeSection>? homeSections;
      try {
        homeSections = await ApiClient.getHomeData();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _products = list;
          _categories = categories;
          _sliderData = sliderData;
          _homeSections = homeSections;
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

  Widget _buildHeader() {
    final logo = _sliderData?.logoSettings;
    final hasLogo = logo != null && logo.url.isNotEmpty;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: Menu
                  InkWell(
                    onTap: widget.onOpenMenu,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.grid_view_rounded, color: Colors.black87, size: 24),
                    ),
                  ),

                  // Center: Logo or Text
                  if (hasLogo)
                    Image.network(
                      logo.url,
                      height: 40 * (logo.size / 100),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text(
                        'المعتمد',
                        style: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    )
                  else
                    const Text(
                      'المعتمد',
                      style: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w900),
                    ),

                  // Right: Cart
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      InkWell(
                        onTap: widget.onOpenCart,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.shopping_bag_outlined, color: Colors.black87, size: 24),
                        ),
                      ),
                      if (widget.cart.isNotEmpty)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: kDanger,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              '${widget.cart.fold(0, (s, e) => s + e.quantity)}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                     ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Location / Greeting row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kPrimaryBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on_rounded, color: kPrimaryBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'التوصيل إلى $_deliveryCity',
                          style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
          border: Border.all(color: Colors.grey.shade100, width: 1),
        ),
        child: TextField(
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: 'عن ماذا تبحث اليوم؟',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w500),
            prefixIcon: const Icon(Icons.search_rounded, color: kPrimaryBlue, size: 24),
            suffixIcon: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kPrimaryBlue, Color(0xFF42C2F7)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
              ),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildSlider() {
    if (_sliderData == null || _sliderData!.slides.isEmpty) {
      return Container(
        height: 160,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: context.colors.primary.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'عروض الصيف التقنية',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'خصم يصل إلى 50% على الإكسسوارات',
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: kPrimaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('تسوق الآن'),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(s.borderRadius),
                  child: url.isEmpty
                      ? Container(
                            color: context.colors.primary.withOpacity(0.5),
                          child: const Center(child: Icon(Icons.image, color: Colors.white54, size: 48)),
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            color: context.colors.primary.withOpacity(0.5),
                            child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48)),
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
              bottom: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _sliderData!.slides.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _bannerIndex == i ? 10 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _bannerIndex == i ? kPrimaryBlue : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _categoryIconUrl(Category c) {
    if (c.iconPath == null || c.iconPath!.isEmpty) return '';
    final base = Config.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/uploads/${c.iconPath!.replaceFirst(RegExp(r'^\/+'), '')}';
  }

  Widget _buildCategories() {
    final list = _categories ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'التصنيفات',
                style: context.textTheme.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: widget.onShowAllCategories,
                child: const Text(
                  'عرض الكل',
                  style: TextStyle(color: kPrimaryBlue, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 88,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: InkWell(
                  onTap: () => widget.onCategoryTap?.call(c),
                  borderRadius: BorderRadius.circular(isCircle ? 26 : radius),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: bgColor,
                          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
                          borderRadius: isCircle ? null : BorderRadius.circular(radius.clamp(0.0, 16)),
                          border: isBgTransparent ? Border.all(color: context.isDark ? kDarkBorder : Colors.grey.shade300, width: 1) : null,
                        ),
                        child: iconUrl.isEmpty
                            ? Icon(categoryIcon(c), color: symbolColor, size: 26)
                            : ClipRRect(
                                borderRadius: isCircle ? BorderRadius.circular(26) : BorderRadius.circular(radius.clamp(0.0, 16)),
                                child: Image.network(
                                  iconUrl,
                                  fit: BoxFit.cover,
                                  width: 52,
                                  height: 52,
                                  errorBuilder: (_, __, ___) => Icon(categoryIcon(c), color: symbolColor, size: 26),
                                ),
                              ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.displayName,
                        style: context.textTheme.bodySmall?.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _cardColorFromHex(String hex) {
    if (hex.isEmpty) return Colors.white;
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    final n = int.tryParse(h, radix: 16);
    if (n == null) return Colors.white;
    return Color(n);
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

  // Remove _textAlignFrom, _cardColorFromHex, _buildActionButtons if unused


  Widget _buildSection(HomeSection section) {
    if (section.products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                section.displayName,
                style: context.textTheme.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => _AllProductsScreen(
                        title: section.displayName,
                        products: section.products,
                        onProductTap: widget.onProductTap,
                        onAddToCart: widget.onAddToCart,
                        onBuyNow: (p) {
                          widget.onAddToCart(p);
                          widget.onOpenCart();
                        },
                        sliderData: _sliderData,
                      ),
                    ),
                  );
                },
                child: const Text(
                  'عرض الكل',
                  style: TextStyle(color: kPrimaryBlue, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        if (section.sectionType == 'slider' || section.sectionType == 'list')
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: section.products.length,
              itemBuilder: (context, i) => SizedBox(
                width: MediaQuery.of(context).size.width * 0.45,
                child: _productCard(section.products[i]),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.62,
            ),
            itemCount: section.products.length,
            itemBuilder: (context, i) => _productCard(section.products[i]),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildProductGrid() {
    final sections = _homeSections ?? [];
    if (sections.isEmpty) {
      if (_products == null || _products!.isEmpty) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text('لا توجد أقسام أو منتجات', style: context.textTheme.bodyMedium)),
          ),
        );
      }
      // Fallback to default grid if no sections defined
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        sliver: SliverGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.62,
          children: _products!.map((p) => _productCard(p)).toList(),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildSection(sections[index]),
        childCount: sections.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildSlider()),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: _buildCategories()),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
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
                ),
              )
            else
              _buildProductGrid(),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

class _AllProductsScreen extends StatelessWidget {
  final String title;
  final List<Product> products;
  final void Function(Product)? onProductTap;
  final void Function(Product) onAddToCart;
  final void Function(Product) onBuyNow;
  final SliderData? sliderData;

  const _AllProductsScreen({
    required this.title,
    required this.products,
    this.onProductTap,
    required this.onAddToCart,
    required this.onBuyNow,
    this.sliderData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: false, // Title on the right (with RTL support)
      ),
      backgroundColor: const Color(0xFFF5F5F7),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: products.isEmpty
            ? const Center(child: Text('لا توجد منتجات'))
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.62,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final p = products[index];
                  return ProductCard(
                    product: p,
                    layout: sliderData?.cardLayout ?? const ProductCardLayout(),
                    onTap: (product) => onProductTap?.call(product),
                    onAddToCart: (product) {
                      onAddToCart(product);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت إضافة ${product.displayName}')));
                    },
                    onBuyNow: () => onBuyNow(p),
                  );
                },
              ),
      ),
    );
  }
}

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
      if (mounted) {
        setState(() {
          _products = list;
          _categories = categories;
          _sliderData = sliderData;
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
      if (mounted) {
        setState(() {
          _products = list;
          _categories = categories;
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onOpenMenu,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                _greeting,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'المعتمد',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kGold,
                shadows: [
Shadow(color: kSilver.withOpacity(0.6), offset: const Offset(0, 1), blurRadius: 2),
                ],
              ),
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {},
              ),
              if (widget.notificationCount > 0)
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
                      widget.notificationCount > 9 ? '9+' : '${widget.notificationCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocation() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            'العنوان ',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          Text(
            _deliveryCity,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.grey.shade600),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(22),
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'ابحث عن منتجك المفضل...',
            hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade600, size: 22),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          color: kBannerPurple.withOpacity(0.3),
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
                            color: kBannerPurple.withOpacity(0.5),
                          child: const Center(child: Icon(Icons.image, color: Colors.white54, size: 48)),
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            color: kBannerPurple.withOpacity(0.5),
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
              const Text(
                'التصنيفات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: widget.onShowAllCategories,
                child: Text(
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
                          border: isBgTransparent ? Border.all(color: Colors.grey.shade300, width: 1) : null,
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
                        style: const TextStyle(fontSize: 12),
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

  TextAlign _textAlignFrom(String align) {
    switch (align) {
      case 'left': return TextAlign.left;
      case 'center': return TextAlign.center;
      case 'right': return TextAlign.right;
      default: return TextAlign.right;
    }
  }

  Widget _productCard(Product p) {
    final imageUrl = _productImageUrl(p);
    final hasDiscount = p.finalPrice < p.price;
    final card = _sliderData?.cardLayout ?? const ProductCardLayout();
    final cardColor = _cardColorFromHex(card.bgColor);
    final radius = card.borderRadius;
    final brandLeft = card.brandPosition == 'left';
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1.5,
      shadowColor: Colors.black12,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      margin: const EdgeInsets.all(6),
      child: InkWell(
        onTap: () {
          if (widget.onProductTap != null) widget.onProductTap!(p);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isEmpty
                      ? Container(color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported, size: 40))
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image, size: 40)),
                        ),
                  if (hasDiscount)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
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
                        style: TextStyle(fontWeight: FontWeight.bold, color: _cardColorFromHex(card.addBtnColor.isEmpty ? '#06A3E7' : card.addBtnColor), fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      if (hasDiscount)
                        Text(
                          '${p.price.toStringAsFixed(0)} د.ل',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500, decoration: TextDecoration.lineThrough),
                        ),
                    ],
                  ),
                  if (card.showAddToCart || card.showBuyNow) _buildActionButtons(p, card),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Product p, ProductCardLayout card) {
    if (!card.showAddToCart && !card.showBuyNow) return const SizedBox.shrink();

    final btnColor = _cardColorFromHex(card.addBtnColor.isEmpty ? '#06A3E7' : card.addBtnColor);
    final shape = card.addBtnStyle == 'sharp'
        ? RoundedRectangleBorder(borderRadius: BorderRadius.zero)
        : card.addBtnStyle == 'full_rounded'
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    final padding = card.addBtnStyle == 'small_rounded' ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6) : const EdgeInsets.symmetric(horizontal: 16, vertical: 8);

    final bool hasBoth = card.showAddToCart && card.showBuyNow;

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
        backgroundColor: btnColor,
        foregroundColor: Colors.white,
        padding: padding,
        minimumSize: Size.zero,
        shape: shape,
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
        padding: padding,
        minimumSize: Size.zero,
        shape: shape,
        textStyle: const TextStyle(fontSize: 12),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          if (card.showAddToCart) Expanded(child: cartBtn),
          if (hasBoth) const SizedBox(width: 4),
          if (card.showBuyNow) Expanded(child: buyBtn),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_products == null || _products!.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('لا توجد منتجات')),
        ),
      );
    }
    final layout = _sliderData?.productLayout ?? 'grid_2';
    if (layout == 'slider') {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _products!.length,
            itemBuilder: (context, i) => SizedBox(
              width: MediaQuery.of(context).size.width * 0.45,
              child: _productCard(_products![i]),
            ),
          ),
        ),
      );
    }
    final crossCount = layout == 'grid_3' ? 3 : 2;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      sliver: SliverGrid.count(
        crossAxisCount: crossCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.62,
        children: _products!.map((p) => _productCard(p)).toList(),
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
            SliverToBoxAdapter(child: _buildLocation()),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildSlider()),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: _buildCategories()),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'المنتجات الشائعة',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Icon(Icons.view_agenda_outlined, size: 20, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
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

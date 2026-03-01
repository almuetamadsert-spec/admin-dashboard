import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../screens/cart_screen.dart';
import '../theme/app_theme.dart';
import 'screens/all_categories_screen.dart';
import 'screens/category_products_screen.dart';
import 'screens/home_screen.dart';
import 'screens/account_screen.dart';
import 'screens/my_orders_screen.dart';
import 'screens/product_detail_screen.dart';

/// واجهة العميل — شريط سفلي (الرئيسية، التصنيفات، السلة، طلباتي، حسابي) ودرج جانبي.
class CustomerShell extends StatefulWidget {
  final ValueChanged<bool>? onDarkModeChanged;

  const CustomerShell({super.key, this.onDarkModeChanged});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  final List<CartItem> _cart = [];
  int _selectedIndex = 0;

  void _addToCart(
    Product product, {
    int quantity = 1,
    String? selectedColor,
    String? selectedSize,
    String? selectedStorage,
    String? selectedBattery,
  }) {
    setState(() {
      final i = _cart.indexWhere((e) =>
          e.product.id == product.id &&
          e.selectedColor == selectedColor &&
          e.selectedSize == selectedSize &&
          e.selectedStorage == selectedStorage &&
          e.selectedBattery == selectedBattery);
          
      if (i >= 0) {
        _cart[i].quantity += quantity;
      } else {
        _cart.add(CartItem(
          product: product,
          quantity: quantity,
          selectedColor: selectedColor,
          selectedSize: selectedSize,
          selectedStorage: selectedStorage,
          selectedBattery: selectedBattery,
        ));
      }
    });
  }

  void _updateQuantity(CartItem item, int delta) {
    setState(() {
      item.quantity += delta;
      if (item.quantity <= 0) _cart.remove(item);
    });
  }

  void _removeFromCart(CartItem item) {
    setState(() => _cart.remove(item));
  }

  void _clearCart() {
    setState(() => _cart.clear());
  }

  void _openCart() {
    setState(() => _selectedIndex = 2);
  }

  int get _cartCount => _cart.fold(0, (s, e) => s + e.quantity);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        drawer: Drawer(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [kPrimaryBlue, Color(0xFF42C2F7)],
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.store_mall_directory_rounded, color: Colors.white, size: 30),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'المعتمد',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                      Text(
                        'بوابتك لعالم التسوق الفاخر',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('الرئيسية'),
                  onTap: () {
                    setState(() => _selectedIndex = 0);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.grid_view),
                  title: const Text('التصنيفات'),
                  onTap: () {
                    setState(() => _selectedIndex = 1);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.shopping_cart),
                  title: Text('السلة${_cartCount > 0 ? ' ($_cartCount)' : ''}'),
                  onTap: () {
                    Navigator.pop(context);
                    _openCart();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: const Text('طلباتي'),
                  onTap: () {
                    setState(() => _selectedIndex = 3);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('حسابي'),
                  onTap: () {
                    setState(() => _selectedIndex = 4);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            HomeScreen(
              cart: _cart,
              onAddToCart: _addToCart,
              onOpenCart: _openCart,
              onOpenMenu: () => Scaffold.of(context).openDrawer(),
              notificationCount: 0,
              onProductTap: (p) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProductDetailScreen(
                      product: p,
                      cart: _cart,
                      onAddToCart: _addToCart,
                      onBuyNow: _openCart,
                    ),
                  ),
                );
              },
              onCategoryTap: (cat) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CategoryProductsScreen(
                      category: cat,
                      cart: _cart,
                      onAddToCart: _addToCart,
                      onOpenCart: _openCart,
                      onProductTap: (p) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ProductDetailScreen(
                              product: p,
                              cart: _cart,
                              onAddToCart: _addToCart,
                              onBuyNow: _openCart,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
              onShowAllCategories: () {
                setState(() => _selectedIndex = 1);
              },
            ),
            AllCategoriesScreen(
              cart: _cart,
              onAddToCart: _addToCart,
              onOpenCart: _openCart,
            ),
            CartScreen(
              cart: _cart,
              onUpdateQuantity: _updateQuantity,
              onRemove: _removeFromCart,
              onOrderSent: _clearCart,
              showAppBar: true,
            ),
            const MyOrdersScreen(),
            AccountScreen(onDarkModeChanged: widget.onDarkModeChanged),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (i) {
              setState(() => _selectedIndex = i);
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: kPrimaryBlue,
            unselectedItemColor: Colors.grey.shade400,
            backgroundColor: Colors.white.withOpacity(0.95),
            elevation: 0,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, fontFamily: 'Tajawal'),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, fontFamily: 'Tajawal'),
            items: [
              const BottomNavigationBarItem(icon: Icon(Icons.home_outlined, size: 24), activeIcon: Icon(Icons.home_rounded, size: 24), label: 'الرئيسية'),
              const BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded, size: 24), activeIcon: Icon(Icons.grid_view_rounded, size: 24), label: 'تصنيفات'),
              BottomNavigationBarItem(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 24),
                    if (_cartCount > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: kDanger, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            _cartCount > 9 ? '9+' : '$_cartCount',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                activeIcon: const Icon(Icons.shopping_bag, size: 24),
                label: 'السلة',
              ),
              const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded, size: 24), activeIcon: Icon(Icons.receipt_long_rounded, size: 24), label: 'طلباتي'),
              const BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded, size: 24), activeIcon: Icon(Icons.person_rounded, size: 24), label: 'حسابي'),
            ],
          ),
        ),
      ),
    );
  }

}

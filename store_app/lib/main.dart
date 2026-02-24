import 'package:flutter/material.dart';

import 'models/cart_item.dart';
import 'models/product.dart';
import 'screens/cart_screen.dart';
import 'screens/products_screen.dart';

void main() {
  runApp(const StoreApp());
}

class StoreApp extends StatelessWidget {
  const StoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'متجر',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const StoreHome(),
    );
  }
}

class StoreHome extends StatefulWidget {
  const StoreHome({super.key});

  @override
  State<StoreHome> createState() => _StoreHomeState();
}

class _StoreHomeState extends State<StoreHome> {
  final List<CartItem> _cart = [];

  void _addToCart(Product product, {int quantity = 1}) {
    setState(() {
      final i = _cart.indexWhere((e) => e.product.id == product.id);
      if (i >= 0) {
        _cart[i].quantity += quantity;
      } else {
        _cart.add(CartItem(product: product, quantity: quantity));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ProductsScreen(
        cart: _cart,
        onAddToCart: _addToCart,
        onOpenCart: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CartScreen(
                cart: _cart,
                onUpdateQuantity: _updateQuantity,
                onRemove: _removeFromCart,
                onOrderSent: _clearCart,
              ),
            ),
          );
        },
      ),
    );
  }
}

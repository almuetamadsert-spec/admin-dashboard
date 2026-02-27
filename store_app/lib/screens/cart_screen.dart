import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/cart_item.dart';
import '../models/cart_item.dart';
import '../theme/app_theme.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  final List<CartItem> cart;
  final void Function(CartItem item, int delta) onUpdateQuantity;
  final void Function(CartItem item) onRemove;
  final VoidCallback onOrderSent;

  const CartScreen({
    super.key,
    required this.cart,
    required this.onUpdateQuantity,
    required this.onRemove,
    required this.onOrderSent,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  double get _total =>
      widget.cart.fold(0, (s, e) => s + e.subtotal);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('السلة وإرسال الطلب')),
        body: widget.cart.isEmpty
            ? const Center(child: Text('السلة فارغة'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('محتوى السلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...widget.cart.map((item) => Card(
                          child: ListTile(
                            title: Text(item.product.displayName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.optionsString.isNotEmpty)
                                  Text(
                                    item.optionsString,
                                    style: TextStyle(color: kPrimaryBlue, fontSize: 13),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item.quantity} × ${item.product.finalPrice.toStringAsFixed(2)} = ${item.subtotal.toStringAsFixed(2)} د.ل',
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () {
                                    widget.onUpdateQuantity(item, -1);
                                    setState(() {});
                                    if (widget.cart.isEmpty && mounted) Navigator.of(context).pop();
                                  },
                                ),
                                Text('${item.quantity}'),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () {
                                    widget.onUpdateQuantity(item, 1);
                                    setState(() {});
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () {
                                    widget.onRemove(item);
                                    setState(() {});
                                    if (widget.cart.isEmpty && mounted) Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            ),
                          ),
                        )),
                    const SizedBox(height: 16),
                    Text(
                      'المجموع: ${_total.toStringAsFixed(2)} د.ل',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryBlue),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: widget.cart.isEmpty
            ? null
            : SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -2))],
                  ),
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => CheckoutScreen(
                            cart: widget.cart,
                            onOrderSent: widget.onOrderSent,
                          ),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: kPrimaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('إتمام الطلب', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
      ),
    );
  }
}

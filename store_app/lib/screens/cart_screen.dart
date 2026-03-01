import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../customer/widgets/custom_illustration.dart';
import '../models/cart_item.dart';
import '../theme/app_theme.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  final List<CartItem> cart;
  final void Function(CartItem item, int delta) onUpdateQuantity;
  final void Function(CartItem item) onRemove;
  final VoidCallback onOrderSent;
  final bool showAppBar;

  const CartScreen({
    super.key,
    required this.cart,
    required this.onUpdateQuantity,
    required this.onRemove,
    required this.onOrderSent,
    this.showAppBar = true,
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
        appBar: widget.showAppBar
            ? AppBar(
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
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: const Text(
                  'السلة',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                ),
              )
            : null,
        body: widget.cart.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CustomIllustration(
                        type: IllustrationType.emptyCart,
                        size: 200,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'سلتك فارغة حالياً',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'ابدأ بإضافة منتجاتك المفضلة للمتابعة واكتشف عالم المعتمد المذهل!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: kTextSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(
                            colors: [kPrimaryBlue, Color(0xFF42C2F7)],
                          ),
                          boxShadow: [
                            BoxShadow(color: kPrimaryBlue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                          label: const Text('بدء التسوق', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.showAppBar) const SizedBox(height: 16),
                    const Text('محتوى السلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ...widget.cart.map((item) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                // Item Image placeholder or real image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 70,
                                    height: 70,
                                    color: context.isDark ? kDarkSurface : Colors.grey.shade100,
                                    child: item.product.imagePath != null && item.product.imagePath!.isNotEmpty
                                        ? Image.network(
                                            '${Config.baseUrl.replaceAll(RegExp(r'/$'), '')}/uploads/${item.product.imagePath!.replaceFirst(RegExp(r'^\/+'), '')}',
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
                                          )
                                        : const Icon(Icons.image_outlined, color: Colors.grey),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.displayName,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      if (item.optionsString.isNotEmpty)
                                        Text(
                                          item.optionsString,
                                          style: TextStyle(color: kPrimaryBlue, fontSize: 12),
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item.product.finalPrice.toStringAsFixed(0)} د.ل',
                                        style: TextStyle(
                                          color: context.colors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                                          onPressed: () => widget.onUpdateQuantity(item, -1),
                                        ),
                                        Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, size: 20),
                                          onPressed: () => widget.onUpdateQuantity(item, 1),
                                        ),
                                      ],
                                    ),
                                    TextButton.icon(
                                      onPressed: () => widget.onRemove(item),
                                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                      label: const Text('حذف', style: TextStyle(color: Colors.red, fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kPrimaryBlue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('إجمالي الطلب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(
                            '${_total.toStringAsFixed(0)} د.ل',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryBlue),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: widget.cart.isEmpty
            ? null
            : SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [kPrimaryBlue, Color(0xFF42C2F7)],
                      ),
                      boxShadow: [
                        BoxShadow(color: kPrimaryBlue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: ElevatedButton(
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
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('إتمام الطلب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

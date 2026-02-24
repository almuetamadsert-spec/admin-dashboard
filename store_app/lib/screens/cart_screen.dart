import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/cart_item.dart';
import '../models/city.dart';

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
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  List<City> _cities = [];
  int? _selectedCityId;
  bool _loadingCities = true;
  bool _citiesError = false; // فشل تحميل المدن
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    setState(() => _citiesError = false);
    try {
      final list = await ApiClient.getCities();
      if (mounted) {
        setState(() {
          _cities = list;
          _loadingCities = false;
          if (_cities.isNotEmpty && _selectedCityId == null) {
            _selectedCityId = _cities.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingCities = false;
          _citiesError = true;
        });
      }
    }
  }

  double get _total =>
      widget.cart.fold(0, (s, e) => s + e.subtotal);

  Future<void> _submitOrder() async {
    if (widget.cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف منتجات للسلة أولاً')),
      );
      return;
    }
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل اسم العميل')),
      );
      return;
    }
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رقم الهاتف')),
      );
      return;
    }
    if (_selectedCityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر المدينة')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final items = widget.cart
          .map((e) => {
                'product_id': e.product.id,
                'quantity': e.quantity,
              })
          .toList();
      final result = await ApiClient.postOrder(
        cityId: _selectedCityId!,
        customerName: name,
        customerPhone: phone,
        customerAddress: _addressController.text.trim(),
        items: items,
      );
      if (!mounted) return;
      widget.onOrderSent();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إرسال الطلب بنجاح — رقم: ${result['order_number'] ?? ''}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

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
                    const Text('العناصر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...widget.cart.map((item) => Card(
                          child: ListTile(
                            title: Text(item.product.displayName),
                            subtitle: Text(
                              '${item.quantity} × ${item.product.finalPrice.toStringAsFixed(2)} = ${item.subtotal.toStringAsFixed(2)} د.ل',
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
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    const Text('بيانات العميل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم العميل *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'الهاتف *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    if (_loadingCities)
                      const LinearProgressIndicator()
                    else if (_citiesError)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'فشل تحميل المدن. تحقق من الاتصال والمفتاح.',
                            style: TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _loadCities,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة تحميل المدن'),
                          ),
                        ],
                      )
                    else if (_cities.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'لا توجد مدن في القائمة.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'أضف مدناً من لوحة التحكم: الدخول → مدن التوصيل → إضافة مدينة (الاسم ورسوم التوصيل).',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _loadCities,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('إعادة تحميل'),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<int>(
                        value: _selectedCityId,
                        decoration: const InputDecoration(
                          labelText: 'المدينة *',
                          border: OutlineInputBorder(),
                        ),
                        items: _cities
                            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedCityId = v),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'العنوان',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _sending ? null : _submitOrder,
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(_sending ? 'جاري الإرسال...' : 'إرسال الطلب'),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

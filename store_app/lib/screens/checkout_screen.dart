import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/cart_item.dart';
import '../models/city.dart';
import '../theme/app_theme.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> cart;
  final VoidCallback onOrderSent;

  const CheckoutScreen({
    super.key,
    required this.cart,
    required this.onOrderSent,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phoneAltController = TextEditingController();
  final _addressController = TextEditingController();
  List<City> _cities = [];
  int? _selectedCityId;
  bool _loadingCities = true;
  bool _citiesError = false;
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

  double get _total => widget.cart.fold(0, (s, e) => s + e.subtotal);

  Future<void> _submitOrder() async {
    if (widget.cart.isEmpty) return;
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final phoneAlt = _phoneAltController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال اسم العميل')));
      return;
    }
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال رقم الهاتف')));
      return;
    }
    if (_selectedCityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار المدينة')));
      return;
    }

    setState(() => _sending = true);
    try {
      final items = widget.cart
          .map((e) => {
                'product_id': e.product.id,
                'quantity': e.quantity,
                'options': e.optionsString,
              })
          .toList();
      
      final result = await ApiClient.postOrder(
        cityId: _selectedCityId!,
        customerName: name,
        customerPhone: phone,
        customerPhoneAlt: phoneAlt,
        customerAddress: address,
        items: items,
      );
      
      if (!mounted) return;
      
      String cityName = '';
      for (final c in _cities) {
        if (c.id == _selectedCityId) { cityName = c.name; break; }
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('customer_name', name);
        await prefs.setString('customer_phone', phone);
        await prefs.setString('customer_address', address);
        if (cityName.isNotEmpty) await prefs.setString('delivery_city_name', cityName);
      } catch (_) {}
      
      final cartForSuccess = List<CartItem>.from(widget.cart);
      final double totalAmount = _total;
      final String orderNumber = result['order_number']?.toString() ?? 'N/A';
      
      widget.onOrderSent(); // This clears the main cart

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => OrderSuccessScreen(
            orderNumber: orderNumber,
            totalAmount: totalAmount,
            cartItems: cartForSuccess,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _phoneAltController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('بيانات العميل'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إتمام الطلب', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
              const SizedBox(height: 8),
              const Text('الرجاء تعبئة بياناتك بدقة لضمان سرعة التوصيل', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'الاسم الكامل *',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'رقم الهاتف *',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneAltController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'رقم هاتف آخر (اختياري)',
                        prefixIcon: const Icon(Icons.phone_android_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_loadingCities)
                      const LinearProgressIndicator()
                    else if (_citiesError)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('فشل تحميل المدن', style: TextStyle(color: Colors.red)),
                          OutlinedButton.icon(
                            onPressed: _loadCities,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة تحميل'),
                          ),
                        ],
                      )
                    else if (_cities.isEmpty)
                      const Text('لا توجد مدن في القائمة.')
                    else
                      DropdownButtonFormField<int>(
                        value: _selectedCityId,
                        decoration: InputDecoration(
                          labelText: 'المدينة *',
                          prefixIcon: const Icon(Icons.location_city_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: _cities.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                        onChanged: (v) => setState(() => _selectedCityId = v),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'الحي / العنوان بالتفصيل *',
                        prefixIcon: const Icon(Icons.home_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _sending ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('رجوع', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _sending ? null : _submitOrder,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: kPrimaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _sending
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('إتمام الطلب', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_client.dart';
import '../../config.dart';
import '../../models/my_order.dart';
import '../../theme/app_theme.dart';
import '../widgets/custom_illustration.dart';
import 'order_tracking_screen.dart';

/// شاشة طلباتي — قائمة الطلبات القديمة والحالية.
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  List<MyOrder>? _orders;
  bool _loading = true;
  String? _error;
  String? _phone;

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
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('customer_phone')?.trim().replaceAll(RegExp(r'\s+'), '') ?? '';
      if (phone.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _orders = [];
            _error = 'أرسل طلباً أولاً من السلة لرؤية طلباتك هنا (يُحفظ رقم هاتفك محلياً).';
          });
        }
        return;
      }
      _phone = phone;
      final list = await ApiClient.getMyOrders(phone);
      if (mounted) {
        setState(() {
          _orders = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  String _imageUrl(MyOrder order) {
    final path = order.firstImagePath;
    if (path == null || path.isEmpty) return '';
    final base = Config.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/uploads/${path.replaceFirst(RegExp(r'^\/+'), '')}';
  }

  String _dateText(MyOrder order) {
    final d = order.createdAt;
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending': return 'قيد الانتظار';
      case 'confirmed': return 'مؤكد';
      case 'shipped': return 'تم الشحن';
      case 'delivered': return 'تم التوصيل';
      case 'cancelled': return 'ملغي';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
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
            'طلباتي',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
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
                : _orders == null || _orders!.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CustomIllustration(
                                type: IllustrationType.emptyOrders,
                                size: 240,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'سجل طلباتك فارغ',
                                style: context.textTheme.titleLarge?.copyWith(
                                  fontSize: 22,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'لم نجد أي طلبات مسجلة بهذا الرقم. ابدأ رحلة التسوق اليوم واستمتع بتجربة فريدة مع المعتمد.',
                                textAlign: TextAlign.center,
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: context.isDark ? kDarkTextSecondary : kTextSecondary,
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 40),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    backgroundColor: kPrimaryBlue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'اكتشف المنتجات',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          itemCount: _orders!.length,
                          itemBuilder: (context, i) {
                            final order = _orders![i];
                            final imageUrl = _imageUrl(order);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade100),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => OrderTrackingScreen(order: order),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.grey.shade100),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: imageUrl.isEmpty
                                            ? const Icon(Icons.inventory_2_rounded, size: 30, color: Colors.grey)
                                            : Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
                                              ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'الطلب #${order.orderNumber}',
                                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, height: 1.2),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _dateText(order),
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: kPrimaryBlue.withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                _statusLabel(order.status),
                                                style: const TextStyle(fontSize: 11, color: kPrimaryBlue, fontWeight: FontWeight.w900),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${order.totalAmount.toStringAsFixed(0)}',
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: kPrimaryBlue),
                                          ),
                                          const Text(
                                            'د.ل',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kPrimaryBlue),
                                          ),
                                          const SizedBox(height: 12),
                                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                                        ],
                                      ),
                                    ],
                                  ),
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

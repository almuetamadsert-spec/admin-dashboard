import 'package:flutter/material.dart';

import '../../models/my_order.dart';
import '../../theme/app_theme.dart';

/// تتبع الطلب — تم استلام طلبك، قيد التنفيذ، سيتم التواصل معك بعد قليل.
class OrderTrackingScreen extends StatefulWidget {
  final MyOrder order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  /// هل مرّ 3 ثوانٍ على قبول التاجر للطلب؟
  bool _contactSoonActive = false;

  @override
  void initState() {
    super.initState();
    _checkContactSoon();
  }

  void _checkContactSoon() {
    if (!widget.order.isAccepted || widget.order.acceptedAt == null) return;
    final now = DateTime.now();
    final accepted = widget.order.acceptedAt!;
    if (now.difference(accepted).inSeconds >= 3) {
      if (mounted) setState(() => _contactSoonActive = true);
      return;
    }
    final remaining = 3 - now.difference(accepted).inSeconds;
    Future.delayed(Duration(seconds: remaining.clamp(1, 10)), () {
      if (mounted) setState(() => _contactSoonActive = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final step1Done = true;
    final step2Done = order.isAccepted;
    final step3Done = order.isAccepted && _contactSoonActive;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: context.colors.surfaceContainerLowest,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: context.theme.scaffoldBackgroundColor,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.colors.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'تتبع الطلب',
            style: context.textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // الهيدر - تفاصيل الطلب
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.theme.cardColor,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  boxShadow: [
                    if (!context.isDark)
                      const BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kPrimaryBlue.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_shipping_outlined, color: kPrimaryBlue, size: 40),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'طلب رقم #${order.orderNumber}',
                      style: context.textTheme.titleLarge?.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'طلبك حالياً في مرحلة: ${_statusLabel(order.status)}',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.isDark ? kDarkTextSecondary : kTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _infoItem('التاريخ', _dateText(order)),
                        _infoItem('الإجمالي', '${order.totalAmount.toStringAsFixed(2)} د.ل'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // التايم لاين
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  children: [
                    _stepItem(
                      done: step1Done,
                      active: !step2Done,
                      title: 'تم استلام طلبك',
                      subtitle: 'لقد استلمنا طلبك بنجاح وهو الآن في انتظار تأكيد التاجر.',
                      icon: Icons.receipt_long,
                    ),
                    _connector(done: step2Done),
                    _stepItem(
                      done: step2Done,
                      active: step2Done && !step3Done,
                      title: 'قيد التجهيز',
                      subtitle: 'التاجر يقوم الآن بتجهيز منتجاتك بكل عناية.',
                      icon: Icons.inventory_2_outlined,
                    ),
                    _connector(done: step3Done),
                    _stepItem(
                      done: step3Done,
                      active: step3Done,
                      title: 'سيتم التواصل معك',
                      subtitle: 'التاجر سيتصل بك قريباً لتنسيق عملية التوصيل.',
                      icon: Icons.phone_callback,
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
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

  String _dateText(MyOrder order) {
    final d = order.createdAt;
    return '${d.year}/${d.month}/${d.day}';
  }

  Widget _infoItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: context.isDark ? kDarkTextSecondary : Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: context.textTheme.titleMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _connector({required bool done}) {
    return Container(
      margin: const EdgeInsets.only(right: 21),
      alignment: Alignment.centerRight,
      child: Container(
        width: 2,
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              done ? kPrimaryBlue : Colors.grey.shade300,
              done ? kPrimaryBlue : (context.isDark ? kDarkBorder : Colors.grey.shade200),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepItem({
    required bool done,
    required bool active,
    required String title,
    required String subtitle,
    required IconData icon,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? kPrimaryBlue : context.theme.cardColor,
                border: Border.all(
                  color: done ? kPrimaryBlue : (context.isDark ? kDarkBorder : Colors.grey.shade300),
                  width: 2,
                ),
                boxShadow: [
                  if (active) BoxShadow(color: kPrimaryBlue.withOpacity(0.3), blurRadius: 10, spreadRadius: 2),
                ],
              ),
              child: Icon(
                done ? Icons.check : icon,
                color: done ? Colors.white : (context.isDark ? kDarkTextSecondary : Colors.grey.shade400),
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                title,
                style: context.textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: done ? context.colors.onSurface : (context.isDark ? kDarkTextSecondary : Colors.grey.shade500),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: context.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: context.isDark ? kDarkTextSecondary.withOpacity(0.7) : Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              if (!isLast) const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }
}

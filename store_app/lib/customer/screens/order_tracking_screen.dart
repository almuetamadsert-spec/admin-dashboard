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
    final step1Done = true; // تم استلام الطلب دائماً عند عرض الصفحة
    final step2Done = order.isAccepted; // قيد التنفيذ = التاجر قبل
    final step3Done = order.isAccepted && _contactSoonActive; // بعد 3 ثوانٍ من القبول

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('تتبع الطلب #${order.orderNumber}', style: const TextStyle(fontSize: 18)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _step(
                done: step1Done,
                title: 'تم استلام طلبك',
                subtitle: 'وصل الطلب للتاجر',
              ),
              _connector(done: step1Done),
              _step(
                done: step2Done,
                title: 'قيد التنفيذ الآن',
                subtitle: 'التاجر قبل الطلب ويعمل عليه',
              ),
              _connector(done: step2Done),
              _step(
                done: step3Done,
                title: 'سيتم التواصل معك بعد قليل',
                subtitle: step3Done ? 'التاجر سيتواصل معك قريباً' : 'بعد قبول التاجر للطلب',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _connector({required bool done}) {
    return Padding(
      padding: const EdgeInsets.only(right: 19, left: 19),
      child: Container(
        width: 2,
        height: 24,
        color: done ? kPrimaryBlue : Colors.grey.shade300,
      ),
    );
  }

  Widget _step({
    required bool done,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? kPrimaryBlue : Colors.grey.shade300,
          ),
          child: done
              ? const Icon(Icons.check, color: Colors.white, size: 22)
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: done ? Colors.black87 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

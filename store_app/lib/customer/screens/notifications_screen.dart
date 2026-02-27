import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// صفحة الإشعارات — توجيه المستخدم لتفعيل الإشعارات في الجهاز.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('الإشعارات', style: TextStyle(fontSize: 18)),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_active_outlined, size: 72, color: kPrimaryBlue.withOpacity(0.7)),
              const SizedBox(height: 24),
              const Text(
                'تفعيل الإشعارات',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'للاستلام تنبيهات الطلبات والعروض، فعّل الإشعارات من إعدادات جهازك.\n\n'
                '• أندرويد: الإعدادات ← التطبيقات ← المعتمد ← الإشعارات\n'
                '• آيفون: الإعدادات ← إشعارات ← المعتمد',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

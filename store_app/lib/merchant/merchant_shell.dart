import 'package:flutter/material.dart';

import 'screens/merchant_dashboard_screen.dart';
import 'screens/merchant_order_detail_screen.dart';
import 'screens/merchant_settlement_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/stats_screen.dart';
import '../api/merchant_api.dart';
import '../theme/app_theme.dart';

/// واجهة التاجر — لوحة تحكم، طلبات، إحصائيات، تسويات.
class MerchantShell extends StatefulWidget {
  const MerchantShell({super.key});

  @override
  State<MerchantShell> createState() => _MerchantShellState();
}

class _MerchantShellState extends State<MerchantShell> {
  int _index = 0;

  void _openOrder(MerchantOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MerchantOrderDetailScreen(orderId: order.id),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            MerchantDashboardScreen(onTapOrder: _openOrder),
            const MerchantSettlementScreen(),
            const InventoryScreen(),
            const Center(child: Text('الملف — قريباً')),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: kPrimaryBlue,
          unselectedItemColor: kTextSecondary,
          backgroundColor: kBodyBg,
          elevation: 8,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'الرئيسية'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'التسويات'),
            BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'المخزون'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'الملف'),
          ],
        ),
      ),
    );
  }
}

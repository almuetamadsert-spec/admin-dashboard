import 'package:flutter/material.dart';

import '../../api/merchant_api.dart';
import '../../theme/app_theme.dart';

/// التسويات المالية: تبويبات، إحصائيات، سجل معاملات، طلب تصفية الحساب.
class MerchantSettlementScreen extends StatefulWidget {
  const MerchantSettlementScreen({super.key});

  @override
  State<MerchantSettlementScreen> createState() => _MerchantSettlementScreenState();
}

class _MerchantSettlementScreenState extends State<MerchantSettlementScreen> {
  MerchantStats? _stats;
  bool _loading = true;
  String? _error;
  int _tabIndex = 0; // 0 مكتمل، 1 نشط، 2 قيد الانتظار

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await MerchantApi.getStats();
      if (mounted) setState(() {
        _stats = s;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => Navigator.maybePop(context)),
          title: const Text('التسويات المالية'),
          actions: [
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.filter_list, size: 20),
              label: const Text('تصفية'),
            ),
          ],
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
                          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 16),
                          FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _settlementTab('مكتمل', 0),
                            _settlementTab('نشط', 1),
                            _settlementTab('قيد الانتظار', 2),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _statCard('الرسوم', '${(_stats!.pendingCommission ?? 345).toStringAsFixed(0)} د.ل', Icons.percent),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _statCard('الطلبات', '${_stats!.orderCount}', Icons.shopping_bag_outlined),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _statCard('الإيرادات', '${_stats!.totalSales.toStringAsFixed(0)} د.ل', Icons.payments_outlined),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('سجل المعاملات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('تنزيل CSV', style: TextStyle(color: kPrimaryBlue, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              _transactionRow('ORD-2481#', '24 أكتوبر، 10:30 ص', 120.0, 12.0),
                              const Divider(),
                              _transactionRow('ORD-2480#', '23 أكتوبر، 15:00 م', 85.0, 8.5),
                              const Divider(),
                              _transactionRow('ORD-2479#', '23 أكتوبر، 11:00 ص', 45.0, 4.5),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('متاح للتسوية', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                              const SizedBox(height: 8),
                              Text(
                                '3,105.00 د.ل',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kPrimaryBlue),
                              ),
                              const SizedBox(height: 8),
                              Text('الدفع القادم: الثلاثاء، 28 أكتوبر', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب تصفية الحساب للمسؤول')));
                                  },
                                  icon: const Icon(Icons.account_balance_wallet_outlined),
                                  label: const Text('طلب تصفية الحساب'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: kPrimaryBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _settlementTab(String label, int index) {
    final selected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: selected ? kPrimaryBlue.withOpacity(0.15) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? kPrimaryBlue : Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kPrimaryBlue, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _transactionRow(String orderId, String date, double total, double commission) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(orderId, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(date, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
        Text('${total.toStringAsFixed(2)} د.ل', style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 12),
        Text('-${commission.toStringAsFixed(2)} د.ل', style: TextStyle(fontSize: 13, color: Colors.red.shade400)),
      ],
    );
  }
}

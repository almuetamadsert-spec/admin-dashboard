import 'package:flutter/material.dart';

import '../../api/merchant_api.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  MerchantOrderDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _transferring = false;

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
      final d = await MerchantApi.getOrderDetail(widget.orderId);
      if (mounted) setState(() {
        _detail = d;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _showTransfer() async {
    if (_detail == null) return;
    List<MerchantItem> merchants = [];
    try {
      merchants = await MerchantApi.getMerchants();
    } catch (_) {}
    if (!mounted) return;
    int? selectedId;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          return AlertDialog(
            title: const Text('تحويل الطلب لتاجر آخر'),
            content: SingleChildScrollView(
              child: merchants.isEmpty
                  ? const Text('لا يوجد تجار آخرون')
                  : DropdownButton<int>(
                      isExpanded: true,
                      value: selectedId,
                      hint: const Text('اختر التاجر'),
                      items: merchants
                          .map((m) => DropdownMenuItem(value: m.id, child: Text('${m.name} — ${m.storeName ?? ""}')))
                          .toList(),
                      onChanged: (v) {
                        selectedId = v;
                        setDialog(() {});
                      },
                    ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              FilledButton(
                onPressed: selectedId == null
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        if (selectedId == null) return;
                        setState(() => _transferring = true);
                        try {
                          await MerchantApi.transferOrder(widget.orderId, selectedId!);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحويل الطلب')));
                            _load();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                            );
                          }
                        }
                        if (mounted) setState(() => _transferring = false);
                      },
                child: const Text('تحويل'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _detail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الطلب')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? 'لا تتوفر تفاصيل'),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('رجوع')),
            ],
          ),
        ),
      );
    }
    final order = _detail!.order;
    final items = _detail!.items;
    return Scaffold(
      appBar: AppBar(
        title: Text('#${order['order_number'] ?? ''}'),
        actions: [
          if (_transferring)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              onPressed: _showTransfer,
              tooltip: 'تحويل الطلب',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('بيانات العميل', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _row('الاسم', order['customer_name']),
                    _row('الهاتف', order['customer_phone']),
                    _row('العنوان', order['customer_address']),
                    _row('المدينة', order['city_name']),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('المنتجات', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...items.map((item) => Card(
                  child: ListTile(
                    title: Text(item['product_name'] ?? '—'),
                    subtitle: Text('${item['quantity']} × ${(item['unit_price'] as num?)?.toStringAsFixed(2) ?? ''} د.ل'),
                    trailing: Text('${(item['total_price'] as num?)?.toStringAsFixed(2) ?? ''} د.ل'),
                  ),
                )),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${(order['total_amount'] as num?)?.toStringAsFixed(2) ?? '0'} د.ل',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('$label: ${value?.toString() ?? '—'}'),
    );
  }
}

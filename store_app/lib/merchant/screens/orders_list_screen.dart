import 'package:flutter/material.dart';

import '../../api/merchant_api.dart';

class OrdersListScreen extends StatefulWidget {
  final void Function(MerchantOrder order) onTapOrder;

  const OrdersListScreen({super.key, required this.onTapOrder});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  List<MerchantOrder> _orders = [];
  bool _loading = true;
  String? _error;

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
      final list = await MerchantApi.getOrders();
      if (mounted) setState(() {
        _orders = list;
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (_orders.isEmpty) {
      return const Center(child: Text('لا توجد طلبات'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, i) {
          final o = _orders[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text('#${o.orderNumber}'),
              subtitle: Text('${o.customerName ?? '—'} • ${o.totalAmount.toStringAsFixed(2)} د.ل'),
              trailing: Chip(
                label: Text(o.status, style: const TextStyle(fontSize: 12)),
              ),
              onTap: () => widget.onTapOrder(o),
            ),
          );
        },
      ),
    );
  }
}

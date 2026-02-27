import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/merchant_api.dart';
import '../../config.dart';
import '../../theme/app_theme.dart';

/// تفاصيل الطلب للتاجر: فاتورة العميل (ملخص الطلب، بيانات العميل)، أزرار اتصل بالعميل / تم التسليم، تحويل الطلب، تعذر التسليم.
class MerchantOrderDetailScreen extends StatefulWidget {
  final int orderId;

  const MerchantOrderDetailScreen({super.key, required this.orderId});

  @override
  State<MerchantOrderDetailScreen> createState() => _MerchantOrderDetailScreenState();
}

class _MerchantOrderDetailScreenState extends State<MerchantOrderDetailScreen> {
  MerchantOrderDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _actionLoading = false;

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

  Future<void> _action(Future<void> Function() fn, {String? successMessage}) async {
    setState(() => _actionLoading = true);
    try {
      await fn();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage ?? 'تمت العملية')));
        await _load();
        if (!mounted) return;
        setState(() => _actionLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
        setState(() => _actionLoading = false);
      }
    }
  }

  String _imageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    final base = Config.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/uploads/${path.replaceFirst(RegExp(r'^\/+'), '')}';
  }

  void _callCustomer(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('رقم العميل'),
          content: SelectableText(phone),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ],
        ),
      );
    }
  }

  Future<void> _onContactedTap() async {
    await _action(() => MerchantApi.setContacted(widget.orderId), successMessage: 'تم تسجيل الاتصال بالعميل');
  }

  Future<void> _onDeliveredTap() async {
    setState(() => _actionLoading = true);
    try {
      await MerchantApi.setDelivered(widget.orderId);
      if (!mounted) return;
      setState(() => _actionLoading = false);
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('تم التسليم'),
          content: const Text('تم تحويل حالة الطلب إلى "تم التسليم". شكراً لك.'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _showTransfer() async {
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
            title: const Text('تحويل الطلب'),
            content: SingleChildScrollView(
              child: merchants.isEmpty
                  ? const Text('لا يوجد تجار آخرون')
                  : DropdownButton<int>(
                      isExpanded: true,
                      value: selectedId,
                      hint: const Text('اختر التاجر / المدينة'),
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
                onPressed: selectedId == null ? null : () async {
                  Navigator.pop(ctx);
                  if (selectedId == null) return;
                  await _action(() => MerchantApi.transferOrder(widget.orderId, selectedId!));
                },
                child: const Text('تحويل'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showUnavailable() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String v = 'نفاد الكمية';
        return StatefulBuilder(
          builder: (ctx, setD) {
            return AlertDialog(
              title: const Text('تعذر التسليم'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('اختر السبب:'),
                  const SizedBox(height: 12),
                  RadioListTile<String>(
                    title: const Text('نفاد الكمية'),
                    value: 'نفاد الكمية',
                    groupValue: v,
                    onChanged: (x) => setD(() => v = x!),
                  ),
                  RadioListTile<String>(
                    title: const Text('خطأ في السعر'),
                    value: 'خطأ في السعر',
                    groupValue: v,
                    onChanged: (x) => setD(() => v = x!),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, v),
                  child: const Text('تأكيد'),
                ),
              ],
            );
          },
        );
      },
    );
    if (reason != null) await _action(() => MerchantApi.setUnavailable(widget.orderId, reason: reason));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
    final orderNumber = order['order_number'] ?? '#${widget.orderId}';
    final customerName = order['customer_name']?.toString() ?? '—';
    final customerPhone = order['customer_phone']?.toString();
    final customerAddress = order['customer_address']?.toString() ?? '—';
    final cityName = order['city_name']?.toString() ?? '—';
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final createdAt = order['created_at']?.toString() ?? '—';
    final contactedAt = order['merchant_contacted_at'];
    final status = order['status']?.toString() ?? 'pending';
    final bool isDelivered = status == 'delivered';
    final bool canShowContact = contactedAt == null && !isDelivered;
    final bool canShowDelivered = contactedAt != null && !isDelivered;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => Navigator.pop(context)),
          title: Text('تفاصيل الطلب $orderNumber', style: const TextStyle(fontSize: 16)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ——— فاتورة العميل ———
              const Text('فاتورة العميل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              // ملخص الطلب
              const Text('ملخص الطلب', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Table(
                columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(0.8), 2: FlexColumnWidth(1)},
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade200),
                    children: const [
                      Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text('المنتج', style: TextStyle(fontWeight: FontWeight.w600))),
                      Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text('الكمية', style: TextStyle(fontWeight: FontWeight.w600))),
                      Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text('السعر', style: TextStyle(fontWeight: FontWeight.w600))),
                    ],
                  ),
                  ...items.map<TableRow>((item) {
                    final imagePath = item['image_path']?.toString();
                    final imageUrl = _imageUrl(imagePath);
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          child: Row(
                            children: [
                              if (imageUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(imageUrl, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 40, height: 40, child: Icon(Icons.image_not_supported))),
                                ),
                              if (imageUrl.isNotEmpty) const SizedBox(width: 8),
                              Expanded(child: Text(item['product_name']?.toString() ?? '—', style: const TextStyle(fontSize: 13))),
                            ],
                          ),
                        ),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text('${item['quantity'] ?? 0}')),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text('${(item['total_price'] as num?)?.toDouble() ?? 0} د.ل')),
                      ],
                    );
                  }),
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: [
                      const Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.w600))),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text('${items.fold<int>(0, (s, i) => s + ((i['quantity'] as num?)?.toInt() ?? 0))}')),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text('$totalAmount د.ل', style: const TextStyle(fontWeight: FontWeight.w600))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('اسم العميل: $customerName', style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
              const SizedBox(height: 4),
              Text('المدينة: $cityName', style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
              const SizedBox(height: 4),
              Text('العنوان: $customerAddress', style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
              const SizedBox(height: 4),
              Text('التاريخ: $createdAt', style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
              const SizedBox(height: 24),
              // ——— أزرار الإجراءات ———
              if (_actionLoading)
                const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
              else ...[
                if (canShowContact)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _onContactedTap(),
                      icon: const Icon(Icons.phone, size: 20),
                      label: const Text('اتصل بالعميل'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                if (canShowContact) const SizedBox(height: 10),
                if (canShowDelivered)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _onDeliveredTap,
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text('تم التسليم'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                if (canShowDelivered) const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isDelivered ? null : _showTransfer,
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text('تحويل الطلب'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isDelivered ? null : _showUnavailable,
                        icon: Icon(Icons.cancel_outlined, size: 18, color: Colors.red.shade400),
                        label: const Text('تعذر التسليم'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red.shade400),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

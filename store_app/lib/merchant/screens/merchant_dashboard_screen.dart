import 'package:flutter/material.dart';

import '../../api/merchant_api.dart';
import '../../core/socket_service.dart';
import '../../theme/app_theme.dart';

/// لوحة التاجر: ترحيب، سعة الطلبات، إحصائيات، تبويبات، بطاقات الطلبات.
class MerchantDashboardScreen extends StatefulWidget {
  final void Function(MerchantOrder order) onTapOrder;
  final int? merchantCityId; // تُمرَّر من الـ shell لتحديد غرفة Socket.io

  const MerchantDashboardScreen({super.key, required this.onTapOrder, this.merchantCityId});

  @override
  State<MerchantDashboardScreen> createState() => _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  List<MerchantOrder> _orders = [];
  MerchantStats? _stats;
  bool _loading = true;
  String? _error;
  int _tabIndex = 2; // 0 مكتملة، 1 قيد التنفيذ، 2 طلبات جديدة

  @override
  void initState() {
    super.initState();
    _load();
    _initSocket();
  }

  void _initSocket() {
    SocketService.connect(cityId: widget.merchantCityId);
    // عند استلام طلب جديد — تحديث القائمة تلقائياً
    SocketService.onNewOrder((_) {
      if (mounted) _load();
    });
    // عند استلام طلب من تاجر آخر — تنبيه + تحديث
    SocketService.onOrderClaimed((data) {
      if (!mounted) return;
      final orderId = data['order_id'];
      _load();
      showDialog(
        context: context,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: const Icon(Icons.info_outline, color: Colors.orange, size: 40),
            title: const Text('تم الاستلام', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text(
              'طلب #$orderId تم استلامه من قبل تاجر آخر في مدينتك.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('حسناً'),
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    SocketService.disconnect();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await MerchantApi.getOrders();
      MerchantStats? stats;
      try {
        stats = await MerchantApi.getStats();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _orders = orders;
          _stats = stats;
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

  List<MerchantOrder> get _filteredOrders {
    if (_tabIndex == 0) return _orders.where((o) => o.status == 'delivered').toList();
    if (_tabIndex == 1) return _orders.where((o) => o.isClaimed && o.status != 'delivered' && o.status != 'cancelled' && o.status != 'customer_refused').toList();
    return _orders.where((o) => !o.isClaimed).toList();
  }

  int get _newCount => _orders.where((o) => !o.isClaimed).length;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              _buildHeader(),
              SliverToBoxAdapter(child: _buildWelcomeCard()),
              SliverToBoxAdapter(child: _buildCapacityCard()),
              SliverToBoxAdapter(child: _buildStatsCards()),
              SliverToBoxAdapter(child: _buildTabs()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الطلبات الواردة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('عرض الكل', style: TextStyle(color: kPrimaryBlue, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(
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
                  ),
                )
              else if (_filteredOrders.isEmpty)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لا توجد طلبات في هذا التبويب'))))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _orderCard(_filteredOrders[i]),
                    childCount: _filteredOrders.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
            const Expanded(child: Text('لوحة التاجر', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
                Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('أهلاً بك، متجر طرابلس المعتمد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.verified, color: kPrimaryBlue, size: 18),
                    const SizedBox(width: 4),
                    Text('تاجر معتمد', style: TextStyle(color: kPrimaryBlue, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          CircleAvatar(radius: 28, backgroundColor: Colors.grey.shade300, child: Icon(Icons.store, size: 32, color: Colors.grey.shade600)),
          const SizedBox(width: 8),
          Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
        ],
      ),
    );
  }

  Widget _buildCapacityCard() {
    const used = 15;
    const maxCap = 20;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('سعة الطلبات اليومية', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(width: 8),
              Icon(Icons.list_alt, color: Colors.white70, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text('$used/$maxCap', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: used / maxCap,
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(kPrimaryBlue),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${maxCap - used} خانات متبقية', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text('طلب مرتفع اليوم', style: TextStyle(color: Colors.amber.shade200, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final sales = _stats?.totalSales ?? 2450.0;
    final commission = _stats?.pendingCommission ?? 150.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('قيد الانتظار', style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
                  const SizedBox(height: 4),
                  Text('العمولة المستحقة', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  Text('${commission.toStringAsFixed(0)} د.ل', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('12%+', style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                  const SizedBox(height: 4),
                  Text('إجمالي مبيعات اليوم', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  Text('${sales.toStringAsFixed(0)} د.ل', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: [
          _tab('المكتملة', 0),
          _tab('قيد التنفيذ', 1),
          _tab('طلبات جديدة', 2, badge: _newCount),
        ],
      ),
    );
  }

  Widget _tab(String label, int index, {int badge = 0}) {
    final selected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? kPrimaryBlue.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (badge > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: kPrimaryBlue, borderRadius: BorderRadius.circular(10)),
                  child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? kPrimaryBlue : Colors.grey.shade700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderCard(MerchantOrder o) {
    final isNew = !o.isClaimed;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isNew)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                child: const Text('جديد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.shopping_bag_outlined, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('طلب ${o.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (o.cityName != null && o.cityName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(o.cityName!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    Text(
                      o.createdAt ?? '',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Text(
                '${o.totalAmount.toStringAsFixed(0)} د.ل',
                style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryBlue, fontSize: 15),
              ),
            ],
          ),
          if (isNew) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.visibility_off, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('بيانات العميل مخفية حتى قبول الطلب', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  try {
                    await MerchantApi.claimOrder(o.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استلام الطلب')));
                      _load();
                      widget.onTapOrder(o);
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
                  }
                },
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text('قيد التنفيذ'),
                style: FilledButton.styleFrom(backgroundColor: kPrimaryBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => widget.onTapOrder(o),
                child: const Text('عرض التفاصيل'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

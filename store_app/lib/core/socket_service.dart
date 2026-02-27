import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'auth/auth_service.dart';

/// خدمة مراقبة الطلبات باستخدام polling.
/// تستطلع السيرفر كل بضع ثوان وترفع أحداث عند وجود طلبات جديدة أو مُستحوَذ عليها.
class SocketService {
  static Timer? _timer;
  static String? _lastSeenOrderIds; // معرفات آخر طلبات تم رؤيتها
  static String? _lastClaimedCheck; // توقيت آخر فحص للاستحواذ

  static final List<void Function(Map<String, dynamic>)> _newOrderListeners = [];
  static final List<void Function(Map<String, dynamic>)> _claimedListeners = [];

  static String get _base => Config.baseUrl.replaceAll(RegExp(r'/$'), '');

  /// بدء الاستطلاع كل 5 ثوان.
  static void connect({int? cityId}) {
    disconnect();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  static Future<void> _poll() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      final r = await http.get(
        Uri.parse('$_base/api/merchant/orders'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 4));
      if (r.statusCode != 200) return;
      final data = jsonDecode(r.body) as Map<String, dynamic>?;
      if (data?['ok'] != true) return;
      final orders = (data!['orders'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      final currentIds = orders.map((o) => '${o['id']}').join(',');

      // طلبات جديدة ظهرت
      if (_lastSeenOrderIds != null && currentIds != _lastSeenOrderIds) {
        final prevSet = _lastSeenOrderIds!.split(',').toSet();
        final currSet = currentIds.split(',').toSet();
        final newIds = currSet.difference(prevSet);
        for (final id in newIds) {
          for (final cb in _newOrderListeners) {
            cb({'order_id': int.tryParse(id)});
          }
        }

        // طلبات اختفت (تم الاستحواذ عليها من تاجر آخر)
        final disappeared = prevSet.difference(currSet);
        for (final id in disappeared) {
          // تحقق مما إذا كانت اختفت بسبب استحواذ تاجر آخر
          for (final cb in _claimedListeners) {
            cb({'order_id': int.tryParse(id)});
          }
        }
      }
      _lastSeenOrderIds = currentIds;
    } catch (_) {}
  }

  /// الاستماع لطلب جديد.
  static void onNewOrder(void Function(Map<String, dynamic>) callback) {
    _newOrderListeners.add(callback);
  }

  /// الاستماع للاستحواذ من تاجر آخر.
  static void onOrderClaimed(void Function(Map<String, dynamic>) callback) {
    _claimedListeners.add(callback);
  }

  /// إيقاف الاستطلاع.
  static void disconnect() {
    _timer?.cancel();
    _timer = null;
    _newOrderListeners.clear();
    _claimedListeners.clear();
    _lastSeenOrderIds = null;
  }

  static bool get isConnected => _timer?.isActive == true;
}

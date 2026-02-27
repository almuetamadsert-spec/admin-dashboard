import 'package:shared_preferences/shared_preferences.dart';

import '../../api/auth_api.dart';

class AuthService {
  static const _keyToken = 'app_token';
  static const _keyRole = 'app_role';
  static const _keyMerchantId = 'app_merchant_id';
  static const _keyEmail = 'app_email';

  static Future<void> saveSession(LoginResponse res) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, res.token);
    await prefs.setString(_keyRole, res.role);
    await prefs.setString(_keyEmail, res.email);
    if (res.merchantId != null) {
      await prefs.setInt(_keyMerchantId, res.merchantId!);
    } else {
      await prefs.remove(_keyMerchantId);
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyMerchantId);
    await prefs.remove(_keyEmail);
  }

  /// يرجع true إذا وُجد توكن (بدون التحقق من الصلاحية على السيرفر)
  static Future<bool> hasStoredSession() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}

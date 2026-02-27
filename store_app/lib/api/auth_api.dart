import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

class AuthApi {
  static String get _base => Config.baseUrl.replaceAll(RegExp(r'/$'), '');

  static Map<String, String> _apiHeaders() => {
        'Content-Type': 'application/json',
        'X-Consumer-Key': Config.consumerKey,
        'X-Consumer-Secret': Config.consumerSecret,
      };

  static Map<String, String> _bearerHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// POST /api/auth/login — إيميل + كلمة مرور، يرجع token و role و merchantId
  static Future<LoginResponse> login(String email, String password) async {
    final r = await http.post(
      Uri.parse('$_base/api/auth/login'),
      headers: _apiHeaders(),
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (r.statusCode == 200 && data?['ok'] == true) {
      return LoginResponse(
        token: data!['token'] as String,
        role: data['role'] as String? ?? 'customer',
        merchantId: data['merchantId'] as int?,
        email: data['email'] as String? ?? email,
      );
    }
    throw Exception(data?['message'] ?? data?['error'] ?? 'فشل تسجيل الدخول: ${r.statusCode}');
  }

  /// GET /api/auth/me — التحقق من التوكن والحصول على المستخدم
  static Future<MeResponse> me(String token) async {
    final r = await http.get(
      Uri.parse('$_base/api/auth/me'),
      headers: _bearerHeaders(token),
    );
    final data = jsonDecode(r.body) as Map<String, dynamic>?;
    if (r.statusCode == 200 && data?['ok'] == true) {
      final u = data!['user'] as Map<String, dynamic>? ?? {};
      return MeResponse(
        id: u['id'] as int?,
        email: u['email'] as String? ?? '',
        role: u['role'] as String? ?? 'customer',
        merchantId: u['merchantId'] as int?,
      );
    }
    throw Exception(data?['message'] ?? 'انتهت الجلسة');
  }
}

class LoginResponse {
  final String token;
  final String role;
  final int? merchantId;
  final String email;
  LoginResponse({required this.token, required this.role, this.merchantId, required this.email});
}

class MeResponse {
  final int? id;
  final String email;
  final String role;
  final int? merchantId;
  MeResponse({this.id, required this.email, required this.role, this.merchantId});
}

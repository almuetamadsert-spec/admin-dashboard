import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/auth/auth_service.dart';
import 'core/auth/login_screen.dart';
import 'api/auth_api.dart';
import 'customer/customer_shell.dart';
import 'merchant/merchant_shell.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dark = prefs.getBool('dark_mode') ?? false;
      if (mounted) setState(() => _themeMode = dark ? ThemeMode.dark : ThemeMode.light);
    } catch (_) {}
  }

  void _onDarkModeChanged(bool isDark) {
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'المعتمد',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.light(),
      darkTheme: AppThemes.dark(),
      themeMode: _themeMode,
      home: _AppRouter(onDarkModeChanged: _onDarkModeChanged),
    );
  }
}

/// البوابة: إذا وُجد توكن صالح → التوجيه حسب role؛ وإلا شاشة الدخول.
class _AppRouter extends StatefulWidget {
  final ValueChanged<bool>? onDarkModeChanged;

  const _AppRouter({this.onDarkModeChanged});

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  bool _checked = false;
  bool _showLogin = true;
  String _role = 'customer';

  @override
  void initState() {
    super.initState();
    _resolveSession();
  }

  Future<void> _resolveSession() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      if (mounted) setState(() {
        _checked = true;
        _showLogin = true;
      });
      return;
    }
    try {
      final me = await AuthApi.me(token);
      if (mounted) {
        setState(() {
          _checked = true;
          _showLogin = false;
          _role = me.role;
        });
      }
    } catch (_) {
      await AuthService.clearSession();
      if (mounted) {
        setState(() {
          _checked = true;
          _showLogin = true;
        });
      }
    }
  }

  Future<void> _onLoginSuccess(String role) async {
    setState(() {
      _showLogin = false;
      _role = role;
    });
  }

  Future<void> _logout() async {
    await AuthService.clearSession();
    if (mounted) {
      setState(() {
        _showLogin = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_showLogin) {
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    }
    if (_role == 'merchant') {
      return MerchantShellWithLogout(onLogout: _logout);
    }
    return CustomerShellWithLogout(onLogout: _logout, onDarkModeChanged: widget.onDarkModeChanged);
  }
}

class CustomerShellWithLogout extends StatelessWidget {
  final VoidCallback onLogout;
  final ValueChanged<bool>? onDarkModeChanged;

  const CustomerShellWithLogout({super.key, required this.onLogout, this.onDarkModeChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomerShell(onDarkModeChanged: onDarkModeChanged),
      floatingActionButton: Builder(
        builder: (context) {
          return FloatingActionButton(
            mini: true,
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('تسجيل الخروج'),
                  content: const Text('هل تريد تسجيل الخروج؟'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('خروج')),
                  ],
                ),
              );
              if (ok == true) onLogout();
            },
            child: const Icon(Icons.logout),
          );
        },
      ),
    );
  }
}

class MerchantShellWithLogout extends StatelessWidget {
  final VoidCallback onLogout;

  const MerchantShellWithLogout({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const MerchantShell(),
      floatingActionButton: Builder(
        builder: (context) {
          return FloatingActionButton(
            mini: true,
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('تسجيل الخروج'),
                  content: const Text('هل تريد تسجيل الخروج؟'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('خروج')),
                  ],
                ),
              );
              if (ok == true) onLogout();
            },
            child: const Icon(Icons.logout),
          );
        },
      ),
    );
  }
}

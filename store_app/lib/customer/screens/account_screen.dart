import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../theme/app_theme.dart';
import 'cms_page_screen.dart';
import 'my_orders_screen.dart';
import 'notifications_screen.dart';
import 'profile_edit_screen.dart';

class AccountScreen extends StatefulWidget {
  final ValueChanged<bool>? onDarkModeChanged;
  const AccountScreen({super.key, this.onDarkModeChanged});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _darkMode = false;
  Map<String, dynamic> _socialData = {};
  String _name = '';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _darkMode = prefs.getBool('dark_mode') ?? false;
          _name = prefs.getString('customer_name') ?? '';
          _phone = prefs.getString('customer_phone') ?? '';
        });
      }
    } catch (_) {}
    try {
      final data = await ApiClient.getSocialLinks();
      if (mounted) setState(() => _socialData = data);
    } catch (_) {}
  }

  Future<void> _toggleDarkMode(bool v) async {
    setState(() => _darkMode = v);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('dark_mode', v);
      widget.onDarkModeChanged?.call(v);
    } catch (_) {}
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _goToEdit() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ProfileEditScreen(onSaved: _loadAll)))
        .then((_) => _loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final initials = _name.trim().isNotEmpty ? _name.trim()[0].toUpperCase() : '؟';
    final hasProfile = _name.isNotEmpty || _phone.isNotEmpty;
    final links = _socialData['links'] as List<dynamic>? ?? [];
    final bgHex = _socialData['icon_bg_color'] as String? ?? '#14acec';
    final symHex = _socialData['icon_symbol_color'] as String? ?? '#ffffff';
    final iconShape = _socialData['icon_shape'] as String? ?? 'circle';
    final bgColor = _hexColor(bgHex, kPrimaryBlue);
    final symColor = _hexColor(symHex, Colors.white);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: context.colors.surfaceContainerLowest,
        body: RefreshIndicator(
          onRefresh: _loadAll,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────
                _buildHeader(initials, hasProfile),

                const SizedBox(height: 16),

                // ── بطاقة الطلبات ──────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _sectionLabel('الطلبات'),
                ),
                const SizedBox(height: 8),
                _buildOrderCard(),

                const SizedBox(height: 16),

                // ── الإعدادات ──────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _sectionLabel('الإعدادات'),
                ),
                const SizedBox(height: 8),
                _buildSettingsCard(),

                const SizedBox(height: 16),

                // ── معلومات ────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _sectionLabel('معلومات'),
                ),
                const SizedBox(height: 8),
                _buildInfoCard(),

                // ── السوشيال ───────────────────────────
                if (links.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _sectionLabel('تابعنا'),
                  ),
                  const SizedBox(height: 12),
                  _buildSocialRow(links, iconShape, bgColor, symColor),
                ],

                // ── Footer ─────────────────────────────
                const SizedBox(height: 28),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Text(
                  'المعتمد سيرت',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'الإصدار 1.0.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────
  Widget _buildHeader(String initials, bool hasProfile) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2A4A), kPrimaryBlue],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'حسابي',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: Colors.white),
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  GestureDetector(
                    onTap: _goToEdit,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white24,
                          child: Text(
                            initials,
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.edit, size: 13, color: kPrimaryBlue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: hasProfile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _name.isNotEmpty ? _name : 'مستخدم',
                                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                              if (_phone.isNotEmpty)
                                Text(_phone, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          )
                        : GestureDetector(
                            onTap: _goToEdit,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('أضف بياناتك',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                Text('اضغط هنا',
                                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                              ],
                            ),
                          ),
                  ),
                  TextButton.icon(
                    onPressed: _goToEdit,
                    icon: const Icon(Icons.edit_outlined, size: 15, color: Colors.white70),
                    label: const Text('تعديل', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── بطاقة الطلبات ────────────────────────────────────────
  Widget _buildOrderCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _cardTile(
        icon: Icons.shopping_bag_outlined,
        iconColor: kPrimaryBlue,
        title: 'طلباتي',
        subtitle: 'عرض وتتبع جميع طلباتك',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyOrdersScreen())),
      ),
    );
  }

  // ── الإعدادات ─────────────────────────────────────────────
  Widget _buildSettingsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: context.theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!context.isDark)
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          children: [
            ListTile(
              leading: _iconBox(Icons.notifications_outlined, Colors.orange),
              title: const Text('الإشعارات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              subtitle: const Text('تفعيل إشعارات الطلبات', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_left, color: Colors.grey, size: 22),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            ),
            const Divider(height: 1, indent: 68),
            ListTile(
              leading: _iconBox(_darkMode ? Icons.dark_mode : Icons.light_mode_outlined, Colors.indigo),
              title: const Text('الوضع الليلي', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              trailing: Switch(value: _darkMode, onChanged: _toggleDarkMode, activeColor: kPrimaryBlue),
            ),
          ],
        ),
      ),
    );
  }

  // ── معلومات ───────────────────────────────────────────────
  Widget _buildInfoCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: context.theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!context.isDark)
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          children: [
            _infoTile(Icons.info_outline, Colors.teal, 'من نحن',
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CmsPageScreen(slug: 'about', title: 'من نحن')))),
            const Divider(height: 1, indent: 68),
            _infoTile(Icons.privacy_tip_outlined, Colors.blue, 'سياسة الخصوصية',
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CmsPageScreen(slug: 'privacy', title: 'سياسة الخصوصية')))),
            const Divider(height: 1, indent: 68),
            _infoTile(Icons.description_outlined, Colors.purple, 'الشروط والأحكام',
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CmsPageScreen(slug: 'terms', title: 'الشروط والأحكام')))),
            const Divider(height: 1, indent: 68),
            _infoTile(Icons.headset_mic_outlined, Colors.green, 'تواصل معنا عبر واتساب',
                () => _openUrl('https://wa.me/218910000000')),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, Color color, String title, VoidCallback onTap) {
    return ListTile(
      leading: _iconBox(icon, color),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_left, color: Colors.grey, size: 22),
      onTap: onTap,
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _cardTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!context.isDark)
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: _iconBox(icon, iconColor),
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
        trailing: const Icon(Icons.chevron_left, color: Colors.grey, size: 22),
        onTap: onTap,
      ),
    );
  }

  // ── السوشيال ─────────────────────────────────────────────
  Widget _buildSocialRow(List<dynamic> links, String shape, Color bg, Color sym) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final link in links) ...[
            const SizedBox(width: 10),
            InkWell(
              onTap: () => _openUrl(link['url'] as String? ?? ''),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: bg,
                  shape: shape == 'circle' ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: shape != 'circle' ? BorderRadius.circular(12) : null,
                  boxShadow: [BoxShadow(color: bg.withOpacity(0.35), blurRadius: 6, offset: const Offset(0, 3))],
                ),
                child: Icon(_socialIcon(link['id'] as String? ?? ''), color: sym, size: 24),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static IconData _socialIcon(String id) {
    switch (id) {
      case 'facebook': return BootstrapIcons.facebook;
      case 'instagram': return BootstrapIcons.instagram;
      case 'whatsapp': return BootstrapIcons.whatsapp;
      case 'tiktok': return BootstrapIcons.tiktok;
      case 'youtube': return BootstrapIcons.youtube;
      case 'twitter': return BootstrapIcons.twitter;
      case 'telegram': return BootstrapIcons.telegram;
      default: return BootstrapIcons.link;
    }
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5),
    );
  }

  static Color _hexColor(String hex, Color fallback) {
    try {
      String h = hex.replaceFirst('#', '');
      if (h.length == 6) h = 'FF$h';
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return fallback;
    }
  }
}

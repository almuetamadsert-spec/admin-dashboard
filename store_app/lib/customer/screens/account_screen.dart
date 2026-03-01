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
          color: kPrimaryBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────
                _buildHeader(initials, hasProfile),

                const SizedBox(height: 12),

                // ── بطاقة الطلبات ──────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: _sectionLabel('النشاط التجاري'),
                ),
                _buildOrderCard(),

                const SizedBox(height: 12),

                // ── الإعدادات ──────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: _sectionLabel('تفضيلات التطبيق'),
                ),
                _buildSettingsCard(),

                const SizedBox(height: 12),

                // ── معلومات ────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: _sectionLabel('حول المتجر'),
                ),
                _buildInfoCard(),

                // ── السوشيال ───────────────────────────
                if (links.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _sectionLabel('تواصل معنا اجتماعياً'),
                  ),
                  const SizedBox(height: 12),
                  _buildSocialRow(links, iconShape, bgColor, symColor),
                ],

                // ── Footer ─────────────────────────────
                const SizedBox(height: 48),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'المعتمد سيرت للأعمال المحدودة',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'الإصدار 1.0.0 (بناء 105)',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 60),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            kPrimaryBlue,
            const Color(0xFF42C2F7), // تدرج لوني أزرق فاتح وأنيق
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: kPrimaryBlue.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مركز الحساب',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                      Text(
                        'إدارة ملفك الشخصي وإعداداتك',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 20),
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  GestureDetector(
                    onTap: _goToEdit,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 38,
                        backgroundColor: Colors.white,
                        child: Text(
                          initials,
                          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: kPrimaryBlue),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasProfile && _name.isNotEmpty ? _name : 'ضيف المعتمد',
                          style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _phone.isNotEmpty ? _phone : 'لم يتم ربط رقم هاتف',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _goToEdit,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.edit_note_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── بطاقات التصميم الجديد ────────────────────────────────────────
  Widget _buildOrderCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _cardTile(
        icon: Icons.local_shipping_outlined,
        iconColor: Colors.blue.shade700,
        title: 'طلباتي ومشترياتي',
        subtitle: 'تتبع حالة الشحن والمشتريات السابقة',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyOrdersScreen())),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: context.theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.isDark ? Colors.white10 : Colors.black.withOpacity(0.03)),
          boxShadow: [
            if (!context.isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 5),
              )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              _premiumListTile(
                icon: Icons.notifications_none_rounded,
                iconColor: Colors.orange.shade600,
                title: 'تنبيهات النظام',
                subtitle: 'إدارة الإشعارات وتحديثات الطلبات',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              ),
              _divider(),
              _premiumListTile(
                icon: _darkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                iconColor: Colors.indigo.shade400,
                title: 'المظهر الداكن',
                subtitle: 'تبديل وضع الألوان للتطبيق',
                trailing: Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _darkMode,
                    onChanged: _toggleDarkMode,
                    activeColor: kPrimaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: context.theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.isDark ? Colors.white10 : Colors.black.withOpacity(0.03)),
          boxShadow: [
            if (!context.isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 5),
              )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              _premiumListTile(
                icon: Icons.info_outline_rounded,
                iconColor: kPrimaryBlue,
                title: 'من نحن والمهمة',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CmsPageScreen(slug: 'about', title: 'من نحن'))),
              ),
              _divider(),
              _premiumListTile(
                icon: Icons.security_outlined,
                iconColor: kPrimaryBlue,
                title: 'سياسة الخصوصية والأمان',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CmsPageScreen(slug: 'privacy', title: 'سياسة الخصوصية'))),
              ),
              _divider(),
              _premiumListTile(
                icon: Icons.article_outlined,
                iconColor: kPrimaryBlue,
                title: 'الشروط والأحكام',
                subtitle: 'حقوقك ومسؤولياتك القانونية',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CmsPageScreen(slug: 'terms', title: 'الشروط والأحكام'))),
              ),
              _divider(),
              _premiumListTile(
                icon: BootstrapIcons.whatsapp,
                iconColor: kSuccess,
                title: 'مركز الدعم والمساعدة',
                subtitle: 'تواصل مباشر عبر الواتساب',
                onTap: () => _openUrl('https://wa.me/218910000000'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _premiumListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)) : null,
      trailing: trailing ?? Icon(Icons.arrow_back_ios_new, color: Colors.grey.shade300, size: 14),
      onTap: onTap,
    );
  }

  Widget _divider() => Divider(height: 1, thickness: 0.5, color: Colors.grey.withOpacity(0.1), indent: 70);

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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.isDark ? Colors.white10 : Colors.black.withOpacity(0.03)),
        boxShadow: [
          if (!context.isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
        ],
      ),
      child: _premiumListTile(
        icon: icon,
        iconColor: iconColor,
        title: title,
        subtitle: subtitle,
        onTap: onTap,
      ),
    );
  }

  // ── السوشيال ─────────────────────────────────────────────
  Widget _buildSocialRow(List<dynamic> links, String shape, Color bg, Color sym) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final link in links)
            InkWell(
              onTap: () => _openUrl(link['url'] as String? ?? ''),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: bg,
                  shape: shape == 'circle' ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: shape != 'circle' ? BorderRadius.circular(16) : null,
                  boxShadow: [
                    BoxShadow(
                      color: bg.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Icon(_socialIcon(link['id'] as String? ?? ''), color: sym, size: 24),
              ),
            ),
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
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: kPrimaryBlue.withOpacity(0.7),
        letterSpacing: 1.2,
      ),
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

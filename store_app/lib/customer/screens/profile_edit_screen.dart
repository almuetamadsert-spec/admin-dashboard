import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_client.dart';
import '../../models/city.dart';
import '../../theme/app_theme.dart';

/// تعديل الملف الشخصي: الاسم، الهاتف، هاتف احتياطي، العنوان، البريد، المدينة.
class ProfileEditScreen extends StatefulWidget {
  final VoidCallback? onSaved;
  const ProfileEditScreen({super.key, this.onSaved});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phoneAltController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  List<City> _cities = [];
  int? _selectedCityId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _phoneAltController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        SharedPreferences.getInstance(),
        ApiClient.getCities(),
      ]);
      final prefs = results[0] as SharedPreferences;
      final cities = results[1] as List<City>;
      if (mounted) {
        setState(() {
          _nameController.text = prefs.getString('customer_name') ?? '';
          _phoneController.text = prefs.getString('customer_phone') ?? '';
          _phoneAltController.text = prefs.getString('customer_phone_alt') ?? '';
          _addressController.text = prefs.getString('customer_address') ?? '';
          _emailController.text = prefs.getString('customer_email') ?? '';
          _selectedCityId = prefs.getInt('customer_city_id');
          _cities = cities;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customer_name', _nameController.text.trim());
      await prefs.setString('customer_phone', _phoneController.text.trim());
      await prefs.setString('customer_phone_alt', _phoneAltController.text.trim());
      await prefs.setString('customer_address', _addressController.text.trim());
      await prefs.setString('customer_email', _emailController.text.trim());
      if (_selectedCityId != null) {
        await prefs.setInt('customer_city_id', _selectedCityId!);
      } else {
        await prefs.remove('customer_city_id');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ تم حفظ التعديلات'), backgroundColor: Colors.green),
        );
        widget.onSaved?.call();
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الحفظ'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E3A5F),
          foregroundColor: Colors.white,
          title: const Text('تعديل الحساب', style: TextStyle(fontSize: 17)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            if (!_loading)
              TextButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('حفظ', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Avatar
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: kPrimaryBlue.withOpacity(0.15),
                              child: Text(
                                _nameController.text.isNotEmpty
                                    ? _nameController.text.trim()[0].toUpperCase()
                                    : '؟',
                                style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: kPrimaryBlue),
                              ),
                            ),
                            Positioned(
                              bottom: 2,
                              left: 2,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(color: kPrimaryBlue, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ─── بيانات شخصية ───────────────────
                      _sectionTitle('البيانات الشخصية'),
                      const SizedBox(height: 10),
                      _card(children: [
                        _field(
                          controller: _nameController,
                          label: 'الاسم الكامل',
                          icon: Icons.person_outline,
                          action: TextInputAction.next,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                        ),
                        const Divider(height: 1, indent: 52),
                        _field(
                          controller: _phoneController,
                          label: 'رقم الهاتف',
                          icon: Icons.phone_outlined,
                          type: TextInputType.phone,
                          action: TextInputAction.next,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'الهاتف مطلوب' : null,
                        ),
                        const Divider(height: 1, indent: 52),
                        _field(
                          controller: _phoneAltController,
                          label: 'هاتف احتياطي (اختياري)',
                          icon: Icons.phone_callback_outlined,
                          type: TextInputType.phone,
                          action: TextInputAction.next,
                        ),
                        const Divider(height: 1, indent: 52),
                        _field(
                          controller: _emailController,
                          label: 'البريد الإلكتروني (اختياري)',
                          icon: Icons.email_outlined,
                          type: TextInputType.emailAddress,
                          action: TextInputAction.next,
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // ─── العنوان والمدينة ─────────────────
                      _sectionTitle('العنوان'),
                      const SizedBox(height: 10),
                      _card(children: [
                        // اختيار المدينة
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: DropdownButtonFormField<int>(
                            value: _selectedCityId,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              prefixIcon: Icon(Icons.location_city_outlined, color: Colors.grey),
                              hintText: 'اختر مدينتك',
                            ),
                            items: [
                              const DropdownMenuItem<int>(value: null, child: Text('لم يتم التحديد')),
                              for (final c in _cities)
                                DropdownMenuItem<int>(value: c.id, child: Text(c.name)),
                            ],
                            onChanged: (v) => setState(() => _selectedCityId = v),
                          ),
                        ),
                        const Divider(height: 1, indent: 52),
                        _field(
                          controller: _addressController,
                          label: 'العنوان التفصيلي',
                          icon: Icons.location_on_outlined,
                          maxLines: 2,
                          action: TextInputAction.done,
                        ),
                      ]),
                      const SizedBox(height: 28),

                      // زر الحفظ
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle_outline),
                        label: const Text('حفظ التعديلات', style: TextStyle(fontSize: 15)),
                        style: FilledButton.styleFrom(
                          backgroundColor: kPrimaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade600),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(children: children),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
    TextInputAction action = TextInputAction.next,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      textInputAction: action,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
      ),
      onChanged: (_) {
        if (label.contains('الاسم')) setState(() {}); // تحديث Avatar
      },
    );
  }
}

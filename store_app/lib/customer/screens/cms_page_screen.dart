import 'package:flutter/material.dart';
// import 'package:flutter_html/flutter_html.dart';

import '../../api/api_client.dart';

/// عرض صفحة CMS (من نحن / خصوصية / شروط) من الـ API.
class CmsPageScreen extends StatefulWidget {
  final String slug;
  final String title;

  const CmsPageScreen({super.key, required this.slug, required this.title});

  @override
  State<CmsPageScreen> createState() => _CmsPageScreenState();
}

class _CmsPageScreenState extends State<CmsPageScreen> {
  String? _content;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page = await ApiClient.getCmsPage(widget.slug);
      if (mounted) {
        setState(() {
          _loading = false;
          if (page != null) {
            _content = (page['content_ar'] ?? page['content_en'] ?? '').toString();
            if (_content != null && _content!.trim().isEmpty) _content = 'لا يوجد محتوى.';
          } else {
            _content = 'الصفحة غير متوفرة.';
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() {
        _loading = false;
        _error = 'فشل تحميل المحتوى';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(widget.title, style: const TextStyle(fontSize: 18)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      (_content ?? '').replaceAll(r'\n', '\n').replaceAll('<strong>', '').replaceAll('</strong>', '').replaceAll('<br>', '\n').replaceAll('&bull;', '•'),
                      style: const TextStyle(fontSize: 15, height: 1.6),
                    ),
                  ),
      ),
    );
  }
}

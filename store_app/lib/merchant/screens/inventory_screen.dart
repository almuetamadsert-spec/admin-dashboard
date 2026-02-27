import 'package:flutter/material.dart';
import '../../api/merchant_api.dart';
import '../../config.dart';
import '../../theme/app_theme.dart';
import 'inventory_add_screen.dart';
import 'inventory_detail_screen.dart';

/// صفحة المخزون الرئيسية: بطاقات المنتجات المضافة، بحث، زر إضافة منتجات.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<MerchantInventoryItem> _items = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await MerchantApi.getInventory();
      if (mounted) setState(() { _items = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _imageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    final base = Config.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/uploads/${path.replaceFirst(RegExp(r'^\/+'), '')}';
  }

  List<MerchantInventoryItem> get _filtered => _search.trim().isEmpty
      ? _items
      : _items.where((i) => i.nameAr.toLowerCase().contains(_search.toLowerCase().trim())).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'بحث عن منتج',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                            ),
                            onChanged: (v) => setState(() => _search = v),
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _load,
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: _filtered.length,
                              itemBuilder: (context, i) {
                                final item = _filtered[i];
                                final url = _imageUrl(item.imagePath);
                                return Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: InkWell(
                                    onTap: () async {
                                      final ok = await Navigator.push<bool>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (ctx) => InventoryDetailScreen(item: item),
                                        ),
                                      );
                                      if (ok == true) _load();
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                            child: url.isEmpty
                                                ? Icon(Icons.image_not_supported, size: 48, color: Colors.grey.shade400)
                                                : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: Colors.grey.shade400)),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.nameAr,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const Text('المخزون', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                                  Text(
                                                    '${item.quantity}',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: item.quantity == 1 ? Colors.red : Colors.black,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
      floatingActionButton: _items.isNotEmpty || !_loading
          ? FloatingActionButton.extended(
              onPressed: () async {
                final ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (ctx) => const InventoryAddScreen()),
                );
                if (ok == true) _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('إضافة منتجات'),
              backgroundColor: kPrimaryBlue,
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'لا توجد منتجات في مخزونك',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'أضف المنتجات المتوفرة لديك لبدء إدارة المخزون',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                final ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (ctx) => const InventoryAddScreen()),
                );
                if (ok == true) _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('إضافة المنتجات المتوفرة لديك'),
              style: FilledButton.styleFrom(
                backgroundColor: kPrimaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

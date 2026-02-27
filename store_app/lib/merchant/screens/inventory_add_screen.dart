import 'package:flutter/material.dart';
import '../../api/merchant_api.dart';
import '../../config.dart';
import '../../theme/app_theme.dart';

/// إضافة منتجات للمخزون: تصنيفات، براندات، بحث، بطاقات منتجات مع + وكمية، زر حفظ.
class InventoryAddScreen extends StatefulWidget {
  const InventoryAddScreen({super.key});

  @override
  State<InventoryAddScreen> createState() => _InventoryAddScreenState();
}

class _InventoryAddScreenState extends State<InventoryAddScreen> {
  List<MerchantCategory> _categories = [];
  List<MerchantBrandCategory> _brands = [];
  List<MerchantProduct> _products = [];
  final Map<int, int> _quantities = {}; // productId -> quantity to add
  bool _loading = true;
  String _search = '';
  int? _selectedCategoryId;
  String? _selectedCompany;
  bool _saving = false;

  Future<void> _loadCategoriesAndBrands() async {
    try {
      final results = await Future.wait([
        MerchantApi.getCategories(),
        MerchantApi.getBrandCategories(),
      ]);
      if (mounted) setState(() {
        _categories = results[0] as List<MerchantCategory>;
        _brands = results[1] as List<MerchantBrandCategory>;
      });
    } catch (_) {}
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    try {
      final list = await MerchantApi.getProductsForInventory(
        categoryId: _selectedCategoryId,
        company: _selectedCompany,
        q: _search.trim().isEmpty ? null : _search.trim(),
      );
      if (mounted) setState(() { _products = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCategoriesAndBrands().then((_) => _loadProducts());
  }

  String _imageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    final base = Config.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/uploads/${path.replaceFirst(RegExp(r'^\/+'), '')}';
  }

  int _getQty(int productId) => _quantities[productId] ?? 0;

  void _setQty(int productId, int qty) {
    setState(() {
      if (qty <= 0) _quantities.remove(productId); else _quantities[productId] = qty;
    });
  }

  Future<void> _save() async {
    final items = _quantities.entries.where((e) => e.value > 0).map((e) => {'product_id': e.key, 'quantity': e.value}).toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف كمية لواحد على الأقل من المنتجات')));
      return;
    }
    setState(() => _saving = true);
    try {
      await MerchantApi.saveInventory(items);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المخزون')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إضافة المنتجات المتوفرة'),
          leading: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => Navigator.pop(context)),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'بحث عن منتج',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
                onChanged: (v) { setState(() => _search = v); _loadProducts(); },
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('الكل'),
                    selected: _selectedCategoryId == null && _selectedCompany == null,
                    onSelected: (_) { setState(() { _selectedCategoryId = null; _selectedCompany = null; }); _loadProducts(); },
                  ),
                  ..._categories.map((c) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: FilterChip(
                      label: Text(c.nameAr),
                      selected: _selectedCategoryId == c.id,
                      onSelected: (_) { setState(() { _selectedCategoryId = c.id; _selectedCompany = null; }); _loadProducts(); },
                    ),
                  )),
                  ..._brands.map((b) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: FilterChip(
                      label: Text(b.nameAr),
                      selected: _selectedCompany == b.nameAr,
                      onSelected: (_) { setState(() { _selectedCompany = b.nameAr; _selectedCategoryId = null; }); _loadProducts(); },
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _products.isEmpty
                      ? const Center(child: Text('لا توجد منتجات'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _products.length,
                          itemBuilder: (context, i) {
                            final p = _products[i];
                            final qty = _getQty(p.id);
                            final url = _imageUrl(p.imagePath);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: url.isEmpty
                                          ? SizedBox(width: 64, height: 64, child: Icon(Icons.image_not_supported, color: Colors.grey.shade400))
                                          : Image.network(url, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 64, height: 64, child: Icon(Icons.broken_image))),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle_outline),
                                                onPressed: qty > 0 ? () => _setQty(p.id, qty - 1) : null,
                                                color: kPrimaryBlue,
                                              ),
                                              Text('${qty}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                              IconButton(
                                                icon: const Icon(Icons.add_circle_outline),
                                                onPressed: () => _setQty(p.id, qty + 1),
                                                color: kPrimaryBlue,
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: kPrimaryBlue, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _saving ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('حفظ'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

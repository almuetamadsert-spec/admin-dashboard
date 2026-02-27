import 'package:flutter/material.dart';
import '../../api/merchant_api.dart';
import '../../config.dart';
import '../../theme/app_theme.dart';

/// تفاصيل منتج في المخزون: صورة، وصف، المخزون، زر إضافة مخزون (+)، زر حذف المنتج.
class InventoryDetailScreen extends StatefulWidget {
  final MerchantInventoryItem item;

  const InventoryDetailScreen({super.key, required this.item});

  @override
  State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  late int _quantity;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _quantity = widget.item.quantity;
  }

  String _imageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    final base = Config.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/uploads/${path.replaceFirst(RegExp(r'^\/+'), '')}';
  }

  Future<void> _saveQuantity() async {
    if (_quantity == widget.item.quantity) return;
    setState(() => _loading = true);
    try {
      await MerchantApi.saveInventory([{'product_id': widget.item.productId, 'quantity': _quantity}]);
      if (mounted) setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث المخزون')));
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  Future<void> _deleteProduct() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المنتج من المخزون'),
        content: const Text('هل تريد إزالة هذا المنتج من مخزونك؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _loading = true);
    try {
      await MerchantApi.deleteInventoryProduct(widget.item.productId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _imageUrl(widget.item.imagePath);
    final description = widget.item.longDescription ?? widget.item.shortDescription ?? '—';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.item.nameAr),
          leading: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => Navigator.pop(context)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (url.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(url, height: 220, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 220, child: Icon(Icons.broken_image, size: 48))),
                      )
                    else
                      Container(height: 220, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey.shade600)),
                    const SizedBox(height: 16),
                    Text(description, style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('المخزون لديك', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '$_quantity',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _quantity == 1 ? Colors.red : Colors.black),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('أضف مخزونك', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 32),
                          onPressed: _quantity > 0 ? () => setState(() => _quantity--) : null,
                          color: kPrimaryBlue,
                        ),
                        Text('$_quantity', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 32),
                          onPressed: () => setState(() => _quantity++),
                          color: kPrimaryBlue,
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _saveQuantity,
                          style: FilledButton.styleFrom(backgroundColor: kPrimaryBlue),
                          child: const Text('حفظ الكمية'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _deleteProduct,
                        icon: const Icon(Icons.delete_outline, size: 20),
                        label: const Text('حذف المنتج من المخزون'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 12)),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

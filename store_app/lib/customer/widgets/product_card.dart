import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../config.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final ProductCardLayout layout;
  final void Function(Product)? onTap;
  final void Function(Product)? onAddToCart;
  final VoidCallback? onBuyNow;

  const ProductCard({
    super.key,
    required this.product,
    required this.layout,
    this.onTap,
    this.onAddToCart,
    this.onBuyNow,
  });

  String _imageUrl() {
    if (product.imagePath == null || product.imagePath!.isEmpty) return '';
    final base = Config.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/uploads/${product.imagePath!.replaceFirst(RegExp(r'^\/+'), '')}';
  }

  Color _colorFromHex(String hex, [Color defaultColor = Colors.white]) {
    if (hex.isEmpty) return defaultColor;
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    final n = int.tryParse(h, radix: 16);
    if (n == null) return defaultColor;
    return Color(n);
  }

  TextAlign _textAlignFrom(String align) {
    switch (align) {
      case 'left': return TextAlign.left;
      case 'center': return TextAlign.center;
      case 'right': return TextAlign.right;
      default: return TextAlign.right;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl();
    final hasDiscount = product.finalPrice < product.price;
    final cardColor = _colorFromHex(layout.bgColor, context.theme.cardColor);
    final btnColor = _colorFromHex(layout.addBtnColor.isEmpty ? '#14ACEC' : layout.addBtnColor);
    final isDark = context.isDark;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: (cardColor == Colors.white || cardColor == const Color(0xFFFFFFFF)) && isDark ? context.theme.cardColor : cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(layout.borderRadius),
        side: BorderSide(color: isDark ? kDarkBorder : kCardBorder, width: 0.8),
      ),
      margin: const EdgeInsets.all(4),
      child: InkWell(
        onTap: onTap != null ? () => onTap!(product) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isEmpty
                      ? Container(
                          color: isDark ? kDarkSurface : kSectionBg,
                          child: Icon(Icons.image_not_supported, size: 40, color: isDark ? kDarkTextSecondary : kTextSecondary),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: isDark ? kDarkSurface : kSectionBg,
                            child: Icon(Icons.broken_image, size: 40, color: isDark ? kDarkTextSecondary : kTextSecondary),
                          ),
                        ),
                  if (hasDiscount)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                        child: const Text('عرض', style: TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   if (layout.brandPosition == 'top' && product.company != null && product.company!.isNotEmpty)
                    Text(
                      product.company!,
                      textAlign: _textAlignFrom(layout.brandAlign),
                      style: TextStyle(fontSize: 10, color: isDark ? kDarkTextSecondary : Colors.grey.shade500),
                    ),
                  
                  Row(
                    children: [
                      if (layout.brandPosition == 'left' && product.company != null && product.company!.isNotEmpty)
                        Text(
                          product.company!,
                          style: TextStyle(fontSize: 10, color: context.colors.primary, fontWeight: FontWeight.bold),
                        ),
                      if (layout.brandPosition == 'left') const SizedBox(width: 4),
                      
                      Expanded(
                        child: Text(
                          product.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: _textAlignFrom(layout.nameAlign),
                          style: context.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      
                      if (layout.brandPosition == 'right' && product.company != null && product.company!.isNotEmpty)
                        const SizedBox(width: 4),
                      if (layout.brandPosition == 'right' && product.company != null && product.company!.isNotEmpty)
                        Text(
                          product.company!,
                          style: TextStyle(fontSize: 10, color: context.colors.primary, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),

                  if (layout.brandPosition == 'bottom' && product.company != null && product.company!.isNotEmpty)
                    Text(
                      product.company!,
                      textAlign: _textAlignFrom(layout.brandAlign),
                      style: TextStyle(fontSize: 10, color: isDark ? kDarkTextSecondary : Colors.grey.shade500),
                    ),

                  const SizedBox(height: 4),
                  
                  Wrap(
                    alignment: layout.priceAlign == 'center' ? WrapAlignment.center : (layout.priceAlign == 'left' ? WrapAlignment.start : WrapAlignment.end),
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${product.finalPrice.toStringAsFixed(0)} د.ل',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _colorFromHex(layout.priceColor, context.colors.primary), // Applied color from layout
                          fontSize: 13,
                        ),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${product.price.toStringAsFixed(0)} د.ل',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? kDarkTextSecondary : kTextSecondary,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),

                  if (layout.stockStyle == 'text')
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        product.stock > 0 ? 'متوفر' : 'نفد',
                        textAlign: _textAlignFrom(layout.nameAlign),
                        style: TextStyle(
                          fontSize: 10,
                          color: product.stock > 0 
                               ? _colorFromHex(layout.stockColorAv, Colors.green) 
                               : _colorFromHex(layout.stockColorOut, Colors.red)
                        ),
                      ),
                    )
                  else if (layout.stockStyle == 'number' || (layout.stockStyle == 'none' && layout.showStock))
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'المخزون: ${product.stock}',
                        textAlign: _textAlignFrom(layout.nameAlign),
                        style: TextStyle(
                          fontSize: 10,
                          color: product.stock > 0 
                               ? _colorFromHex(layout.stockColorAv, Colors.green) 
                               : _colorFromHex(layout.stockColorOut, Colors.red)
                        ),
                      ),
                    ),

                  if (layout.showAddToCart || layout.showBuyNow) 
                    _buildButtons(context, btnColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtons(BuildContext context, Color btnColor) {
    final br = layout.addBtnStyle == 'sharp'
        ? BorderRadius.zero
        : layout.addBtnStyle == 'full_rounded'
            ? BorderRadius.circular(24)
            : BorderRadius.circular(8);
    final shape = RoundedRectangleBorder(borderRadius: br);
    final padding = layout.addBtnStyle == 'small_rounded' ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6) : const EdgeInsets.symmetric(horizontal: 16, vertical: 8);

    final bool hasBoth = layout.showAddToCart && layout.showBuyNow;

    Widget cartBtn = FilledButton.icon(
      onPressed: product.stock > 0 && onAddToCart != null
          ? () => onAddToCart!(product)
          : null,
      icon: const Icon(Icons.add_shopping_cart, size: 14),
      label: const Text('إضافة'),
      style: FilledButton.styleFrom(
        backgroundColor: _colorFromHex(layout.addBtnColor, btnColor),
        foregroundColor: Colors.white,
        padding: padding,
        minimumSize: Size.zero,
        shape: shape,
        textStyle: const TextStyle(fontSize: 11),
      ),
    );

    Widget buyBtn = FilledButton.icon(
      onPressed: product.stock > 0 && onBuyNow != null
          ? onBuyNow
          : null,
      icon: const Icon(Icons.shopping_bag, size: 14),
      label: const Text('شراء'),
      style: FilledButton.styleFrom(
        backgroundColor: _colorFromHex(layout.buyNowColor, Colors.orange),
        foregroundColor: Colors.white,
        padding: padding,
        minimumSize: Size.zero,
        shape: shape,
        textStyle: const TextStyle(fontSize: 11),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          if (layout.showAddToCart) Expanded(child: cartBtn),
          if (hasBoth) const SizedBox(width: 4),
          if (layout.showBuyNow) Expanded(child: buyBtn),
        ],
      ),
    );
  }
}

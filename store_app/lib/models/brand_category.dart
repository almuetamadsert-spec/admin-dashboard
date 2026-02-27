/// تصنيف براند — يظهر في "تصنيفات البراندات" مع أيقونة من الجهاز.
class BrandCategory {
  final int id;
  final String nameAr;
  final String? iconPath;
  final String? iconUrl;
  final String iconSize; // small | medium | large
  final String iconCorner; // sharp | rounded | medium
  final String iconShape; // square | rectangle
  final String iconColor;
  final int sortOrder;

  BrandCategory({
    required this.id,
    required this.nameAr,
    this.iconPath,
    this.iconUrl,
    this.iconSize = 'medium',
    this.iconCorner = 'rounded',
    this.iconShape = 'square',
    this.iconColor = '#06A3E7',
    this.sortOrder = 0,
  });

  String get displayName => nameAr;

  factory BrandCategory.fromJson(Map<String, dynamic> json) {
    return BrandCategory(
      id: (json['id'] as num).toInt(),
      nameAr: (json['name_ar'] as String? ?? '').trim(),
      iconPath: (json['icon_path'] as String?)?.trim(),
      iconUrl: (json['icon_url'] as String?)?.trim(),
      iconSize: (json['icon_size'] as String? ?? 'medium').trim(),
      iconCorner: (json['icon_corner'] as String? ?? 'rounded').trim(),
      iconShape: (json['icon_shape'] as String? ?? 'square').trim(),
      iconColor: (json['icon_color'] as String? ?? '#06A3E7').trim(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

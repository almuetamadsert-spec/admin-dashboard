class Category {
  final int id;
  final String nameAr;
  final String? nameEn;
  final String iconType; // circle | rounded | sharp
  final String? iconName;
  final String iconColor; // لون المحيط (أو transparent)
  final String? iconSymbolColor; // لون الرمز
  final int iconOpacity; // 0-100 شفافية المحيط فقط
  final String? iconPath;

  Category({
    required this.id,
    required this.nameAr,
    this.nameEn,
    this.iconType = 'circle',
    this.iconName,
    this.iconColor = '#14acec',
    this.iconSymbolColor,
    this.iconOpacity = 100,
    this.iconPath,
  });

  String get displayName => nameAr.isNotEmpty ? nameAr : (nameEn ?? '');

  factory Category.fromJson(Map<String, dynamic> json) {
    final rawIconName = json['icon_name'] as String?;
    final iconName = (rawIconName != null && rawIconName.trim().isNotEmpty) ? rawIconName.trim() : null;
    return Category(
      id: (json['id'] as num).toInt(),
      nameAr: (json['name_ar'] as String? ?? '').trim(),
      nameEn: (json['name_en'] as String?)?.trim(),
      iconType: (json['icon_type'] as String? ?? 'circle').trim(),
      iconName: iconName,
      iconColor: (json['icon_color'] as String? ?? '#14acec').trim(),
      iconSymbolColor: (json['icon_symbol_color'] as String?)?.trim(),
      iconOpacity: (json['icon_opacity'] as num?)?.toInt() ?? 100,
      iconPath: (json['icon_path'] as String?)?.trim(),
    );
  }
}

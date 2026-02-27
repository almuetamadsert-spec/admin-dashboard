import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';

import '../models/category.dart';

/// تحويل لون هيكس إلى Color (يدعم الشفافية عبر alpha)
Color colorFromHex(String hex, {double opacity = 1.0}) {
  if (hex.isEmpty || hex == 'transparent') return Colors.transparent;
  String h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  final n = int.tryParse(h, radix: 16);
  if (n == null) return const Color(0xFF06A3E7).withOpacity(opacity);
  return Color(n).withOpacity(opacity);
}

/// ربط رمز الأيقونة (من لوحة التحكم) بأيقونة Bootstrap نفسها المستخدمة في اللوحة
IconData iconDataFromName(String? iconName) {
  switch (iconName) {
    // مطابق تماماً لـ ICON_PRESETS في routes/categories.js (icon: 'bi-xxx')
    case 'case_cover': return BootstrapIcons.phone;
    case 'screen_protector': return BootstrapIcons.phone_vibrate;
    case 'camera_lens_protector': return BootstrapIcons.camera;
    case 'phone_grip': return BootstrapIcons.phone;
    case 'phone_strap': return BootstrapIcons.phone;
    case 'wall_charger': return BootstrapIcons.plug;
    case 'charging_cable': return BootstrapIcons.lightning_charge;
    case 'power_bank': return BootstrapIcons.battery_charging;
    case 'wireless_charging_pad': return BootstrapIcons.broadcast;
    case 'car_charger': return BootstrapIcons.car_front;
    case 'wired_earphones': return BootstrapIcons.headphones;
    case 'wireless_earbuds': return BootstrapIcons.headphones;
    case 'bluetooth_speaker': return BootstrapIcons.speaker;
    case 'audio_adapter': return BootstrapIcons.usb_symbol;
    case 'tripod': return BootstrapIcons.camera;
    case 'selfie_stick': return BootstrapIcons.camera;
    case 'gimbal': return BootstrapIcons.camera_video;
    case 'ring_light': return BootstrapIcons.brightness_high;
    case 'stylus_pen': return BootstrapIcons.pencil;
    case 'car_phone_holder': return BootstrapIcons.phone;
    case 'desktop_stand': return BootstrapIcons.display;
    case 'aux_cable': return BootstrapIcons.music_note_beamed;
    case 'power_bank_portable': return BootstrapIcons.battery_charging;
    case 'solar_power_bank': return BootstrapIcons.sun;
    case 'portable_power_station': return BootstrapIcons.lightning_charge;
    case 'dslr_camera': return BootstrapIcons.camera;
    case 'action_camera': return BootstrapIcons.camera_video;
    case 'security_camera': return BootstrapIcons.camera_video;
    case 'external_phone_lenses': return BootstrapIcons.camera;
    case 'smartwatch': return BootstrapIcons.smartwatch;
    // قديم (للتوافق مع تصنيفات سابقة)
    case 'bluetooth_headphones': return BootstrapIcons.headphones;
    case 'chargers': return BootstrapIcons.battery_charging;
    case 'watches': return BootstrapIcons.smartwatch;
    case 'speakers': return BootstrapIcons.speaker;
    case 'phone_holders': return BootstrapIcons.phone;
    case 'phone_stands': return BootstrapIcons.phone;
    case 'charging_cables': return BootstrapIcons.lightning_charge;
    case 'cases': return BootstrapIcons.phone;
    case 'powerbank': return BootstrapIcons.battery_charging;
    case 'cameras': return BootstrapIcons.camera;
    case 'mics': return BootstrapIcons.mic;
    case 'playstation_controller': return BootstrapIcons.controller;
    case 'smart_screens': return BootstrapIcons.tv;
    case 'flash_memory': return BootstrapIcons.usb_symbol;
    case 'memory_card': return BootstrapIcons.sd_card;
    default: return BootstrapIcons.grid_3x3; // شبكة كافتراضي بدل المثلث
  }
}

/// استنتاج الأيقونة من اسم التصنيف عند غياب icon_name أو عدم تطابقه (تصنيفات قديمة)
IconData iconDataFromCategoryName(String? nameAr) {
  if (nameAr == null || nameAr.isEmpty) return BootstrapIcons.smartwatch;
  final n = nameAr.trim();
  if (n.contains('ساعة')) return BootstrapIcons.smartwatch;
  if (n.contains('سبيكر') || n.contains('مكبر') || n.contains('سبيكرات')) return BootstrapIcons.speaker;
  if (n.contains('سماع')) return BootstrapIcons.headphones;
  if (n == 'ش' || n.contains('شاحن') || n.contains('شواحن') || n.contains('باور')) return BootstrapIcons.battery_charging;
  if (n.contains('كفر') || n.contains('غطاء') || n.contains('كفرات')) return BootstrapIcons.phone;
  if (n.contains('كابل') || n.contains('سلك')) return BootstrapIcons.lightning_charge;
  if (n.contains('كاميرا')) return BootstrapIcons.camera;
  if (n.contains('حامل') || n.contains('ستند')) return BootstrapIcons.phone;
  if (n.contains('لاصق') || n.contains('حماية')) return BootstrapIcons.phone_vibrate;
  if (n.contains('مايك') || n.contains('ميك')) return BootstrapIcons.mic;
  if (n.contains('تلفزيون') || n.contains('شاشة')) return BootstrapIcons.tv;
  if (n.contains('لعب') || n.contains('دراع')) return BootstrapIcons.controller;
  if (n.contains('فلاش') || n.contains('ميموري') || n.contains('usb')) return BootstrapIcons.usb_symbol;
  return BootstrapIcons.smartwatch;
}

/// أيقونة التصنيف: من icon_name أولاً (Bootstrap نفس اللوحة)، وإلا من اسم التصنيف
IconData categoryIcon(Category c) {
  if (c.iconName != null && c.iconName!.trim().isNotEmpty) {
    final icon = iconDataFromName(c.iconName);
    if (icon != BootstrapIcons.grid_3x3) return icon;
  }
  return iconDataFromCategoryName(c.nameAr);
}

/// نصف قطر الزوايا حسب شكل الأيقونة
double borderRadiusForType(String iconType) {
  switch (iconType) {
    case 'sharp': return 0;
    case 'rounded': return 12;
    case 'circle':
    default: return 26; // دائري = نصف العرض
  }
}

/// هل الشكل دائري؟
bool isCircleShape(String iconType) => iconType == 'circle';

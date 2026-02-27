import 'package:flutter/material.dart';

/// لون واجهة العميل — المعتمد
const Color kPrimaryBlue = Color(0xFF06A3E7);

/// لمسة ذهبية للشعار والعناصر المميزة
const Color kGold = Color(0xFFD4AF37);

/// فضية للظلال والنصوص الثانوية
const Color kSilver = Color(0xFFC0C0C0);

/// خلفية البطاقات والسلايدر البنفسجي
const Color kBannerPurple = Color(0xFF6B4E9B);

extension AppTheme on BuildContext {
  ThemeData get appTheme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
}

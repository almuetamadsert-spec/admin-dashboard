import 'package:flutter/material.dart';

// ─── ألوان هوية المعتمد الرسمية ───────────────────────────────────────────

const Color kPrimaryBlue = Color(0xFF14ACEC);
const Color kPrimaryBlueDark = Color(0xFF1298D4);
const Color kBodyBg = Color(0xFFFFFFFF);
const Color kSectionBg = Color(0xFFF8F9FA);
const Color kTextPrimary = Color(0xFF212529);
const Color kTextSecondary = Color(0xFF495057);
const Color kCardBorder = Color(0xFFE9ECEF);
const Color kCardBg = Color(0xFFFFFFFF);

const Color kSuccess = Color(0xFF28A745);
const Color kWarning = Color(0xFFFFC107);
const Color kDanger = Color(0xFFDC3545);
const Color kGold = Color(0xFFD4AF37);
const Color kSilver = Color(0xFFC0C0C0);

// ─── الألوان المخصصة للوضع الليلي ──────────────────────────────────────────

const Color kDarkBg = Color(0xFF121212);
const Color kDarkSurface = Color(0xFF1E1E1E);
const Color kDarkCard = Color(0xFF252525);
const Color kDarkBorder = Color(0xFF333333);
const Color kDarkTextPrimary = Color(0xFFE9ECEF);
const Color kDarkTextSecondary = Color(0xFFAAAAAA);

// ─── مولد الثيمات ────────────────────────────────────────────────────────

class AppThemes {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kPrimaryBlue,
        primary: kPrimaryBlue,
        onPrimary: Colors.white,
        surface: kBodyBg,
        onSurface: kTextPrimary,
        surfaceContainerLowest: kSectionBg,
      ),
      scaffoldBackgroundColor: kBodyBg,
      cardColor: kCardBg,
      dividerColor: kCardBorder,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: kTextPrimary),
        bodyMedium: TextStyle(color: kTextPrimary),
        bodySmall: TextStyle(color: kTextSecondary),
        titleLarge: TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: kTextPrimary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kBodyBg,
        foregroundColor: kTextPrimary,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: kPrimaryBlue,
        onPrimary: Colors.white,
        surface: kDarkBg,
        onSurface: kDarkTextPrimary,
        surfaceContainerLowest: kDarkSurface,
      ),
      scaffoldBackgroundColor: kDarkBg,
      cardColor: kDarkCard,
      dividerColor: kDarkBorder,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: kDarkTextPrimary),
        bodyMedium: TextStyle(color: kDarkTextPrimary),
        bodySmall: TextStyle(color: kDarkTextSecondary),
        titleLarge: TextStyle(color: kDarkTextPrimary, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: kDarkTextPrimary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kDarkBg,
        foregroundColor: kDarkTextPrimary,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}

extension AppThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

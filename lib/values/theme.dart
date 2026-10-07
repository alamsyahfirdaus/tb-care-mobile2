import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:apk_tb_care/values/colors.dart';

/// Konfigurasi tema global terpusat untuk aplikasi TB Care.
/// Menyediakan standardisasi AppBarTheme untuk seluruh halaman.
class AppTheme {
  // Standar AppBar TB Care
  static const double appBarFontSize = 18.0;
  static const FontWeight appBarFontWeight = FontWeight.w600;
  static const double appBarIconSize = 24.0;
  static const double appBarElevation = 0.0;

  /// Gaya teks judul AppBar terpusat:
  /// GoogleFonts.plusJakartaSans, 18px, FontWeight.w600, Colors.white
  static final TextStyle appBarTitleTextStyle = GoogleFonts.plusJakartaSans(
    fontSize: appBarFontSize,
    fontWeight: appBarFontWeight,
    color: Colors.white,
  );

  /// AppBarTheme standar untuk seluruh halaman aplikasi TB Care
  static final AppBarTheme appBarTheme = AppBarTheme(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    elevation: appBarElevation,
    scrolledUnderElevation: 0,
    centerTitle: false,
    iconTheme: const IconThemeData(
      color: Colors.white,
      size: appBarIconSize,
    ),
    actionsIconTheme: const IconThemeData(
      color: Colors.white,
      size: appBarIconSize,
    ),
    titleTextStyle: appBarTitleTextStyle,
  );

  /// ThemeData global aplikasi TB Care
  static final ThemeData theme = ThemeData(
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: Colors.amber,
    ),
    appBarTheme: appBarTheme,
  );
}

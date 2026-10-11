import 'package:flutter/material.dart';

/// Central color palette and text styling for the Almamoura Film Festival app.
class AppColors {
  AppColors._();

  static const cream = Color(0xFFFBF3E3);
  static const sand = Color(0xFFF5E6C8);
  static const gold = Color(0xFF9C7A1E);
  static const ink = Color(0xFF161311);
  static const charcoal = Color(0xFF1F1B18);
  static const muted = Color(0xFF7A7368);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scaffoldColor = isDark ? AppColors.ink : AppColors.cream;
    final onSurface = isDark ? AppColors.cream : AppColors.ink;

    final base = ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldColor,
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: onSurface,
        onPrimary: scaffoldColor,
        secondary: AppColors.gold,
        onSecondary: AppColors.ink,
        error: Colors.redAccent,
        onError: Colors.white,
        surface: isDark ? AppColors.charcoal : Colors.white,
        onSurface: onSurface,
      ),
      textTheme: (isDark ? ThemeData.dark() : ThemeData.light()).textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldColor,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      dividerColor: onSurface.withValues(alpha: 0.1),
    );
    return base;
  }
}

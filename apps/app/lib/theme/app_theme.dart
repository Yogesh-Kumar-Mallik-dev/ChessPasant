import 'package:flutter/material.dart';

/// Authentic Studio Noir Monochrome Theme Tokens
/// Exactly matching apps/web/src/app.css and NativeDashboard.svelte
class AppColors {
  AppColors._();

  // Canvas & Surfaces
  static const Color background = Color(0xFF0F0F12);
  static const Color surfaceCard = Color(0xFF18181D);
  static const Color surfacePanel = Color(0xFF1F1F25);
  static const Color surfaceHover = Color(0xFF26262E);

  // Borders & Dividers
  static const Color border = Color(0xFF292931);
  static const Color borderSubtle = Color(0xFF33333D);
  static const Color borderProminent = Color(0xFF444450);

  // Typography
  static const Color textPrimary = Color(0xFFFAFAFA);
  static const Color textMuted = Color(0xFFA1A1AA);
  static const Color textSecondary = Color(0xFF71717A);

  // Brand Accents
  static const Color amber = Color(0xFFFBBF24);
  static const Color green = Color(0xFF22C55E);
  static const Color red = Color(0xFFEF4444);

  // Board Squares (Monochrome)
  static const Color boardLight = Color(0xFFF4F4F6);
  static const Color boardDark = Color(0xFF30323D);
  static const Color boardSelected = Color(0x59FBBF24);
  static const Color boardLastMove = Color(0x38FBBF24);
  static const Color boardHint = Color(0x40FBBF24);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    cardColor: AppColors.surfaceCard,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.surfaceCard,
      primary: AppColors.textPrimary,
      onPrimary: AppColors.background,
      secondary: AppColors.surfacePanel,
      onSecondary: AppColors.textPrimary,
      outline: AppColors.border,
      error: AppColors.red,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surfaceCard,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.borderSubtle,
      thickness: 1,
      space: 1,
    ),
    fontFamily: 'Roboto',
  );
}

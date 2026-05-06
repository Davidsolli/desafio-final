import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Acessa as cores do tema atual via BuildContext.
/// Uso: context.colors.background, context.colors.surface, etc.
class ThemeColors {
  final bool isDark;
  const ThemeColors(this.isDark);

  Color get background => isDark ? AppColors.background : AppColors.lightBackground;
  Color get surface => isDark ? AppColors.surface : AppColors.lightSurface;
  Color get surfaceLight => isDark ? AppColors.surfaceLight : AppColors.lightSurfaceLight;
  Color get surfaceLighter => isDark ? AppColors.surfaceLighter : AppColors.lightSurfaceLighter;
  Color get secondary => isDark ? AppColors.secondary : AppColors.lightSecondary;
  Color get secondaryDark => isDark ? AppColors.secondaryDark : AppColors.lightSecondaryDark;
  Color get textPrimary => isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get textSecondary => isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
  Color get textMuted => isDark ? AppColors.textMuted : AppColors.lightTextMuted;
  Color get border => isDark ? AppColors.border : AppColors.lightBorder;
  Color get borderLight => isDark ? AppColors.borderLight : AppColors.lightBorderLight;

  // Compartilhadas (invariáveis entre temas)
  Color get primary => AppColors.primary;
  Color get primaryDark => AppColors.primaryDark;
  Color get primaryLight => AppColors.primaryLight;
  Color get accentInfo => AppColors.accentInfo;
  Color get accentWarning => AppColors.accentWarning;
  Color get accentSuccess => AppColors.accentSuccess;
  Color get accentError => AppColors.accentError;
}

extension ThemeColorsX on BuildContext {
  ThemeColors get colors => ThemeColors(Theme.of(this).brightness == Brightness.dark);
}

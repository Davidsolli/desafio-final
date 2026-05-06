import 'package:flutter/material.dart';

class AppColors {
  // ── Compartilhadas (iguais em ambos os temas) ─────────────────────────────
  static const Color primary = Color(0xFF3dba5e);
  static const Color primaryDark = Color(0xFF2d8a47);
  static const Color primaryLight = Color(0xFF5ed97a);

  static const Color accent = Color(0xFF3dba5e);
  static const Color accentInfo = Color(0xFF4db8ff);
  static const Color accentWarning = Color(0xFFffc84d);
  static const Color accentSuccess = Color(0xFF3dba5e);
  static const Color accentError = Color(0xFFff6b6b);

  static const Color chartColor1 = Color(0xFF3dba5e);
  static const Color chartColor2 = Color(0xFF4db8ff);
  static const Color chartColor3 = Color(0xFFffc84d);
  static const Color chartColor4 = Color(0xFFd977ff);
  static const Color chartColor5 = Color(0xFFff6b6b);

  static const LinearGradient gradientPrimary = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Tema Escuro ───────────────────────────────────────────────────────────
  static const Color background = Color(0xFF0a0e1a);
  static const Color surface = Color(0xFF12161f);
  static const Color surfaceLight = Color(0xFF1a1f2e);
  static const Color surfaceLighter = Color(0xFF23293d);
  static const Color secondary = Color(0xFF2d3b52);
  static const Color secondaryDark = Color(0xFF1f2835);
  static const Color textPrimary = Color(0xFFf5f5f5);
  static const Color textSecondary = Color(0xFF8c95a0);
  static const Color textMuted = Color(0xFF5a6370);
  static const Color border = Color(0xFF2d3b52);
  static const Color borderLight = Color(0xFF3d4b62);

  // ── Tema Claro ────────────────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLight = Color(0xFFF0F4F8);
  static const Color lightSurfaceLighter = Color(0xFFE8EDF5);
  static const Color lightSecondary = Color(0xFFEEF2F7);
  static const Color lightSecondaryDark = Color(0xFFE0E8F2);
  static const Color lightTextPrimary = Color(0xFF1A1D2E);
  static const Color lightTextSecondary = Color(0xFF5B6475);
  static const Color lightTextMuted = Color(0xFF9AA3AD);
  static const Color lightBorder = Color(0xFFDDE3EE);
  static const Color lightBorderLight = Color(0xFFE8EDF5);
}

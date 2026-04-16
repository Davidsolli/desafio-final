import 'package:flutter/material.dart';

class AppColors {
  // Fundo e superfícies
  static const Color background = Color(0xFF0a0e1a);
  static const Color surface = Color(0xFF12161f);
  static const Color surfaceLight = Color(0xFF1a1f2e);
  static const Color surfaceLighter = Color(0xFF23293d);

  // Primária (Verde)
  static const Color primary = Color(0xFF3dba5e);
  static const Color primaryDark = Color(0xFF2d8a47);
  static const Color primaryLight = Color(0xFF5ed97a);

  // Secundária
  static const Color secondary = Color(0xFF2d3b52);
  static const Color secondaryDark = Color(0xFF1f2835);

  // Acentos
  static const Color accent = Color(0xFF3dba5e);
  static const Color accentInfo = Color(0xFF4db8ff);
  static const Color accentWarning = Color(0xFFffc84d);
  static const Color accentSuccess = Color(0xFF3dba5e);
  static const Color accentError = Color(0xFFff6b6b);

  // Texto
  static const Color textPrimary = Color(0xFFf5f5f5);
  static const Color textSecondary = Color(0xFF8c95a0);
  static const Color textMuted = Color(0xFF5a6370);

  // Borda
  static const Color border = Color(0xFF2d3b52);
  static const Color borderLight = Color(0xFF3d4b62);

  // Gradientes
  static const LinearGradient gradientPrimary = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Chart colors
  static const Color chartColor1 = Color(0xFF3dba5e); // Verde
  static const Color chartColor2 = Color(0xFF4db8ff); // Azul
  static const Color chartColor3 = Color(0xFFffc84d); // Amarelo
  static const Color chartColor4 = Color(0xFFd977ff); // Roxo
  static const Color chartColor5 = Color(0xFFff6b6b); // Vermelho
}

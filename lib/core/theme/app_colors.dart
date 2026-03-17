import 'package:flutter/material.dart';

abstract final class AppColors {
  // ─── Base Palette ────────────────────────────────────────────────
  static const Color black = Color(0xFF1E1E1E);
  static const Color white = Color(0xFFFFFFFF);
  static const Color transparent = Color(0x00000000);
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);

  // ─── Brand Colors ────────────────────────────────────────────────
  static const Color brandBackground = Color(0xFFECE2D5);

  // ─── Light Theme ─────────────────────────────────────────────────
  static const Color background = white;
  static const Color surface = white;
  static const Color secondarySurface = gray100;
  static const Color border = black;
  static const Color textPrimary = black;
  static const Color textSecondary = gray600;
  static const Color textTertiary = gray400;

  // ─── Dark Theme ──────────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color secondarySurfaceDark = Color(0xFF2C2C2C);
  static const Color borderDark = gray200;
  static const Color textPrimaryDark = gray200;
  static const Color textSecondaryDark = Color(0xFFA3A3A3);
  static const Color textTertiaryDark = Color(0xFF737373);

  // ─── Solid Pastel Shadows (Neobrutalism signatures) ──────────────
  static const Color shadowMint = Color(0xFFB5E4CA);
  static const Color shadowPeach = Color(0xFFFFDAB9);
  static const Color shadowSky = Color(0xFFBBE4FB);
  static const Color shadowRose = Color(0xFFFFD1DC);
  static const Color shadowLemon = Color(0xFFFDF0A6);

  // ─── Semantic ────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // ─── Tags/Accents ───────────────────────────────────────────────
  static const Color accentGreen = Color(0xFFD1FADF);
  static const Color accentOrange = Color(0xFFFEF0C7);
  static const Color accentBlue = Color(0xFFD1E9FF);
  static const Color accentPurple = Color(0xFFF4EBFF);
}

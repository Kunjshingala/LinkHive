import 'package:flutter/widgets.dart';

/// Consistent spacing rhythm for LinkHive
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // ─── Border Radius ───────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusFull = 100;

  // ─── Card Padding ────────────────────────────────────────────────
  static const double cardPaddingH = 16;
  static const double cardPaddingV = 14;

  // ─── Page Horizontal Padding ─────────────────────────────────────
  static const double pageH = 20;

  /// Standard page body padding — a single source of truth so every screen's
  /// content aligns to the same [pageH] inset (and matches the app bar's
  /// leading button and the Home header buttons).
  static const EdgeInsets pagePadding = EdgeInsets.all(pageH);

  /// Width reserved for the [CommonAppBar] leading slot so a full-size 44px
  /// button (matching the Home header buttons) sits at [pageH] from the edge
  /// without clipping: pageH + button width (44) + shadow (4).
  static const double appBarLeadingWidth = pageH + 48;
}

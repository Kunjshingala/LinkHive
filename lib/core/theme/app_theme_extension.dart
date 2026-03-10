import 'package:flutter/material.dart';

/// A [ThemeExtension] for Neo-Brutalist design properties.
///
/// This allows us to store custom properties like shadows and border widths
/// directly in the [ThemeData] in a type-safe way.
class AppNeoBrutalTheme extends ThemeExtension<AppNeoBrutalTheme> {
  final Color shadowColor;
  final Color borderColor;
  final double borderWidth;
  final double shadowOffset;

  const AppNeoBrutalTheme({
    required this.shadowColor,
    required this.borderColor,
    this.borderWidth = 2.0,
    this.shadowOffset = 4.0,
  });

  @override
  AppNeoBrutalTheme copyWith({Color? shadowColor, Color? borderColor, double? borderWidth, double? shadowOffset}) {
    return AppNeoBrutalTheme(
      shadowColor: shadowColor ?? this.shadowColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      shadowOffset: shadowOffset ?? this.shadowOffset,
    );
  }

  @override
  AppNeoBrutalTheme lerp(ThemeExtension<AppNeoBrutalTheme>? other, double t) {
    if (other is! AppNeoBrutalTheme) return this;
    return AppNeoBrutalTheme(
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t)!,
      shadowOffset: lerpDouble(shadowOffset, other.shadowOffset, t)!,
    );
  }

  // Helper to lerp doubles
  double? lerpDouble(num? a, num? b, double t) {
    if (a == null && b == null) return null;
    a ??= 0;
    b ??= 0;
    return a + (b - a) * t;
  }
}

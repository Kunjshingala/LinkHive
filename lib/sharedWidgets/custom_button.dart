import 'package:flutter/material.dart';

import '../core/constants/app_enums.dart';
import '../core/extensions/context_extension.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// Full-width Neo-Brutalist action button for LinkHive.
///
/// Follows the design system: thick 2px [AppColors.border] outline,
/// hard offset shadow rendered under the button, and token-only
/// colors/spacing/typography. Supports an optional leading [icon].
class NeoBrutalistButton extends StatefulWidget {
  final String? text;
  final VoidCallback onPressed;
  final bool isLoading;

  /// Override background color of the button surface.
  /// Defaults to [ColorScheme.surface].
  final Color? backgroundColor;

  /// Override text/icon color.
  /// Defaults to [ColorScheme.onSurface].
  final Color? textColor;

  /// The color of the offset shadow (the "gap").
  /// Defaults to [ColorScheme.primary] for primary variants, and [ColorScheme.surface] for outlined.
  final Color? shadowColor;

  /// Optional leading icon (or only icon if [text] is null).
  final IconData? icon;

  /// Visual style; defaults to [ButtonVariant.primary].
  final ButtonVariant variant;

  /// Button width.
  final double? width;

  /// Button height; defaults to 52 for text buttons.
  final double? height;

  /// Shape of the button; defaults to rectangle with radius.
  final BoxShape shape;

  /// Corner radius for rectangle shape.
  final double? borderRadius;

  const NeoBrutalistButton({
    super.key,
    this.text,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.shadowColor,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.width,
    this.height,
    this.shape = BoxShape.rectangle,
    this.borderRadius,
  });

  @override
  State<NeoBrutalistButton> createState() => _NeoBrutalistButtonState();
}

class _NeoBrutalistButtonState extends State<NeoBrutalistButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    final isPrimary = widget.variant == ButtonVariant.primary;
    final cs = Theme.of(context).colorScheme;

    final bgColor = widget.backgroundColor ?? cs.surface;
    final fgColor = widget.textColor ?? cs.onSurface;

    // The shadow gap color
    final gapColor = widget.shadowColor ?? (isPrimary ? cs.primary : cs.surface);
    final isDisabled = widget.isLoading;

    final isCircle = widget.shape == BoxShape.circle;
    final effectiveBorderRadius = isCircle
        ? null
        : BorderRadius.circular(widget.borderRadius ?? (widget.text == null ? AppSpacing.radiusLg : AppSpacing.radiusFull));

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: isDisabled
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onPressed.call();
            },
      onTapCancel: isDisabled ? null : () => setState(() => _pressed = false),
      child: SizedBox(
        height: (widget.height ?? (widget.text == null ? 44 : 52)) + neo.shadowOffset,
        width: widget.width ?? (widget.text == null ? (widget.height ?? 44) : double.infinity),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Underlying Shadow Layer
            Positioned(
              left: neo.shadowOffset - 1,
              right: -(neo.shadowOffset - 1),
              top: neo.shadowOffset,
              bottom: -neo.shadowOffset,
              child: Container(
                decoration: BoxDecoration(
                  color: isDisabled ? AppColors.secondarySurface : gapColor,
                  shape: widget.shape,
                  borderRadius: effectiveBorderRadius,
                  border: Border.all(color: neo.borderColor, width: neo.borderWidth),
                ),
              ),
            ),

            // Top Interactive Layer
            AnimatedPositioned(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              left: _pressed ? neo.shadowOffset : 0,
              right: _pressed ? -neo.shadowOffset : 0,
              top: _pressed ? neo.shadowOffset : 0,
              bottom: _pressed ? -neo.shadowOffset : 0,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: widget.shape,
                  borderRadius: effectiveBorderRadius,
                  border: Border.all(color: neo.borderColor, width: neo.borderWidth),
                ),
                child: widget.isLoading
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: fgColor))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) Icon(widget.icon, color: fgColor, size: 20),
                          if (widget.icon != null && widget.text != null) const SizedBox(width: AppSpacing.sm),
                          if (widget.text != null)
                            Text(
                              widget.text!,
                              style: AppTypography.bodyMedium.copyWith(color: fgColor, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

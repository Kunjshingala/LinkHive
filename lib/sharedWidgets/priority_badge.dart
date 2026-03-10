import 'package:flutter/material.dart';
import '../core/extensions/context_extension.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// Colored badge indicating link priority: High / Normal / Low.
/// Uses design system semantic color tokens.
class PriorityBadge extends StatelessWidget {
  final String priority;

  const PriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = _resolve(priority, context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppSpacing.radiusFull)),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }

  (Color, Color, String) _resolve(String p, BuildContext context) {
    switch (p.toLowerCase()) {
      case 'high':
        return (AppColors.accentOrange, Theme.of(context).colorScheme.onSurface, context.l10n.priorityHigh);
      case 'low':
        return (AppColors.accentBlue, Theme.of(context).colorScheme.onSurface, context.l10n.priorityLow);
      default:
        return (
          Theme.of(context).colorScheme.surfaceContainerHighest,
          Theme.of(context).colorScheme.onSurface,
          context.l10n.priorityNormal,
        );
    }
  }
}

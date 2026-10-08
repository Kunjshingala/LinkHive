import 'package:flutter/material.dart';

import '../core/extensions/context_extension.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// "Saved 3×" pill for a link that was shared more than once.
///
/// Renders nothing at a [count] of 1. Styled like [PriorityBadge] (pill,
/// caption w600) with a fixed purple fill and black text, the same pair as
/// the merge bar's badge, so it reads in both themes. Screen readers get the
/// spelled-out form ("Saved 3 times") instead of "3 multiplication sign".
class SavedCountChip extends StatelessWidget {
  final int count;

  const SavedCountChip({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count < 2) return const SizedBox.shrink();

    return Semantics(
      label: context.l10n.todaySavedCountA11y(count),
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.accentPurple,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Text(
          context.l10n.todaySavedCount(count),
          style: AppTypography.caption.copyWith(
            color: AppColors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

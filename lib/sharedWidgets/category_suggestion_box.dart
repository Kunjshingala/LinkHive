import 'package:flutter/material.dart';

import '../core/extensions/context_extension.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/category_utils.dart';
import 'category_chip.dart';

/// "Suggested for youtube.com": category chips picked from the site a link
/// came from (see `CategorySuggester`), above the full category list.
///
/// A lemon box with an ink outline. The chips inside stay light in both
/// themes, since text on a pastel is always ink (DESIGN.md).
class CategorySuggestionBox extends StatelessWidget {
  const CategorySuggestionBox({
    super.key,
    required this.host,
    required this.suggestions,
    required this.isSelected,
    required this.onTap,
  });

  final String host;
  final List<String> suggestions;
  final bool Function(String name) isSelected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.shadowLemon,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.black, width: neo.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: AppColors.black,
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Text(
                  context.l10n.bulkCategorySuggested(host),
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          Theme(
            data: theme.copyWith(
              colorScheme: theme.colorScheme.copyWith(
                surface: AppColors.white,
                onSurface: AppColors.black,
                primary: AppColors.black,
                onPrimary: AppColors.white,
              ),
              extensions: [
                context.neoBrutal.copyWith(borderColor: AppColors.black),
              ],
            ),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final name in suggestions)
                  CategoryChip(
                    label: CategoryUtils.getLocalizedCategory(context, name),
                    isSelected: isSelected(name),
                    onTap: () => onTap(name),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

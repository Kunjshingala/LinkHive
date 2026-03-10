import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/extensions/context_extension.dart';

/// Animated category filter chip following the Neo-Brutalist design system.
///
/// - Always has a thick 2px [AppColors.border] outline.
/// - Selected state: primary fill + hard offset shadow.
/// - Unselected state: surface fill, no shadow.
///
/// Used in the HomeScreen filter row and AddLinkScreen category multi-select.
///
/// ```dart
/// CategoryChip(
///   label: 'Design',
///   isSelected: _selected,
///   onTap: () => setState(() => _selected = !_selected),
/// )
/// ```
class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({super.key, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final neo = context.neoBrutal;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: neo.borderColor, width: neo.borderWidth),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: neo.borderColor,
                    offset: Offset(neo.shadowOffset - 2, neo.shadowOffset - 2),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge!.copyWith(
            color: isSelected ? cs.onPrimary : cs.onSurface,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

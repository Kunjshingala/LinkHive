import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../core/theme/app_spacing.dart';

class BottomSheetOption<T> {
  final String label;
  final T value;
  final IconData? icon;
  final bool isDestructive;

  const BottomSheetOption({required this.label, required this.value, this.icon, this.isDestructive = false});
}

/// A reusable Neo-Brutalist bottom sheet for selecting an option from a list.
///
/// Features a thick top border radius, an optional [title] and [titleIcon] header,
/// and support for indicating the currently [selectedValue].
/// Can optionally provide [BottomSheetOption.icon] and [BottomSheetOption.isDestructive]
/// flags for context menus.
Future<T?> showOptionsBottomSheet<T>({
  required BuildContext context,
  String? title,
  IconData? titleIcon,
  required List<BottomSheetOption<T>> options,
  T? selectedValue,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl))),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Optional Header Row
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    if (titleIcon != null) ...[
                      Icon(titleIcon, color: Theme.of(context).colorScheme.onSurface),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium!)),
                  ],
                ),
              ),
              Divider(color: Theme.of(context).colorScheme.outline, thickness: 1),
            ],

            // Options List
            ...options.map((option) {
              final isSelected = selectedValue == option.value;
              final textColor = option.isDestructive
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurface;
              final iconColor = option.isDestructive
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurface;

              return ListTile(
                leading: option.icon != null ? Icon(option.icon, color: iconColor) : null,
                title: Text(
                  option.label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: textColor,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                trailing: isSelected ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary) : null,
                selected: isSelected,
                selectedTileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                onTap: () => context.pop(option.value),
              );
            }),
          ],
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../core/constants/app_enums.dart';
import '../core/theme/app_spacing.dart';
import 'custom_button.dart';

/// A reusable Neo-Brutalist confirmation bottom sheet.
///
/// Features a title, optional message, and two `NeoBrutalistButton`s (Cancel and Confirm)
/// that perfectly match the app's primary action buttons.
Future<bool?> showConfirmationBottomSheet({
  required BuildContext context,
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  IconData? titleIcon,
  Color? titleIconColor,
  bool isDestructive = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl))),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (titleIcon != null) ...[
              Icon(
                titleIcon,
                color: titleIconColor ?? (isDestructive ? Theme.of(context).colorScheme.error : null),
                size: 48,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(title, style: Theme.of(context).textTheme.titleLarge!, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: NeoBrutalistButton(
                    text: cancelLabel,
                    variant: ButtonVariant.outlined,
                    onPressed: () => context.pop(false),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: NeoBrutalistButton(
                    text: confirmLabel,
                    variant: ButtonVariant.primary,
                    backgroundColor: isDestructive ? Theme.of(context).colorScheme.error : null,
                    textColor: isDestructive ? Theme.of(context).colorScheme.onError : null,
                    onPressed: () => context.pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

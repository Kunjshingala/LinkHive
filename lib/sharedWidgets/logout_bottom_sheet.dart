import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_enums.dart';
import '../core/theme/app_spacing.dart';
import 'custom_button.dart';

/// Neo-Brutalist logout confirmation with optional "clear local data" toggle.
Future<(bool confirmed, bool clearLocal, bool clearRemote)?> showLogoutBottomSheet({
  required BuildContext context,
  required String title,
  String? message,
  required String confirmLabel,
  required String clearLocalLabel,
  required String clearRemoteLabel,
  String cancelLabel = 'Cancel',
  IconData? titleIcon,
  Color? titleIconColor,
}) {
  return showModalBottomSheet<(bool, bool, bool)>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl))),
    builder: (context) {
      bool clearLocal = false;
      bool clearRemote = false;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (titleIcon != null) ...[
                    Icon(titleIcon, color: titleIconColor ?? Theme.of(context).colorScheme.error, size: 48),
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
                  const SizedBox(height: AppSpacing.lg),
                  InkWell(
                    onTap: () => setState(() => clearLocal = !clearLocal),
                    child: Row(
                      children: [
                        Checkbox(value: clearLocal, onChanged: (value) => setState(() => clearLocal = value ?? false)),
                        Expanded(child: Text(clearLocalLabel, style: Theme.of(context).textTheme.bodyMedium)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  InkWell(
                    onTap: () => setState(() => clearRemote = !clearRemote),
                    child: Row(
                      children: [
                        Checkbox(
                          value: clearRemote,
                          onChanged: (value) => setState(() => clearRemote = value ?? false),
                        ),
                        Expanded(child: Text(clearRemoteLabel, style: Theme.of(context).textTheme.bodyMedium)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: NeoBrutalistButton(
                          text: cancelLabel,
                          variant: ButtonVariant.outlined,
                          onPressed: () => context.pop((false, clearLocal, clearRemote)),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: NeoBrutalistButton(
                          text: confirmLabel,
                          variant: ButtonVariant.primary,
                          backgroundColor: Theme.of(context).colorScheme.error,
                          textColor: Theme.of(context).colorScheme.onError,
                          onPressed: () => context.pop((true, clearLocal, clearRemote)),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

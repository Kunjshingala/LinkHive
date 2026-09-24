import 'package:flutter/material.dart';

import '../core/constants/app_enums.dart';
import '../core/extensions/context_extension.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../my_app.dart';
import 'custom_button.dart';

/// Shows the lightweight "Saved to LinkHive" confirmation after an instant
/// share-save.
///
/// This is the payoff of the frictionless capture flow: the link is already
/// persisted, and the user gets two optional quick actions — **Add details**
/// (open the edit form) or **Undo** (delete the just-saved link). Both dismiss
/// the bar before running.
///
/// Rendered through [scaffoldMessengerKey] rather than a widget-local
/// `ScaffoldMessenger` because it is triggered from `ReceiveSharedIntent`,
/// which has no widget context of its own.
void showSavedLinkSnackBar({
  required VoidCallback onAddDetails,
  required VoidCallback onUndo,
}) {
  final messenger = scaffoldMessengerKey.currentState;
  final context = scaffoldMessengerKey.currentContext;
  if (messenger == null || context == null) return;

  final neo = context.neoBrutal;
  final cs = Theme.of(context).colorScheme;

  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      // elevation 0 keeps the Neo-Brutalist "no blur" rule — the border does
      // the visual lifting, not a soft Material shadow.
      elevation: 0,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: neo.borderColor, width: neo.borderWidth),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      duration: const Duration(seconds: 5),
      content: _SavedLinkSnackContent(
        onAddDetails: () {
          messenger.hideCurrentSnackBar();
          onAddDetails();
        },
        onUndo: () {
          messenger.hideCurrentSnackBar();
          onUndo();
        },
      ),
    ),
  );
}

class _SavedLinkSnackContent extends StatelessWidget {
  final VoidCallback onAddDetails;
  final VoidCallback onUndo;

  const _SavedLinkSnackContent({
    required this.onAddDetails,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            context.l10n.sharedSaveConfirm,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        NeoBrutalistButton(
          text: context.l10n.sharedAddDetails,
          height: 40,
          width: 116,
          onPressed: onAddDetails,
        ),
        SizedBox(width: AppSpacing.sm),
        NeoBrutalistButton(
          icon: Icons.undo_rounded,
          height: 40,
          variant: ButtonVariant.outlined,
          onPressed: onUndo,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../core/constants/app_enums.dart';
import '../core/extensions/context_extension.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../my_app.dart';
import 'custom_button.dart';

/// Shows the confirmation bar after a link is saved, or merged into a link
/// that was already saved.
///
/// - **Fresh save** ([message] is null): one row, green check, "Saved to
///   LinkHive", optional **Add details**, **Undo**. 5 seconds.
/// - **Merge** ([message] given): the message gets its own full-width row
///   (up to 3 lines, so hi/gu/ar fit on a 360dp phone) with a purple
///   "revisit" badge instead of the check, so it can't be mistaken for a new
///   save; the actions sit on a row below, end-aligned (flips in RTL).
///   8 seconds, since there's a date to read.
///
/// At most one of [onAddDetails] (share path) and [onEdit] (Add form) is
/// shown. Every action dismisses the bar before running.
///
/// [message] is a builder because the text is localized and this can be
/// called before any widget context exists: on a cold-start share the
/// messenger isn't mounted yet, so the bar waits for the first frame and
/// tries once more. If there's still no messenger, it's skipped (the save
/// itself already happened).
///
/// Rendered through [scaffoldMessengerKey] rather than a widget-local
/// `ScaffoldMessenger` because it is triggered from `ReceiveSharedIntent`,
/// which has no widget context of its own.
void showSavedLinkSnackBar({
  String Function(BuildContext context)? message,
  VoidCallback? onAddDetails,
  VoidCallback? onEdit,
  required VoidCallback onUndo,
  bool retryAfterFirstFrame = true,
}) {
  final messenger = scaffoldMessengerKey.currentState;
  final context = scaffoldMessengerKey.currentContext;
  if (messenger == null || context == null) {
    if (retryAfterFirstFrame) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => showSavedLinkSnackBar(
          message: message,
          onAddDetails: onAddDetails,
          onEdit: onEdit,
          onUndo: onUndo,
          retryAfterFirstFrame: false,
        ),
      );
    }
    return;
  }

  final neo = context.neoBrutal;
  final cs = Theme.of(context).colorScheme;
  final isMerge = message != null;

  VoidCallback dismissThen(VoidCallback action) => () {
    messenger.hideCurrentSnackBar();
    action();
  };

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
      duration: Duration(seconds: isMerge ? 8 : 5),
      content: SavedLinkSnackContent(
        message: isMerge ? message(context) : null,
        onAddDetails: onAddDetails == null ? null : dismissThen(onAddDetails),
        onEdit: onEdit == null ? null : dismissThen(onEdit),
        onUndo: dismissThen(onUndo),
      ),
    ),
  );
}

/// The bar's content. Public so the layout can be widget-tested without the
/// global messenger.
class SavedLinkSnackContent extends StatelessWidget {
  final String? message;
  final VoidCallback? onAddDetails;
  final VoidCallback? onEdit;
  final VoidCallback onUndo;

  const SavedLinkSnackContent({
    super.key,
    this.message,
    this.onAddDetails,
    this.onEdit,
    required this.onUndo,
  });

  /// Touch-target height for the bar's buttons (design review D13).
  static const buttonHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMerge = message != null;

    final text = Text(
      message ?? context.l10n.sharedSaveConfirm,
      maxLines: isMerge ? 3 : 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.bodyMedium.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );

    final primaryLabel = onAddDetails != null
        ? context.l10n.sharedAddDetails
        : (onEdit != null ? context.l10n.linkEditLabel : null);
    final primary = primaryLabel == null
        ? null
        : NeoBrutalistButton(
            text: primaryLabel,
            height: buttonHeight,
            // Flexible, not a fixed width: "विवरण जोड़ें" at 1.3x text doesn't
            // fit the old fixed 116dp. On a fresh save it shares the row with
            // the text (about the old width on a 360dp phone); on a merge the
            // actions have their own row and it takes the free space.
            width: double.infinity,
            onPressed: (onAddDetails ?? onEdit)!,
          );

    final actions = <Widget>[
      if (primary != null) Flexible(child: primary),
      SizedBox(width: AppSpacing.sm),
      NeoBrutalistButton(
        key: const ValueKey('savedLinkUndo'),
        icon: Icons.undo_rounded,
        height: buttonHeight,
        variant: ButtonVariant.outlined,
        onPressed: onUndo,
      ),
    ];

    if (!isMerge) {
      return Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 22,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: text),
          SizedBox(width: AppSpacing.sm),
          ...actions,
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _MergeBadge(),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: text),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
      ],
    );
  }
}

/// "You've been here before": a history icon on a purple disc. Fill and icon
/// are fixed in both themes (pastel fill + black, like PriorityBadge), so it
/// stays readable in dark mode.
class _MergeBadge extends StatelessWidget {
  const _MergeBadge();

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    return Container(
      key: const ValueKey('savedLinkMergeBadge'),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.accentPurple,
        shape: BoxShape.circle,
        border: Border.all(color: neo.borderColor, width: neo.borderWidth),
      ),
      child: const Icon(
        Icons.history_rounded,
        color: AppColors.black,
        size: 18,
      ),
    );
  }
}

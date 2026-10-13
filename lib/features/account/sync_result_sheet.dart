import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_enums.dart';
import '../../core/extensions/context_extension.dart';
import '../../core/services/sync_status.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../sharedWidgets/custom_button.dart';
import 'sync_description.dart';

/// Tells the user how a Sync Data run ended, from the real sync state, and
/// offers to check everything again.
///
/// Returns true if the user asked to check everything again.
Future<bool?> showSyncResultSheet(BuildContext context, SyncSnapshot snapshot) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: Theme.of(context).colorScheme.outline, width: 2),
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusXl),
      ),
    ),
    builder: (_) => _SyncResultSheet(snapshot: snapshot),
  );
}

class _SyncResultSheet extends StatelessWidget {
  const _SyncResultSheet({required this.snapshot});

  final SyncSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final description = describeSync(context, snapshot);
    final scheme = Theme.of(context).colorScheme;
    // Downloading again cannot help while the phone is offline.
    final canCheckAgain = snapshot.status != SyncStatus.waitingForInternet;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(description.icon, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              description.title,
              style: AppTypography.titleLarge,
              textAlign: TextAlign.center,
            ),
            for (final line in description.details) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                line,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            NeoBrutalistButton(
              text: l10n.accountSyncDone,
              onPressed: () => context.pop(),
            ),
            if (canCheckAgain) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.accountSyncCheckAgainDesc,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              NeoBrutalistButton(
                text: l10n.accountSyncCheckAgain,
                variant: ButtonVariant.outlined,
                onPressed: () => context.pop(true),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

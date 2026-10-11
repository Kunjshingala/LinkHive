import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/extensions/context_extension.dart';
import '../../../core/services/account_session_service.dart';
import '../../../core/services/sync_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/locator.dart';
import '../../../l10n/localization/app_localizations.dart';
import '../../../sharedWidgets/custom_button.dart';
import 'sign_out_cubit.dart';

/// Asks the user to confirm a sign-out, showing the live sync state.
///
/// Returns what the user was shown when they chose to sign out, or null if
/// they backed out. A sign-out that would lose more than that is not carried
/// out. See [AccountSessionService.signOut].
Future<UnsyncedSummary?> showSignOutSheet(BuildContext context) {
  return showModalBottomSheet<UnsyncedSummary>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: Theme.of(context).colorScheme.outline, width: 2),
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusXl),
      ),
    ),
    builder: (_) => BlocProvider(
      create: (_) =>
          SignOutCubit(sessionService: locator<AccountSessionService>()),
      child: const _SignOutSheet(),
    ),
  );
}

class _SignOutSheet extends StatelessWidget {
  const _SignOutSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: BlocBuilder<SignOutCubit, SyncSnapshot>(
          builder: (context, snapshot) {
            final unsynced = snapshot.unsynced;
            // Syncing cannot fix a conflict or reach the cloud while offline,
            // so "Sync now" is only offered when it can help.
            final canSyncNow =
                snapshot.conflicts == 0 &&
                snapshot.status != SyncStatus.waitingForInternet;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: 48,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.accountSignOut,
                  style: AppTypography.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                // A live region: a screen reader announces it when the state
                // changes while the sheet is open.
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _messageFor(l10n, snapshot),
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (unsynced.isEmpty) ...[
                  NeoBrutalistButton(
                    text: l10n.accountSignOut,
                    backgroundColor: AppColors.error,
                    textColor: AppColors.white,
                    onPressed: () => context.pop(unsynced),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  NeoBrutalistButton(
                    text: l10n.accountCancel,
                    variant: ButtonVariant.outlined,
                    onPressed: () => context.pop(),
                  ),
                ] else ...[
                  // The safe way out comes first.
                  if (canSyncNow)
                    NeoBrutalistButton(
                      text: l10n.accountSignOutSyncNow,
                      isLoading: snapshot.status == SyncStatus.syncing,
                      onPressed: () => context.read<SignOutCubit>().syncNow(),
                    )
                  else
                    NeoBrutalistButton(
                      text: l10n.accountCancel,
                      onPressed: () => context.pop(),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  NeoBrutalistButton(
                    text: l10n.accountSignOutAnyway,
                    variant: ButtonVariant.outlined,
                    textColor: AppColors.error,
                    onPressed: () => context.pop(unsynced),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// What the user is told, from the real state: never "running" while
  /// offline, never "failed" while only waiting for internet.
  String _messageFor(AppLocalizations l10n, SyncSnapshot snapshot) {
    if (snapshot.unsynced.isEmpty) return l10n.accountSignOutDesc;
    if (snapshot.conflicts > 0) return l10n.accountSignOutConflicts;

    final count = snapshot.pendingChanges;
    return switch (snapshot.status) {
      SyncStatus.syncing => l10n.accountSignOutSyncing(count),
      SyncStatus.waitingForInternet => l10n.accountSignOutWaiting(count),
      SyncStatus.failed => l10n.accountSignOutFailed(count),
      SyncStatus.idle ||
      SyncStatus.conflict => l10n.accountSignOutPending(count),
    };
  }
}

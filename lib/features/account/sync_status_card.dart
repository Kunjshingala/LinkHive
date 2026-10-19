import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/extensions/context_extension.dart';
import '../../core/services/sync_status.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../sharedWidgets/custom_button.dart';
import '../sync/bloc/sync_status_bloc.dart';
import '../sync/bloc/sync_status_state.dart';
import 'sync_description.dart';

/// The one place the Account screen tells the user how sync is going.
///
/// Signed in, it follows the sync engine: what is happening, why a sync
/// failed, how many changes are still on this phone, and when the last sync
/// finished. As a guest nothing syncs, so it says the links are only here.
class SyncStatusCard extends StatelessWidget {
  const SyncStatusCard({super.key, required this.isSignedIn, required this.onRetry});

  final bool isSignedIn;

  /// Called by the Retry button, shown only after a failed sync.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (!isSignedIn) {
      return _CardShell(
        icon: Icons.phone_android_rounded,
        title: context.l10n.accountStatLocal,
        shadowColor: AppColors.shadowPeach,
      );
    }

    return BlocBuilder<SyncStatusBloc, SyncStatusState>(
      builder: (context, state) {
        final snapshot = state.snapshot;
        final description = describeSync(context, snapshot);
        return _CardShell(
          icon: description.icon,
          title: description.title,
          details: description.details,
          shadowColor: _shadowFor(snapshot),
          onRetry: _canRetry(snapshot) ? onRetry : null,
        );
      },
    );
  }
}

/// Retry after a failed sync, and for an unfinished cloud delete that is not
/// running right now.
bool _canRetry(SyncSnapshot snapshot) => switch (snapshot.status) {
  SyncStatus.failed => true,
  SyncStatus.cloudDeletePending => !snapshot.running,
  _ => false,
};

/// The hard shadow says the state at a glance: mint for in sync, sky while
/// syncing, lemon for waiting, rose for failed, peach for a conflict. Never
/// purple, which is reserved for "it came back".
Color _shadowFor(SyncSnapshot snapshot) {
  return switch (snapshot.status) {
    SyncStatus.cloudDeletePending when snapshot.running => AppColors.shadowSky,
    SyncStatus.cloudDeletePending when snapshot.online && snapshot.failure != null => AppColors.shadowRose,
    SyncStatus.cloudDeletePending => AppColors.shadowLemon,
    SyncStatus.conflict => AppColors.shadowPeach,
    SyncStatus.failed => AppColors.shadowRose,
    SyncStatus.waitingForInternet => AppColors.shadowLemon,
    SyncStatus.syncing => AppColors.shadowSky,
    SyncStatus.idle when snapshot.pendingChanges > 0 => AppColors.shadowLemon,
    SyncStatus.idle => AppColors.shadowMint,
  };
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.icon,
    required this.title,
    required this.shadowColor,
    this.details = const [],
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final Color shadowColor;
  final List<String> details;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // A live region, so a screen reader announces a change of state.
    return Semantics(
      container: true,
      liveRegion: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: Transform.translate(
              offset: const Offset(4, 4),
              child: Container(
                decoration: BoxDecoration(
                  color: shadowColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: scheme.outline, width: 2),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border.all(color: scheme.outline, width: 2),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppTypography.titleSmall),
                          for (final line in details) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(line, style: AppTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  NeoBrutalistButton(
                    text: context.l10n.accountRetry,
                    icon: Icons.refresh_rounded,
                    height: 44,
                    onPressed: onRetry!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

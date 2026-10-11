import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/extensions/context_extension.dart';
import '../../core/services/sync_status.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/localization/app_localizations.dart';
import '../../sharedWidgets/custom_button.dart';
import '../sync/bloc/sync_status_bloc.dart';
import '../sync/bloc/sync_status_state.dart';

/// The one place the Account screen tells the user how sync is going.
///
/// Signed in, it follows the sync engine: what is happening, why a sync
/// failed, how many changes are still on this phone, and when the last sync
/// finished. As a guest nothing syncs, so it says the links are only here.
class SyncStatusCard extends StatelessWidget {
  const SyncStatusCard({
    super.key,
    required this.isSignedIn,
    required this.onRetry,
  });

  final bool isSignedIn;

  /// Called by the Retry button, shown only after a failed sync.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (!isSignedIn) {
      return _CardShell(
        icon: Icons.phone_android_rounded,
        title: context.l10n.accountStatLocal,
      );
    }

    return BlocBuilder<SyncStatusBloc, SyncStatusState>(
      builder: (context, state) {
        final snapshot = state.snapshot;
        final (title, icon) = _titleAndIcon(context.l10n, snapshot);
        return _CardShell(
          icon: icon,
          title: title,
          details: _details(context, snapshot),
          onRetry: snapshot.status == SyncStatus.failed ? onRetry : null,
        );
      },
    );
  }

  (String, IconData) _titleAndIcon(
    AppLocalizations l10n,
    SyncSnapshot snapshot,
  ) {
    return switch (snapshot.status) {
      SyncStatus.conflict => (
        l10n.accountSyncStatusConflict,
        Icons.warning_amber_rounded,
      ),
      SyncStatus.failed => (
        l10n.accountSyncStatusFailed,
        Icons.cloud_off_rounded,
      ),
      SyncStatus.waitingForInternet => (
        l10n.accountSyncStatusWaiting,
        Icons.wifi_off_rounded,
      ),
      SyncStatus.syncing => (l10n.accountSyncStatusSyncing, Icons.sync_rounded),
      SyncStatus.idle when snapshot.pendingChanges > 0 => (
        l10n.accountSyncStatusPending,
        Icons.cloud_upload_outlined,
      ),
      SyncStatus.idle when snapshot.lastSyncedAt != null => (
        l10n.accountSyncStatusSynced,
        Icons.cloud_done_rounded,
      ),
      SyncStatus.idle => (
        l10n.accountSyncStatusReady,
        Icons.cloud_done_rounded,
      ),
    };
  }

  /// The lines under the title: what is true right now, then when sync last
  /// finished.
  List<String> _details(BuildContext context, SyncSnapshot snapshot) {
    final l10n = context.l10n;
    final pending = snapshot.pendingChanges;

    final now = switch (snapshot.status) {
      SyncStatus.conflict => l10n.accountSyncConflictDetail(snapshot.conflicts),
      SyncStatus.failed => _failureText(l10n, snapshot.failure),
      SyncStatus.waitingForInternet => l10n.accountSyncWaitingDetail(pending),
      SyncStatus.syncing || SyncStatus.idle =>
        pending > 0 ? l10n.accountSyncPendingDetail(pending) : null,
    };

    final syncedAt = snapshot.lastSyncedAt;
    final last = syncedAt != null
        ? l10n.accountSyncLastSynced(_formatTime(context, syncedAt))
        : (snapshot.status == SyncStatus.idle && pending == 0
              ? l10n.accountSyncNever
              : null);

    return [?now, ?last];
  }

  String _failureText(AppLocalizations l10n, SyncFailure? failure) {
    return switch (failure) {
      SyncFailure.timeout => l10n.accountSyncFailureTimeout,
      SyncFailure.permissionDenied => l10n.accountSyncFailurePermission,
      SyncFailure.unavailable => l10n.accountSyncFailureUnavailable,
      SyncFailure.unknown || null => l10n.accountSyncFailureUnknown,
    };
  }

  String _formatTime(BuildContext context, int millisecondsSinceEpoch) {
    final locale = Localizations.localeOf(context).languageCode;
    return DateFormat.MMMd(locale).add_jm().format(
      DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.icon,
    required this.title,
    this.details = const [],
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final List<String> details;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
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
                      Text(
                        line,
                        style: AppTypography.caption.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
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
    );
  }
}

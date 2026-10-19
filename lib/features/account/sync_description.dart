import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/extensions/context_extension.dart';
import '../../core/services/sync_status.dart';
import '../../l10n/localization/app_localizations.dart';

/// What to tell the user about a [SyncSnapshot]: a title, an icon, and the
/// lines under it.
///
/// Shared by the sync status card and the Sync Data result, so the two can
/// never say different things about the same state.
class SyncDescription {
  const SyncDescription({required this.title, required this.icon, this.details = const []});

  final String title;
  final IconData icon;

  /// What is true right now, then when sync last finished.
  final List<String> details;
}

SyncDescription describeSync(BuildContext context, SyncSnapshot snapshot) {
  final l10n = context.l10n;
  final (title, icon) = _titleAndIcon(l10n, snapshot);
  return SyncDescription(title: title, icon: icon, details: _details(context, snapshot));
}

(String, IconData) _titleAndIcon(AppLocalizations l10n, SyncSnapshot snapshot) {
  return switch (snapshot.status) {
    SyncStatus.cloudDeletePending when snapshot.running => (
      l10n.accountSyncStatusDeletingCloud,
      Icons.delete_sweep_rounded,
    ),
    SyncStatus.cloudDeletePending => (
      l10n.accountSyncStatusCloudDeleteUnfinished,
      snapshot.online ? Icons.cloud_off_rounded : Icons.wifi_off_rounded,
    ),
    SyncStatus.conflict => (l10n.accountSyncStatusConflict, Icons.warning_amber_rounded),
    SyncStatus.failed => (l10n.accountSyncStatusFailed, Icons.cloud_off_rounded),
    SyncStatus.waitingForInternet => (l10n.accountSyncStatusWaiting, Icons.wifi_off_rounded),
    SyncStatus.syncing => (l10n.accountSyncStatusSyncing, Icons.sync_rounded),
    SyncStatus.idle when snapshot.pendingChanges > 0 => (l10n.accountSyncStatusPending, Icons.cloud_upload_outlined),
    SyncStatus.idle when snapshot.lastSyncedAt != null => (l10n.accountSyncStatusSynced, Icons.cloud_done_rounded),
    SyncStatus.idle => (l10n.accountSyncStatusReady, Icons.cloud_done_rounded),
  };
}

List<String> _details(BuildContext context, SyncSnapshot snapshot) {
  final l10n = context.l10n;
  final pending = snapshot.pendingChanges;

  // An unfinished cloud delete replaces everything else the tile would say:
  // nothing syncs until it is done.
  if (snapshot.status == SyncStatus.cloudDeletePending) {
    if (snapshot.running) return [l10n.accountSyncDeletingCloudDetail];
    if (!snapshot.online) return [l10n.accountSyncCloudDeleteOfflineDetail];
    final failure = snapshot.failure;
    return [if (failure != null) _failureText(l10n, failure), l10n.accountSyncCloudDeleteRetryDetail];
  }

  final now = switch (snapshot.status) {
    SyncStatus.conflict => l10n.accountSyncConflictDetail(snapshot.conflicts),
    SyncStatus.failed => _failureText(l10n, snapshot.failure),
    SyncStatus.waitingForInternet => l10n.accountSyncWaitingDetail(pending),
    SyncStatus.syncing || SyncStatus.idle => pending > 0 ? l10n.accountSyncPendingDetail(pending) : null,
    SyncStatus.cloudDeletePending => null, // handled above
  };

  final syncedAt = snapshot.lastSyncedAt;
  final last = syncedAt != null
      ? l10n.accountSyncLastSynced(_formatTime(context, syncedAt))
      : (snapshot.status == SyncStatus.idle && pending == 0 ? l10n.accountSyncNever : null);

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
  return DateFormat.MMMd(locale).add_jm().format(DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch));
}

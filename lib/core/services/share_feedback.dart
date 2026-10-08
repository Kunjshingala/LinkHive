import '../../features/links/manager/save_result.dart';
import '../../l10n/localization/app_localizations.dart';
import '../utils/saved_date.dart';

/// The text for the bar shown after a share into LinkHive.
///
/// Pulled out of `ReceiveSharedIntent._saveInstantly` so every outcome is
/// unit-tested, including the save failure that can't be triggered on a
/// device. Precedence: an [error] wins; then a merge that kept a new URL
/// version; then a merge that brought back an archived link; then a plain
/// merge; then a new save.
String shareOutcomeMessage({
  SaveResult? result,
  Object? error,
  required AppLocalizations l10n,
  required DateTime now,
}) {
  if (error != null || result == null) return l10n.sharedSaveFailed;

  return switch (result) {
    SaveCreated() => l10n.sharedSaveConfirm,
    SaveMerged(addedVersion: true) => l10n.sharedAnotherVersion,
    SaveMerged(:final previous) when previous.isRead => l10n.sharedUnarchived(
      _date(previous.lastResurfacedAt ?? previous.createdAt, now, l10n),
    ),
    SaveMerged(:final previous) => l10n.sharedAlreadySaved(
      _date(previous.createdAt, now, l10n),
    ),
  };
}

String _date(int utcMs, DateTime now, AppLocalizations l10n) =>
    formatSavedDate(DateTime.fromMillisecondsSinceEpoch(utcMs), now, l10n);

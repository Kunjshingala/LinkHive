import 'package:intl/intl.dart';

import '../../l10n/localization/app_localizations.dart';

/// When a link was saved, phrased for a sentence like "Already saved {date}".
///
/// Same calendar day → "today", the day before → "yesterday", earlier this
/// year → "Sep 28", older → "Sep 28, 2025". Both [when] and [now] must be
/// **local** times: link timestamps are stored as UTC epoch ms, so callers
/// use `DateTime.fromMillisecondsSinceEpoch(ms)` (not `isUtc: true`), or a link
/// saved at 00:30 IST would read as the previous day.
String formatSavedDate(DateTime when, DateTime now, AppLocalizations l10n) {
  final day = DateTime(when.year, when.month, when.day);
  final today = DateTime(now.year, now.month, now.day);
  final daysAgo = today.difference(day).inDays;

  if (daysAgo == 0) return l10n.dateToday;
  if (daysAgo == 1) return l10n.dateYesterday;
  final pattern = when.year == now.year
      ? DateFormat.MMMd(l10n.localeName)
      : DateFormat.yMMMd(l10n.localeName);
  return pattern.format(when);
}

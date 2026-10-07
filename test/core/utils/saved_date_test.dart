import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:link_hive/core/utils/saved_date.dart';
import 'package:link_hive/l10n/localization/app_localizations.dart';

void main() {
  // Pure unit test: no localization delegates run, so load the hi/gu/ar date
  // symbols ourselves.
  setUpAll(() => initializeDateFormatting());

  final en = lookupAppLocalizations(const Locale('en'));
  final hi = lookupAppLocalizations(const Locale('hi'));
  final now = DateTime(2026, 10, 7, 9);

  group('formatSavedDate', () {
    test('same calendar day reads "today"', () {
      expect(formatSavedDate(DateTime(2026, 10, 7, 0, 30), now, en), 'today');
    });

    test('previous calendar day reads "yesterday", even under 24h ago', () {
      expect(
        formatSavedDate(DateTime(2026, 10, 6, 23, 50), now, en),
        'yesterday',
      );
    });

    test('earlier this year drops the year', () {
      expect(formatSavedDate(DateTime(2026, 9, 28), now, en), 'Sep 28');
    });

    test('a previous year keeps the year', () {
      expect(formatSavedDate(DateTime(2025, 9, 28), now, en), 'Sep 28, 2025');
    });

    test('uses the locale for words and dates', () {
      expect(formatSavedDate(DateTime(2026, 10, 7, 1), now, hi), 'आज');
      expect(formatSavedDate(DateTime(2026, 10, 6), now, hi), 'कल');
      expect(
        formatSavedDate(DateTime(2026, 9, 28), now, hi),
        isNot('Sep 28'),
        reason: 'Hindi month name, not English',
      );
    });
  });
}

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:link_hive/core/services/share_feedback.dart';
import 'package:link_hive/features/links/manager/save_result.dart';
import 'package:link_hive/features/links/models/link_model.dart';
import 'package:link_hive/l10n/localization/app_localizations.dart';

/// Which bar text each share outcome gets. The failure case can't be
/// triggered on a device, so this is its only proof.
void main() {
  setUpAll(() => initializeDateFormatting());

  final l10n = lookupAppLocalizations(const Locale('en'));
  final now = DateTime(2026, 10, 7, 9);

  LinkModel link({bool isRead = false, int? lastResurfacedAt}) => LinkModel(
    id: '1',
    url: 'https://www.instagram.com/reel/DeKio97zfoF/',
    title: '',
    // Local 00:30 on the same day: formatted as UTC this would be the 6th in
    // IST, so this also guards the local-time conversion.
    createdAt: DateTime(2026, 10, 7, 0, 30).millisecondsSinceEpoch,
    isRead: isRead,
    lastResurfacedAt: lastResurfacedAt,
  );

  SaveMerged merged(LinkModel previous, {bool addedVersion = false}) =>
      SaveMerged(
        merged: previous,
        previous: previous,
        addedVersion: addedVersion,
      );

  test('a new save confirms it', () {
    expect(
      shareOutcomeMessage(result: SaveCreated(link()), l10n: l10n, now: now),
      'Saved to LinkHive',
    );
  });

  test('a merge into an unread link says when it was saved', () {
    expect(
      shareOutcomeMessage(result: merged(link()), l10n: l10n, now: now),
      "Already saved today, it'll come back in Today",
    );
  });

  test('a merge into an archived link says it was archived', () {
    final archived = link(
      isRead: true,
      lastResurfacedAt: DateTime(2026, 9, 28).millisecondsSinceEpoch,
    );

    expect(
      shareOutcomeMessage(result: merged(archived), l10n: l10n, now: now),
      "You archived this Sep 28, it'll come back in Today",
    );
  });

  test('a new URL version wins over the archived message', () {
    expect(
      shareOutcomeMessage(
        result: merged(link(isRead: true), addedVersion: true),
        l10n: l10n,
        now: now,
      ),
      "Saved another version of this link, it'll come back in Today",
    );
  });

  test('a failed save tells the user to share again', () {
    expect(
      shareOutcomeMessage(error: StateError('Hive'), l10n: l10n, now: now),
      "Couldn't save this link. Try sharing again.",
    );
  });
}

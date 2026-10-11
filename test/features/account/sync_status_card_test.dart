import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/services/sync_status.dart';
import 'package:link_hive/core/theme/app_theme.dart';
import 'package:link_hive/features/account/sync_status_card.dart';
import 'package:link_hive/features/sync/bloc/sync_status_bloc.dart';
import 'package:link_hive/features/sync/bloc/sync_status_event.dart';
import 'package:link_hive/features/sync/bloc/sync_status_state.dart';
import 'package:link_hive/l10n/localization/app_localizations.dart';
import 'package:link_hive/sharedWidgets/custom_button.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncStatusBloc extends MockBloc<SyncStatusEvent, SyncStatusState>
    implements SyncStatusBloc {}

/// The one tile that tells the user how sync is going. It must never say
/// something the engine does not know to be true.
void main() {
  late MockSyncStatusBloc bloc;
  var retries = 0;

  setUp(() {
    bloc = MockSyncStatusBloc();
    retries = 0;
  });

  Future<void> pumpCard(
    WidgetTester tester,
    SyncSnapshot snapshot, {
    bool isSignedIn = true,
    double textScale = 1.0,
  }) async {
    when(() => bloc.state).thenReturn(SyncStatusState(snapshot));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildLinkHiveTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlocProvider<SyncStatusBloc>.value(
              value: bloc,
              child: SyncStatusCard(
                isSignedIn: isSignedIn,
                onRetry: () => retries++,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 2026-03-04 10:30 local time.
  final syncedAt = DateTime(2026, 3, 4, 10, 30).millisecondsSinceEpoch;

  testWidgets('a guest is told the links stay on this phone', (tester) async {
    await pumpCard(tester, const SyncSnapshot(), isSignedIn: false);

    expect(find.text('Local Only'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('signed in and caught up: all synced, with the time', (
    tester,
  ) async {
    await pumpCard(tester, SyncSnapshot(lastSyncedAt: syncedAt));

    expect(find.text('All synced'), findsOneWidget);
    expect(find.textContaining('Last synced Mar 4'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('before the first sync it does not claim to be synced', (
    tester,
  ) async {
    await pumpCard(tester, const SyncSnapshot());

    expect(find.text('Ready to sync'), findsOneWidget);
    expect(find.text('Not synced yet'), findsOneWidget);
    expect(find.text('All synced'), findsNothing);
  });

  testWidgets('changes still on the phone are not called synced', (
    tester,
  ) async {
    await pumpCard(
      tester,
      SyncSnapshot(pendingChanges: 3, lastSyncedAt: syncedAt),
    );

    expect(find.text('Waiting to sync'), findsOneWidget);
    expect(
      find.text('3 changes have not reached the cloud yet.'),
      findsOneWidget,
    );
    expect(find.text('All synced'), findsNothing);
  });

  testWidgets('offline with changes pending reads as waiting, not failed', (
    tester,
  ) async {
    await pumpCard(
      tester,
      const SyncSnapshot(
        status: SyncStatus.waitingForInternet,
        pendingChanges: 1,
      ),
    );

    expect(find.text('Waiting for internet'), findsOneWidget);
    expect(
      find.text('1 change will sync when you are back online.'),
      findsOneWidget,
    );
    expect(find.text('Sync failed'), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('while syncing it says so', (tester) async {
    await pumpCard(
      tester,
      const SyncSnapshot(status: SyncStatus.syncing, pendingChanges: 2),
    );

    expect(find.text('Syncing…'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('a failure gives the reason and a Retry that works', (
    tester,
  ) async {
    await pumpCard(
      tester,
      const SyncSnapshot(
        status: SyncStatus.failed,
        pendingChanges: 1,
        failure: SyncFailure.timeout,
      ),
    );

    expect(find.text('Sync failed'), findsOneWidget);
    expect(find.text('The cloud did not answer in time.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(retries, 1);
  });

  const reasons = {
    SyncFailure.timeout: 'The cloud did not answer in time.',
    SyncFailure.permissionDenied: 'This account is not allowed to sync.',
    SyncFailure.unavailable: 'The cloud cannot be reached right now.',
    SyncFailure.unknown: 'Something went wrong while syncing.',
  };

  for (final MapEntry(key: failure, value: words) in reasons.entries) {
    testWidgets('a $failure failure is explained in its own words', (
      tester,
    ) async {
      await pumpCard(
        tester,
        SyncSnapshot(status: SyncStatus.failed, failure: failure),
      );

      expect(find.text(words), findsOneWidget);
    });
  }

  testWidgets('conflicts are named, with how many', (tester) async {
    await pumpCard(
      tester,
      const SyncSnapshot(status: SyncStatus.conflict, conflicts: 2),
    );

    expect(find.text('Conflicts need attention'), findsOneWidget);
    expect(find.text('2 edits need your decision.'), findsOneWidget);
  });

  testWidgets('Retry is at least 44px tall and fits at 1.3x text size', (
    tester,
  ) async {
    await pumpCard(
      tester,
      SyncSnapshot(
        status: SyncStatus.failed,
        failure: SyncFailure.unavailable,
        pendingChanges: 12,
        lastSyncedAt: syncedAt,
      ),
      textScale: 1.3,
    );

    expect(tester.takeException(), isNull);
    final button = tester.getSize(find.byType(NeoBrutalistButton));
    expect(button.height, greaterThanOrEqualTo(44));
  });
}

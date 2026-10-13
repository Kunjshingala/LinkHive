import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:link_hive/core/services/sync_engine.dart';
import 'package:link_hive/core/services/sync_service.dart';
import 'package:link_hive/core/services/sync_status.dart';
import 'package:link_hive/core/theme/app_theme.dart';
import 'package:link_hive/core/utils/locator.dart';
import 'package:link_hive/features/account/bloc/account_bloc.dart';
import 'package:link_hive/features/account/bloc/account_event.dart';
import 'package:link_hive/features/account/bloc/account_state.dart';
import 'package:link_hive/features/account/sync_data_flow.dart';
import 'package:link_hive/l10n/localization/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncService extends Mock implements SyncService {}

class MockSyncEngine extends Mock implements SyncEngine {}

class MockAccountBloc extends MockBloc<AccountEvent, AccountState>
    implements AccountBloc {}

/// "Sync Data": sync, then say how it went, and offer to check everything
/// again.
void main() {
  late MockSyncService sync;
  late MockSyncEngine engine;
  late MockAccountBloc accountBloc;

  setUpAll(() => registerFallbackValue(const AccountLoadRequested()));

  setUp(() {
    sync = MockSyncService();
    engine = MockSyncEngine();
    accountBloc = MockAccountBloc();
    when(() => sync.requestSync(pull: true)).thenAnswer((_) async {});
    when(() => sync.requestFullResync()).thenAnswer((_) async {});
    when(() => engine.snapshot).thenReturn(const SyncSnapshot());
    when(() => accountBloc.state).thenReturn(const AccountInitial());
    if (locator.isRegistered<SyncService>()) locator.unregister<SyncService>();
    if (locator.isRegistered<SyncEngine>()) locator.unregister<SyncEngine>();
    locator
      ..registerSingleton<SyncService>(sync)
      ..registerSingleton<SyncEngine>(engine);
  });

  Future<void> pumpFlow(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildLinkHiveTheme(),
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => BlocProvider<AccountBloc>.value(
                value: accountBloc,
                child: Builder(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => runSyncDataFlow(context),
                        child: const Text('sync'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('sync'));
    await tester.pumpAndSettle();
  }

  testWidgets('syncs, reloads the account and shows how it went', (
    tester,
  ) async {
    when(() => engine.snapshot).thenReturn(
      SyncSnapshot(
        lastSyncedAt: DateTime(2026, 3, 4, 10, 30).millisecondsSinceEpoch,
      ),
    );

    await pumpFlow(tester);

    verify(() => sync.requestSync(pull: true)).called(1);
    verifyNever(() => sync.requestFullResync());
    verify(() => accountBloc.add(const AccountLoadRequested())).called(1);
    expect(find.text('All synced'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('"Done" ends the flow', (tester) async {
    await pumpFlow(tester);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Done'), findsNothing);
    verifyNever(() => sync.requestFullResync());
  });

  testWidgets('"Check everything again" downloads everything, then reports', (
    tester,
  ) async {
    await pumpFlow(tester);

    await tester.tap(find.text('Check everything again'));
    await tester.pumpAndSettle();

    verify(() => sync.requestFullResync()).called(1);
    // The result of the second run is shown, and can be closed.
    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('a failed sync is reported from the sync state, not thrown', (
    tester,
  ) async {
    when(
      () => sync.requestSync(pull: true),
    ).thenAnswer((_) async => throw StateError('offline'));
    when(() => engine.snapshot).thenReturn(
      const SyncSnapshot(
        status: SyncStatus.failed,
        pendingChanges: 1,
        failure: SyncFailure.timeout,
      ),
    );

    await pumpFlow(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Sync failed'), findsOneWidget);
    expect(find.text('The cloud did not answer in time.'), findsOneWidget);
    expect(find.text('Check everything again'), findsOneWidget);
  });

  testWidgets('offline, checking again is not offered', (tester) async {
    when(() => engine.snapshot).thenReturn(
      const SyncSnapshot(
        status: SyncStatus.waitingForInternet,
        pendingChanges: 2,
      ),
    );

    await pumpFlow(tester);

    expect(find.text('Waiting for internet'), findsOneWidget);
    expect(find.text('Check everything again'), findsNothing);
  });
}

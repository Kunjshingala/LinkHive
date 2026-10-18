import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:link_hive/core/services/account_session_service.dart';
import 'package:link_hive/core/services/sync_status.dart';
import 'package:link_hive/core/theme/app_theme.dart';
import 'package:link_hive/core/utils/locator.dart';
import 'package:link_hive/features/account/sign_out/sign_out_sheet.dart';
import 'package:link_hive/l10n/localization/app_localizations.dart';
import 'package:link_hive/sharedWidgets/custom_button.dart';
import 'package:mocktail/mocktail.dart';

class MockAccountSessionService extends Mock implements AccountSessionService {}

/// What the user is told before signing out, and what each button does.
void main() {
  late MockAccountSessionService session;
  late StreamController<SyncSnapshot> live;
  var closed = false;
  UnsyncedSummary? shown;

  setUp(() {
    session = MockAccountSessionService();
    live = StreamController<SyncSnapshot>.broadcast();
    closed = false;
    shown = null;
    when(() => session.syncSnapshot).thenReturn(const SyncSnapshot());
    when(() => session.watchSync()).thenAnswer((_) => live.stream);
    when(() => session.requestSync()).thenAnswer((_) async {});
    if (locator.isRegistered<AccountSessionService>()) {
      locator.unregister<AccountSessionService>();
    }
    locator.registerSingleton<AccountSessionService>(session);
  });

  tearDown(() => live.close());

  /// Opens the sheet under a go_router app, like production: the sheet closes
  /// itself with `context.pop()`, which needs a GoRouter.
  Future<void> openSheet(WidgetTester tester, SyncSnapshot snapshot) async {
    when(() => session.syncSnapshot).thenReturn(snapshot);
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildLinkHiveTheme(),
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async {
                      shown = await showSignOutSheet(context);
                      closed = true;
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // A spinner never settles, so let the sheet slide in and stop there.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The title says "Sign Out" too, so find the button by its type.
  final signOutButton = find.widgetWithText(NeoBrutalistButton, 'Sign Out');

  testWidgets('with nothing to lose it says so and signs out', (tester) async {
    await openSheet(tester, const SyncSnapshot());

    expect(find.textContaining('Everything is saved'), findsOneWidget);
    expect(find.text('Sync now'), findsNothing);

    await tester.tap(signOutButton);
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(shown, const UnsyncedSummary());
    verifyNever(() => session.requestSync());
  });

  testWidgets('cancelling closes the sheet without a decision', (tester) async {
    await openSheet(tester, const SyncSnapshot());

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(shown, isNull);
  });

  testWidgets('offline, it says the changes wait for internet, not that sync '
      'failed', (tester) async {
    await openSheet(tester, const SyncSnapshot(status: SyncStatus.waitingForInternet, pendingChanges: 2));

    expect(find.text('2 changes are waiting for internet. If you sign out now, they are lost.'), findsOneWidget);
    expect(find.textContaining('could not sync'), findsNothing);
    // Syncing cannot help offline, so the safe choice is to back out.
    expect(find.text('Sync now'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('"Sign out anyway" hands back exactly what the user was shown', (tester) async {
    await openSheet(tester, const SyncSnapshot(status: SyncStatus.waitingForInternet, pendingChanges: 2, conflicts: 1));

    await tester.tap(find.text('Sign out anyway'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(shown, const UnsyncedSummary(changes: 2, conflicts: 1));
  });

  testWidgets('online with changes pending, "Sync now" asks for a sync', (tester) async {
    await openSheet(tester, const SyncSnapshot(status: SyncStatus.failed, pendingChanges: 1));

    expect(find.text('1 change could not sync. Try again, or sign out and lose it.'), findsOneWidget);
    // The sheet already asked once when it opened.
    verify(() => session.requestSync()).called(1);

    await tester.tap(find.text('Sync now'));
    await tester.pump();

    verify(() => session.requestSync()).called(1);
    expect(closed, isFalse);
  });

  testWidgets('while syncing it shows progress and still allows leaving', (tester) async {
    await openSheet(tester, const SyncSnapshot(status: SyncStatus.syncing, pendingChanges: 3));

    expect(find.text('Syncing 3 changes. Wait for them to finish, or sign out and lose them.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Sign out anyway'), findsOneWidget);
  });

  testWidgets('a conflict cannot be fixed by syncing, so it only warns', (tester) async {
    await openSheet(tester, const SyncSnapshot(status: SyncStatus.conflict, conflicts: 1));

    expect(find.textContaining('need your decision'), findsOneWidget);
    expect(find.text('Sync now'), findsNothing);
    expect(find.text('Sign out anyway'), findsOneWidget);
  });

  testWidgets('updates live: once sync catches up, signing out is safe', (tester) async {
    await openSheet(tester, const SyncSnapshot(status: SyncStatus.syncing, pendingChanges: 2));
    expect(find.text('Sign out anyway'), findsOneWidget);

    live.add(const SyncSnapshot());
    await tester.pumpAndSettle();

    expect(find.text('Sign out anyway'), findsNothing);
    expect(find.textContaining('Everything is saved'), findsOneWidget);

    await tester.tap(signOutButton);
    await tester.pumpAndSettle();

    // What it hands back is what the user saw last: nothing to lose.
    expect(shown, const UnsyncedSummary());
  });

  testWidgets('fits at 1.3x text size without overflowing', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await openSheet(tester, const SyncSnapshot(status: SyncStatus.waitingForInternet, pendingChanges: 12));

    expect(tester.takeException(), isNull);
    expect(find.text('Sign out anyway'), findsOneWidget);
  });
}

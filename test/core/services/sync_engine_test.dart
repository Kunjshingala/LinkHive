import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/core/services/sync_engine.dart';
import 'package:link_hive/core/services/sync_status.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockLinkRepository extends Mock implements LinkRepository {}

void main() {
  late MockLinkRepository repository;
  late UnsyncedSummary summary;
  late SyncFailure? repositoryFailure;

  SyncEngine buildEngine({bool authenticated = true}) =>
      SyncEngine(repository: repository, isAuthenticated: () => authenticated);

  setUp(() {
    repository = MockLinkRepository();
    summary = const UnsyncedSummary();
    repositoryFailure = null;
    when(() => repository.unsyncedSummary()).thenAnswer((_) => summary);
    when(() => repository.lastFailure).thenAnswer((_) => repositoryFailure);
    when(() => repository.lastPulledAt).thenReturn(null);
  });

  test('collapses concurrent requests into one repository sync', () async {
    final syncCompleter = Completer<void>();
    when(
      () => repository.syncPendingLinks(),
    ).thenAnswer((_) => syncCompleter.future);
    final engine = buildEngine();

    final first = engine.requestSync();
    final second = engine.requestSync();

    expect(identical(first, second), isTrue);
    verify(() => repository.syncPendingLinks()).called(1);

    syncCompleter.complete();
    await Future.wait([first, second]);
  });

  test('does not perform cloud work when disabled', () async {
    when(() => repository.syncPendingLinks()).thenAnswer((_) async {});
    final engine = buildEngine();
    engine.setCloudWorkEnabled(false);

    await engine.requestSync();

    verifyNever(() => repository.syncPendingLinks());
  });

  test('does not perform cloud work when unauthenticated', () async {
    when(() => repository.syncPendingLinks()).thenAnswer((_) async {});
    final engine = buildEngine(authenticated: false);

    await engine.requestSync();

    verifyNever(() => repository.syncPendingLinks());
  });

  test('runs pull after push when requested', () async {
    when(() => repository.syncPendingLinks()).thenAnswer((_) async {});
    when(() => repository.pullFromCloud()).thenAnswer((_) async {});
    final engine = buildEngine();

    await engine.requestSync(pull: true);

    verifyInOrder([
      () => repository.syncPendingLinks(),
      () => repository.pullFromCloud(),
    ]);
  });

  test('reports idle after a successful run', () async {
    when(() => repository.syncPendingLinks()).thenAnswer((_) async {});
    final engine = buildEngine();

    await engine.requestSync();

    expect(engine.status, SyncStatus.idle);
    await engine.dispose();
  });

  test('reports failed when the repository sync throws', () async {
    when(() => repository.syncPendingLinks()).thenThrow(Exception('offline'));
    final engine = buildEngine();

    await expectLater(engine.requestSync(), throwsException);

    expect(engine.status, SyncStatus.failed);
    expect(engine.snapshot.failure, SyncFailure.unknown);
    await engine.dispose();
  });

  group('a pull that arrives during a push-only run', () {
    late Completer<void> firstPush;
    late SyncEngine engine;

    setUp(() {
      firstPush = Completer<void>();
      var pushes = 0;
      when(() => repository.syncPendingLinks()).thenAnswer(
        (_) => ++pushes == 1 ? firstPush.future : Future<void>.value(),
      );
      when(() => repository.pullFromCloud()).thenAnswer((_) async {});
      engine = buildEngine();
    });

    test('is not dropped: it runs right after that run', () async {
      final push = engine.requestSync();
      final pull = engine.requestSync(pull: true);

      verifyNever(() => repository.pullFromCloud());

      firstPush.complete();
      await Future.wait([push, pull]);

      verify(() => repository.pullFromCloud()).called(1);
      verify(() => repository.syncPendingLinks()).called(2);
    });

    test('is shared by every pull requested meanwhile', () async {
      final push = engine.requestSync();
      final pullA = engine.requestSync(pull: true);
      final pullB = engine.requestSync(pull: true);

      expect(identical(pullA, pullB), isTrue);

      firstPush.complete();
      await Future.wait([push, pullA, pullB]);

      verify(() => repository.pullFromCloud()).called(1);
    });

    test('still runs when the push-only run failed', () async {
      final push = engine.requestSync();
      final pull = engine.requestSync(pull: true);

      firstPush.completeError(Exception('offline'));
      await expectLater(push, throwsException);
      await pull;

      verify(() => repository.pullFromCloud()).called(1);
    });
  });

  test('a pull requested during a pull shares that run', () async {
    final pullRun = Completer<void>();
    when(() => repository.syncPendingLinks()).thenAnswer((_) async {});
    when(() => repository.pullFromCloud()).thenAnswer((_) => pullRun.future);
    final engine = buildEngine();

    final first = engine.requestSync(pull: true);
    await Future<void>.delayed(Duration.zero);
    final second = engine.requestSync(pull: true);

    expect(identical(first, second), isTrue);
    pullRun.complete();
    await first;
    verify(() => repository.pullFromCloud()).called(1);
  });

  group('pause', () {
    test('refuses new runs until resume', () async {
      when(() => repository.syncPendingLinks()).thenAnswer((_) async {});
      final engine = buildEngine();

      engine.pause();
      await engine.requestSync();
      verifyNever(() => repository.syncPendingLinks());

      engine.resume();
      await engine.requestSync();
      verify(() => repository.syncPendingLinks()).called(1);
    });

    test('does not stop a run that is already going', () async {
      final push = Completer<void>();
      when(() => repository.syncPendingLinks()).thenAnswer((_) => push.future);
      final engine = buildEngine();

      final run = engine.requestSync();
      engine.pause();
      push.complete();

      await run;
      verify(() => repository.syncPendingLinks()).called(1);
    });
  });

  group('status, as the user sees it', () {
    late Completer<void> push;
    late SyncEngine engine;

    setUp(() {
      push = Completer<void>();
      when(() => repository.syncPendingLinks()).thenAnswer((_) => push.future);
      engine = buildEngine();
    });

    test('online with a run active is syncing', () async {
      final run = engine.requestSync();

      expect(engine.status, SyncStatus.syncing);
      push.complete();
      await run;
      expect(engine.status, SyncStatus.idle);
    });

    test('offline with pending changes is waiting for internet, even while a '
        'request is stuck: never syncing, never failed', () async {
      summary = const UnsyncedSummary(changes: 3);
      engine.setOnline(false);

      final run = engine.requestSync(); // the cloud call never answers

      expect(engine.status, SyncStatus.waitingForInternet);
      expect(engine.snapshot.pendingChanges, 3);
      push.complete();
      await run;
    });

    test('offline with nothing pending is idle', () {
      engine.setOnline(false);

      expect(engine.status, SyncStatus.idle);
    });

    test('a failure while offline is still waiting, not failed', () async {
      summary = const UnsyncedSummary(changes: 1, failedChanges: 1);
      repositoryFailure = SyncFailure.unavailable;
      engine.setOnline(false);

      expect(engine.status, SyncStatus.waitingForInternet);
    });

    test(
      'online with failed changes after a run is failed, with the reason',
      () {
        summary = const UnsyncedSummary(changes: 2, failedChanges: 2);
        repositoryFailure = SyncFailure.timeout;

        expect(engine.status, SyncStatus.failed);
        expect(engine.snapshot.failure, SyncFailure.timeout);
      },
    );

    test('a retry in progress shows syncing, not the old failure', () async {
      summary = const UnsyncedSummary(changes: 1, failedChanges: 1);
      repositoryFailure = SyncFailure.timeout;

      final run = engine.requestSync();

      expect(engine.status, SyncStatus.syncing);
      push.complete();
      await run;
    });

    test('a conflict wins over every other state', () {
      summary = const UnsyncedSummary(
        changes: 1,
        failedChanges: 1,
        conflicts: 1,
      );
      engine.setOnline(false);

      expect(engine.status, SyncStatus.conflict);
    });

    test('reports the last successful pull time', () {
      when(() => repository.lastPulledAt).thenReturn(1234);

      expect(engine.snapshot.lastSyncedAt, 1234);
    });
  });

  group('watch', () {
    late StreamController<BoxEvent> queueChanges;

    setUp(() {
      queueChanges = StreamController<BoxEvent>.broadcast();
      when(
        () => repository.watchSyncOperations(),
      ).thenAnswer((_) => queueChanges.stream);
    });

    tearDown(() => queueChanges.close());

    test('follows the queue of unsynced writes and the connection', () async {
      final engine = buildEngine();
      final snapshots = <SyncSnapshot>[];
      final subscription = engine.watch().listen(snapshots.add);

      summary = const UnsyncedSummary(changes: 1);
      queueChanges.add(BoxEvent('op-1', null, false));
      await Future<void>.delayed(Duration.zero);
      engine.setOnline(false);
      await Future<void>.delayed(Duration.zero);

      expect(snapshots.map((s) => s.status), [
        SyncStatus.idle,
        SyncStatus.waitingForInternet,
      ]);
      expect(snapshots.map((s) => s.pendingChanges), [1, 1]);
      await subscription.cancel();
      await engine.dispose();
    });
  });
}

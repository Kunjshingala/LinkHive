import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/core/services/cloud_sync_service.dart';
import 'package:link_hive/core/services/sync_engine.dart';
import 'package:link_hive/core/services/sync_status.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockLinkRepository extends Mock implements LinkRepository {}

class MockCloudSyncService extends Mock implements CloudSyncService {}

void main() {
  late MockLinkRepository repository;
  late MockCloudSyncService cloudSync;
  late UnsyncedSummary summary;
  late SyncFailure? repositoryFailure;

  SyncEngine buildEngine({bool authenticated = true}) =>
      SyncEngine(cloudSync: cloudSync, repository: repository, isAuthenticated: () => authenticated);

  setUp(() {
    repository = MockLinkRepository();
    cloudSync = MockCloudSyncService();
    summary = const UnsyncedSummary();
    repositoryFailure = null;
    when(() => repository.unsyncedSummary()).thenAnswer((_) => summary);
    when(() => cloudSync.lastFailure).thenAnswer((_) => repositoryFailure);
    when(() => repository.lastPulledAt).thenReturn(null);
  });

  test('collapses concurrent requests into one cloud sync', () async {
    final syncCompleter = Completer<void>();
    when(() => cloudSync.push()).thenAnswer((_) => syncCompleter.future);
    final engine = buildEngine();

    final first = engine.requestSync();
    final second = engine.requestSync();

    expect(identical(first, second), isTrue);
    verify(() => cloudSync.push()).called(1);

    syncCompleter.complete();
    await Future.wait([first, second]);
  });

  test('does not perform cloud work when disabled', () async {
    when(() => cloudSync.push()).thenAnswer((_) async {});
    final engine = buildEngine();
    engine.setCloudWorkEnabled(false);

    await engine.requestSync();

    verifyNever(() => cloudSync.push());
  });

  test('does not perform cloud work when unauthenticated', () async {
    when(() => cloudSync.push()).thenAnswer((_) async {});
    final engine = buildEngine(authenticated: false);

    await engine.requestSync();

    verifyNever(() => cloudSync.push());
  });

  test('runs pull after push when requested', () async {
    when(() => cloudSync.push()).thenAnswer((_) async {});
    when(() => cloudSync.pull(full: any(named: 'full'))).thenAnswer((_) async {});
    final engine = buildEngine();

    await engine.requestSync(pull: true);

    verifyInOrder([() => cloudSync.push(), () => cloudSync.pull(full: false)]);
  });

  test('reports idle after a successful run', () async {
    when(() => cloudSync.push()).thenAnswer((_) async {});
    final engine = buildEngine();

    await engine.requestSync();

    expect(engine.status, SyncStatus.idle);
    await engine.dispose();
  });

  test('reports failed when the cloud sync throws', () async {
    when(() => cloudSync.push()).thenThrow(Exception('offline'));
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
      when(() => cloudSync.push()).thenAnswer((_) => ++pushes == 1 ? firstPush.future : Future<void>.value());
      when(() => cloudSync.pull(full: any(named: 'full'))).thenAnswer((_) async {});
      engine = buildEngine();
    });

    test('is not dropped: it runs right after that run', () async {
      final push = engine.requestSync();
      final pull = engine.requestSync(pull: true);

      verifyNever(() => cloudSync.pull(full: any(named: 'full')));

      firstPush.complete();
      await Future.wait([push, pull]);

      verify(() => cloudSync.pull(full: any(named: 'full'))).called(1);
      verify(() => cloudSync.push()).called(2);
    });

    test('is shared by every pull requested meanwhile', () async {
      final push = engine.requestSync();
      final pullA = engine.requestSync(pull: true);
      final pullB = engine.requestSync(pull: true);

      expect(identical(pullA, pullB), isTrue);

      firstPush.complete();
      await Future.wait([push, pullA, pullB]);

      verify(() => cloudSync.pull(full: any(named: 'full'))).called(1);
    });

    test('still runs when the push-only run failed', () async {
      final push = engine.requestSync();
      final pull = engine.requestSync(pull: true);

      firstPush.completeError(Exception('offline'));
      await expectLater(push, throwsException);
      await pull;

      verify(() => cloudSync.pull(full: any(named: 'full'))).called(1);
    });
  });

  test('a pull requested during a pull shares that run', () async {
    final pullRun = Completer<void>();
    when(() => cloudSync.push()).thenAnswer((_) async {});
    when(() => cloudSync.pull(full: any(named: 'full'))).thenAnswer((_) => pullRun.future);
    final engine = buildEngine();

    final first = engine.requestSync(pull: true);
    await Future<void>.delayed(Duration.zero);
    final second = engine.requestSync(pull: true);

    expect(identical(first, second), isTrue);
    pullRun.complete();
    await first;
    verify(() => cloudSync.pull(full: any(named: 'full'))).called(1);
  });

  group('pause', () {
    test('refuses new runs until resume', () async {
      when(() => cloudSync.push()).thenAnswer((_) async {});
      final engine = buildEngine();

      engine.pause();
      await engine.requestSync();
      verifyNever(() => cloudSync.push());

      engine.resume();
      await engine.requestSync();
      verify(() => cloudSync.push()).called(1);
    });

    test('does not stop a run that is already going', () async {
      final push = Completer<void>();
      when(() => cloudSync.push()).thenAnswer((_) => push.future);
      final engine = buildEngine();

      final run = engine.requestSync();
      engine.pause();
      push.complete();

      await run;
      verify(() => cloudSync.push()).called(1);
    });
  });

  group('full resync', () {
    setUp(() {
      when(() => cloudSync.push()).thenAnswer((_) async {});
      when(() => cloudSync.pull(full: any(named: 'full'))).thenAnswer((_) async {});
    });

    // The cursor itself is forgotten inside the pull run, behind the wipe
    // guard (see cloud_sync_service_test); the engine asks for a full pull.
    test('forgets the cursor right before pulling, after the push', () async {
      final engine = buildEngine();

      await engine.requestFullResync();

      verifyInOrder([() => cloudSync.push(), () => cloudSync.pull(full: true)]);
    });

    test('a normal pull leaves the cursor alone', () async {
      final engine = buildEngine();

      await engine.requestSync(pull: true);

      verifyNever(() => cloudSync.pull(full: true));
    });

    test('waits for a run that is going, so its cursor is not written back '
        'over the reset', () async {
      final push = Completer<void>();
      var pushes = 0;
      when(() => cloudSync.push()).thenAnswer((_) => ++pushes == 1 ? push.future : Future<void>.value());
      final engine = buildEngine();

      final running = engine.requestSync();
      final full = engine.requestFullResync();
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => cloudSync.pull(full: true));

      push.complete();
      await Future.wait([running, full]);

      verify(() => cloudSync.pull(full: true)).called(1);
    });

    test('still runs when the run it waited for failed', () async {
      var pushes = 0;
      when(() => cloudSync.push()).thenAnswer((_) async => ++pushes == 1 ? throw Exception('offline') : null);
      final engine = buildEngine();

      final running = engine.requestSync();
      final full = engine.requestFullResync();
      await expectLater(running, throwsException);
      await full;

      verify(() => cloudSync.pull(full: any(named: 'full'))).called(1);
    });

    test('does nothing when paused or signed out', () async {
      final paused = buildEngine()..pause();
      await paused.requestFullResync();
      await buildEngine(authenticated: false).requestFullResync();

      verifyNever(() => cloudSync.pull(full: any(named: 'full')));
    });
  });

  group('status, as the user sees it', () {
    late Completer<void> push;
    late SyncEngine engine;

    setUp(() {
      push = Completer<void>();
      when(() => cloudSync.push()).thenAnswer((_) => push.future);
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

    test('online with failed changes after a run is failed, with the reason', () {
      summary = const UnsyncedSummary(changes: 2, failedChanges: 2);
      repositoryFailure = SyncFailure.timeout;

      expect(engine.status, SyncStatus.failed);
      expect(engine.snapshot.failure, SyncFailure.timeout);
    });

    test('a retry in progress shows syncing, not the old failure', () async {
      summary = const UnsyncedSummary(changes: 1, failedChanges: 1);
      repositoryFailure = SyncFailure.timeout;

      final run = engine.requestSync();

      expect(engine.status, SyncStatus.syncing);
      push.complete();
      await run;
    });

    test('a conflict wins over every other state', () {
      summary = const UnsyncedSummary(changes: 1, failedChanges: 1, conflicts: 1);
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
      when(() => repository.watchSyncOperations()).thenAnswer((_) => queueChanges.stream);
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

      expect(snapshots.map((s) => s.status), [SyncStatus.idle, SyncStatus.waitingForInternet]);
      expect(snapshots.map((s) => s.pendingChanges), [1, 1]);
      await subscription.cancel();
      await engine.dispose();
    });
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/services/sync_engine.dart';
import 'package:link_hive/core/services/sync_status.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockLinkRepository extends Mock implements LinkRepository {}

void main() {
  late MockLinkRepository repository;

  setUp(() {
    repository = MockLinkRepository();
    when(() => repository.conflicts).thenReturn([]);
  });

  test('collapses concurrent requests into one repository sync', () async {
    final syncCompleter = Completer<void>();
    when(
      () => repository.syncPendingLinks(),
    ).thenAnswer((_) => syncCompleter.future);
    final engine = SyncEngine(
      repository: repository,
      isAuthenticated: () => true,
    );

    final first = engine.requestSync();
    final second = engine.requestSync();

    expect(identical(first, second), isTrue);
    verify(() => repository.syncPendingLinks()).called(1);

    syncCompleter.complete();
    await Future.wait([first, second]);
  });

  test('does not perform cloud work when disabled', () async {
    when(() => repository.syncPendingLinks()).thenAnswer((_) async {});
    final engine = SyncEngine(
      repository: repository,
      isAuthenticated: () => true,
    );
    engine.setCloudWorkEnabled(false);

    await engine.requestSync();

    verifyNever(() => repository.syncPendingLinks());
  });

  test('does not perform cloud work when unauthenticated', () async {
    when(() => repository.syncPendingLinks()).thenAnswer((_) async {});
    final engine = SyncEngine(
      repository: repository,
      isAuthenticated: () => false,
    );

    await engine.requestSync();

    verifyNever(() => repository.syncPendingLinks());
  });

  test('runs pull after push when requested', () async {
    when(() => repository.syncPendingLinks()).thenAnswer((_) async {});
    when(() => repository.pullFromCloud()).thenAnswer((_) async {});
    final engine = SyncEngine(
      repository: repository,
      isAuthenticated: () => true,
    );

    await engine.requestSync(pull: true);

    verifyInOrder([
      () => repository.syncPendingLinks(),
      () => repository.pullFromCloud(),
    ]);
  });

  test('reports idle after a successful run', () async {
    when(() => repository.syncPendingLinks()).thenAnswer((_) async {});
    final engine = SyncEngine(
      repository: repository,
      isAuthenticated: () => true,
    );

    await engine.requestSync();

    expect(engine.status, SyncStatus.idle);
    await engine.dispose();
  });

  test('reports failed when the repository sync throws', () async {
    when(() => repository.syncPendingLinks()).thenThrow(Exception('offline'));
    final engine = SyncEngine(
      repository: repository,
      isAuthenticated: () => true,
    );

    await expectLater(engine.requestSync(), throwsException);

    expect(engine.status, SyncStatus.failed);
    await engine.dispose();
  });
}

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/core/services/sync_engine.dart';
import 'package:link_hive/core/services/sync_status.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';
import 'package:link_hive/features/sync/bloc/sync_status_bloc.dart';
import 'package:link_hive/features/sync/bloc/sync_status_event.dart';
import 'package:link_hive/features/sync/bloc/sync_status_state.dart';
import 'package:mocktail/mocktail.dart';

class MockLinkRepository extends Mock implements LinkRepository {}

void main() {
  late MockLinkRepository repository;
  late StreamController<BoxEvent> queueChanges;
  late UnsyncedSummary summary;
  late SyncEngine engine;

  setUp(() {
    repository = MockLinkRepository();
    queueChanges = StreamController<BoxEvent>.broadcast();
    summary = const UnsyncedSummary();
    when(() => repository.unsyncedSummary()).thenAnswer((_) => summary);
    when(() => repository.lastFailure).thenReturn(null);
    when(() => repository.lastPulledAt).thenReturn(null);
    when(
      () => repository.watchSyncOperations(),
    ).thenAnswer((_) => queueChanges.stream);
    engine = SyncEngine(repository: repository, isAuthenticated: () => true);
  });

  tearDown(() async {
    await queueChanges.close();
    await engine.dispose();
  });

  blocTest<SyncStatusBloc, SyncStatusState>(
    'starts with the engine snapshot and reflects status events',
    build: () => SyncStatusBloc(syncEngine: engine),
    act: (bloc) => bloc.add(
      const SyncStatusChanged(SyncSnapshot(status: SyncStatus.conflict)),
    ),
    expect: () => [
      const SyncStatusState(SyncSnapshot(status: SyncStatus.conflict)),
    ],
  );

  test('receives status changes emitted by the engine', () async {
    final bloc = SyncStatusBloc(syncEngine: engine);
    final states = <SyncStatusState>[];
    final subscription = bloc.stream.listen(states.add);

    when(() => repository.syncPendingLinks()).thenAnswer((_) async {});
    await engine.requestSync();
    await Future<void>.delayed(Duration.zero);

    expect(states.map((s) => s.status), contains(SyncStatus.syncing));
    expect(states.last.status, SyncStatus.idle);
    await subscription.cancel();
    await bloc.close();
  });

  test('follows the queue of unsynced writes and the connection', () async {
    final bloc = SyncStatusBloc(syncEngine: engine);
    final states = <SyncStatusState>[];
    final subscription = bloc.stream.listen(states.add);

    summary = const UnsyncedSummary(changes: 2);
    queueChanges.add(BoxEvent('op-1', null, false));
    await Future<void>.delayed(Duration.zero);
    engine.setOnline(false);
    await Future<void>.delayed(Duration.zero);

    expect(states.last.status, SyncStatus.waitingForInternet);
    expect(states.last.snapshot.pendingChanges, 2);
    await subscription.cancel();
    await bloc.close();
  });
}

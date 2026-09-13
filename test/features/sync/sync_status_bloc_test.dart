import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
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
  late SyncEngine engine;

  setUp(() {
    repository = MockLinkRepository();
    when(() => repository.conflicts).thenReturn([]);
    engine = SyncEngine(repository: repository, isAuthenticated: () => true);
  });

  tearDown(() async => engine.dispose());

  blocTest<SyncStatusBloc, SyncStatusState>(
    'starts with the engine status and reflects status events',
    build: () => SyncStatusBloc(syncEngine: engine),
    act: (bloc) => bloc.add(const SyncStatusChanged(SyncStatus.conflict)),
    expect: () => [const SyncStatusState(SyncStatus.conflict)],
  );

  test('receives status changes emitted by the engine', () async {
    final bloc = SyncStatusBloc(syncEngine: engine);
    final states = <SyncStatusState>[];
    final subscription = bloc.stream.listen(states.add);

    when(() => repository.syncPendingLinks()).thenAnswer((_) async {});
    await engine.requestSync();
    await Future<void>.delayed(Duration.zero);

    expect(states, contains(const SyncStatusState(SyncStatus.syncing)));
    expect(states.last, const SyncStatusState(SyncStatus.idle));
    await subscription.cancel();
    await bloc.close();
  });
}

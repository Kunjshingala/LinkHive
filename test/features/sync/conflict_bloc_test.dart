import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/models/conflict_record.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';
import 'package:link_hive/features/sync/bloc/conflict_bloc.dart';
import 'package:link_hive/features/sync/bloc/conflict_event.dart';
import 'package:link_hive/features/sync/bloc/conflict_state.dart';
import 'package:mocktail/mocktail.dart';

class MockLinkRepository extends Mock implements LinkRepository {}

void main() {
  late MockLinkRepository repository;
  const conflict = ConflictRecord(
    conflictId: 'conflict-1',
    linkId: 'link-1',
    conflictingFields: ['title'],
    baseVersion: {'id': 'link-1', 'title': 'Base', 'createdAt': 1},
    localVersion: {'id': 'link-1', 'title': 'Local', 'createdAt': 1},
    cloudVersion: {'id': 'link-1', 'title': 'Cloud', 'createdAt': 1},
    createdAt: 2,
  );

  setUp(() {
    repository = MockLinkRepository();
    when(() => repository.conflicts).thenReturn([conflict]);
  });

  blocTest<ConflictBloc, ConflictState>(
    'loads persisted conflicts',
    build: () => ConflictBloc(repository: repository),
    expect: () => [
      const ConflictLoaded([conflict]),
    ],
  );

  blocTest<ConflictBloc, ConflictState>(
    'resolves a conflict by keeping local data',
    build: () {
      when(
        () => repository.resolveConflictKeepLocal('conflict-1'),
      ).thenAnswer((_) async {});
      when(() => repository.conflicts).thenReturn([]);
      return ConflictBloc(repository: repository);
    },
    act: (bloc) => bloc.add(const ConflictKeepLocalRequested('conflict-1')),
    expect: () => [
      const ConflictLoaded([]),
      const ConflictLoading(),
      const ConflictLoaded([]),
    ],
    verify: (_) => verify(
      () => repository.resolveConflictKeepLocal('conflict-1'),
    ).called(1),
  );
}

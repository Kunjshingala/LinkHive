import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/features/library/bloc/library_bloc.dart';
import 'package:link_hive/features/links/manager/link_manager.dart';
import 'package:mocktail/mocktail.dart';

class MockLinkManager extends Mock implements LinkManager {}

void main() {
  late MockLinkManager manager;
  late StreamController<BoxEvent> changes;

  const stats = LibraryStats(total: 3, unread: 2, read: 1);
  const sources = [NamedCount('youtube.com', 2)];
  const categories = [NamedCount('Watch', 1)];
  const loaded = LibraryLoaded(
    stats: stats,
    sources: sources,
    categories: categories,
  );

  setUp(() {
    manager = MockLinkManager();
    changes = StreamController<BoxEvent>.broadcast();
    when(() => manager.watchLinks()).thenAnswer((_) => changes.stream);
    when(() => manager.getLibraryStats()).thenReturn(stats);
    when(() => manager.getSourceCounts()).thenReturn(sources);
    when(() => manager.getCategoryCounts()).thenReturn(categories);
  });

  tearDown(() => changes.close());

  blocTest<LibraryBloc, LibraryState>(
    'load emits Loading then the overview',
    build: () => LibraryBloc(manager: manager),
    act: (bloc) => bloc.add(const LibraryLoadRequested()),
    expect: () => const [LibraryLoading(), loaded],
  );

  blocTest<LibraryBloc, LibraryState>(
    'a links change reloads without showing Loading',
    build: () => LibraryBloc(manager: manager),
    seed: () => loaded,
    act: (bloc) async {
      when(
        () => manager.getLibraryStats(),
      ).thenReturn(const LibraryStats(total: 4, unread: 3, read: 1));
      changes.add(BoxEvent('k', null, false));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => const [
      LibraryLoaded(
        stats: LibraryStats(total: 4, unread: 3, read: 1),
        sources: sources,
        categories: categories,
      ),
    ],
  );

  blocTest<LibraryBloc, LibraryState>(
    'pull-to-refresh pushes, pulls, reloads and completes the indicator',
    build: () {
      when(() => manager.syncPendingLinks()).thenAnswer((_) async {});
      when(() => manager.pullFromCloud()).thenAnswer((_) async {});
      return LibraryBloc(manager: manager);
    },
    seed: () => loaded,
    act: (bloc) async {
      final completer = Completer<void>();
      bloc.add(LibrarySyncRequested(completer: completer));
      await completer.future;
    },
    verify: (_) {
      verify(() => manager.syncPendingLinks()).called(1);
      verify(() => manager.pullFromCloud()).called(1);
    },
  );

  blocTest<LibraryBloc, LibraryState>(
    'a failed sync still completes the indicator and reports the error',
    build: () {
      when(() => manager.syncPendingLinks()).thenThrow(Exception('offline'));
      return LibraryBloc(manager: manager);
    },
    seed: () => loaded,
    act: (bloc) async {
      final completer = Completer<void>();
      bloc.add(LibrarySyncRequested(completer: completer));
      await completer.future;
    },
    expect: () => [isA<LibraryError>()],
  );
}

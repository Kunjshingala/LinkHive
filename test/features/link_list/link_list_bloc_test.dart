import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/features/link_list/bloc/link_list_bloc.dart';
import 'package:link_hive/features/links/manager/link_manager.dart';
import 'package:link_hive/features/links/models/link_model.dart';
import 'package:mocktail/mocktail.dart';

class MockLinkManager extends Mock implements LinkManager {}

void main() {
  late MockLinkManager manager;
  late StreamController<BoxEvent> changes;

  LinkModel link(String id, {bool isRead = false}) => LinkModel(
    id: id,
    url: 'https://e.com/$id',
    title: id,
    createdAt: 0,
    isRead: isRead,
  );

  final all = List.generate(25, (i) => link('l$i'));
  const stats = LibraryStats(total: 25, unread: 25, uncategorized: 3);
  const sources = [NamedCount('e.com', 25)];

  /// Answers findLinks/countLinks from [source] like the repository would.
  void stubLinks(List<LinkModel> Function() source) {
    when(
      () => manager.findLinks(
        any(),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((inv) {
      final limit = inv.namedArguments[#limit] as int;
      final offset = (inv.namedArguments[#offset] as int?) ?? 0;
      return source().skip(offset).take(limit).toList();
    });
    when(() => manager.countLinks(any())).thenAnswer((_) => source().length);
  }

  /// A loaded state as the bloc builds it, overview fields included.
  LinkListLoaded loaded({
    LinkQuery query = const LinkQuery(),
    List<LinkModel>? links,
    int total = 25,
    bool hasReachedMax = false,
    bool isSelecting = false,
    Set<String> selectedIds = const {},
  }) => LinkListLoaded(
    query: query,
    links: links ?? all.take(20).toList(),
    total: total,
    hasReachedMax: hasReachedMax,
    stats: stats,
    sources: sources,
    isSelecting: isSelecting,
    selectedIds: selectedIds,
  );

  setUpAll(() => registerFallbackValue(const LinkQuery()));

  setUp(() {
    manager = MockLinkManager();
    changes = StreamController<BoxEvent>.broadcast();
    when(() => manager.watchLinks()).thenAnswer((_) => changes.stream);
    when(() => manager.getLibraryStats()).thenReturn(stats);
    when(
      () => manager.getSourceCounts(within: any(named: 'within')),
    ).thenReturn(sources);
    when(() => manager.getCategoryCounts()).thenReturn(const []);
    stubLinks(() => all);
  });

  tearDown(() => changes.close());

  LinkListBloc build() => LinkListBloc(manager: manager);

  blocTest<LinkListBloc, LinkListState>(
    'load emits Loading then the first page with the chip counts',
    build: build,
    act: (bloc) => bloc.add(const LinkListLoadRequested()),
    expect: () => [const LinkListLoading(), loaded()],
  );

  blocTest<LinkListBloc, LinkListState>(
    'next page appends and reaches the end',
    build: build,
    seed: loaded,
    act: (bloc) => bloc.add(const LinkListNextPageRequested()),
    expect: () => [loaded(links: all, hasReachedMax: true)],
  );

  blocTest<LinkListBloc, LinkListState>(
    'a quick chip reloads from the first page with its query',
    build: build,
    seed: () => loaded(links: all, hasReachedMax: true),
    act: (bloc) => bloc.add(
      LinkListQueryChanged(
        const LinkQuery().withQuickFilter(QuickFilter.unread),
      ),
    ),
    expect: () => [
      loaded(query: const LinkQuery(readFilter: ReadFilter.unread)),
    ],
  );

  blocTest<LinkListBloc, LinkListState>(
    'sorting by site loads per-site counts for the group headers',
    build: build,
    seed: loaded,
    act: (bloc) => bloc.add(
      const LinkListQueryChanged(LinkQuery(sort: LinkSort.site)),
    ),
    verify: (bloc) => expect(
      (bloc.state as LinkListLoaded).siteCounts,
      {'e.com': 25},
    ),
  );

  blocTest<LinkListBloc, LinkListState>(
    'search waits for typing to pause and keeps only the last value',
    build: build,
    seed: loaded,
    act: (bloc) {
      bloc.add(const LinkListSearchChanged('p'));
      bloc.add(const LinkListSearchChanged('pi'));
      bloc.add(const LinkListSearchChanged('piz'));
    },
    wait: const Duration(milliseconds: 400),
    expect: () => [
      isA<LinkListLoaded>().having((s) => s.query.search, 'search', 'piz'),
    ],
  );

  group('selection', () {
    blocTest<LinkListBloc, LinkListState>(
      'the Select button enters selection mode with nothing picked',
      build: build,
      seed: loaded,
      act: (bloc) => bloc.add(const LinkListSelectionStarted()),
      expect: () => [loaded(isSelecting: true)],
    );

    blocTest<LinkListBloc, LinkListState>(
      'a long-press enters selection mode with that link picked',
      build: build,
      seed: loaded,
      act: (bloc) => bloc.add(const LinkListSelectionToggled('l1')),
      expect: () => [loaded(isSelecting: true, selectedIds: {'l1'})],
    );

    blocTest<LinkListBloc, LinkListState>(
      'unpicking the last link stays in selection mode',
      build: build,
      seed: () => loaded(isSelecting: true, selectedIds: {'l1'}),
      act: (bloc) => bloc.add(const LinkListSelectionToggled('l1')),
      expect: () => [loaded(isSelecting: true)],
    );

    blocTest<LinkListBloc, LinkListState>(
      'cancel leaves selection mode',
      build: build,
      seed: () => loaded(isSelecting: true, selectedIds: {'l1'}),
      act: (bloc) => bloc.add(const LinkListSelectionCleared()),
      expect: () => [loaded()],
    );

    blocTest<LinkListBloc, LinkListState>(
      'select all includes links not loaded yet',
      build: build,
      seed: () => loaded(isSelecting: true),
      act: (bloc) => bloc.add(const LinkListSelectAllRequested()),
      verify: (bloc) => expect(
        (bloc.state as LinkListLoaded).selectedIds,
        all.map((l) => l.id).toSet(),
      ),
    );

    blocTest<LinkListBloc, LinkListState>(
      'a bulk action runs on the selection, then leaves selection mode',
      build: () {
        when(() => manager.markLinksRead(any())).thenAnswer((_) async {});
        return build();
      },
      seed: () => loaded(isSelecting: true, selectedIds: {'l1', 'l2'}),
      act: (bloc) => bloc.add(const LinkListBulkMarkReadRequested()),
      verify: (bloc) {
        verify(() => manager.markLinksRead({'l1', 'l2'})).called(1);
        final state = bloc.state as LinkListLoaded;
        expect(state.isSelecting, isFalse);
        expect(state.selectedIds, isEmpty);
      },
    );

    blocTest<LinkListBloc, LinkListState>(
      'bulk category and priority pass their value through',
      build: () {
        when(
          () => manager.addCategoryToLinks(any(), any()),
        ).thenAnswer((_) async {});
        when(
          () => manager.setPriorityForLinks(any(), any()),
        ).thenAnswer((_) async {});
        return build();
      },
      seed: () => loaded(isSelecting: true, selectedIds: {'l1'}),
      act: (bloc) async {
        bloc.add(const LinkListBulkCategoryAdded('Watch'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const LinkListSelectionToggled('l2'));
        bloc.add(const LinkListBulkPriorityChanged('High'));
      },
      verify: (_) {
        verify(() => manager.addCategoryToLinks({'l1'}, 'Watch')).called(1);
        verify(() => manager.setPriorityForLinks({'l2'}, 'High')).called(1);
      },
    );
  });

  blocTest<LinkListBloc, LinkListState>(
    'a links change reloads silently and drops selected links that are gone',
    build: build,
    seed: () => loaded(isSelecting: true, selectedIds: const {'l1', 'l24'}),
    act: (bloc) async {
      stubLinks(() => all.where((l) => l.id != 'l24').toList());
      changes.add(BoxEvent('l24', null, true));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      isA<LinkListLoaded>()
          .having((s) => s.total, 'total', 24)
          .having((s) => s.links.length, 'links kept', 20)
          .having((s) => s.selectedIds, 'selection', {'l1'}),
    ],
  );

  blocTest<LinkListBloc, LinkListState>(
    'pull-to-refresh pushes, pulls and completes the indicator',
    build: () {
      when(() => manager.syncPendingLinks()).thenAnswer((_) async {});
      when(() => manager.pullFromCloud()).thenAnswer((_) async {});
      return build();
    },
    seed: loaded,
    act: (bloc) async {
      final completer = Completer<void>();
      bloc.add(LinkListSyncRequested(completer: completer));
      await completer.future;
    },
    verify: (_) {
      verify(() => manager.syncPendingLinks()).called(1);
      verify(() => manager.pullFromCloud()).called(1);
    },
  );

  blocTest<LinkListBloc, LinkListState>(
    'a failed sync still completes the indicator and reports the error',
    build: () {
      when(() => manager.syncPendingLinks()).thenThrow(Exception('offline'));
      return build();
    },
    seed: loaded,
    act: (bloc) async {
      final completer = Completer<void>();
      bloc.add(LinkListSyncRequested(completer: completer));
      await completer.future;
    },
    expect: () => [isA<LinkListError>()],
  );

  blocTest<LinkListBloc, LinkListState>(
    'swipe toggles read state through the manager',
    build: () {
      when(() => manager.markAsRead(any())).thenAnswer((_) async {});
      when(() => manager.markAsUnread(any())).thenAnswer((_) async {});
      return build();
    },
    act: (bloc) => bloc
      ..add(LinkListReadToggled(link('a')))
      ..add(LinkListReadToggled(link('b', isRead: true))),
    verify: (_) {
      verify(() => manager.markAsRead('a')).called(1);
      verify(() => manager.markAsUnread('b')).called(1);
    },
  );
}

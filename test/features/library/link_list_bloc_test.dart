import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/features/library/link_list/bloc/link_list_bloc.dart';
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

  setUpAll(() => registerFallbackValue(const LinkQuery()));

  setUp(() {
    manager = MockLinkManager();
    changes = StreamController<BoxEvent>.broadcast();
    when(() => manager.watchLinks()).thenAnswer((_) => changes.stream);
    stubLinks(() => all);
  });

  tearDown(() => changes.close());

  LinkListBloc build() =>
      LinkListBloc(manager: manager, query: const LinkQuery());

  blocTest<LinkListBloc, LinkListState>(
    'load emits Loading then the first page',
    build: build,
    act: (bloc) => bloc.add(const LinkListLoadRequested()),
    expect: () => [
      const LinkListLoading(),
      LinkListLoaded(
        query: const LinkQuery(),
        links: all.take(20).toList(),
        total: 25,
      ),
    ],
  );

  blocTest<LinkListBloc, LinkListState>(
    'next page appends and reaches the end',
    build: build,
    seed: () => LinkListLoaded(
      query: const LinkQuery(),
      links: all.take(20).toList(),
      total: 25,
    ),
    act: (bloc) => bloc.add(const LinkListNextPageRequested()),
    expect: () => [
      LinkListLoaded(
        query: const LinkQuery(),
        links: all,
        total: 25,
        hasReachedMax: true,
      ),
    ],
  );

  blocTest<LinkListBloc, LinkListState>(
    'a query change reloads from the first page',
    build: build,
    seed: () => LinkListLoaded(
      query: const LinkQuery(),
      links: all,
      total: 25,
      hasReachedMax: true,
    ),
    act: (bloc) => bloc.add(
      const LinkListQueryChanged(LinkQuery(readFilter: ReadFilter.unread)),
    ),
    expect: () => [
      LinkListLoaded(
        query: const LinkQuery(readFilter: ReadFilter.unread),
        links: all.take(20).toList(),
        total: 25,
      ),
    ],
  );

  blocTest<LinkListBloc, LinkListState>(
    'search waits for typing to pause and keeps only the last value',
    build: build,
    seed: () => LinkListLoaded(
      query: const LinkQuery(),
      links: all.take(20).toList(),
      total: 25,
    ),
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
    final seed = LinkListLoaded(
      query: const LinkQuery(),
      links: all.take(20).toList(),
      total: 25,
    );

    blocTest<LinkListBloc, LinkListState>(
      'toggle adds then removes a link',
      build: build,
      seed: () => seed,
      act: (bloc) => bloc
        ..add(const LinkListSelectionToggled('l1'))
        ..add(const LinkListSelectionToggled('l1')),
      expect: () => [
        seed.copyWith(selectedIds: {'l1'}),
        seed.copyWith(selectedIds: {}),
      ],
    );

    blocTest<LinkListBloc, LinkListState>(
      'select all includes links not loaded yet',
      build: build,
      seed: () => seed,
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
      seed: () => seed.copyWith(selectedIds: {'l1', 'l2'}),
      act: (bloc) => bloc.add(const LinkListBulkMarkReadRequested()),
      verify: (bloc) {
        verify(() => manager.markLinksRead({'l1', 'l2'})).called(1);
        expect((bloc.state as LinkListLoaded).isSelecting, isFalse);
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
      seed: () => seed.copyWith(selectedIds: {'l1'}),
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
    seed: () => LinkListLoaded(
      query: const LinkQuery(),
      links: all.take(20).toList(),
      total: 25,
      selectedIds: const {'l1', 'l24'},
    ),
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

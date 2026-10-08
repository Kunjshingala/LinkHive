import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/features/library/link_list/bloc/category_picker_cubit.dart';
import 'package:link_hive/features/library/link_list/bloc/filter_sheet_cubit.dart';
import 'package:link_hive/features/links/manager/link_manager.dart';
import 'package:link_hive/features/links/models/link_model.dart';
import 'package:link_hive/features/shell/bloc/inbox_badge_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockLinkManager extends Mock implements LinkManager {}

void main() {
  late MockLinkManager manager;

  setUpAll(() => registerFallbackValue(const LinkQuery()));

  setUp(() {
    manager = MockLinkManager();
    when(() => manager.categoryOptions()).thenReturn(['Watch', 'Read', 'Dev']);
    when(() => manager.getSourceCounts()).thenReturn(const [
      NamedCount('youtube.com', 9),
      NamedCount('amazon.in', 3),
    ]);
    // Match count = number of active filters, so each toggle is visible.
    when(() => manager.countLinks(any())).thenAnswer(
      (inv) => (inv.positionalArguments.first as LinkQuery).activeFilterCount,
    );
  });

  group('FilterSheetCubit', () {
    FilterSheetCubit build({
      LinkQuery initial = const LinkQuery(),
      LinkQuery scope = const LinkQuery(),
    }) => FilterSheetCubit(manager: manager, initial: initial, scope: scope);

    test('starts with the options and the live count', () {
      final cubit = build(initial: const LinkQuery(categories: {'Watch'}));
      expect(cubit.state.categories, ['Watch', 'Read', 'Dev']);
      expect(cubit.state.sources, ['youtube.com', 'amazon.in']);
      expect(cubit.state.matchCount, 1);
    });

    blocTest<FilterSheetCubit, FilterSheetState>(
      'toggles add and remove filters and update the count',
      build: build,
      act: (cubit) => cubit
        ..toggleCategory('Watch')
        ..togglePriority('High')
        ..toggleSource('amazon.in')
        ..toggleCategory('Watch'),
      verify: (cubit) {
        expect(
          cubit.state.query,
          const LinkQuery(priorities: {'High'}, host: 'amazon.in'),
        );
        expect(cubit.state.matchCount, 2);
      },
    );

    test('a selected source outside the top list is still offered', () {
      final cubit = build(initial: const LinkQuery(host: 'rare.site'));
      expect(cubit.state.sources, ['youtube.com', 'amazon.in', 'rare.site']);
    });

    blocTest<FilterSheetCubit, FilterSheetState>(
      'reset returns to the scope but keeps tab, sort and search',
      build: () => build(
        initial: const LinkQuery(
          host: 'youtube.com',
          categories: {'Read'},
          readFilter: ReadFilter.unread,
          sort: LinkSort.oldest,
          search: 'pizza',
        ),
        scope: const LinkQuery(host: 'youtube.com'),
      ),
      act: (cubit) => cubit.reset(),
      verify: (cubit) => expect(
        cubit.state.query,
        const LinkQuery(
          host: 'youtube.com',
          readFilter: ReadFilter.unread,
          sort: LinkSort.oldest,
          search: 'pizza',
        ),
      ),
    );
  });

  group('CategoryPickerCubit', () {
    LinkModel link(String id, String url) =>
        LinkModel(id: id, url: url, title: id, createdAt: 0);

    setUp(() {
      when(
        () => manager.linkById('a'),
      ).thenReturn(link('a', 'https://youtu.be/1'));
      when(
        () => manager.linkById('b'),
      ).thenReturn(link('b', 'https://www.youtube.com/watch?v=2'));
      when(
        () => manager.linkById('c'),
      ).thenReturn(link('c', 'https://amazon.in/x'));
      when(() => manager.getCategoryCountsForHost(any())).thenReturn(const []);
    });

    test('links from one site get its suggestion, picked by default', () {
      final cubit = CategoryPickerCubit(
        manager: manager,
        selectedIds: {'a', 'b'},
      );
      expect(cubit.state.host, 'youtube.com');
      expect(cubit.state.suggested, ['Watch']);
      expect(cubit.state.picked, 'Watch');
      expect(cubit.state.others, ['Read', 'Dev']);
    });

    test('links from different sites get no suggestion', () {
      final cubit = CategoryPickerCubit(
        manager: manager,
        selectedIds: {'a', 'c'},
      );
      expect(cubit.state.host, '');
      expect(cubit.state.suggested, isEmpty);
      expect(cubit.state.picked, isNull);
      expect(cubit.state.others, ['Watch', 'Read', 'Dev']);
    });

    blocTest<CategoryPickerCubit, CategoryPickerState>(
      'pick changes the chosen category',
      build: () => CategoryPickerCubit(manager: manager, selectedIds: {'a'}),
      act: (cubit) => cubit.pick('Dev'),
      verify: (cubit) => expect(cubit.state.picked, 'Dev'),
    );
  });

  group('InboxBadgeCubit', () {
    late StreamController<BoxEvent> changes;

    setUp(() {
      changes = StreamController<BoxEvent>.broadcast();
      when(() => manager.watchLinks()).thenAnswer((_) => changes.stream);
    });

    tearDown(() => changes.close());

    blocTest<InboxBadgeCubit, int>(
      'emits only when the Inbox count changes',
      build: () {
        var count = 2;
        when(() => manager.inboxCount).thenAnswer((_) => count);
        Future<void>.delayed(Duration.zero, () {
          changes.add(BoxEvent('x', null, false)); // still 2: no emit
          count = 3;
          changes.add(BoxEvent('y', null, false));
        });
        return InboxBadgeCubit(manager: manager);
      },
      wait: const Duration(milliseconds: 10),
      expect: () => [3],
    );
  });
}

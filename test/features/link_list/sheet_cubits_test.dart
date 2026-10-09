import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/features/link_list/bloc/category_picker_cubit.dart';
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

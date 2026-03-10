import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/features/links/bloc/link_bloc.dart';
import 'package:link_hive/features/links/bloc/link_event.dart';
import 'package:link_hive/features/links/bloc/link_state.dart';
import 'package:link_hive/features/links/models/link_model.dart';
import 'package:link_hive/features/links/models/category_model.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockLinkRepository extends Mock implements LinkRepository {}

void main() {
  group('LinkBloc', () {
    late MockLinkRepository mockRepository;
    late StreamController<BoxEvent> boxStreamController;

    final testLink = LinkModel(id: '1', url: 'https://flutter.dev', title: 'Flutter', createdAt: 123456789);
    const testCategory = CategoryModel(id: 'cat1', name: 'Dev');

    setUp(() {
      mockRepository = MockLinkRepository();
      boxStreamController = StreamController<BoxEvent>.broadcast();

      when(() => mockRepository.watchLinksBox()).thenAnswer((_) => boxStreamController.stream);
      when(() => mockRepository.getCategories()).thenReturn([testCategory]);
    });

    tearDown(() {
      boxStreamController.close();
    });

    test('initial state is LinkInitial', () {
      final bloc = LinkBloc(repository: mockRepository);
      expect(bloc.state, const LinkInitial());
      bloc.close();
    });

    blocTest<LinkBloc, LinkState>(
      'emits [LinkLoading, LinksLoaded] when LinkLoadRequested is added',
      build: () {
        when(() => mockRepository.queryLinks(limit: 20, offset: 0)).thenReturn([testLink]);
        return LinkBloc(repository: mockRepository);
      },
      act: (bloc) => bloc.add(const LinkLoadRequested()),
      expect: () => [
        const LinkLoading(),
        LinksLoaded(links: [testLink], hasReachedMax: true, offset: 1, customCategories: const [testCategory]),
      ],
    );

    blocTest<LinkBloc, LinkState>(
      'reloads when boxStream emits and state is LinksLoaded',
      build: () {
        when(() => mockRepository.queryLinks(limit: 20, offset: 0)).thenReturn([testLink]);
        return LinkBloc(repository: mockRepository);
      },
      seed: () => const LinksLoaded(links: [], hasReachedMax: true, offset: 0, customCategories: []),
      act: (bloc) {
        boxStreamController.add(BoxEvent('new_key', testLink, false));
      },
      // Since it's seeded with LinksLoaded, the stream event will trigger add(LinkLoadRequested())
      expect: () => [
        const LinkLoading(),
        LinksLoaded(links: [testLink], hasReachedMax: true, offset: 1, customCategories: const [testCategory]),
      ],
    );
  });
}

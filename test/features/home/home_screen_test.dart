import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/core/utils/locator.dart';
import 'package:link_hive/features/home/home.dart';
import 'package:link_hive/features/links/models/link_model.dart';
import 'package:link_hive/features/links/models/category_model.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';
import 'package:link_hive/l10n/localization/app_localizations.dart';
import 'package:link_hive/core/theme/app_theme.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mocktail_image_network/mocktail_image_network.dart';

// Mock LinkRepository to isolate HomeScreen from actual database queries
class MockLinkRepository extends Mock implements LinkRepository {}

void main() {
  group('HomeScreen Widget Tests', () {
    late MockLinkRepository mockRepository;
    late StreamController<BoxEvent> boxStreamController;

    setUp(() {
      mockRepository = MockLinkRepository();
      boxStreamController = StreamController<BoxEvent>.broadcast();
      
      // Inject the mocked repository into locator so HomeScreen can build LinkBloc successfully
      locator.registerSingleton<LinkRepository>(mockRepository);

      when(() => mockRepository.watchLinksBox()).thenAnswer((_) => boxStreamController.stream);
      when(() => mockRepository.getCategories()).thenReturn(const <CategoryModel>[]);
    });

    tearDown(() {
      boxStreamController.close();
      // Ensure locator is cleaned up after each test to prevent side-effects
      locator.reset();
    });

    Widget buildTestWidget() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildLinkHiveTheme(),
        home: const HomeScreen(), // Test the actual HomeScreen widget
      );
    }

    testWidgets('shows empty state when no links exist', (tester) async {
      // 1. Mock the repository to return an empty list
      when(() => mockRepository.queryLinks(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            query: any(named: 'query'),
            category: any(named: 'category'),
            priority: any(named: 'priority'),
          )).thenReturn([]);

      // 2. Build the widget
      await tester.pumpWidget(buildTestWidget());
      
      // 3. Wait for LinkBloc to finish loading and transition to LinksLoaded
      await tester.pumpAndSettle();

      // 4. Verify empty state elements are displayed
      expect(find.byIcon(Icons.link_rounded), findsOneWidget);
      expect(find.text('No Links yet!'), findsWidgets); // using string since l10n is processed
    });

    testWidgets('renders links in the list', (tester) async {
      final testLink = LinkModel(
        id: '1',
        title: 'Flutter Dev',
        url: 'https://flutter.dev',
        image: '',
        categories: [],
        priority: 'Normal',
        isSynced: true,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        syncedAt: DateTime.now().millisecondsSinceEpoch,
      );

      // 1. Mock repository to return one link
      when(() => mockRepository.queryLinks(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            query: any(named: 'query'),
            category: any(named: 'category'),
            priority: any(named: 'priority'),
          )).thenReturn([testLink]);

      // Wrap in mockNetworkImages to safely render CachedNetworkImage or fallbacks
      await mockNetworkImages(() async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // 2. Verify the link is rendered using its title
        expect(find.text('Flutter Dev'), findsOneWidget);
        expect(find.text('flutter.dev'), findsOneWidget); // host extraction test
      });
    });
  });
}

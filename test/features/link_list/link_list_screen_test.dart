import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/core/services/sync_engine.dart';
import 'package:link_hive/core/theme/app_theme.dart';
import 'package:link_hive/core/utils/locator.dart';
import 'package:link_hive/features/link_list/link_list_screen.dart';
import 'package:link_hive/features/links/manager/link_manager.dart';
import 'package:link_hive/features/links/models/link_model.dart';
import 'package:link_hive/features/shell/app_shell.dart';
import 'package:link_hive/l10n/localization/app_localizations.dart';
import 'package:link_hive/sharedWidgets/app_bottom_nav.dart';
import 'package:mocktail/mocktail.dart';

class MockLinkManager extends Mock implements LinkManager {}

class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late MockLinkManager manager;
  late StreamController<BoxEvent> changes;

  final links = [
    LinkModel(
      id: 'a',
      url: 'https://youtu.be/1',
      title: 'Pizza video',
      createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    ),
    LinkModel(
      id: 'b',
      url: 'https://amazon.in/x',
      title: 'Keyboard',
      createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    ),
  ];

  setUpAll(() => registerFallbackValue(const LinkQuery()));

  setUp(() {
    manager = MockLinkManager();
    changes = StreamController<BoxEvent>.broadcast();
    locator.registerSingleton<LinkManager>(manager);
    locator.registerSingleton<SyncEngine>(MockSyncEngine());
    when(() => manager.watchLinks()).thenAnswer((_) => changes.stream);
    when(() => manager.getLibraryStats()).thenReturn(
      const LibraryStats(total: 2, unread: 2, high: 1, uncategorized: 1),
    );
    when(
      () => manager.getSourceCounts(within: any(named: 'within')),
    ).thenReturn(const [
      NamedCount('youtube.com', 1),
      NamedCount('amazon.in', 1),
    ]);
    when(
      () => manager.getCategoryCounts(),
    ).thenReturn(const [NamedCount('Watch', 1)]);
    when(
      () => manager.findLinks(
        any(),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenReturn(links);
    when(() => manager.countLinks(any())).thenReturn(links.length);
  });

  tearDown(() {
    changes.close();
    AppShell.navVisible.value = true;
    locator.reset();
  });

  Widget app() => MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildLinkHiveTheme(),
    routerConfig: GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const LinkListScreen())],
    ),
  );

  testWidgets('shows search, quick chips, filter buttons and the links', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Links'), findsOneWidget);
    expect(find.text('Search 2 links...'), findsOneWidget);
    expect(find.text('Unread'), findsOneWidget);
    expect(find.text('Saved 2×+'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Newest first'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('Pizza video'), findsOneWidget);
  });

  testWidgets('shows the empty state when nothing is saved yet', (
    tester,
  ) async {
    when(() => manager.getLibraryStats()).thenReturn(const LibraryStats());
    when(
      () => manager.findLinks(
        any(),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenReturn(const []);
    when(() => manager.countLinks(any())).thenReturn(0);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('No Links yet!'), findsOneWidget);
  });

  testWidgets('a quick chip filters the list in place', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();

    verify(
      () => manager.findLinks(
        const LinkQuery(readFilter: ReadFilter.unread),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).called(greaterThan(0));
    // A filter is on, so the match count shows.
    expect(find.text('2 links'), findsOneWidget);
  });

  testWidgets('the Source sheet picks a site and the button turns into it', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Source'));
    await tester.pumpAndSettle();
    expect(find.text('All sites'), findsOneWidget);

    await tester.tap(find.text('amazon.in').last);
    await tester.pumpAndSettle();

    verify(
      () => manager.findLinks(
        const LinkQuery(host: 'amazon.in'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).called(greaterThan(0));
    // The button now names the site instead of "Source".
    expect(find.text('Source'), findsNothing);
  });

  testWidgets('the Category sheet offers "No category"', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No category'));
    await tester.pumpAndSettle();

    verify(
      () => manager.findLinks(
        const LinkQuery(uncategorized: true),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).called(greaterThan(0));
  });

  testWidgets(
    'Select enters selection mode: action bar shows, nav hides, close ends it',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.checklist_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Select links'), findsOneWidget);
      expect(find.text('Mark read'), findsOneWidget);
      expect(AppShell.navVisible.value, isFalse);

      await tester.tap(find.text('Keyboard'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Mark read'), findsNothing);
      expect(AppShell.navVisible.value, isTrue);
    },
  );

  testWidgets('long-press also starts selection with that link picked', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Pizza video'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('floating nav labels only the active tab and shows the badge', (
    tester,
  ) async {
    int? tapped;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLinkHiveTheme(),
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(
            currentIndex: 0,
            onTap: (i) => tapped = i,
            items: const [
              AppBottomNavItem(
                icon: Icons.collections_bookmark_rounded,
                label: 'Links',
              ),
              AppBottomNavItem(icon: Icons.today_rounded, label: 'Today'),
              AppBottomNavItem(
                icon: Icons.inbox_rounded,
                label: 'Inbox',
                badgeCount: 4,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Links'), findsOneWidget);
    expect(find.text('Today'), findsNothing);
    expect(find.text('4'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.inbox_rounded));
    expect(tapped, 2);
  });
}

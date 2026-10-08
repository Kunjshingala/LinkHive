import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/core/services/sync_engine.dart';
import 'package:link_hive/core/theme/app_theme.dart';
import 'package:link_hive/core/utils/locator.dart';
import 'package:link_hive/core/utils/navigation/route.dart';
import 'package:link_hive/features/library/library_screen.dart';
import 'package:link_hive/features/library/link_list/link_list_screen.dart';
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
      createdAt: 0,
    ),
    LinkModel(
      id: 'b',
      url: 'https://amazon.in/x',
      title: 'Keyboard',
      createdAt: 0,
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
      const LibraryStats(total: 2, unread: 2, high: 1, savedTwicePlus: 1),
    );
    when(() => manager.getSourceCounts()).thenReturn(const [
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

  /// The Library and its list under a minimal router, like the real branch.
  Widget app() => MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildLinkHiveTheme(),
    routerConfig: GoRouter(
      initialLocation: '/library',
      routes: [
        GoRoute(
          path: '/library',
          builder: (_, _) => const LibraryScreen(),
          routes: [
            GoRoute(
              path: 'links',
              name: MyRouteName.linkList,
              builder: (_, state) =>
                  LinkListScreen(args: state.extra! as LinkListArgs),
            ),
          ],
        ),
      ],
    ),
  );

  testWidgets('Library shows counts, sources and categories', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Unread'), findsOneWidget);
    expect(find.text('Saved 2×+'), findsOneWidget);
    expect(find.text('youtube.com'), findsOneWidget);
    expect(find.text('amazon.in'), findsOneWidget);
    expect(find.text('Watch'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('All links'), 200);
    expect(find.text('All links'), findsOneWidget);
  });

  testWidgets('Library shows the empty state with no links', (tester) async {
    when(() => manager.getLibraryStats()).thenReturn(const LibraryStats());
    when(() => manager.getSourceCounts()).thenReturn(const []);
    when(() => manager.getCategoryCounts()).thenReturn(const []);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('No Links yet!'), findsOneWidget);
  });

  testWidgets('tapping a source opens its list, scoped to that site', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('youtube.com'));
    await tester.pumpAndSettle();

    expect(find.byType(LinkListScreen), findsOneWidget);
    final screen = tester.widget<LinkListScreen>(find.byType(LinkListScreen));
    expect(screen.args.query, const LinkQuery(host: 'youtube.com'));
    expect(find.text('Pizza video'), findsOneWidget);
  });

  testWidgets(
    'long-press starts selection: action bar shows, nav hides, close ends it',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('All links'), 200);
      await tester.tap(find.text('All links'));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Pizza video'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Mark read'), findsOneWidget);
      expect(AppShell.navVisible.value, isFalse);

      await tester.tap(find.text('Keyboard'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Mark read'), findsNothing);
      expect(AppShell.navVisible.value, isTrue);
    },
  );

  testWidgets('bottom nav reports taps and shows the Inbox badge', (
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

    expect(find.text('4'), findsOneWidget);
    await tester.tap(find.text('Inbox'));
    expect(tapped, 1);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/features/links/models/link_model.dart';
import 'package:link_hive/sharedWidgets/link_card.dart';
import 'package:link_hive/l10n/localization/app_localizations.dart';
import 'package:link_hive/core/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:link_hive/core/utils/locator.dart';
import 'package:link_hive/features/links/manager/link_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mocktail_image_network/mocktail_image_network.dart';

class MockLinkManager extends Mock implements LinkManager {}

void main() {
  group('LinkCard', () {
    late LinkModel testLink;
    late MockLinkManager manager;

    setUpAll(() {
      registerFallbackValue(LinkModel(id: 'fallback', url: '', title: '', createdAt: 0));
    });

    setUp(() {
      // The card resolves LinkManager from the locator on tap, so the test
      // has to provide one. Registering a mock also lets the tap assertion
      // check the real outcome (the link is opened) rather than only that
      // editing was not triggered.
      manager = MockLinkManager();
      when(() => manager.openLink(any())).thenAnswer((_) async {});
      if (locator.isRegistered<LinkManager>()) {
        locator.unregister<LinkManager>();
      }
      locator.registerSingleton<LinkManager>(manager);

      testLink = LinkModel(
        id: '1',
        title: 'Flutter Dev',
        url: 'https://flutter.dev',
        description: 'Flutter SDK documentation',
        image: 'https://flutter.dev/images/flutter-logo-sharing.png',
        categories: ['tech', 'flutter'],
        priority: 'High',
        isSynced: true,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        syncedAt: DateTime.now().millisecondsSinceEpoch,
      );
    });

    Widget buildTestWidget(LinkModel link, {String searchQuery = ''}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Using the built-in app theme to prevent NeoBrutal extension crash
        theme: buildLinkHiveTheme(),
        home: Scaffold(
          body: LinkCard(
            link: link,
            searchQuery: searchQuery,
            onDelete: () {},
            onEdit: () {},
          ),
        ),
      );
    }

    testWidgets('displays title, URL, and high priority icon', (tester) async {
      await mockNetworkImages(() async {
        await tester.pumpWidget(buildTestWidget(testLink));

        // Verify title
        expect(find.text('Flutter Dev'), findsOneWidget);
        
        // Verify URL (host)
        expect(find.text('flutter.dev'), findsOneWidget);

        // High priority shows text "High"
        expect(find.text('High'), findsOneWidget);
      });
    });

    testWidgets('shows offline cloud icon when not synced', (tester) async {
      final unsyncedLink = testLink.copyWith(isSynced: false);
      
      await mockNetworkImages(() async {
        await tester.pumpWidget(buildTestWidget(unsyncedLink));

        // Verify cloud_off_rounded icon is present
        expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      });
    });

    testWidgets('highlights matching title and host text', (tester) async {
      await mockNetworkImages(() async {
        await tester.pumpWidget(buildTestWidget(testLink, searchQuery: 'flutter'));

        final richTexts = tester.widgetList<RichText>(find.byType(RichText));
        final highlighted = richTexts.any(
          (richText) => _containsHighlightedSpan(richText.text),
        );
        expect(highlighted, isTrue);
      });
    });

    testWidgets('displays letter placeholder when image is empty', (tester) async {
      final noImageLink = testLink.copyWith(image: '');

      await tester.pumpWidget(buildTestWidget(noImageLink));

      // CachedNetworkImage should NOT be there
      expect(find.byType(CachedNetworkImage), findsNothing);
      // Fallback letter 'F' (from Flutter Dev) should be there
      expect(find.text('F'), findsWidgets);
    });

    testWidgets('opens the link from the card body instead of editing', (tester) async {
      var editCalled = false;

      await mockNetworkImages(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildLinkHiveTheme(),
            home: Scaffold(
              body: LinkCard(
                link: testLink,
                onEdit: () => editCalled = true,
              ),
            ),
          ),
        );

        await tester.tap(find.text('Flutter Dev'));
        await tester.pump();
      });

      expect(editCalled, isFalse);
      // The card body opens the link through the manager, which is also what
      // marks it read and resurfaced. Before the LinkManager refactor this
      // path launched the URL and recorded nothing.
      verify(() => manager.openLink(testLink)).called(1);
    });
  });
}

bool _containsHighlightedSpan(InlineSpan span) {
  if (span.style?.backgroundColor != null) return true;
  return span is TextSpan ? span.children?.any(_containsHighlightedSpan) ?? false : false;
}

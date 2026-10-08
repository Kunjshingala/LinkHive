import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:link_hive/core/theme/app_theme.dart';
import 'package:link_hive/core/utils/locator.dart';
import 'package:link_hive/features/links/manager/link_manager.dart';
import 'package:link_hive/features/links/models/link_model.dart';
import 'package:link_hive/l10n/localization/app_localizations.dart';
import 'package:link_hive/sharedWidgets/version_picker_sheet.dart';
import 'package:mocktail/mocktail.dart';

class MockLinkManager extends Mock implements LinkManager {}

/// "Which version?" when a link was saved under more than one URL.
void main() {
  late MockLinkManager manager;

  const plain =
      'https://luxury.tatacliq.com/sennheiser-ie-200/p-mp000000030311042';
  const affiliate = '$plain?utm_source=youtube&utm_content=YT3&cid=YTaffiliate';

  final single = LinkModel(id: '1', url: plain, title: 'IE 200', createdAt: 1);
  final twoVersions = single.copyWith(otherUrls: [affiliate]);

  setUpAll(() => registerFallbackValue(single));

  setUp(() {
    manager = MockLinkManager();
    when(
      () => manager.openLink(any(), url: any(named: 'url')),
    ).thenAnswer((_) async {});
    when(() => manager.openLink(any())).thenAnswer((_) async {});
    when(() => manager.keepOnlyVersion(any(), any())).thenAnswer((_) async {});
    if (locator.isRegistered<LinkManager>()) locator.unregister<LinkManager>();
    locator.registerSingleton<LinkManager>(manager);
  });

  /// A button that runs [onTap] under a go_router app, like production: the
  /// sheet closes itself with `context.pop()`, which needs a GoRouter.
  Widget host(Future<void> Function(BuildContext) onTap) => MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildLinkHiveTheme(),
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => onTap(context),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  testWidgets('a link with one URL opens directly, no sheet', (tester) async {
    await tester.pumpWidget(host((c) => openLinkWithVersions(c, single)));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Which version?'), findsNothing);
    verify(() => manager.openLink(single)).called(1);
  });

  testWidgets('lists the main URL first, then each version with its tracking', (
    tester,
  ) async {
    await tester.pumpWidget(host((c) => openLinkWithVersions(c, twoVersions)));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Which version?'), findsOneWidget);
    expect(find.text('Saved first · no tracking'), findsOneWidget);
    expect(find.text('utm_source · utm_content · cid'), findsOneWidget);
  });

  testWidgets('Open launches the selected version', (tester) async {
    await tester.pumpWidget(host((c) => openLinkWithVersions(c, twoVersions)));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('version:$affiliate')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('versionPickerOpen')));
    await tester.pumpAndSettle();

    verify(() => manager.openLink(twoVersions, url: affiliate)).called(1);
    verifyNever(() => manager.keepOnlyVersion(any(), any()));
  });

  testWidgets('"Keep only this one" keeps the pick, then opens it', (
    tester,
  ) async {
    await tester.pumpWidget(host((c) => openLinkWithVersions(c, twoVersions)));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('version:$affiliate')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('versionPickerKeepOnly')));
    await tester.pumpAndSettle();

    verifyInOrder([
      () => manager.keepOnlyVersion(twoVersions, affiliate),
      () => manager.openLink(twoVersions, url: affiliate),
    ]);
  });

  testWidgets('dismissing the sheet opens nothing', (tester) async {
    await tester.pumpWidget(host((c) => openLinkWithVersions(c, twoVersions)));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    verifyNever(() => manager.openLink(any(), url: any(named: 'url')));
    verifyNever(() => manager.openLink(any()));
  });
}

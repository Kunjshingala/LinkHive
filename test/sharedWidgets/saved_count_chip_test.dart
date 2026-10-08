import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/theme/app_theme.dart';
import 'package:link_hive/l10n/localization/app_localizations.dart';
import 'package:link_hive/sharedWidgets/saved_count_chip.dart';

/// "Saved N×" on the Today card (design review D10, D12).
void main() {
  Widget host(Widget child, {Locale locale = const Locale('en')}) =>
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildLinkHiveTheme(),
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('hidden for a link saved once', (tester) async {
    await tester.pumpWidget(host(const SavedCountChip(count: 1)));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('shows the count from the second save', (tester) async {
    await tester.pumpWidget(host(const SavedCountChip(count: 3)));
    expect(find.text('Saved 3×'), findsOneWidget);
  });

  testWidgets('screen readers hear words, not the × symbol', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const SavedCountChip(count: 3)));

    expect(find.bySemanticsLabel('Saved 3 times'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('×')), findsNothing);
    handle.dispose();
  });

  testWidgets('Arabic uses words and its plural forms', (tester) async {
    await tester.pumpWidget(
      host(const SavedCountChip(count: 2), locale: const Locale('ar')),
    );
    expect(find.text('حُفظ مرتين'), findsOneWidget);

    await tester.pumpWidget(
      host(const SavedCountChip(count: 3), locale: const Locale('ar')),
    );
    expect(find.text('حُفظ 3 مرات'), findsOneWidget);
  });

  testWidgets(
    'Arabic chip next to a long host wraps without overflow at 1.3x',
    (tester) async {
      // Set on the test window: MaterialApp builds its own MediaQuery from
      // it, so wrapping the app in a MediaQuery would not take effect.
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        host(
          SizedBox(
            width: 280,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: const [
                Text(
                  'subdomain.example-news-site.co.uk',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SavedCountChip(count: 5),
              ],
            ),
          ),
          locale: const Locale('ar'),
        ),
      );

      expect(
        MediaQuery.of(tester.element(find.byType(SavedCountChip))).textScaler,
        isA<TextScaler>().having((s) => s.scale(10), "scale(10)", 13),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SavedCountChip), findsOneWidget);
    },
  );
}

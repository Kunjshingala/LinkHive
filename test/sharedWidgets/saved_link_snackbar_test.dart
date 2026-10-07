import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/theme/app_theme.dart';
import 'package:link_hive/l10n/localization/app_localizations.dart';
import 'package:link_hive/sharedWidgets/saved_link_snackbar.dart';

/// Layout of the save / merge bar (design review D3, D4, D7, D13).
void main() {
  Widget host(
    Widget content, {
    Locale locale = const Locale('en'),
    double width = 360,
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildLinkHiveTheme(),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width - 32, child: content),
        ),
      ),
    );
  }

  // On a fresh save the "Add details" button shares one row with the text.
  // The test font draws every glyph as a full em square, which makes that
  // label far wider than any real font, so fresh-row tests use a wider host.
  // Merge-layout tests (actions on their own row) stay at a real 360dp width.
  const freshWidth = 600.0;

  testWidgets('a fresh save is one row with the green check and no badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SavedLinkSnackContent(onAddDetails: () {}, onUndo: () {}),
        width: freshWidth,
      ),
    );

    expect(find.text('Saved to LinkHive'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byKey(const ValueKey('savedLinkMergeBadge')), findsNothing);
    expect(find.text('Add details'), findsOneWidget);
  });

  testWidgets('a merge shows the badge, the full message and its actions', (
    tester,
  ) async {
    const message = "Already saved Sep 28, it'll come back in Today";
    await tester.pumpWidget(
      host(
        SavedLinkSnackContent(
          message: message,
          onAddDetails: () {},
          onUndo: () {},
        ),
      ),
    );

    expect(find.text(message), findsOneWidget);
    expect(find.byKey(const ValueKey('savedLinkMergeBadge')), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    // Message sits above the actions, not squeezed beside them.
    final textBottom = tester.getBottomLeft(find.text(message)).dy;
    final undoTop = tester
        .getTopLeft(find.byKey(const ValueKey('savedLinkUndo')))
        .dy;
    expect(textBottom, lessThanOrEqualTo(undoTop));
  });

  testWidgets('the manual-merge bar offers Edit instead of Add details', (
    tester,
  ) async {
    var edited = false;
    await tester.pumpWidget(
      host(
        SavedLinkSnackContent(
          message: 'Already saved today. Kept your existing details.',
          onEdit: () => edited = true,
          onUndo: () {},
        ),
      ),
    );

    expect(find.text('Add details'), findsNothing);
    await tester.tap(find.text('Edit'));
    expect(edited, isTrue);
  });

  testWidgets('Undo fires', (tester) async {
    var undone = false;
    await tester.pumpWidget(
      host(SavedLinkSnackContent(onUndo: () => undone = true)),
    );

    await tester.tap(find.byKey(const ValueKey('savedLinkUndo')));
    expect(undone, isTrue);
  });

  testWidgets('buttons meet the 44dp touch target', (tester) async {
    await tester.pumpWidget(
      host(
        SavedLinkSnackContent(onAddDetails: () {}, onUndo: () {}),
        width: freshWidth,
      ),
    );

    final undo = tester.getSize(find.byKey(const ValueKey('savedLinkUndo')));
    expect(undo.height, greaterThanOrEqualTo(44));
    expect(undo.width, greaterThanOrEqualTo(44));
  });

  testWidgets(
    'a long Hindi merge message fits at 360dp and 1.3x text without overflow',
    (tester) async {
      // Set on the test window: MaterialApp builds its own MediaQuery from
      // it, so wrapping the app in a MediaQuery would not take effect.
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        host(
          SavedLinkSnackContent(
            message: 'पहले से सहेजा गया (28 सित॰ 2025), यह "आज" में वापस आएगा',
            onAddDetails: () {},
            onUndo: () {},
          ),
          locale: const Locale('hi'),
        ),
      );

      expect(
        MediaQuery.of(
          tester.element(find.byType(SavedLinkSnackContent)),
        ).textScaler,
        isA<TextScaler>().having((s) => s.scale(10), "scale(10)", 13),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Arabic puts the actions on the leading (left) edge in RTL', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SavedLinkSnackContent(
          message: 'محفوظ مسبقًا (اليوم)، وسيعود في «اليوم»',
          onAddDetails: () {},
          onUndo: () {},
        ),
        locale: const Locale('ar'),
      ),
    );

    final undo = tester.getCenter(find.byKey(const ValueKey('savedLinkUndo')));
    final screenCenter = tester.getCenter(find.byType(Scaffold));
    expect(undo.dx, lessThan(screenCenter.dx));
    expect(tester.takeException(), isNull);
  });
}

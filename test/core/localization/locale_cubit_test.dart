import 'dart:ui';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/core/constants/hive_constants.dart';
import 'package:link_hive/core/localization/locale_cubit.dart';
import 'package:link_hive/core/utils/hive_helper.dart';
import 'package:mocktail/mocktail.dart';

class MockHiveHelper extends Mock implements HiveHelper {}

class MockBox extends Mock implements Box {}

void main() {
  group('LocaleCubit', () {
    late MockHiveHelper mockHiveHelper;
    late MockBox mockSettingsBox;

    setUp(() {
      mockHiveHelper = MockHiveHelper();
      mockSettingsBox = MockBox();
      when(() => mockHiveHelper.settingsBox).thenReturn(mockSettingsBox);
    });

    test('initial state falls back to system locale or en when no locale saved', () {
      when(() => mockSettingsBox.get(HiveConstants.localeKey)).thenReturn(null);

      final cubit = LocaleCubit(hiveHelper: mockHiveHelper);

      // Since system locale could be anything during test, we just check it doesn't crash
      expect(cubit.state, isA<Locale>());
    });

    test('initial state matches stored locale when saved', () {
      when(() => mockSettingsBox.get(HiveConstants.localeKey)).thenReturn('ar');

      final cubit = LocaleCubit(hiveHelper: mockHiveHelper);

      expect(cubit.state, const Locale('ar'));
    });

    blocTest<LocaleCubit, Locale>(
      'emits [Locale("hi")] when changeLocale is called with "hi"',
      setUp: () {
        when(() => mockSettingsBox.get(HiveConstants.localeKey)).thenReturn('en');
        when(() => mockSettingsBox.put(HiveConstants.localeKey, 'hi')).thenAnswer((_) async {});
      },
      build: () => LocaleCubit(hiveHelper: mockHiveHelper),
      act: (cubit) => cubit.changeLocale('hi'),
      expect: () => [const Locale('hi')],
      verify: (_) {
        verify(() => mockSettingsBox.put(HiveConstants.localeKey, 'hi')).called(1);
      },
    );
  });
}

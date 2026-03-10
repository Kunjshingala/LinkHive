import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/core/constants/hive_constants.dart';
import 'package:link_hive/core/theme/theme_cubit.dart';
import 'package:link_hive/core/utils/hive_helper.dart';
import 'package:mocktail/mocktail.dart';

class MockHiveHelper extends Mock implements HiveHelper {}

class MockBox extends Mock implements Box {}

void main() {
  group('ThemeCubit', () {
    late MockHiveHelper mockHiveHelper;
    late MockBox mockSettingsBox;

    setUp(() {
      mockHiveHelper = MockHiveHelper();
      mockSettingsBox = MockBox();
      when(() => mockHiveHelper.settingsBox).thenReturn(mockSettingsBox);
    });

    test('initial state is ThemeMode.system when no theme is saved', () {
      when(() => mockSettingsBox.get(HiveConstants.themeKey)).thenReturn(null);

      final cubit = ThemeCubit(hiveHelper: mockHiveHelper);

      expect(cubit.state, ThemeMode.system);
    });

    test('initial state is ThemeMode.dark when dark theme is saved', () {
      when(() => mockSettingsBox.get(HiveConstants.themeKey)).thenReturn('dark');

      final cubit = ThemeCubit(hiveHelper: mockHiveHelper);

      expect(cubit.state, ThemeMode.dark);
    });

    blocTest<ThemeCubit, ThemeMode>(
      'emits [ThemeMode.light] when changeTheme is called with ThemeMode.light',
      setUp: () {
        when(() => mockSettingsBox.get(HiveConstants.themeKey)).thenReturn(null);
        when(() => mockSettingsBox.put(HiveConstants.themeKey, 'light')).thenAnswer((_) async {});
      },
      build: () => ThemeCubit(hiveHelper: mockHiveHelper),
      act: (cubit) => cubit.changeTheme(ThemeMode.light),
      expect: () => [ThemeMode.light],
      verify: (_) {
        verify(() => mockSettingsBox.put(HiveConstants.themeKey, 'light')).called(1);
      },
    );
  });
}

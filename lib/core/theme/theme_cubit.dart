import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../constants/hive_constants.dart';
import '../utils/hive_helper.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  final HiveHelper _hiveHelper;

  ThemeCubit({required HiveHelper hiveHelper}) : _hiveHelper = hiveHelper, super(ThemeMode.system) {
    _loadTheme();
  }

  void _loadTheme() {
    final String? savedTheme = _hiveHelper.settingsBox.get(HiveConstants.themeKey);
    ThemeMode initial = ThemeMode.system;

    if (savedTheme == ThemeMode.light.name) {
      initial = ThemeMode.light;
    } else if (savedTheme == ThemeMode.dark.name) {
      initial = ThemeMode.dark;
    }
    // If savedTheme is null or 'system', initial remains ThemeMode.system

    emit(initial);
  }

  void changeTheme(ThemeMode theme) {
    _hiveHelper.settingsBox.put(HiveConstants.themeKey, theme.name);
    emit(theme);
  }
}

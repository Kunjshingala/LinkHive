import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/localization/app_localizations.dart';
import '../constants/hive_constants.dart';
import '../utils/hive_helper.dart';

class LocaleCubit extends Cubit<Locale> {
  final HiveHelper _hiveHelper;

  LocaleCubit({required HiveHelper hiveHelper}) : _hiveHelper = hiveHelper, super(_getSystemLocale()) {
    _loadLocale();
  }

  static Locale _getSystemLocale() {
    final deviceLocale = PlatformDispatcher.instance.locale.languageCode;
    if (AppLocalizations.supportedLocales.any((locale) => locale.languageCode == deviceLocale)) {
      return Locale(deviceLocale);
    }
    return const Locale('en'); // Default fallback
  }

  void _loadLocale() {
    final box = _hiveHelper.settingsBox;
    final String? storedLocale = box.get(HiveConstants.localeKey);
    if (storedLocale != null) {
      // User has explicitly chosen a locale, override device default
      emit(Locale(storedLocale));
    }
    // If storedLocale is null, the Cubit will naturally stay on the `_getSystemLocale()`
    // ensuring the app follows the device language until the user explicitly changes it.
  }

  Future<void> changeLocale(String languageCode) async {
    final box = _hiveHelper.settingsBox;
    await box.put(HiveConstants.localeKey, languageCode);
    emit(Locale(languageCode));
  }
}

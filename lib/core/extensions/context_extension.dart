import 'package:flutter/material.dart';
import '../../l10n/localization/app_localizations.dart';
import '../theme/app_theme_extension.dart';

extension LocalizedContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

extension AppNeoBrutalThemeContext on BuildContext {
  AppNeoBrutalTheme get neoBrutal => Theme.of(this).extension<AppNeoBrutalTheme>()!;
}

extension ThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => theme.colorScheme;
  TextTheme get text => theme.textTheme;
}

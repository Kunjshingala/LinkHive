import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/localization/locale_cubit.dart';
import 'core/services/receive_shared_intent.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'core/utils/hive_helper.dart';
import 'core/utils/locator.dart';
import 'core/utils/navigation/route.dart';
import 'l10n/localization/app_localizations.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ReceiveSharedIntent? _receiveSharedIntent;

  @override
  void initState() {
    super.initState();
    // Initialize the service once from the locator
    _receiveSharedIntent ??= locator<ReceiveSharedIntent>();
    _receiveSharedIntent?.initialize();
  }

  @override
  void dispose() {
    _receiveSharedIntent?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => LocaleCubit(hiveHelper: locator<HiveHelper>())),
        BlocProvider(create: (_) => ThemeCubit(hiveHelper: locator<HiveHelper>())),
      ],
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
          return BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, themeMode) {
              return MaterialApp.router(
                scaffoldMessengerKey: scaffoldMessengerKey,
                debugShowCheckedModeBanner: false,
                title: 'LinkHive', // Fallback title
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: locale,
                themeMode: themeMode,
                theme: buildLinkHiveTheme(),
                darkTheme: buildLinkHiveDarkTheme(),
                routerConfig: router,
                builder: (context, child) {
                  final mediaQuery = MediaQuery.of(context);

                  return MediaQuery(
                    data: mediaQuery.copyWith(textScaler: TextScaler.noScaling),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

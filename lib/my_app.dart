import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/localization/locale_cubit.dart';
import 'core/services/home_widget_service.dart';
import 'core/services/receive_shared_intent.dart';
import 'core/services/resurface_notification_service.dart';
import 'core/services/sync_service.dart';
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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  ReceiveSharedIntent? _receiveSharedIntent;
  HomeWidgetService? _homeWidgetService;

  /// Created here rather than in build so the notification service can start
  /// in the saved language (see initState).
  late final LocaleCubit _localeCubit = LocaleCubit(
    hiveHelper: locator<HiveHelper>(),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize the service once from the locator
    _receiveSharedIntent ??= locator<ReceiveSharedIntent>();
    _receiveSharedIntent?.initialize();
    // Fire-and-forget: schedules the Daily Resurface notification. Runs after
    // the router is attached (needed for a cold-start notification tap to
    // navigate), fails silently on its own — see
    // ResurfaceNotificationService.initialize().
    locator<ResurfaceNotificationService>().initialize(
      locale: _localeCubit.state,
    );
    // Same fire-and-forget pattern: pushes initial data to the home-screen
    // widget and starts watching for changes. Android only for now — see
    // HomeWidgetService's doc comment.
    _homeWidgetService ??= locator<HomeWidgetService>();
    _homeWidgetService?.initialize(locale: _localeCubit.state);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      locator<SyncService>().requestSync(pull: true);
    }
  }

  @override
  void didChangePlatformBrightness() {
    // Android doesn't redraw home screen widgets when the system theme
    // flips, so the widget would keep its old colors until the next data
    // change or the 30-minute fallback tick. Push an update so light/dark
    // actually follows the system.
    _homeWidgetService?.refresh();
  }

  @override
  void dispose() {
    _receiveSharedIntent?.dispose();
    _homeWidgetService?.dispose();
    _localeCubit.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _localeCubit),
        BlocProvider(
          create: (_) => ThemeCubit(hiveHelper: locator<HiveHelper>()),
        ),
      ],
      child: BlocConsumer<LocaleCubit, Locale>(
        // Keep the daily notification and the home-screen widget in the
        // app's language.
        listener: (context, locale) {
          locator<ResurfaceNotificationService>().setLocale(locale);
          _homeWidgetService?.setLocale(locale);
        },
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
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      child: child ?? const SizedBox.shrink(),
                    ),
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

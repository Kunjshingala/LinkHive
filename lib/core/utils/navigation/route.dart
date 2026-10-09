import 'package:go_router/go_router.dart';

import '../../../features/account/account.dart';
import '../../../features/authentication/login_screen.dart';
import '../../../features/authentication/signup_screen.dart';
import '../../../features/link_list/link_list_screen.dart';
import '../../../features/inbox/inbox_screen.dart';
import '../../../features/links/ui/add_link_screen.dart';
import '../../../features/links/models/link_model.dart';
import '../../../features/shell/app_shell.dart';
import '../../../features/splash/splash_screen.dart';
import '../../../features/sync/conflict_screen.dart';
import '../../../features/today/today_screen.dart';
import '../../../my_app.dart';

final class MyRouteName {
  MyRouteName._();

  static const String splash = '/';
  static const String login = 'login';
  static const String homeScreen = 'home';
  static const String accountScreen = 'accountScreen';
  static const String signup = 'signup';
  static const String addLink = 'addLink';
  static const String editLink = 'editLink';
  static const String conflicts = 'conflicts';
  static const String inbox = 'inbox';
  static const String today = 'today';
  static const String links = 'links';
}

final router = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: MyRouteName.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      name: MyRouteName.login,
      builder: (context, state) => const LoginScreen(),
    ),
    // Old entry point, kept so login, signup, account, share and widget
    // callers keep working: the app's home is now the Links tab.
    GoRoute(
      path: '/home',
      name: MyRouteName.homeScreen,
      redirect: (context, state) => '/links',
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/links',
              name: MyRouteName.links,
              builder: (context, state) => const LinkListScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/today',
              name: MyRouteName.today,
              builder: (context, state) => const TodayScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/inbox',
              name: MyRouteName.inbox,
              builder: (context, state) => const InboxScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/accountScreen',
      name: MyRouteName.accountScreen,
      builder: (context, state) => const AccountScreen(),
    ),
    GoRoute(
      path: '/signup',
      name: MyRouteName.signup,
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/addLink',
      name: MyRouteName.addLink,
      builder: (context, state) {
        // Use a type-safe check — extra is String? when passed from share intent/FAB,
        // null/missing otherwise.
        final prefillUrl = state.extra is String ? state.extra as String : null;
        return AddLinkScreen(prefillUrl: prefillUrl);
      },
    ),
    GoRoute(
      path: '/editLink',
      name: MyRouteName.editLink,
      builder: (context, state) {
        final existingLink = state.extra as LinkModel?;
        return AddLinkScreen(existingLink: existingLink);
      },
    ),
    GoRoute(
      path: '/conflicts',
      name: MyRouteName.conflicts,
      builder: (context, state) => const ConflictScreen(),
    ),
  ],
);

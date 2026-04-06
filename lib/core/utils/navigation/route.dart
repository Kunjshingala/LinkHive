import 'package:go_router/go_router.dart';

import '../../../features/account/account.dart';
import '../../../features/authentication/login_screen.dart';
import '../../../features/authentication/signup_screen.dart';
import '../../../features/home/home.dart';
import '../../../features/links/ui/add_link_screen.dart';
import '../../../features/splash/splash_screen.dart';
import '../../../my_app.dart';

final class MyRouteName {
  MyRouteName._();

  static const String splash = '/';
  static const String login = 'login';
  static const String homeScreen = 'home';
  static const String accountScreen = 'accountScreen';
  static const String signup = 'signup';
  static const String addLink = 'addLink';
}

final router = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', name: MyRouteName.splash, builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', name: MyRouteName.login, builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/home', name: MyRouteName.homeScreen, builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/accountScreen',
      name: MyRouteName.accountScreen,
      builder: (context, state) => const AccountScreen(),
    ),
    GoRoute(path: '/signup', name: MyRouteName.signup, builder: (context, state) => const SignupScreen()),
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
  ],
);

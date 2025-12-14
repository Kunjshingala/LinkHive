import 'package:go_router/go_router.dart';
import 'package:link_hive/screen/account/account.dart';
import 'package:link_hive/screen/home/home.dart';

import '../../my_app.dart';

final router = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', name: 'home', builder: (context, state) => MyHomePage()),
    GoRoute(path: '/accountScreen', name: 'accountScreen', builder: (context, state) => AccountScreen()),
  ],
);
